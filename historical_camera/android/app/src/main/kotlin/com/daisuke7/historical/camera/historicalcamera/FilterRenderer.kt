package com.daisuke7.historical.camera.historicalcamera

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES30
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GL pipeline (docs/06 §3): CameraX frames arrive on an OES SurfaceTexture,
 * get drawn through the era-filter fragment shader into the Flutter
 * SurfaceProducer's window surface. Everything GL runs on a dedicated
 * HandlerThread; task T8 ships the shader as a pass-through (docs/06 §7).
 */
class FilterRenderer(
    private val surfaceProducer: TextureRegistry.SurfaceProducer,
) {
    companion object {
        private const val EGL_RECORDABLE_ANDROID = 0x3142

        // Fixed vertex stage (docs/03 §3.1), GLSL ES 3.0.
        private const val VERTEX_SHADER = """#version 300 es
in vec4 aPosition;
in vec2 aTexCoord;
out vec2 vUV;
void main() {
  gl_Position = aPosition;
  vUV = aTexCoord;
}
"""

        // T8 pass-through; the docs/03 §3 algorithm replaces this in T9.
        // highp is mandatory (docs/03 §3.4).
        private const val FRAGMENT_SHADER = """#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
precision highp float;
uniform samplerExternalOES uTexture;
uniform mat4 uTexMatrix;
in vec2 vUV;
out vec4 fragColor;
void main() {
  vec2 suv = (uTexMatrix * vec4(vUV, 0.0, 1.0)).xy;
  fragColor = vec4(texture(uTexture, suv).rgb, 1.0);
}
"""
    }

    private val thread = HandlerThread("gl-render").apply { start() }
    private val handler = Handler(thread.looper)

    /** Latest filter parameters; read every frame on the GL thread. */
    @Volatile
    var params: FilterParams = FilterParams.NEUTRAL

    /** Display rotation for direction-dependent effects (docs/02 §4.1). */
    @Volatile
    var orientationTurns: Int = 0

    @Volatile
    private var mirror = false

    /** Set synchronously at release time so no further frame reaches the
     *  (possibly detached) Flutter engine. */
    @Volatile
    private var released = false

    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglConfig: EGLConfig? = null
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var pbufferSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var windowSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var program = 0
    private var oesTextureId = 0
    private var cameraSurfaceTexture: SurfaceTexture? = null
    private var cameraSurface: Surface? = null
    private var width = 0
    private var height = 0
    private var configured = false
    private val texMatrix = FloatArray(16)
    private val startTimeNs = System.nanoTime()

    private lateinit var positionBuffer: FloatBuffer
    private lateinit var texCoordBuffer: FloatBuffer

    init {
        surfaceProducer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                handler.post { recreateWindowSurface() }
            }

            override fun onSurfaceCleanup() {
                handler.post { destroyWindowSurface() }
            }
        })
    }

    /**
     * One-time GL setup. The camera produces sensor-sized buffers
     * ([bufferW] x [bufferH] = `request.resolution`, docs/06 §3.2), but the
     * SurfaceTexture transform matrix bakes in the sensor rotation, so the
     * sampled content is upright in the device's NATURAL orientation. The
     * output window therefore uses the rotated size ([outW] x [outH]) to
     * keep the aspect ratio correct (deviation from docs/06 §3.1 recorded in
     * implementation-notes). Idempotent so a pause/resume rebind can call it
     * again; [onReady] receives the Surface to hand to CameraX.
     */
    fun configure(
        bufferW: Int,
        bufferH: Int,
        outW: Int,
        outH: Int,
        mirror: Boolean,
        onReady: (Surface) -> Unit,
    ) {
        handler.post {
            this.mirror = mirror
            if (!configured) {
                width = outW
                height = outH
                initEgl()
                surfaceProducer.setSize(outW, outH)
                recreateWindowSurface()
                buildQuad()
                program = buildProgram(VERTEX_SHADER, FRAGMENT_SHADER)
                oesTextureId = createOesTexture()
                val surfaceTexture = SurfaceTexture(oesTextureId)
                surfaceTexture.setDefaultBufferSize(bufferW, bufferH)
                // Listener on the GL handler: updateTexImage must run on the
                // thread that owns the GL context (docs/06 §8).
                surfaceTexture.setOnFrameAvailableListener({ tex ->
                    drawFrame(tex)
                }, handler)
                cameraSurfaceTexture = surfaceTexture
                cameraSurface = Surface(surfaceTexture)
                configured = true
            }
            cameraSurface?.let(onReady)
        }
    }

    /** Tear down in the strict order of docs/06 §6. */
    fun release(onDone: () -> Unit) {
        released = true
        handler.post {
            cameraSurfaceTexture?.setOnFrameAvailableListener(null)
            cameraSurface?.release()
            cameraSurface = null
            destroyWindowSurface()
            if (display != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(
                    display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_CONTEXT)
                if (pbufferSurface != EGL14.EGL_NO_SURFACE) {
                    EGL14.eglDestroySurface(display, pbufferSurface)
                    pbufferSurface = EGL14.EGL_NO_SURFACE
                }
                if (context != EGL14.EGL_NO_CONTEXT) {
                    EGL14.eglDestroyContext(display, context)
                    context = EGL14.EGL_NO_CONTEXT
                }
                EGL14.eglReleaseThread()
                display = EGL14.EGL_NO_DISPLAY
            }
            cameraSurfaceTexture?.release()
            cameraSurfaceTexture = null
            configured = false
            thread.quitSafely()
            onDone()
        }
    }

    // MARK: EGL setup (docs/06 §3.1)

    private fun initEgl() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        check(display != EGL14.EGL_NO_DISPLAY) { "no EGL display" }
        val version = IntArray(2)
        check(EGL14.eglInitialize(display, version, 0, version, 1)) {
            "eglInitialize failed"
        }
        // ES 3.0 + RECORDABLE from P0 so the P2 recording surface works with
        // the same config (docs/06 §3.1, 07 §4).
        val attribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGLExt.EGL_OPENGL_ES3_BIT_KHR,
            EGL_RECORDABLE_ANDROID, 1,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        check(
            EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, numConfigs, 0)
                && numConfigs[0] > 0
        ) { "no ES3 RECORDABLE EGL config" }
        eglConfig = configs[0]

        val contextAttribs = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION, 3,
            EGL14.EGL_NONE,
        )
        context = EGL14.eglCreateContext(
            display, eglConfig, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
        check(context != EGL14.EGL_NO_CONTEXT) { "eglCreateContext failed" }

        // Tiny pbuffer so the context can be current before (or without) a
        // window surface.
        val pbufferAttribs = intArrayOf(
            EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
        pbufferSurface =
            EGL14.eglCreatePbufferSurface(display, eglConfig, pbufferAttribs, 0)
        makeCurrent(pbufferSurface)
    }

    private fun makeCurrent(surface: EGLSurface) {
        check(EGL14.eglMakeCurrent(display, surface, surface, context)) {
            "eglMakeCurrent failed"
        }
    }

    private fun recreateWindowSurface() {
        if (display == EGL14.EGL_NO_DISPLAY) return
        destroyWindowSurface()
        val surface = surfaceProducer.surface ?: return
        windowSurface = EGL14.eglCreateWindowSurface(
            display, eglConfig, surface, intArrayOf(EGL14.EGL_NONE), 0)
    }

    private fun destroyWindowSurface() {
        if (windowSurface != EGL14.EGL_NO_SURFACE) {
            if (pbufferSurface != EGL14.EGL_NO_SURFACE) {
                makeCurrent(pbufferSurface)
            }
            EGL14.eglDestroySurface(display, windowSurface)
            windowSurface = EGL14.EGL_NO_SURFACE
        }
    }

    // MARK: Drawing

    private fun drawFrame(surfaceTexture: SurfaceTexture) {
        if (released || display == EGL14.EGL_NO_DISPLAY) return
        if (windowSurface == EGL14.EGL_NO_SURFACE) {
            // Consume the frame so the queue does not back up while the
            // output surface is temporarily gone (background).
            makeCurrent(pbufferSurface)
            surfaceTexture.updateTexImage()
            return
        }
        makeCurrent(windowSurface)
        surfaceTexture.updateTexImage()
        surfaceTexture.getTransformMatrix(texMatrix)

        GLES30.glViewport(0, 0, width, height)
        GLES30.glUseProgram(program)

        val positionLoc = GLES30.glGetAttribLocation(program, "aPosition")
        val texCoordLoc = GLES30.glGetAttribLocation(program, "aTexCoord")
        GLES30.glEnableVertexAttribArray(positionLoc)
        GLES30.glVertexAttribPointer(
            positionLoc, 2, GLES30.GL_FLOAT, false, 0, positionBuffer)
        GLES30.glEnableVertexAttribArray(texCoordLoc)
        GLES30.glVertexAttribPointer(
            texCoordLoc, 2, GLES30.GL_FLOAT, false, 0, texCoordBuffer)

        // The SurfaceTexture matrix carries y-flip/crop only, no rotation
        // (docs/06 §3.1). Front-camera mirroring is folded in here.
        val matrix = texMatrix.copyOf()
        if (mirror) {
            // Flip x: column-major post-multiply by diag(-1,1,1,1) + shift.
            for (row in 0..3) {
                matrix[row] = -matrix[row]
                matrix[12 + row] += texMatrix[row]
            }
        }
        GLES30.glUniformMatrix4fv(
            GLES30.glGetUniformLocation(program, "uTexMatrix"),
            1, false, matrix, 0)

        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES30.glUniform1i(GLES30.glGetUniformLocation(program, "uTexture"), 0)

        GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
        EGL14.eglSwapBuffers(display, windowSurface)
    }

    private fun buildQuad() {
        // Positions (±1) with texcoords (0..1); the transform matrix from
        // SurfaceTexture handles the y-flip.
        positionBuffer = floatBufferOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
        texCoordBuffer = floatBufferOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f)
    }

    private fun floatBufferOf(vararg values: Float): FloatBuffer =
        ByteBuffer.allocateDirect(values.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(values)
                position(0)
            }

    private fun createOesTexture(): Int {
        val ids = IntArray(1)
        GLES30.glGenTextures(1, ids, 0)
        GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, ids[0])
        GLES30.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
        return ids[0]
    }

    private fun buildProgram(vertexSource: String, fragmentSource: String): Int {
        val vertex = compileShader(GLES30.GL_VERTEX_SHADER, vertexSource)
        val fragment = compileShader(GLES30.GL_FRAGMENT_SHADER, fragmentSource)
        val program = GLES30.glCreateProgram()
        GLES30.glAttachShader(program, vertex)
        GLES30.glAttachShader(program, fragment)
        GLES30.glLinkProgram(program)
        val status = IntArray(1)
        GLES30.glGetProgramiv(program, GLES30.GL_LINK_STATUS, status, 0)
        check(status[0] == GLES30.GL_TRUE) {
            "program link failed: ${GLES30.glGetProgramInfoLog(program)}"
        }
        GLES30.glDeleteShader(vertex)
        GLES30.glDeleteShader(fragment)
        return program
    }

    private fun compileShader(type: Int, source: String): Int {
        val shader = GLES30.glCreateShader(type)
        GLES30.glShaderSource(shader, source)
        GLES30.glCompileShader(shader)
        val status = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0)
        check(status[0] == GLES30.GL_TRUE) {
            "shader compile failed: ${GLES30.glGetShaderInfoLog(shader)}"
        }
        return shader
    }
}
