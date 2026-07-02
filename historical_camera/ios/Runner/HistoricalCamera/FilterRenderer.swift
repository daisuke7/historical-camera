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

/// GPU filter pipeline (docs/05 §4).
///
/// camera CVPixelBuffer -> Metal texture (zero copy) -> eraFilter compute
/// kernel -> pooled BGRA output buffer -> Flutter external texture.
final class FilterRenderer: NSObject, FlutterTexture {
    let width: Int
    let height: Int

    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private var textureCache: CVMetalTextureCache?
    private var pool: CVPixelBufferPool?
    private let startTime = CACurrentMediaTime()

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

        command.addCompletedHandler { [weak self] _ in
            // Keep the CVMetalTexture wrappers alive until the GPU is done.
            withExtendedLifetime((source.cv, destination.cv)) {}
            guard let self else { return }
            self.lock.lock()
            self.latestBuffer = output
            self.isRendering = false
            self.lock.unlock()
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
