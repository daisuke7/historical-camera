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
import android.util.Log
import android.view.Surface
import com.daisuke7.historical.camera.BuildConfig
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GL pipeline (docs/06 §3): CameraX frames arrive on an OES SurfaceTexture,
 * get drawn through the era-filter fragment shader (docs/03 §3) into the
 * Flutter SurfaceProducer's window surface. Everything GL runs on a
 * dedicated HandlerThread.
 */
class FilterRenderer(
    private val surfaceProducer: TextureRegistry.SurfaceProducer,
) {
    companion object {
        private const val TAG = "HistoricalCamera"
        private const val EGL_RECORDABLE_ANDROID = 0x3142
        private const val GL_TIME_ELAPSED_EXT = 0x88BF

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

        /**
         * One fragment source, two sampler variants (docs/06 §3.4): the
         * preview compiles with samplerExternalOES, the still path (T10)
         * with sampler2D. `uParams[20]` follows the FilterParams declaration
         * order (docs/02 §2).
         *
         * Coordinate note: `vUV` has its origin at the BOTTOM-left of the
         * output, while the docs/03 §3.1 effect space is top-left. main()
         * flips into doc space; sampleAt() flips back and applies uTexMatrix.
         */
        private const val FRAGMENT_BODY = """
precision highp float;

uniform SAMPLER uTexture;
uniform mat4 uTexMatrix;
uniform float uParams[20];
uniform float uTime;
uniform vec2 uResolution;
uniform float uOrientation;

in vec2 vUV;
out vec4 fragColor;

#define P_MONOCHROME uParams[0]
#define P_SEPIA uParams[1]
#define P_SATURATION uParams[2]
#define P_CONTRAST uParams[3]
#define P_BRIGHTNESS uParams[4]
#define P_WARMTH uParams[5]
#define P_FADE uParams[6]
#define P_GRAIN uParams[7]
#define P_GRAIN_SIZE uParams[8]
#define P_VIGNETTE uParams[9]
#define P_SCRATCHES uParams[10]
#define P_DUST uParams[11]
#define P_JITTER uParams[12]
#define P_HALATION uParams[13]
#define P_BLUR uParams[14]
#define P_ORTHOCHROMATIC uParams[15]
#define P_ENGRAVING uParams[16]
#define P_HATCH_SCALE uParams[17]
#define P_INK_PAINTING uParams[18]
#define P_PAPER_TEXTURE uParams[19]

// ---- Utilities (docs/03 §3.2 — implement exactly as specified) ----

float hash21(vec2 p) {
  p = mod(p, vec2(1024.0));
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
      mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
      mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
      u.y);
}

float fbm3(vec2 p) {
  return (0.5 * valueNoise(p)
        + 0.25 * valueNoise(p * 2.0)
        + 0.125 * valueNoise(p * 4.0)) / 0.875;
}

float luma3(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 rotQ(vec2 p, float q) {
  p -= 0.5;
  if (q > 2.5) {
    p = vec2(-p.y, p.x);
  } else if (q > 1.5) {
    p = -p;
  } else if (q > 0.5) {
    p = vec2(p.y, -p.x);
  }
  return p + 0.5;
}

// Doc-space sampling: flip back to quad space, then apply the SurfaceTexture
// transform (y-flip/crop; identity for the still path).
vec3 sampleAt(vec2 docUV) {
  vec2 quadUV = vec2(docUV.x, 1.0 - docUV.y);
  return texture(uTexture, (uTexMatrix * vec4(quadUV, 0.0, 1.0)).xy).rgb;
}

vec3 sampleBlurred(vec2 uv, float amount) {
  if (amount <= 0.0) {
    return sampleAt(uv);
  }
  vec2 o = vec2(amount * 3.0) / uResolution;
  return sampleAt(uv) * 0.4
      + (sampleAt(uv + vec2(o.x, 0.0)) + sampleAt(uv - vec2(o.x, 0.0))
       + sampleAt(uv + vec2(0.0, o.y)) + sampleAt(uv - vec2(0.0, o.y))) * 0.15;
}

float sobelLuma(vec2 uv) {
  vec2 o = 2.0 / uResolution;
  float l00 = luma3(sampleAt(uv + vec2(-o.x, -o.y)));
  float l10 = luma3(sampleAt(uv + vec2(0.0, -o.y)));
  float l20 = luma3(sampleAt(uv + vec2(o.x, -o.y)));
  float l01 = luma3(sampleAt(uv + vec2(-o.x, 0.0)));
  float l21 = luma3(sampleAt(uv + vec2(o.x, 0.0)));
  float l02 = luma3(sampleAt(uv + vec2(-o.x, o.y)));
  float l12 = luma3(sampleAt(uv + vec2(0.0, o.y)));
  float l22 = luma3(sampleAt(uv + vec2(o.x, o.y)));
  float gx = -l00 - 2.0 * l01 - l02 + l20 + 2.0 * l21 + l22;
  float gy = -l00 - 2.0 * l10 - l20 + l02 + 2.0 * l12 + l22;
  return clamp(length(vec2(gx, gy)), 0.0, 1.0);
}

// ---- Era filter (docs/03 §3.3) ----
void main() {
  vec2 uv = vec2(vUV.x, 1.0 - vUV.y); // doc space, origin top-left
  vec2 euv = rotQ(uv, uOrientation);

  // 1. jitter: smooth low-frequency wander + slight zoom to hide edges.
  float tj = uTime * 12.0;
  vec2 j0 = vec2(hash21(vec2(floor(tj), 1.0)), hash21(vec2(floor(tj), 2.0)));
  vec2 j1 = vec2(hash21(vec2(floor(tj) + 1.0, 1.0)),
                 hash21(vec2(floor(tj) + 1.0, 2.0)));
  vec2 wander = mix(j0, j1, smoothstep(0.0, 1.0, fract(tj))) - 0.5;
  uv = (uv - 0.5) * (1.0 - 0.012 * P_JITTER) + 0.5;
  uv += wander * 0.006 * P_JITTER;

  // 2. blur: overall softness of an old lens.
  vec3 c = sampleBlurred(uv, P_BLUR);

  // 3. tone (fixed order).
  c += P_BRIGHTNESS;
  c = (c - 0.5) * P_CONTRAST + 0.5;
  c = mix(vec3(luma3(c)), c, P_SATURATION);
  c += vec3(0.06, 0.015, -0.06) * P_WARMTH;
  c = mix(c, c * 0.85 + 0.13, P_FADE);

  // 4. monochrome (orthochromatic plate response) / sepia.
  float yPan = luma3(c);
  float yOrtho = dot(c, vec3(0.10, 0.50, 0.40));
  float y = mix(yPan, yOrtho, P_ORTHOCHROMATIC);
  c = mix(c, vec3(y), P_MONOCHROME);
  c = mix(c, y * vec3(1.10, 0.90, 0.65) + vec3(0.06, 0.03, 0.0),
          P_SEPIA * 0.85);

  // 5. halation: highlight glow from an 8-point ring average.
  if (P_HALATION > 0.0) {
    vec2 rad = vec2(12.0 + 8.0 * P_HALATION) / uResolution;
    vec3 glow = vec3(0.0);
    for (int i = 0; i < 8; i++) {
      float a = float(i) * 0.7854;
      glow += sampleAt(uv + vec2(cos(a), sin(a)) * rad);
    }
    float bright = smoothstep(0.7, 1.0, luma3(glow / 8.0));
    c += bright * P_HALATION * vec3(0.25, 0.18, 0.10);
  }

  // 6. engraving: cross-hatch, line width follows tone, hand-carved wobble.
  if (P_ENGRAVING > 0.0) {
    float tone = clamp(luma3(c), 0.0, 1.0);
    float k = 90.0 * P_HATCH_SCALE;
    float wob = (fbm3(euv * 24.0) - 0.5) * 2.5;
    float d1 = (euv.x + euv.y) * k * 3.1416 + wob;
    float d2 = (euv.x - euv.y) * k * 3.1416 + wob * 1.3;
    float aa = k * 3.1416 * (1.0 / uResolution.x + 1.0 / uResolution.y) * 0.5
        + 0.06;
    float l1 = smoothstep(tone - aa, tone + aa, 0.5 + 0.5 * sin(d1));
    float l2 = smoothstep(tone * 1.6 - aa, tone * 1.6 + aa,
                          0.5 + 0.5 * sin(d2));
    float inkAmt = clamp(l1 + l2 * 0.8, 0.0, 1.0);
    vec3 inkCol = vec3(0.18, 0.12, 0.08);
    vec3 paperC = vec3(0.93, 0.88, 0.78);
    c = mix(c, mix(paperC, inkCol, inkAmt * 0.9), P_ENGRAVING);
  }

  // 7. ink painting: Sobel ink lines + soft posterize + ink bleed.
  if (P_INK_PAINTING > 0.0) {
    float edge = sobelLuma(uv);
    float t0 = luma3(c);
    float n = 4.0;
    float tq = (floor(t0 * n) + smoothstep(0.35, 0.65, fract(t0 * n))) / n;
    float bleed = fbm3(uv * 60.0) * 0.15;
    vec3 paperC = vec3(0.90, 0.85, 0.72);
    vec3 wash = mix(vec3(0.25, 0.22, 0.18), paperC, tq * 0.85 + 0.15);
    vec3 inked = mix(wash, vec3(0.10, 0.08, 0.06),
                     smoothstep(0.25 - bleed, 0.6, edge));
    c = mix(c, inked, P_INK_PAINTING);
  }

  // 8. grain: 24 Hz reseeded, strongest in midtones.
  float gseed = floor(uTime * 24.0);
  float g = hash21(floor(uv * uResolution / P_GRAIN_SIZE)
                   + vec2(gseed * 13.1, gseed * 7.7)) - 0.5;
  float lum = luma3(c);
  float lw = 4.0 * lum * (1.0 - lum);
  c += g * P_GRAIN * 0.25 * mix(0.5, 1.0, lw);

  // 9. scratches: generational vertical scratches, light/dark variants.
  if (P_SCRATCHES > 0.0) {
    for (int i = 0; i < 3; i++) {
      float seed = float(i) * 7.31;
      float seg = floor(uTime * 0.5) + seed;
      float life = step(0.55, hash21(vec2(seg, 3.0)));
      float sx = hash21(vec2(seg, 1.0))
          + (valueNoise(vec2(uTime * 1.7, seed)) - 0.5) * 0.02;
      float line = (1.0 - smoothstep(0.0, 0.0015, abs(euv.x - sx))) * life;
      float toneS = (hash21(vec2(seg, 2.0)) > 0.5) ? 0.4 : -0.35;
      c += line * P_SCRATCHES * toneS;
    }
  }

  // 10. dust: static dark stains + per-frame light specks.
  if (P_DUST > 0.0) {
    float aspect = uResolution.x / uResolution.y;
    float stain = smoothstep(0.80, 0.90,
                             valueNoise(uv * vec2(aspect, 1.0) * 24.0));
    float fseed = floor(uTime * 24.0);
    float flick = smoothstep(1.0 - P_DUST * 0.05, 1.0 - P_DUST * 0.02,
                             valueNoise(uv * 60.0
                                 + vec2(fseed * 13.1, fseed * 7.7)));
    c = mix(c, c * 0.55, stain * P_DUST * 0.6);
    c = mix(c, vec3(0.9), flick * P_DUST * 0.8);
  }

  // 11. paper texture: low-frequency mottle + high-frequency fibers.
  if (P_PAPER_TEXTURE > 0.0) {
    float aspect = uResolution.x / uResolution.y;
    vec2 puv = uv * vec2(aspect, 1.0);
    float ptex = 0.75 * fbm3(puv * 7.0) + 0.25 * fbm3(puv * 90.0);
    c *= mix(1.0, 0.80 + 0.20 * ptex, P_PAPER_TEXTURE);
  }

  // 12. projector flicker (rides on jitter).
  c *= 1.0 + (hash21(vec2(floor(uTime * 24.0), 5.0)) - 0.5) * 0.06 * P_JITTER;

  // 13. vignette.
  float r = distance(uv, vec2(0.5)) * 1.414;
  c *= 1.0 - P_VIGNETTE * smoothstep(0.45, 1.0, r);

  fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

        /** Assembles the fragment source for either sampler variant. */
        fun fragmentSource(external: Boolean): String = buildString {
            appendLine("#version 300 es")
            if (external) {
                appendLine("#extension GL_OES_EGL_image_external_essl3 : require")
                appendLine("#define SAMPLER samplerExternalOES")
            } else {
                appendLine("#define SAMPLER sampler2D")
            }
            append(FRAGMENT_BODY)
        }
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

    // Cached uniform/attribute locations (looked up once after link).
    private var locPosition = -1
    private var locTexCoord = -1
    private var locTexture = -1
    private var locTexMatrix = -1
    private var locParams = -1
    private var locTime = -1
    private var locResolution = -1
    private var locOrientation = -1

    // GPU frame-time measurement (docs/08 T9): EXT_disjoint_timer_query,
    // debug builds only, ping-pong queries to avoid stalling.
    private var timerSupported = false
    private val timerQueries = IntArray(2)
    private val timerPending = BooleanArray(2)
    private var timerIndex = 0
    private var gpuTimeSumNs = 0L
    private var gpuFrameCount = 0

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
                program = buildProgram(VERTEX_SHADER, fragmentSource(external = true))
                cacheLocations()
                setupTimerQueries()
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

    /**
     * Stops feeding frames immediately (synchronous). Call before releasing
     * the SurfaceProducer so no image reaches a detaching Flutter engine.
     */
    fun stopDrawing() {
        released = true
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

        val timing = beginGpuTimer()

        GLES30.glViewport(0, 0, width, height)
        GLES30.glUseProgram(program)

        GLES30.glEnableVertexAttribArray(locPosition)
        GLES30.glVertexAttribPointer(
            locPosition, 2, GLES30.GL_FLOAT, false, 0, positionBuffer)
        GLES30.glEnableVertexAttribArray(locTexCoord)
        GLES30.glVertexAttribPointer(
            locTexCoord, 2, GLES30.GL_FLOAT, false, 0, texCoordBuffer)

        // The SurfaceTexture matrix carries flip/crop plus the HAL's sensor
        // rotation (implementation-notes #3). Front-camera mirroring is
        // folded in here.
        val matrix = texMatrix.copyOf()
        if (mirror) {
            for (row in 0..3) {
                matrix[row] = -matrix[row]
                matrix[12 + row] += texMatrix[row]
            }
        }
        GLES30.glUniformMatrix4fv(locTexMatrix, 1, false, matrix, 0)

        val p = params
        GLES30.glUniform1fv(locParams, 20, p.toFloatArray(), 0)
        val seconds =
            ((System.nanoTime() - startTimeNs) / 1_000_000_000.0 % 3600.0)
        GLES30.glUniform1f(locTime, seconds.toFloat())
        GLES30.glUniform2f(locResolution, width.toFloat(), height.toFloat())
        GLES30.glUniform1f(locOrientation, orientationTurns.toFloat())

        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES30.glUniform1i(locTexture, 0)

        GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)

        endGpuTimer(timing)
        EGL14.eglSwapBuffers(display, windowSurface)
    }

    private fun cacheLocations() {
        locPosition = GLES30.glGetAttribLocation(program, "aPosition")
        locTexCoord = GLES30.glGetAttribLocation(program, "aTexCoord")
        locTexture = GLES30.glGetUniformLocation(program, "uTexture")
        locTexMatrix = GLES30.glGetUniformLocation(program, "uTexMatrix")
        locParams = GLES30.glGetUniformLocation(program, "uParams")
        locTime = GLES30.glGetUniformLocation(program, "uTime")
        locResolution = GLES30.glGetUniformLocation(program, "uResolution")
        locOrientation = GLES30.glGetUniformLocation(program, "uOrientation")
    }

    // MARK: GPU timing (docs/08 T9 acceptance: <8 ms on the test device)

    private fun setupTimerQueries() {
        if (!BuildConfig.DEBUG) return
        val extensions = GLES30.glGetString(GLES30.GL_EXTENSIONS) ?: ""
        timerSupported = extensions.contains("GL_EXT_disjoint_timer_query")
        if (timerSupported) {
            GLES30.glGenQueries(2, timerQueries, 0)
            Log.d(TAG, "GPU timer queries enabled")
        } else {
            Log.d(TAG, "GL_EXT_disjoint_timer_query unsupported; no GPU timing")
        }
    }

    /** Returns the query slot begun for this frame, or -1. */
    private fun beginGpuTimer(): Int {
        if (!timerSupported) return -1
        val index = timerIndex
        if (timerPending[index]) {
            val available = IntArray(1)
            GLES30.glGetQueryObjectuiv(
                timerQueries[index], GLES30.GL_QUERY_RESULT_AVAILABLE,
                available, 0)
            if (available[0] == 0) return -1 // still in flight; skip this frame
            val nanos = IntArray(1)
            GLES30.glGetQueryObjectuiv(
                timerQueries[index], GLES30.GL_QUERY_RESULT, nanos, 0)
            timerPending[index] = false
            recordGpuTime(nanos[0].toLong() and 0xFFFFFFFFL)
        }
        GLES30.glBeginQuery(GL_TIME_ELAPSED_EXT, timerQueries[index])
        return index
    }

    private fun endGpuTimer(index: Int) {
        if (index < 0) return
        GLES30.glEndQuery(GL_TIME_ELAPSED_EXT)
        timerPending[index] = true
        timerIndex = (index + 1) % timerQueries.size
    }

    private fun recordGpuTime(nanos: Long) {
        gpuTimeSumNs += nanos
        gpuFrameCount++
        if (gpuFrameCount >= 120) {
            val avgMs = gpuTimeSumNs / gpuFrameCount / 1_000_000.0
            Log.d(TAG, "eraFilter GPU avg: %.2f ms (last %d frames)"
                .format(avgMs, gpuFrameCount))
            gpuTimeSumNs = 0
            gpuFrameCount = 0
        }
    }

    // MARK: GL helpers

    private fun buildQuad() {
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
