import CoreImage
import CoreVideo
import Foundation
import ImageIO
import Photos

/// JPEG encoding, temp-file handling and gallery save (docs/05 §5).
/// (P2) AVAssetWriter recording will live here as well.
final class MediaWriter {
    private static let ciContext = CIContext()

    /// Encodes a BGRA pixel buffer as JPEG (quality 0.9 per docs/02 §4).
    /// The buffer is upright, so EXIF orientation stays `.up` implicitly.
    static func encodeJPEG(_ buffer: CVPixelBuffer, quality: Double) -> Data? {
        let image = CIImage(cvPixelBuffer: buffer)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        let qualityKey = CIImageRepresentationOption(
            rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return ciContext.jpegRepresentation(
            of: image, colorSpace: colorSpace, options: [qualityKey: quality])
    }

    /// Writes into the app temp directory; the absolute path is the
    /// `capturePhoto` result value (docs/02 §3.1).
    static func writeTempFile(_ data: Data) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmssSSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let name = "historical_\(formatter.string(from: Date())).jpg"
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent(name)
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return path
        } catch {
            return nil
        }
    }

    /// Add-only photo library save; asks for permission on first use.
    static func saveToPhotoLibrary(
        _ data: Data,
        completion: @escaping (Result<Void, PluginError>) -> Void
    ) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(PluginError(
                    code: ErrorCodes.saveFailed,
                    message: "photo library add permission denied")))
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.creationDate = Date()
                request.addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(PluginError(
                        code: ErrorCodes.saveFailed,
                        message: error?.localizedDescription ?? "save failed")))
                }
            }
        }
    }

    /// Fallback for devices whose photo output cannot deliver BGRA
    /// (docs/05 §3.4 step 1): decode the encoded photo into a BGRA buffer.
    static func decodeToBGRA(_ data: Data) -> CVPixelBuffer? {
        guard let image = CIImage(data: data) else { return nil }
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        guard width > 0, height > 0 else { return nil }
        let attrs: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            nil, width, height, kCVPixelFormatType_32BGRA,
            attrs as CFDictionary, &buffer
        ) == kCVReturnSuccess, let output = buffer else { return nil }
        ciContext.render(image, to: output)
        return output
    }
}
