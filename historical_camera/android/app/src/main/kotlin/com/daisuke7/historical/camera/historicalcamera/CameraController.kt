package com.daisuke7.historical.camera.historicalcamera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.util.Range
import android.util.Size
import android.view.OrientationEventListener
import android.view.Surface
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.SurfaceRequest
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
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
    private var isFrontLens = false
    private var captureInFlight = false
    private var resolutionSelector:
        androidx.camera.core.resolutionselector.ResolutionSelector? = null
    private var cameraSelector: CameraSelector? = null
    private var isThrottled = false
    private val writerExecutor = Executors.newSingleThreadExecutor()

    private companion object {
        const val TAG = "HistoricalCamera"
    }

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
        isFrontLens = mirror

        val providerFuture = ProcessCameraProvider.getInstance(activity)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                cameraProvider = provider

                val targetSize =
                    if (resolutionPreset == "hd1080") Size(1920, 1080)
                    else Size(1280, 720)
                resolutionSelector = ResolutionSelector.Builder()
                    .setResolutionStrategy(ResolutionStrategy(
                        targetSize,
                        ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER))
                    .build()

                imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                    .build()

                val selector =
                    if (mirror) CameraSelector.DEFAULT_FRONT_CAMERA
                    else CameraSelector.DEFAULT_BACK_CAMERA
                cameraSelector = selector

                val preview = buildPreview(throttled = false)
                this.preview = preview

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

    private fun buildPreview(throttled: Boolean): Preview {
        val builder = Preview.Builder()
            .setResolutionSelector(requireNotNull(resolutionSelector))
        if (throttled) {
            // Thermal auto-downgrade to 24 fps (docs/02 §6.1).
            builder.setTargetFrameRate(Range(15, 24))
        }
        val preview = builder.build()
        preview.setSurfaceProvider(mainExecutor) { request ->
            handleSurfaceRequest(request)
        }
        return preview
    }

    private fun handleSurfaceRequest(request: SurfaceRequest) {
        val renderer = renderer ?: return
        // request.resolution is the truth (docs/06 §3.2).
        val size = request.resolution
        request.setTransformationInfoListener(mainExecutor) { info ->
            onRotationDegrees(info.rotationDegrees)
        }
        // The transform matrix bakes in the sensor rotation, so the visible
        // content is natural-orientation upright; the output buffer uses the
        // rotated dimensions (implementation-notes #3).
        val swap = (sensorRotationDegrees / 90) % 2 == 1
        val outSize = if (swap) Size(size.height, size.width) else size
        outputSize = outSize
        renderer.configure(
            size.width, size.height,
            outSize.width, outSize.height, isFrontLens) { surface ->
            request.provideSurface(surface, mainExecutor) {}
            mainHandler.post { completeInitialize(outSize) }
        }
    }

    /** Rebinds the preview with/without the 24 fps thermal cap. */
    private fun applyThermalFrameRate(throttled: Boolean) {
        if (throttled == isThrottled) return
        val provider = cameraProvider ?: return
        val selector = cameraSelector ?: return
        val old = preview ?: return
        isThrottled = throttled
        try {
            provider.unbind(old)
            val newPreview = buildPreview(throttled)
            preview = newPreview
            provider.bindToLifecycle(
                activity as LifecycleOwner, selector, newPreview)
            newPreview.targetRotation =
                quartersToRotation(sensorRotationDegrees / 90)
        } catch (e: Exception) {
            Log.w(TAG, "thermal frame-rate rebind failed", e)
        }
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

    // MARK: Still capture (docs/06 §3.4)

    fun capturePhoto(onResult: (Result<Map<String, Any>>) -> Unit) {
        val imageCapture = imageCapture
        val renderer = renderer
        if (!isInitialized || imageCapture == null || renderer == null) {
            onResult(Result.failure(PluginError(
                ErrorCodes.BAD_STATE, "camera is not initialized")))
            return
        }
        // Overlapping captures are BAD_STATE (docs/02 §3.1).
        if (captureInFlight) {
            onResult(Result.failure(PluginError(
                ErrorCodes.BAD_STATE, "a capture is already in progress")))
            return
        }
        captureInFlight = true
        val complete: (Result<Map<String, Any>>) -> Unit = { outcome ->
            mainHandler.post {
                captureInFlight = false
                onResult(outcome)
            }
        }

        imageCapture.takePicture(
            writerExecutor,
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(image: ImageProxy) {
                    try {
                        processPhoto(image, renderer, complete)
                    } catch (e: PluginError) {
                        complete(Result.failure(e))
                    } catch (e: Exception) {
                        complete(Result.failure(PluginError(
                            ErrorCodes.CAPTURE_FAILED,
                            e.message ?: "capture processing failed")))
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    complete(Result.failure(PluginError(
                        ErrorCodes.CAPTURE_FAILED,
                        exception.message ?: "capture failed")))
                }
            })
    }

    /** Runs on the writer executor. */
    private fun processPhoto(
        image: ImageProxy,
        renderer: FilterRenderer,
        complete: (Result<Map<String, Any>>) -> Unit,
    ) {
        // JPEG bytes + the rotation CameraX asks us to apply for upright.
        val buffer = image.planes[0].buffer
        val bytes = ByteArray(buffer.remaining()).also { buffer.get(it) }
        val rotationDegrees = image.imageInfo.rotationDegrees
        image.close()

        // Decode with an OOM retry at half resolution (docs/06 §3.4).
        val decoded = try {
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: OutOfMemoryError) {
            val options = BitmapFactory.Options().apply { inSampleSize = 2 }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        } ?: throw PluginError(ErrorCodes.CAPTURE_FAILED, "JPEG decode failed")

        // Upright + preview-matching mirror for the front camera
        // (docs/02 §4.1).
        val matrix = Matrix()
        if (rotationDegrees != 0) matrix.postRotate(rotationDegrees.toFloat())
        if (isFrontLens) matrix.postScale(-1f, 1f)
        val upright = if (matrix.isIdentity) decoded else {
            val transformed = Bitmap.createBitmap(
                decoded, 0, 0, decoded.width, decoded.height, matrix, true)
            if (transformed != decoded) decoded.recycle()
            transformed
        }

        // Same params as the preview, grain scaled to the still resolution
        // (docs/03 §4; the preview reference is the output width).
        val previewWidth = outputSize?.width ?: upright.width
        val params = renderer.params.copy(
            grainSize = renderer.params.grainSize *
                (upright.width.toFloat() / previewWidth))

        renderer.renderStill(upright, params) { filtered ->
            if (filtered == null) {
                complete(Result.failure(PluginError(
                    ErrorCodes.CAPTURE_FAILED, "GPU still-render failed")))
                return@renderStill
            }
            writerExecutor.execute {
                try {
                    val stamp = SimpleDateFormat(
                        "yyyyMMdd_HHmmssSSS", Locale.US).format(Date())
                    val temp = File(activity.cacheDir, "historical_$stamp.jpg")
                    temp.outputStream().use { out ->
                        if (!filtered.compress(
                                Bitmap.CompressFormat.JPEG, 90, out)) {
                            throw PluginError(
                                ErrorCodes.SAVE_FAILED, "JPEG encode failed")
                        }
                    }
                    val width = filtered.width
                    val height = filtered.height
                    filtered.recycle()
                    // Complete after the gallery save (docs/08 §3-4).
                    MediaWriter.saveToGallery(activity, temp)
                    emitEvent(mapOf(
                        "type" to "photoSaved", "path" to temp.absolutePath))
                    complete(Result.success(mapOf(
                        "path" to temp.absolutePath,
                        "width" to width,
                        "height" to height)))
                } catch (e: PluginError) {
                    complete(Result.failure(e))
                } catch (e: Exception) {
                    complete(Result.failure(PluginError(
                        ErrorCodes.SAVE_FAILED, e.message ?: "save failed")))
                }
            }
        }
    }

    fun pause() {
        val provider = cameraProvider ?: return
        val preview = preview ?: return
        provider.unbind(preview)
    }

    fun resume() {
        val provider = cameraProvider ?: return
        val preview = preview ?: return
        val selector = cameraSelector ?: return
        if (!provider.isBound(preview)) {
            provider.bindToLifecycle(
                activity as LifecycleOwner, selector, preview)
            preview.targetRotation =
                quartersToRotation(sensorRotationDegrees / 90)
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
        writerExecutor.shutdown()
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
                applyThermalFrameRate(
                    status >= PowerManager.THERMAL_STATUS_SEVERE)
            }
            pm.addThermalStatusListener(mainExecutor, listener)
            thermalListener = listener
        }
    }
}
