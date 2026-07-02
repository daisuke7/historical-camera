import CoreVideo
import Flutter
import Metal
import QuartzCore

/// Shader uniforms: FilterParams (20 floats, docs/02 §2 order) + time +
/// width + height + orientation = 24 floats. Must match `Uniforms` in
/// Shaders.metal exactly (docs/05 §4.2).
struct FilterUniforms {
    var params: FilterParams
    var time: Float
    var width: Float
    var height: Float
    var orientation: Float
}

/// Must match `RotateUniforms` in Shaders.metal.
struct RotateUniforms {
    var dstWidth: UInt32
    var dstHeight: UInt32
    var quarterTurns: UInt32
    var mirror: UInt32
}

/// GPU filter pipeline (docs/05 §4).
///
/// camera CVPixelBuffer -> Metal texture (zero copy) -> eraFilter compute
/// kernel -> pooled BGRA output buffer -> Flutter external texture.
final class FilterRenderer: NSObject, FlutterTexture {
    let width: Int
    let height: Int

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private var textureCache: CVMetalTextureCache?
    private var pool: CVPixelBufferPool?
    private let startTime = CACurrentMediaTime()

    // Still-photo path (docs/05 §3.4): its own command queue so a 12MP
    // dispatch never blocks the preview queue. Accessed only from the
    // controller's writer queue.
    private var stillQueue: MTLCommandQueue?
    private var rotatePipeline: MTLComputePipelineState?

    /// Protects latestBuffer / isRendering / params / orientation.
    private let lock = NSLock()
    private var latestBuffer: CVPixelBuffer?
    private var isRendering = false
    private var currentParams = FilterParams.neutral
    private var currentOrientation: Float = 0

    /// Called after each rendered frame; wired to textureFrameAvailable.
    var onFrameAvailable: (() -> Void)?

