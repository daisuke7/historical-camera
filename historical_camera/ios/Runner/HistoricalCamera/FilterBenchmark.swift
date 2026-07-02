import Metal

/// Offscreen GPU benchmark for the era filter (docs/01 §1.1; the Android
/// sibling is FilterBenchmark.kt, docs/06 §9).
///
/// Runs `frames` compute passes of the eraFilter kernel at width x height
/// with the given parameters on a private queue and returns per-frame GPU
/// times in milliseconds (nil when Metal is unavailable). Shared by the
/// RunnerTests budget test (T12) and the 1080p unlock gate (T14).
enum FilterBenchmark {

    static func run(
        width: Int, height: Int, params: FilterParams,
        frames: Int = 30, warmup: Int = 5
    ) -> [Double]? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "eraFilter"),
              let pipeline = try? device.makeComputePipelineState(function: function)
        else { return nil }

        let srcDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height,
            mipmapped: false)
        srcDescriptor.usage = [.shaderRead]
        let dstDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height,
            mipmapped: false)
        dstDescriptor.usage = [.shaderWrite]
        guard let src = device.makeTexture(descriptor: srcDescriptor),
              let dst = device.makeTexture(descriptor: dstDescriptor)
        else { return nil }

        var times: [Double] = []
        times.reserveCapacity(frames)
        for frame in 0..<(warmup + frames) {
            var uniforms = FilterUniforms(
                params: params,
                // Advance like real 30 fps playback so the 24 Hz reseeded
                // effects (grain/dust) change every frame.
                time: Float(frame) / 30.0,
                width: Float(width),
                height: Float(height),
                orientation: 0)
            guard let command = queue.makeCommandBuffer(),
                  let encoder = command.makeComputeCommandEncoder()
            else { return nil }
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(src, index: 0)
            encoder.setTexture(dst, index: 1)
            encoder.setBytes(
                &uniforms, length: MemoryLayout<FilterUniforms>.stride,
                index: 0)
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let groups = MTLSize(
                width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
            encoder.dispatchThreadgroups(
                groups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted()
            if frame >= warmup {
                times.append((command.gpuEndTime - command.gpuStartTime) * 1000)
            }
        }
        return times
    }

    /// Nearest-rank percentile (`p` in 1...100) of the frame times.
    static func percentileMs(_ times: [Double], _ p: Int) -> Double {
        guard !times.isEmpty else { return 0 }
        let sorted = times.sorted()
        let rank = Int((Double(p) / 100.0 * Double(sorted.count)).rounded(.up))
        return sorted[max(0, min(sorted.count - 1, rank - 1))]
    }
}
