package com.daisuke7.historical.camera.historicalcamera

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES30
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.ceil

/**
 * Offscreen GPU benchmark for the era filter (docs/06 §9, docs/01 §1.1).
 *
 * Renders full passes of the sampler2D shader variant into a width x height
 * FBO using a private EGL context on the calling thread, and returns
 * per-frame GPU times. Shared by the instrumented budget test (T12) and the
 * 1080p unlock gate (T14).
 *
 * Timing uses EXT_disjoint_timer_query when available; otherwise it falls
 * back to glFinish-bracketed CPU timing, which overestimates and therefore
 * never unlocks 1080p by mistake (docs/01 §1.1).
 */
object FilterBenchmark {

    class Result(val frameTimesMs: List<Double>, val usedTimerQuery: Boolean) {
        /** Nearest-rank percentile ([p] in 1..100) of the frame times. */
        fun percentileMs(p: Int): Double {
            if (frameTimesMs.isEmpty()) return 0.0
            val sorted = frameTimesMs.sorted()
            val rank = ceil(p / 100.0 * sorted.size).toInt()
            return sorted[(rank - 1).coerceIn(0, sorted.size - 1)]
        }
    }

    private const val GL_TIME_ELAPSED_EXT = 0x88BF

    fun run(
        width: Int,
        height: Int,
        params: FilterParams,
        frames: Int = 30,
        warmup: Int = 5,
    ): Result {
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        check(display != EGL14.EGL_NO_DISPLAY) { "no EGL display" }
        val version = IntArray(2)
        check(EGL14.eglInitialize(display, version, 0, version, 1)) {
            "eglInitialize failed"
        }
        var context: EGLContext = EGL14.EGL_NO_CONTEXT
        var pbuffer: EGLSurface = EGL14.EGL_NO_SURFACE
        try {
            val configAttribs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_RENDERABLE_TYPE, EGLExt.EGL_OPENGL_ES3_BIT_KHR,
                EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            check(
                EGL14.eglChooseConfig(
                    display, configAttribs, 0, configs, 0, 1, numConfigs, 0)
                    && numConfigs[0] > 0
            ) { "no ES3 pbuffer EGL config" }
            val config = configs[0]

            context = EGL14.eglCreateContext(
                display, config, EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE), 0)
            check(context != EGL14.EGL_NO_CONTEXT) { "eglCreateContext failed" }
            pbuffer = EGL14.eglCreatePbufferSurface(
                display, config,
                intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
            check(EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)) {
                "eglMakeCurrent failed"
            }
            return renderLoop(width, height, params, frames, warmup)
        } finally {
            EGL14.eglMakeCurrent(
                display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_CONTEXT)
            if (pbuffer != EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroySurface(display, pbuffer)
            }
            if (context != EGL14.EGL_NO_CONTEXT) {
                EGL14.eglDestroyContext(display, context)
            }
            EGL14.eglReleaseThread()
            EGL14.eglTerminate(display)
        }
    }

    /** Runs with the benchmark context current; GL objects die with it. */
    private fun renderLoop(
        width: Int,
        height: Int,
        params: FilterParams,
        frames: Int,
        warmup: Int,
    ): Result {
        val program = buildProgram()
        val positionBuffer = floatBufferOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
        val texCoordBuffer = floatBufferOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f)

        val textures = IntArray(2)
        GLES30.glGenTextures(2, textures, 0)
        // Input: deterministic noise. Real camera content is irrelevant to
        // the GPU cost; sampling an uploaded texture is what matters.
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[0])
        setTexParams()
        GLES30.glTexImage2D(
            GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA, width, height, 0,
            GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, noisePixels(width, height))
        // Output texture + FBO.
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[1])
        setTexParams()
        GLES30.glTexImage2D(
            GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA, width, height, 0,
            GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, null)
        val fbo = IntArray(1)
        GLES30.glGenFramebuffers(1, fbo, 0)
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, fbo[0])
        GLES30.glFramebufferTexture2D(
            GLES30.GL_FRAMEBUFFER, GLES30.GL_COLOR_ATTACHMENT0,
            GLES30.GL_TEXTURE_2D, textures[1], 0)
        check(
            GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER)
                == GLES30.GL_FRAMEBUFFER_COMPLETE
        ) { "benchmark FBO incomplete" }

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

        val identity = FloatArray(16).also {
            it[0] = 1f; it[5] = 1f; it[10] = 1f; it[15] = 1f
        }
        GLES30.glUniformMatrix4fv(
            GLES30.glGetUniformLocation(program, "uTexMatrix"), 1, false,
            identity, 0)
        GLES30.glUniform1fv(
            GLES30.glGetUniformLocation(program, "uParams"), 20,
            params.toFloatArray(), 0)
        GLES30.glUniform2f(
            GLES30.glGetUniformLocation(program, "uResolution"),
            width.toFloat(), height.toFloat())
        GLES30.glUniform1f(
            GLES30.glGetUniformLocation(program, "uOrientation"), 0f)
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[0])
        GLES30.glUniform1i(GLES30.glGetUniformLocation(program, "uTexture"), 0)
        val timeLoc = GLES30.glGetUniformLocation(program, "uTime")

        val extensions = GLES30.glGetString(GLES30.GL_EXTENSIONS) ?: ""
        val useTimerQuery = extensions.contains("GL_EXT_disjoint_timer_query")
        val query = IntArray(1)
        if (useTimerQuery) {
            GLES30.glGenQueries(1, query, 0)
        }

        fun draw(frame: Int) {
            // Advance the clock like real 30 fps playback so the 24 Hz
            // reseeded effects (grain/dust) change every frame.
            GLES30.glUniform1f(timeLoc, frame / 30f)
            GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
        }

        for (frame in 0 until warmup) {
            draw(frame)
        }
        GLES30.glFinish()

        val times = ArrayList<Double>(frames)
        for (frame in 0 until frames) {
            if (useTimerQuery) {
                GLES30.glBeginQuery(GL_TIME_ELAPSED_EXT, query[0])
                draw(warmup + frame)
                GLES30.glEndQuery(GL_TIME_ELAPSED_EXT)
                // Blocking read is fine here: this is a benchmark, not the
                // preview path (the renderer's live timing ping-pongs).
                val nanos = IntArray(1)
                GLES30.glGetQueryObjectuiv(
                    query[0], GLES30.GL_QUERY_RESULT, nanos, 0)
                times.add((nanos[0].toLong() and 0xFFFFFFFFL) / 1_000_000.0)
            } else {
                val start = System.nanoTime()
                draw(warmup + frame)
                GLES30.glFinish()
                times.add((System.nanoTime() - start) / 1_000_000.0)
            }
        }
        if (useTimerQuery) {
            GLES30.glDeleteQueries(1, query, 0)
        }
        return Result(times, useTimerQuery)
    }

    private fun buildProgram(): Int {
        fun compile(type: Int, source: String): Int {
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
        val vertex = compile(GLES30.GL_VERTEX_SHADER, FilterRenderer.VERTEX_SHADER)
        val fragment = compile(
            GLES30.GL_FRAGMENT_SHADER,
            FilterRenderer.fragmentSource(external = false))
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

    private fun setTexParams() {
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D,
            GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D,
            GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D,
            GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D,
            GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
    }

    /** Deterministic pseudo-random RGBA pixels (same LCG as the iOS test). */
    private fun noisePixels(width: Int, height: Int): ByteBuffer {
        val buffer = ByteBuffer.allocateDirect(width * height * 4)
            .order(ByteOrder.nativeOrder())
        var seed = 0x12345678L
        for (i in 0 until width * height) {
            seed = (seed * 1_664_525L + 1_013_904_223L) and 0xFFFFFFFFL
            buffer.put(((seed shr 8) and 0xFF).toByte())
            buffer.put(((seed shr 16) and 0xFF).toByte())
            buffer.put(((seed shr 24) and 0xFF).toByte())
            buffer.put(0xFF.toByte())
        }
        buffer.position(0)
        return buffer
    }

    private fun floatBufferOf(vararg values: Float): FloatBuffer =
        ByteBuffer.allocateDirect(values.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(values)
                position(0)
            }
}
