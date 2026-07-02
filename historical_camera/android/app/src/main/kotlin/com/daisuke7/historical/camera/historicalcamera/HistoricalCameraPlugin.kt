package com.daisuke7.historical.camera.historicalcamera

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Channel registration and method dispatch only (docs/06 §2). ActivityAware
 * is used solely to obtain the Activity / LifecycleOwner; permission
 * requesting lives in Dart (permission_handler).
 */
class HistoricalCameraPlugin :
    FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var textureRegistry: TextureRegistry? = null
    private var activity: Activity? = null
    private var controller: CameraController? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        textureRegistry = binding.textureRegistry
        methodChannel = MethodChannel(
            binding.binaryMessenger, "historical_camera/method")
        methodChannel?.setMethodCallHandler(this)
        eventChannel = EventChannel(
            binding.binaryMessenger, "historical_camera/event")
        eventChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Stop frame production before the engine goes away, otherwise the
        // SurfaceProducer's ImageReader delivers into a detached FlutterJNI.
        controller?.dispose {}
        controller = null
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        textureRegistry = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        controller?.dispose {}
        controller = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val activity = activity
                val textures = textureRegistry
                if (activity == null || textures == null) {
                    result.error(ErrorCodes.CAMERA_UNAVAILABLE, "no activity", null)
                    return
                }
                if (controller != null) {
                    result.error(ErrorCodes.BAD_STATE, "already initialized", null)
                    return
                }
                val controller = CameraController(activity, textures) { event ->
                    emit(event)
                }
                this.controller = controller
                controller.initialize(
                    lens = call.argument<String>("lens") ?: "back",
                    resolutionPreset = call.argument<String>("resolutionPreset")
                        ?: "hd720",
                ) { outcome ->
                    mainHandler.post {
                        outcome.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { error ->
                                // Allow a clean retry after failure.
                                this.controller = null
                                val plugin = error as? PluginError
                                result.error(
                                    plugin?.code ?: ErrorCodes.CAMERA_UNAVAILABLE,
                                    error.message, null)
                            },
                        )
                    }
                }
            }

            "setFilterParams" -> {
                val map = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                if (controller?.setFilterParams(map) == true) {
                    result.success(null)
                } else {
                    result.error(ErrorCodes.BAD_STATE, "camera is not initialized", null)
                }
            }

            "pausePreview" -> {
                val controller = controller
                    ?: return result.error(ErrorCodes.BAD_STATE, "not initialized", null)
                controller.pause()
                result.success(null)
            }

            "resumePreview" -> {
                val controller = controller
                    ?: return result.error(ErrorCodes.BAD_STATE, "not initialized", null)
                controller.resume()
                result.success(null)
            }

            "capturePhoto" -> {
                val controller = controller
                    ?: return result.error(ErrorCodes.BAD_STATE, "not initialized", null)
                controller.capturePhoto { outcome ->
                    outcome.fold(
                        onSuccess = { result.success(it) },
                        onFailure = { error ->
                            val plugin = error as? PluginError
                            result.error(
                                plugin?.code ?: ErrorCodes.CAPTURE_FAILED,
                                error.message, null)
                        },
                    )
                }
            }

            "startRecording", "stopRecording" -> {
                result.error(ErrorCodes.RECORDING_FAILED, "not implemented", null)
            }

            "dispose" -> {
                val controller = controller
                this.controller = null
                if (controller != null) {
                    controller.dispose { mainHandler.post { result.success(null) } }
                } else {
                    result.success(null)
                }
            }

            // setZoom / switchLens are P1 (docs/02 §3.1).
            else -> result.notImplemented()
        }
    }

    private fun emit(event: Map<String, Any>) {
        mainHandler.post { eventSink?.success(event) }
    }

    // MARK: EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
