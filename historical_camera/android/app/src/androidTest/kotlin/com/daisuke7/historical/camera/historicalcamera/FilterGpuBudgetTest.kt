package com.daisuke7.historical.camera.historicalcamera

import android.os.Build
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeFalse
import org.junit.Test
import org.junit.runner.RunWith

/**
 * GPU budget regression test (docs/06 §9): p90 frame time of the era filter
 * must stay under 8 ms at the preview resolution class, for the same era
 * parameter sets as the iOS RunnerTests GPU test. Run on a real device with
 * `connectedAndroidTest`; emulator GPU numbers are meaningless.
 */
@RunWith(AndroidJUnit4::class)
class FilterGpuBudgetTest {

    // Natural-orientation output size actually used for the preview on the
    // reference device (Pixel 6 negotiates 1280x960 -> output 960x1280,
    // docs/06 §3.1), so results stay comparable to the docs/01 §1 records.
    private val width = 960
    private val height = 1280

    @Test
    fun eraFilterStaysWithinGpuBudget() {
        assumeFalse("emulator GPU timing is meaningless (docs/06 §9)", isEmulator())

        // Worst case of the photo era (~year 1845: blur + halation + every
        // noise layer) and of the ink era (Sobel + posterize + paper) —
        // mirrors ios/RunnerTests/RunnerTests.swift.
        val photoEra = FilterParams(
            monochrome = 1.0f,
            sepia = 0.9f,
            contrast = 0.95f,
            brightness = 0.05f,
            fade = 0.4f,
            grain = 0.5f,
            grainSize = 3.0f,
            vignette = 0.7f,
            scratches = 0.2f,
            dust = 0.5f,
            jitter = 0.05f,
            halation = 0.35f,
            blur = 0.4f,
            orthochromatic = 1.0f,
            paperTexture = 0.35f,
        )
        val inkEra = FilterParams(
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

        for ((label, params) in listOf("photoEra" to photoEra, "inkEra" to inkEra)) {
            val result = FilterBenchmark.run(width, height, params)
            val p90 = result.percentileMs(90)
            val method = if (result.usedTimerQuery) "timer query" else "glFinish"
            Log.i(
                "HistoricalCamera",
                "eraFilter GPU p90 ($label, ${width}x$height, $method): "
                    + "%.2f ms".format(p90))
            assertTrue(
                "eraFilter exceeds the 8 ms GPU budget for $label "
                    + "(p90=%.2f ms, $method)".format(p90),
                p90 < 8.0)
        }
    }

    private fun isEmulator(): Boolean =
        Build.FINGERPRINT.contains("generic")
            || Build.FINGERPRINT.contains("emulator")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("sdk_gphone")
}
