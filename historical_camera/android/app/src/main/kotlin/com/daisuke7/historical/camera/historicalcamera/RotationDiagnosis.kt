package com.daisuke7.historical.camera.historicalcamera

import kotlin.math.abs

/**
 * Rotation-model self-diagnosis (docs/06 §3.3).
 *
 * The docs/02 §4.1 Android model relies on the HAL baking the sensor
 * rotation into the SurfaceTexture transform matrix (implementation-notes
 * #3). This pure function extracts that baked rotation so the controller can
 * flag devices whose HAL behaves differently — detection only, the render
 * model is never switched automatically.
 */
object RotationDiagnosis {
    private const val EPS = 1e-3f

    /**
     * Returns the 90-degree-unit rotation (0..3 quarter turns) baked into a
     * SurfaceTexture transform matrix (column-major 4x4), or null when the
     * 2x2 linear part is not on the 90-degree grid.
     *
     * The standard y-flip that SurfaceTexture always composes (recognized by
     * a negative determinant) and crop-induced scale/translation are
     * normalized away before classification.
     */
    fun detectBakedQuarterTurns(matrix: FloatArray): Int? {
        if (matrix.size < 16) return null
        val a = matrix[0]
        val b = matrix[1]
        var c = matrix[4]
        var d = matrix[5]

        val det = a * d - b * c
        if (abs(det) < EPS) return null // degenerate, no rotation to read
        if (det < 0) {
            // Cancel the standard y-flip: linear part of M x flipV.
            c = -c
            d = -d
        }

        // After the flip cancel the determinant is positive, so an on-grid
        // matrix is either diagonal (0 or 180 degrees) or anti-diagonal
        // (90 or 270) with consistent signs; crop scales are positive and
        // do not affect the signs.
        return when {
            abs(b) < EPS && abs(c) < EPS && abs(a) > EPS && abs(d) > EPS ->
                if (a > 0) 0 else 2
            abs(a) < EPS && abs(d) < EPS && abs(b) > EPS && abs(c) > EPS ->
                if (b > 0) 1 else 3
            else -> null
        }
    }
}
