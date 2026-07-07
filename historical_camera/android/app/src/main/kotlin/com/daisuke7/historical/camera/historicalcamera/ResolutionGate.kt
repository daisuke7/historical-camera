package com.daisuke7.historical.camera.historicalcamera

import android.content.Context
import android.os.Build
import android.util.Log

/**
 * One-time on-device 1080p unlock gate (docs/01 §1.1).
 *
 * Renders 30 frames of the worst-case ink-era parameters into an offscreen
 * 1920x1080 target through [FilterBenchmark] (shared with the docs/06 §9
 * budget test) and persists `p90 < 8ms` keyed by the app version, so a
 * shader-changing update re-measures automatically. `resolutionPreset:
 * "auto"` resolves against the persisted result; the unlock therefore takes
 * effect from the NEXT initialize (docs/02 §3.1).
 */
object ResolutionGate {
    private const val TAG = "HistoricalCamera"
    private const val PREFS = "historical_camera"
    private const val BUDGET_MS = 8.0

    // Idle delay after preview start; the bench must never block the first
    // launch (docs/01 §1.1).
    private const val IDLE_DELAY_MS = 3000L

    /**
     * Worst-case ink-era parameters (~paramsForYear(1100), the heaviest era
     * measured in P0 — docs/01 §1.1). Same set as FilterGpuBudgetTest and the
     * iOS RunnerTests.
     */
    val INK_ERA_WORST_CASE = FilterParams(
        monochrome = 1.0f,
        sepia = 0.4f,
        fade = 0.68f,
        grain = 0.05f,
        grainSize = 2.0f,
        vignette = 0.45f,
        dust = 0.5f,
        blur = 0.34f,
        orthochromatic = 1.0f,
        inkPainting = 1.0f,
        paperTexture = 1.0f,
    )

    @Volatile
    private var scheduled = false

    private fun storageKey(context: Context): String {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val code =
            if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
            else @Suppress("DEPRECATION") info.versionCode.toLong()
        return "hd1080_gate_${info.versionName}-$code"
    }

    /** Persisted gate result for this app version; null = not measured yet. */
    fun storedResult(context: Context): Boolean? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = storageKey(context)
        return if (prefs.contains(key)) prefs.getBoolean(key, false) else null
    }

    /** Resolves `"auto"` to hd720/hd1080; absent result means hd720. */
    fun resolvePreset(context: Context, preset: String): String {
        if (preset != "auto") return preset
        return if (storedResult(context) == true) "hd1080" else "hd720"
    }

    /**
     * Runs the bench once per install-version, on a low-priority background
     * thread shortly after preview start. No-op when already measured.
     */
    fun scheduleIfNeeded(context: Context) {
        if (scheduled || storedResult(context) != null) return
        scheduled = true
        val appContext = context.applicationContext
        Thread({
            try {
                Thread.sleep(IDLE_DELAY_MS)
                runAndStore(appContext)
            } catch (t: Throwable) {
                // Leave the result unset so the next launch retries.
                Log.w(TAG, "1080p gate bench failed", t)
                scheduled = false
            }
        }, "hd1080-gate").apply { priority = Thread.MIN_PRIORITY }.start()
    }

    private fun runAndStore(context: Context) {
        val result = FilterBenchmark.run(1920, 1080, INK_ERA_WORST_CASE)
        val p90 = result.percentileMs(90)
        val pass = p90 < BUDGET_MS
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(storageKey(context), pass)
            .apply()
        val method = if (result.usedTimerQuery) "timer query" else "glFinish"
        Log.i(TAG, "1080p gate: p90 %.2f ms ($method) -> %s"
            .format(p90, if (pass) "unlocked" else "locked"))
    }
}
