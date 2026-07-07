import Flutter
import Metal
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  /// Pass-through check (docs/03 §3.4): with neutral FilterParams the
  /// eraFilter kernel must return the input unchanged.
  func testEraFilterNeutralIsPassthrough() throws {
    guard let device = MTLCreateSystemDefaultDevice(),
          let queue = device.makeCommandQueue(),
          let library = device.makeDefaultLibrary(),
          let function = library.makeFunction(name: "eraFilter"),
          let pipeline = try? device.makeComputePipelineState(function: function)
    else {
      throw XCTSkip("Metal is unavailable in this test environment")
    }

    let width = 64
    let height = 64

    // Deterministic pseudo-random input, opaque alpha.
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    var seed: UInt32 = 0x1234_5678
    for i in 0..<(width * height) {
      seed = seed &* 1_664_525 &+ 1_013_904_223
      pixels[i * 4 + 0] = UInt8((seed >> 8) & 0xFF)
      pixels[i * 4 + 1] = UInt8((seed >> 16) & 0xFF)
      pixels[i * 4 + 2] = UInt8((seed >> 24) & 0xFF)
      pixels[i * 4 + 3] = 255
    }

    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = [.shaderRead]
    guard let src = device.makeTexture(descriptor: descriptor) else {
      return XCTFail("failed to create source texture")
    }
    src.replace(
      region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
      withBytes: pixels, bytesPerRow: width * 4)

    let outDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    outDescriptor.usage = [.shaderWrite, .shaderRead]
    guard let dst = device.makeTexture(descriptor: outDescriptor) else {
      return XCTFail("failed to create destination texture")
    }

    var uniforms = FilterUniforms(
      params: .neutral,
      time: 0,
      width: Float(width),
      height: Float(height),
      orientation: 0)

    guard let command = queue.makeCommandBuffer(),
          let encoder = command.makeComputeCommandEncoder()
    else {
      return XCTFail("failed to create command buffer")
    }
    encoder.setComputePipelineState(pipeline)
    encoder.setTexture(src, index: 0)
    encoder.setTexture(dst, index: 1)
    encoder.setBytes(&uniforms, length: MemoryLayout<FilterUniforms>.stride, index: 0)
    let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
    let groups = MTLSize(
      width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
    encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()

    var result = [UInt8](repeating: 0, count: width * height * 4)
    dst.getBytes(
      &result, bytesPerRow: width * 4,
      from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

    // Allow ±1/255 for float round-tripping.
    for i in 0..<(width * height * 4) {
      let diff = abs(Int(result[i]) - Int(pixels[i]))
      if diff > 1 {
        let pixel = i / 4
        return XCTFail(
          "pass-through mismatch at pixel \(pixel % width),\(pixel / width) "
            + "channel \(i % 4): got \(result[i]), expected \(pixels[i])")
      }
    }
  }

  /// GPU budget check (docs/08 T6, T12): p90 frame time of the worst-case
  /// parameter sets at 720p must stay under 8 ms on the device GPU.
  /// Measurement goes through FilterBenchmark, the utility shared with the
  /// 1080p unlock gate (docs/01 §1.1); the Android sibling is
  /// FilterGpuBudgetTest (docs/06 §9).
  func testEraFilterGpuBudgetAt720p() throws {
    let width = 1280
    let height = 720

    // Worst case of the photo era (~year 1845: blur + halation + every
    // noise layer) and of the ink era (Sobel + posterize + paper).
    var photoEra = FilterParams.neutral
    photoEra.monochrome = 1.0
    photoEra.sepia = 0.9
    photoEra.contrast = 0.95
    photoEra.brightness = 0.05
    photoEra.fade = 0.4
    photoEra.grain = 0.5
    photoEra.grainSize = 3.0
    photoEra.vignette = 0.7
    photoEra.scratches = 0.2
    photoEra.dust = 0.5
    photoEra.jitter = 0.05
    photoEra.halation = 0.35
    photoEra.blur = 0.4
    photoEra.orthochromatic = 1.0
    photoEra.paperTexture = 0.35

    var inkEra = FilterParams.neutral
    inkEra.monochrome = 1.0
    inkEra.sepia = 0.4
    inkEra.fade = 0.68
    inkEra.grain = 0.05
    inkEra.grainSize = 2.0
    inkEra.vignette = 0.45
    inkEra.dust = 0.5
    inkEra.blur = 0.34
    inkEra.orthochromatic = 1.0
    inkEra.inkPainting = 1.0
    inkEra.paperTexture = 1.0

    for (label, params) in [("photoEra", photoEra), ("inkEra", inkEra)] {
      guard let times = FilterBenchmark.run(
        width: width, height: height, params: params, frames: 60)
      else {
        throw XCTSkip("Metal is unavailable in this test environment")
      }
      let p90 = FilterBenchmark.percentileMs(times, 90)
      print("eraFilter GPU p90 (\(label), 720p): "
        + String(format: "%.2f", p90) + " ms")
      XCTAssertLessThan(
        p90, 8.0,
        "eraFilter exceeds the 8 ms GPU budget for \(label)")
    }
  }

  /// 1080p gate preset resolution (docs/01 §1.1, 02 §3.1): "auto" resolves
  /// from the persisted per-version result, everything else passes through,
  /// and an absent result stays conservative (hd720).
  func testResolutionGateResolvePreset() {
    let suite = "ResolutionGateTests"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    XCTAssertEqual(
      ResolutionGate.resolvePreset("hd720", defaults: defaults), "hd720")
    XCTAssertEqual(
      ResolutionGate.resolvePreset("hd1080", defaults: defaults), "hd1080",
      "explicit presets bypass the gate")
    XCTAssertEqual(
      ResolutionGate.resolvePreset("auto", defaults: defaults), "hd720",
      "no stored result must resolve to hd720")

    defaults.set(false, forKey: ResolutionGate.storageKey)
    XCTAssertEqual(
      ResolutionGate.resolvePreset("auto", defaults: defaults), "hd720",
      "a failed gate keeps hd720")

    defaults.set(true, forKey: ResolutionGate.storageKey)
    XCTAssertEqual(
      ResolutionGate.resolvePreset("auto", defaults: defaults), "hd1080",
      "a passed gate unlocks hd1080")
  }
}
