import AVFoundation
import Flutter
import UIKit

/// Error codes shared with Dart (docs/02 §3.1).
enum ErrorCodes {
    static let permissionDenied = "CAMERA_PERMISSION_DENIED"
    static let cameraUnavailable = "CAMERA_UNAVAILABLE"
    static let captureFailed = "CAPTURE_FAILED"
    static let saveFailed = "SAVE_FAILED"
    static let recordingFailed = "RECORDING_FAILED"
    static let badState = "BAD_STATE"
}

struct PluginError: Error {
    let code: String
    let message: String

    var flutterError: FlutterError {
        FlutterError(code: code, message: message, details: nil)
    }
}

/// Owns the AVCaptureSession and feeds frames into FilterRenderer
/// (docs/05 §3). Buffers stay sensor-oriented; rotation is reported to Dart
/// as quarterTurns only (docs/02 §4.1).
final class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let textures: FlutterTextureRegistry
    private let emitEvent: ([String: Any]) -> Void

    private let sessionQueue = DispatchQueue(label: "historical_camera.session")
    private let captureQueue = DispatchQueue(label: "historical_camera.capture")
    private let writerQueue = DispatchQueue(label: "historical_camera.writer")

    private var session: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var renderer: FilterRenderer?
    private var textureId: Int64 = -1
    private(set) var isInitialized = false
    private var currentQuarterTurns = 1
    private var observersInstalled = false
    private var previewWidth = 1280
    private var lensPosition: AVCaptureDevice.Position = .back
    private var inFlightCapture: PhotoCaptureDelegate?

    init(
        textures: FlutterTextureRegistry,
        emitEvent: @escaping ([String: Any]) -> Void
    ) {
        self.textures = textures
        self.emitEvent = emitEvent
    }

    // MARK: - Lifecycle

    func initialize(
        lens: String,
        resolutionPreset: String,
        completion: @escaping (Result<[String: Any], PluginError>) -> Void
    ) {
        sessionQueue.async {
            do {
                completion(.success(try self.configureSession(
                    lens: lens, resolutionPreset: resolutionPreset
                )))
            } catch let error as PluginError {
                completion(.failure(error))
            } catch {
                completion(.failure(PluginError(
                    code: ErrorCodes.cameraUnavailable,
                    message: error.localizedDescription
                )))
            }
        }
    }

    func setFilterParams(_ map: [String: Any]) -> Bool {
        guard isInitialized, let renderer else { return false }
        renderer.params = FilterParams(map: map)
        return true
    }

    func pause(completion: @escaping () -> Void) {
        sessionQueue.async {
            self.session?.stopRunning()
            completion()
        }
    }

    func resume(completion: @escaping () -> Void) {
        sessionQueue.async {
            self.session?.startRunning()
            completion()
        }
    }

    func dispose(completion: @escaping () -> Void) {
        sessionQueue.async {
            self.session?.stopRunning()
            self.session = nil
            self.videoDevice = nil
            self.photoOutput = nil
            if self.textureId >= 0 {
                self.textures.unregisterTexture(self.textureId)
            }
            self.renderer?.dispose()
            self.renderer = nil
            self.isInitialized = false
            DispatchQueue.main.async { self.removeObservers() }
            completion()
        }
    }

    // MARK: - Session construction (docs/05 §3.1)

    private func configureSession(
        lens: String,
        resolutionPreset: String
    ) throws -> [String: Any] {
        guard !isInitialized else {
            throw PluginError(code: ErrorCodes.badState, message: "already initialized")
        }
        // Permission requesting is Dart's job (permission_handler); native
        // only verifies the status (docs/02 §3.1).
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw PluginError(
                code: ErrorCodes.permissionDenied,
                message: "camera permission is not granted"
            )
        }

        let session = AVCaptureSession()
        let isHD1080 = resolutionPreset == "hd1080"
        session.sessionPreset = isHD1080 ? .hd1920x1080 : .hd1280x720
        let width = isHD1080 ? 1920 : 1280
        let height = isHD1080 ? 1080 : 720

        let position: AVCaptureDevice.Position = lens == "front" ? .front : .back
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: position
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            throw PluginError(
                code: ErrorCodes.cameraUnavailable,
                message: "no usable camera for lens \(lens)"
            )
        }
        session.addInput(input)

        let videoOutput = AVCaptureVideoDataOutput()
        // BGRA keeps YUV conversion out of the shader (docs/05 §3.1).
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        guard session.canAddOutput(videoOutput) else {
            throw PluginError(
                code: ErrorCodes.cameraUnavailable,
                message: "cannot add video output"
            )
        }
        session.addOutput(videoOutput)

        // Photo output configured now so T7 needs no session reconfiguration.
        // Full-resolution stills require explicit opt-in (docs/05 §3.1).
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            if #available(iOS 16.0, *) {
                if let dims = device.activeFormat.supportedMaxPhotoDimensions.last {
                    photoOutput.maxPhotoDimensions = dims
                }
            } else {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
        }

        // Keep the connection at sensor orientation (no videoOrientation
        // updates — docs/05 §3.3). Mirror the front camera preview.
        if position == .front,
           let connection = videoOutput.connection(with: .video),
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        guard let renderer = FilterRenderer(width: width, height: height) else {
            throw PluginError(
                code: ErrorCodes.cameraUnavailable,
                message: "Metal is unavailable on this device"
            )
        }
        let textureId = textures.register(renderer)
        renderer.onFrameAvailable = { [weak self] in
            self?.textures.textureFrameAvailable(textureId)
        }

        self.session = session
        self.videoDevice = device
        self.photoOutput = photoOutput
        self.renderer = renderer
        self.textureId = textureId
        self.previewWidth = width
        self.lensPosition = position

        session.startRunning()
        isInitialized = true

        // UIDevice must be touched on the main thread. The session queue is
        // never blocked by main here (plugin calls dispatch async).
        let turns = DispatchQueue.main.sync { () -> Int in
            self.installObservers()
            return Self.quarterTurns(for: UIDevice.current.orientation)
                ?? self.currentQuarterTurns
        }
        currentQuarterTurns = turns
        renderer.orientation = Float(turns)

        return [
            "textureId": textureId,
            "previewWidth": width,
            "previewHeight": height,
            "quarterTurns": turns,
        ]
    }

    // MARK: - Still capture (docs/05 §3.4)

    func capturePhoto(
        completion: @escaping (Result<[String: Any], PluginError>) -> Void
    ) {
        sessionQueue.async {
            guard self.isInitialized, let photoOutput = self.photoOutput else {
                completion(.failure(PluginError(
                    code: ErrorCodes.badState,
                    message: "camera is not initialized")))
                return
            }
            // Overlapping captures are BAD_STATE (docs/02 §3.1).
            guard self.inFlightCapture == nil else {
                completion(.failure(PluginError(
                    code: ErrorCodes.badState,
                    message: "a capture is already in progress")))
                return
            }

            // Prefer uncompressed BGRA; fall back to encoded capture +
            // decode on devices without BGRA photo support (docs/05 §3.4).
            let bgra = kCVPixelFormatType_32BGRA
            let settings: AVCapturePhotoSettings
            if photoOutput.availablePhotoPixelFormatTypes.contains(bgra) {
                settings = AVCapturePhotoSettings(format: [
                    kCVPixelBufferPixelFormatTypeKey as String: bgra,
                ])
            } else {
                settings = AVCapturePhotoSettings()
            }
            if #available(iOS 16.0, *) {
                settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            } else {
                settings.isHighResolutionPhotoEnabled = true
            }

            let turns = self.currentQuarterTurns
            let mirror = self.lensPosition == .front
            let delegate = PhotoCaptureDelegate { [weak self] photo, error in
                guard let self else { return }
                self.sessionQueue.async { self.inFlightCapture = nil }
                self.writerQueue.async {
                    self.processPhoto(
                        photo: photo, error: error,
                        quarterTurns: turns, mirror: mirror,
                        completion: completion)
                }
            }
            self.inFlightCapture = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    /// Runs on the writer queue: rotate upright -> full-res filter -> JPEG ->
    /// temp file + gallery save.
    private func processPhoto(
        photo: AVCapturePhoto?,
        error: Error?,
        quarterTurns: Int,
        mirror: Bool,
        completion: (Result<[String: Any], PluginError>) -> Void
    ) {
        guard error == nil, let photo, let renderer else {
            completion(.failure(PluginError(
                code: ErrorCodes.captureFailed,
                message: error?.localizedDescription ?? "capture failed")))
            return
        }

        var input = photo.pixelBuffer
        if input == nil, let data = photo.fileDataRepresentation() {
            input = MediaWriter.decodeToBGRA(data)
        }
        guard let pixelBuffer = input else {
            completion(.failure(PluginError(
                code: ErrorCodes.captureFailed,
                message: "no pixel data in the captured photo")))
            return
        }

        // Same params as the preview, with grain scaled to the still
        // resolution (docs/03 §4).
        var params = renderer.params
        params.grainSize *= Float(CVPixelBufferGetWidth(pixelBuffer))
            / Float(previewWidth)

        guard let filtered = renderer.renderStill(
            pixelBuffer, quarterTurns: quarterTurns, mirror: mirror,
            params: params)
        else {
            completion(.failure(PluginError(
                code: ErrorCodes.captureFailed,
                message: "GPU still-render failed")))
            return
        }

        let width = CVPixelBufferGetWidth(filtered)
        let height = CVPixelBufferGetHeight(filtered)
        guard let jpeg = MediaWriter.encodeJPEG(filtered, quality: 0.9),
              let path = MediaWriter.writeTempFile(jpeg)
        else {
            completion(.failure(PluginError(
                code: ErrorCodes.saveFailed,
                message: "JPEG encoding failed")))
            return
        }

        // Complete after the gallery save so the acceptance criterion
        // "appears in the OS gallery" holds (docs/08 §3-4).
        let semaphore = DispatchSemaphore(value: 0)
        var saveResult: Result<Void, PluginError> = .success(())
        MediaWriter.saveToPhotoLibrary(jpeg) { outcome in
            saveResult = outcome
            semaphore.signal()
        }
        semaphore.wait()

        switch saveResult {
        case .success:
            emitEvent(["type": "photoSaved", "path": path])
            completion(.success([
                "path": path,
                "width": width,
                "height": height,
            ]))
        case .failure(let pluginError):
            completion(.failure(pluginError))
        }
    }

    // MARK: - Frame delivery (docs/05 §3.2)

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        renderer?.enqueue(pixelBuffer)
    }

    // MARK: - Rotation (docs/02 §4.1, 05 §3.3)

    /// Clockwise quarter turns that make the sensor-oriented buffer upright.
    /// The sensor's native orientation matches UIDeviceOrientation
    /// .landscapeLeft (home button on the right).
    static func quarterTurns(for orientation: UIDeviceOrientation) -> Int? {
        switch orientation {
        case .landscapeLeft: return 0
        case .portrait: return 1
        case .landscapeRight: return 2
        case .portraitUpsideDown: return 3
        default: return nil // face up / face down / unknown: keep last
        }
    }

    private func installObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(sessionRuntimeError(_:)),
            name: .AVCaptureSessionRuntimeError, object: session
        )
    }

    private func removeObservers() {
        guard observersInstalled else { return }
        observersInstalled = false
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    @objc private func orientationDidChange() {
        guard let turns = Self.quarterTurns(for: UIDevice.current.orientation),
              turns != currentQuarterTurns
        else { return }
        currentQuarterTurns = turns
        renderer?.orientation = Float(turns)
        emitEvent(["type": "orientationChanged", "quarterTurns": turns])
    }

    // MARK: - Thermal (docs/02 §6.1, 05 §6)

    @objc private func thermalStateDidChange() {
        let state = ProcessInfo.processInfo.thermalState
        let level: String
        switch state {
        case .nominal: level = "nominal"
        case .fair: level = "fair"
        case .serious: level = "serious"
        case .critical: level = "critical"
        @unknown default: level = "nominal"
        }
        emitEvent(["type": "thermal", "level": level])

        // Auto-downgrade to 24 fps under thermal pressure.
        let throttled = state == .serious || state == .critical
        sessionQueue.async {
            guard let device = self.videoDevice,
                  (try? device.lockForConfiguration()) != nil
            else { return }
            device.activeVideoMinFrameDuration = throttled
                ? CMTime(value: 1, timescale: 24)
                : CMTime.invalid
            device.unlockForConfiguration()
        }
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
        emitEvent([
            "type": "error",
            "code": ErrorCodes.cameraUnavailable,
            "message": error?.localizedDescription ?? "capture session error",
        ])
    }
}

/// Retains the AVCapturePhotoCaptureDelegate for the duration of a capture.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let handler: (AVCapturePhoto?, Error?) -> Void

    init(handler: @escaping (AVCapturePhoto?, Error?) -> Void) {
        self.handler = handler
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        handler(error == nil ? photo : nil, error)
    }
}
