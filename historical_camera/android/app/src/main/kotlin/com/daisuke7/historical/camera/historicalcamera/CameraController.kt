package com.daisuke7.historical.camera.historicalcamera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Size
import android.view.OrientationEventListener
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.view.TextureRegistry

/** Error codes shared with Dart (docs/02 §3.1). */
object ErrorCodes {
    const val PERMISSION_DENIED = "CAMERA_PERMISSION_DENIED"
    const val CAMERA_UNAVAILABLE = "CAMERA_UNAVAILABLE"
    const val CAPTURE_FAILED = "CAPTURE_FAILED"
    const val SAVE_FAILED = "SAVE_FAILED"
    const val RECORDING_FAILED = "RECORDING_FAILED"
    const val BAD_STATE = "BAD_STATE"
}

class PluginError(val code: String, override val message: String) : Exception(message)

/**
 * Owns the CameraX use cases and feeds frames into [FilterRenderer]
 * (docs/06 §3). Buffers stay sensor-oriented; rotation reaches Dart as
 * quarterTurns only (docs/02 §4.1).
 */
class CameraController(
    private val activity: Activity,
    private val textureRegistry: TextureRegistry,
    private val emitEvent: (Map<String, Any>) -> Unit,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = ContextCompat.getMainExecutor(activity)

    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var renderer: FilterRenderer? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var orientationListener: OrientationEventListener? = null
    private var displayListener: DisplayManager.DisplayListener? = null
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null

    var isInitialized = false
        private set
    private var currentQuarterTurns = 0
    private var sensorRotationDegrees = 0
    private var outputSize: Size? = null
    private var pendingInitResult: ((Result<Map<String, Any>>) -> Unit)? = null

    fun initialize(
        lens: String,
        resolutionPreset: String,
        onResult: (Result<Map<String, Any>>) -> Unit,
    ) {
        // Permission requesting is Dart's job (permission_handler); native
        // only verifies the status (docs/02 §3.1, 06 §2).
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            onResult(Result.failure(PluginError(
                ErrorCodes.PERMISSION_DENIED, "camera permission is not granted")))
            return
        }
        if (isInitialized || pendingInitResult != null) {
            onResult(Result.failure(PluginError(
                ErrorCodes.BAD_STATE, "already initialized")))
            return
        }
        pendingInitResult = onResult

        val producer = textureRegistry.createSurfaceProducer()
        surfaceProducer = producer
        val renderer = FilterRenderer(producer)
        this.renderer = renderer
        val mirror = lens == "front"

        val providerFuture = ProcessCameraProvider.getInstance(activity)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                cameraProvider = provider

                val targetSize =
                    if (resolutionPreset == "hd1080") Size(1920, 1080)
                    else Size(1280, 720)
                val resolutionSelector = ResolutionSelector.Builder()
                    .setResolutionStrategy(ResolutionStrategy(
                        targetSize,
                        ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER))
                    .build()

                val preview = Preview.Builder()
                    .setResolutionSelector(resolutionSelector)
                    .build()
                this.preview = preview

                preview.setSurfaceProvider(mainExecutor) { request ->
                    // request.resolution is the truth (docs/06 §3.2).
                    val size = request.resolution
                    request.setTransformationInfoListener(mainExecutor) { info ->
                        onRotationDegrees(info.rotationDegrees)
                    }
                    // The transform matrix bakes in the sensor rotation, so
                    // the visible content is natural-orientation upright; the
                    // output buffer uses the rotated dimensions.
                    val swap = (sensorRotationDegrees / 90) % 2 == 1
                    val outSize =
                        if (swap) Size(size.height, size.width) else size
                    outputSize = outSize
                    renderer.configure(
                        size.width, size.height,
                        outSize.width, outSize.height, mirror) { surface ->
                        request.provideSurface(surface, mainExecutor) {}
                        mainHandler.post { completeInitialize(outSize) }
                    }
                }

                imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                    .build()

                val selector =
                    if (mirror) CameraSelector.DEFAULT_FRONT_CAMERA
                    else CameraSelector.DEFAULT_BACK_CAMERA
                val camera = provider.bindToLifecycle(
                    activity as LifecycleOwner, selector, preview, imageCapture)
                sensorRotationDegrees = camera.cameraInfo.sensorRotationDegrees

                // CameraX bakes (sensor - targetRotation) into the buffer
                // transform, which would squash the fixed-size texture.
                // Pinning targetRotation to the sensor orientation keeps the
                // buffer sensor-oriented as the docs/02 §4.1 model expects;
                // display rotation is handled purely by Dart's RotatedBox.
                preview.targetRotation =
                    quartersToRotation(sensorRotationDegrees / 90)

                installObservers()
            } catch (e: Exception) {
                failInitialize(PluginError(
                    ErrorCodes.CAMERA_UNAVAILABLE,
                    e.message ?: "camera initialization failed"))
            }
        }, mainExecutor)
    }

    private fun completeInitialize(size: Size) {
        val producer = surfaceProducer ?: return
        val result = pendingInitResult ?: return
        pendingInitResult = null
        updateTurnsFromDisplay()
        isInitialized = true
        android.util.Log.d(
            "HistoricalCamera",
            "initialize complete: ${size.width}x${size.height} " +
                "quarterTurns=$currentQuarterTurns")
        result(Result.success(mapOf(
            "textureId" to producer.id(),
            "previewWidth" to size.width,
            "previewHeight" to size.height,
            "quarterTurns" to currentQuarterTurns,
        )))
    }

    private fun failInitialize(error: PluginError) {
        val result = pendingInitResult
        pendingInitResult = null
        result?.invoke(Result.failure(error))
    }

    fun setFilterParams(map: Map<*, *>): Boolean {
        val renderer = renderer ?: return false
        if (!isInitialized) return false
        renderer.params = FilterParams.fromMap(map)
        return true
    }

    fun pause() {
        val provider = cameraProvider ?: return
        val preview = preview ?: return
        provider.unbind(preview)
    }

    fun resume() {
        val provider = cameraProvider ?: return
        val preview = preview ?: return
        val imageCapture = imageCapture ?: return
        if (!provider.isBound(preview)) {
            provider.bindToLifecycle(
                activity as LifecycleOwner,
                CameraSelector.DEFAULT_BACK_CAMERA, preview, imageCapture)
        }
    }

    fun dispose(onDone: () -> Unit) {
        // Ordering matters for the engine-detach race (FlutterJNI crash):
        // 1) stop producing frames synchronously, 2) release the
        // SurfaceProducer so the engine guards late images, 3) tear down
        // camera and GL asynchronously.
        renderer?.stopDrawing()
        surfaceProducer?.release()
        surfaceProducer = null

        orientationListener?.disable()
        orientationListener = null
        displayListener?.let {
            activity.getSystemService(DisplayManager::class.java)
                ?.unregisterDisplayListener(it)
        }
        displayListener = null
        if (Build.VERSION.SDK_INT >= 29) {
            thermalListener?.let {
                val pm = activity.getSystemService(PowerManager::class.java)
                pm?.removeThermalStatusListener(it)
            }
        }
        thermalListener = null
        cameraProvider?.unbindAll()
        cameraProvider = null
        preview = null
        imageCapture = null
        isInitialized = false
        val renderer = renderer
        this.renderer = null
        if (renderer != null) {
            renderer.release { mainHandler.post(onDone) }
        } else {
            onDone()
        }
    }

    // MARK: Rotation (docs/02 §4.1, 06 §3.3)

    private fun onRotationDegrees(degrees: Int) {
        // With targetRotation pinned to the sensor orientation this should
        // stay 0; kept as a diagnostic (docs/06 deviation is recorded in
        // implementation-notes).
        android.util.Log.d(
            "HistoricalCamera",
            "TransformationInfo rotationDegrees=$degrees " +
                "(sensor=$sensorRotationDegrees, expected 0 when pinned)")
    }

    /**
     * RotatedBox turns: the buffer content is natural-orientation upright
     * (sensor rotation baked into the transform matrix), so only the display
     * rotation needs cancelling.
     */
    private fun updateTurnsFromDisplay() {
        val displayQuarters = rotationToQuarters(currentDisplayRotation())
        val turns = ((-displayQuarters) % 4 + 4) % 4
        android.util.Log.d(
            "HistoricalCamera",
            "display=$displayQuarters sensor=$sensorRotationDegrees " +
                "-> quarterTurns=$turns")
        if (turns == currentQuarterTurns) return
        currentQuarterTurns = turns
        renderer?.orientationTurns = turns
        if (isInitialized) {
            emitEvent(mapOf("type" to "orientationChanged", "quarterTurns" to turns))
        }
    }

    private fun currentDisplayRotation(): Int {
        return if (Build.VERSION.SDK_INT >= 30) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay.rotation
        }
    }

    private fun rotationToQuarters(rotation: Int): Int = when (rotation) {
        Surface.ROTATION_90 -> 1
        Surface.ROTATION_180 -> 2
        Surface.ROTATION_270 -> 3
        else -> 0
    }

    private fun quartersToRotation(quarters: Int): Int = when (quarters and 3) {
        1 -> Surface.ROTATION_90
        2 -> Surface.ROTATION_180
        3 -> Surface.ROTATION_270
        else -> Surface.ROTATION_0
    }

    private fun installObservers() {
        // UI rotation drives the RotatedBox turns (docs/02 §4.1). The
        // preview's targetRotation stays pinned; only stills follow the
        // physical orientation for EXIF (docs/06 §3.3).
        val dm = activity.getSystemService(DisplayManager::class.java)
        if (dm != null) {
            val listener = object : DisplayManager.DisplayListener {
                override fun onDisplayAdded(displayId: Int) {}
                override fun onDisplayRemoved(displayId: Int) {}
                override fun onDisplayChanged(displayId: Int) {
                    updateTurnsFromDisplay()
                }
            }
            dm.registerDisplayListener(listener, mainHandler)
            displayListener = listener
        }

        orientationListener = object : OrientationEventListener(activity) {
            override fun onOrientationChanged(angle: Int) {
                if (angle == ORIENTATION_UNKNOWN) return
                val rotation = when {
                    angle >= 315 || angle < 45 -> Surface.ROTATION_0
                    angle < 135 -> Surface.ROTATION_270
                    angle < 225 -> Surface.ROTATION_180
                    else -> Surface.ROTATION_90
                }
                if (imageCapture?.targetRotation != rotation) {
                    imageCapture?.targetRotation = rotation
                }
            }
        }.apply { enable() }

        // Thermal events (docs/02 §6.1); auto-downgrade lands in T11.
        if (Build.VERSION.SDK_INT >= 29) {
            val pm = activity.getSystemService(PowerManager::class.java) ?: return
            val listener = PowerManager.OnThermalStatusChangedListener { status ->
                val level = when {
                    status >= PowerManager.THERMAL_STATUS_CRITICAL -> "critical"
                    status >= PowerManager.THERMAL_STATUS_SEVERE -> "serious"
                    status >= PowerManager.THERMAL_STATUS_LIGHT -> "fair"
                    else -> "nominal"
                }
                emitEvent(mapOf("type" to "thermal", "level" to level))
            }
            pm.addThermalStatusListener(mainExecutor, listener)
            thermalListener = listener
        }
    }
}