    init?(width: Int, height: Int) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary(),
            let function = library.makeFunction(name: "eraFilter"),
            let pipeline = try? device.makeComputePipelineState(function: function)
        else { return nil }
        self.width = width
        self.height = height
        self.device = device
        self.commandQueue = queue
        self.pipeline = pipeline
        super.init()

        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) ==
            kCVReturnSuccess else { return nil }

        // Output pool: 4 buffers for P0, IOSurface-backed for Flutter display
        // (docs/05 §4.1).
        let poolAttrs: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 4,
        ]
        let bufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        guard CVPixelBufferPoolCreate(
            nil, poolAttrs as CFDictionary, bufferAttrs as CFDictionary, &pool
        ) == kCVReturnSuccess else { return nil }
    }

    var params: FilterParams {
        get { lock.lock(); defer { lock.unlock() }; return currentParams }
        set { lock.lock(); currentParams = newValue; lock.unlock() }
    }

    var orientation: Float {
        get { lock.lock(); defer { lock.unlock() }; return currentOrientation }
        set { lock.lock(); currentOrientation = newValue; lock.unlock() }
    }

    /// Preview clock, so still photos share the grain/scratch pattern of the
    /// moment they were shot (docs/03 §4).
    var currentTime: Float {
        Float(fmod(CACurrentMediaTime() - startTime, 3600.0))
    }

    /// Full-resolution still pipeline (docs/05 §3.4): upright rotation (+
    /// mirror for the front camera) followed by the same eraFilter kernel.
    /// Synchronous; call from the writer queue. `params.grainSize` must
    /// already be scaled by the caller (docs/03 §4).
    func renderStill(
        _ input: CVPixelBuffer,
        quarterTurns: Int,
        mirror: Bool,
        params: FilterParams
    ) -> CVPixelBuffer? {
        if stillQueue == nil {
            stillQueue = device.makeCommandQueue()
        }
        guard let queue = stillQueue,
              let source = makeTexture(from: input)
        else { return nil }

        let turns = ((quarterTurns % 4) + 4) % 4
        let srcW = CVPixelBufferGetWidth(input)
        let srcH = CVPixelBufferGetHeight(input)
        let outW = turns % 2 == 1 ? srcH : srcW
        let outH = turns % 2 == 1 ? srcW : srcH

        let bufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outW,
            kCVPixelBufferHeightKey as String: outH,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        var outBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            nil, outW, outH, kCVPixelFormatType_32BGRA,
            bufferAttrs as CFDictionary, &outBuffer
        ) == kCVReturnSuccess,
            let output = outBuffer,
            let destination = makeTexture(from: output),
            let command = queue.makeCommandBuffer()
        else { return nil }

        var filterInput = source.metal

        let needsRotate = turns != 0 || mirror
        if needsRotate {
            if rotatePipeline == nil,
               let library = device.makeDefaultLibrary(),
               let function = library.makeFunction(name: "rotateQuarter") {
                rotatePipeline = try? device.makeComputePipelineState(function: function)
            }
            let midDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: outW, height: outH,
                mipmapped: false)
            midDescriptor.usage = [.shaderWrite, .shaderRead]
            midDescriptor.storageMode = .private
            guard let rotatePipeline,
                  let mid = device.makeTexture(descriptor: midDescriptor),
                  let encoder = command.makeComputeCommandEncoder()
            else { return nil }
            var rotate = RotateUniforms(
                dstWidth: UInt32(outW), dstHeight: UInt32(outH),
                quarterTurns: UInt32(turns), mirror: mirror ? 1 : 0)
            encoder.setComputePipelineState(rotatePipeline)
            encoder.setTexture(source.metal, index: 0)
            encoder.setTexture(mid, index: 1)
            encoder.setBytes(&rotate, length: MemoryLayout<RotateUniforms>.stride, index: 0)
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let groups = MTLSize(
                width: (outW + 15) / 16, height: (outH + 15) / 16, depth: 1)
            encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
            filterInput = mid
        }

        guard let encoder = command.makeComputeCommandEncoder() else { return nil }
        var uniforms = FilterUniforms(
            params: params,
            time: currentTime,
            width: Float(outW),
            height: Float(outH),
            orientation: 0 // the buffer is upright already (docs/03 §4)
        )
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(filterInput, index: 0)
        encoder.setTexture(destination.metal, index: 1)
        encoder.setBytes(&uniforms, length: MemoryLayout<FilterUniforms>.stride, index: 0)
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(
            width: (outW + 15) / 16, height: (outH + 15) / 16, depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        command.commit()
        command.waitUntilCompleted()
        withExtendedLifetime((source.cv, destination.cv)) {}
        guard command.error == nil else { return nil }
        return output
    }

    /// Called on the capture queue for every camera frame. Drops the frame if
    /// the previous one is still on the GPU (backpressure, docs/05 §4.1).
    func enqueue(_ pixelBuffer: CVPixelBuffer) {
        lock.lock()
        if isRendering {
            lock.unlock()
            return
        }
        isRendering = true
        let params = currentParams
        let orientation = currentOrientation
        lock.unlock()

        guard let source = makeTexture(from: pixelBuffer) else {
            finishRendering()
            return
        }

        // Pool exhaustion: skip the frame and keep showing the previous
        // output — never block or crash (docs/05 §4.1).
        var outBuffer: CVPixelBuffer?
        let aux = [kCVPixelBufferPoolAllocationThresholdKey as String: 4]
        guard let pool,
              CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
                  nil, pool, aux as CFDictionary, &outBuffer
              ) == kCVReturnSuccess,
              let output = outBuffer,
              let destination = makeTexture(from: output)
        else {
            finishRendering()
            return
        }

        var uniforms = FilterUniforms(
            params: params,
            time: Float(fmod(CACurrentMediaTime() - startTime, 3600.0)),
            width: Float(width),
            height: Float(height),
            orientation: orientation
        )

        guard let command = commandQueue.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder()
        else {
            finishRendering()
            return
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source.metal, index: 0)
        encoder.setTexture(destination.metal, index: 1)
        encoder.setBytes(&uniforms, length: MemoryLayout<FilterUniforms>.stride, index: 0)
        // dispatchThreadgroups + in-kernel bounds guard; dispatchThreads
        // crashes on pre-A11 GPUs (docs/05 §4.2).
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        command.addCompletedHandler { [weak self] finished in
            // Keep the CVMetalTexture wrappers alive until the GPU is done.
            withExtendedLifetime((source.cv, destination.cv)) {}
            guard let self else { return }
            self.lock.lock()
            self.latestBuffer = output
            self.isRendering = false
            self.lock.unlock()
            #if DEBUG
            self.recordGpuTime(finished.gpuEndTime - finished.gpuStartTime)
            #endif
            self.onFrameAvailable?()
        }
        command.commit()
    }

    // MARK: - FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let buffer = latestBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    func dispose() {
        lock.lock()
        latestBuffer = nil
        lock.unlock()
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
        textureCache = nil
        pool = nil
    }

    // MARK: - Private

    private func finishRendering() {
        lock.lock()
        isRendering = false
        lock.unlock()
    }

    #if DEBUG
    // Rolling GPU-time report to verify the <8 ms budget (docs/08 T6) from
    // `flutter run` logs without attaching Xcode.
    private var gpuTimeSum: Double = 0
    private var gpuFrameCount = 0

    private func recordGpuTime(_ seconds: Double) {
        lock.lock()
        gpuTimeSum += seconds
        gpuFrameCount += 1
        let report = gpuFrameCount >= 120
        let average = report ? gpuTimeSum / Double(gpuFrameCount) : 0
        if report {
            gpuTimeSum = 0
            gpuFrameCount = 0
        }
        lock.unlock()
        if report {
            NSLog("eraFilter GPU avg: %.2f ms (last 120 frames)", average * 1000)
        }
    }
    #endif

    private func makeTexture(
        from buffer: CVPixelBuffer
    ) -> (cv: CVMetalTexture, metal: MTLTexture)? {
        guard let cache = textureCache else { return nil }
        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, buffer, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer),
            0, &cvTexture
        )
        guard result == kCVReturnSuccess,
              let cv = cvTexture,
              let metal = CVMetalTextureGetTexture(cv)
        else { return nil }
        return (cv, metal)
    }
}
