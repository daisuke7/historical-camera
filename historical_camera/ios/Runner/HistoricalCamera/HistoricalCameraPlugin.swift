import Flutter

/// Channel registration and method dispatch only (docs/05 §2).
public final class HistoricalCameraPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let textures: FlutterTextureRegistry
    private var controller: CameraController?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HistoricalCameraPlugin(textures: registrar.textures())
        let methodChannel = FlutterMethodChannel(
            name: "historical_camera/method",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        let eventChannel = FlutterEventChannel(
            name: "historical_camera/event",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    init(textures: FlutterTextureRegistry) {
        self.textures = textures
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Results always land on the main thread (docs/05 §2).
        let mainResult: (Any?) -> Void = { value in
            DispatchQueue.main.async { result(value) }
        }

        switch call.method {
        case "initialize":
            guard controller == nil else {
                mainResult(FlutterError(
                    code: ErrorCodes.badState,
                    message: "already initialized", details: nil
                ))
                return
            }
            let args = call.arguments as? [String: Any] ?? [:]
            let controller = CameraController(textures: textures) { [weak self] event in
                self?.emit(event)
            }
            self.controller = controller
            controller.initialize(
                lens: args["lens"] as? String ?? "back",
                resolutionPreset: args["resolutionPreset"] as? String ?? "hd720"
            ) { [weak self] outcome in
                switch outcome {
                case .success(let info):
                    mainResult(info)
                case .failure(let error):
                    // Allow a clean retry after failure.
                    DispatchQueue.main.async { self?.controller = nil }
                    mainResult(error.flutterError)
                }
            }

        case "setFilterParams":
            let args = call.arguments as? [String: Any] ?? [:]
            if controller?.setFilterParams(args) == true {
                mainResult(nil)
            } else {
                mainResult(badState())
            }

        case "pausePreview":
            guard let controller else { return mainResult(badState()) }
            controller.pause { mainResult(nil) }

        case "resumePreview":
            guard let controller else { return mainResult(badState()) }
            controller.resume { mainResult(nil) }

        case "capturePhoto":
            guard let controller else { return mainResult(badState()) }
            controller.capturePhoto { outcome in
                switch outcome {
                case .success(let info):
                    mainResult(info)
                case .failure(let error):
                    mainResult(error.flutterError)
                }
            }

        case "setDebugStatsEnabled":
            let args = call.arguments as? [String: Any] ?? [:]
            let enabled = args["enabled"] as? Bool ?? false
            if controller?.setDebugStatsEnabled(enabled) == true {
                mainResult(nil)
            } else {
                mainResult(badState())
            }

        case "startRecording", "stopRecording":
            mainResult(FlutterError(
                code: ErrorCodes.recordingFailed,
                message: "not implemented", details: nil
            ))

        case "dispose":
            if let controller {
                self.controller = nil
                controller.dispose { mainResult(nil) }
            } else {
                mainResult(nil)
            }

        default:
            // setZoom / switchLens are P1 (docs/02 §3.1).
            result(FlutterMethodNotImplemented)
        }
    }

    private func badState() -> FlutterError {
        FlutterError(
            code: ErrorCodes.badState,
            message: "camera is not initialized", details: nil
        )
    }

    private func emit(_ event: [String: Any]) {
        DispatchQueue.main.async { self.eventSink?(event) }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
