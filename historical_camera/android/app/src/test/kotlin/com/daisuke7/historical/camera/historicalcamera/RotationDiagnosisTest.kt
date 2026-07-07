package com.daisuke7.historical.camera.historicalcamera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Synthetic-matrix unit tests required by docs/06 §3.3: identity, y-flip
 * only, 90-degree rotation + flip, and crop-carrying variants. Matrices are
 * column-major 4x4 like SurfaceTexture.getTransformMatrix().
 */
class RotationDiagnosisTest {

    /** Column-major helper: pass the 2x2 linear part and the translation. */
    private fun matrix(
        a: Float, b: Float, // column 0: (m0, m1)
        c: Float, d: Float, // column 1: (m4, m5)
        tx: Float = 0f, ty: Float = 0f,
    ) = floatArrayOf(
        a, b, 0f, 0f,
        c, d, 0f, 0f,
        0f, 0f, 1f, 0f,
        tx, ty, 0f, 1f,
    )

    @Test
    fun identityIsZeroTurns() {
        assertEquals(0, RotationDiagnosis.detectBakedQuarterTurns(
            matrix(1f, 0f, 0f, 1f)))
    }

    @Test
    fun yFlipOnlyIsZeroTurns() {
        // The standard SurfaceTexture matrix for an unrotated buffer.
        assertEquals(0, RotationDiagnosis.detectBakedQuarterTurns(
            matrix(1f, 0f, 0f, -1f, ty = 1f)))
    }

    @Test
    fun quarterRotationsWithFlipAreDetected() {
        // GLConsumer composes crop x rotation x flipV; these are the linear
        // parts of rotation x flipV for each HAL_TRANSFORM_ROT_* value.
        assertEquals(1, RotationDiagnosis.detectBakedQuarterTurns(
            matrix(0f, 1f, 1f, 0f)))
        assertEquals(2, RotationDiagnosis.detectBakedQuarterTurns(
            matrix(-1f, 0f, 0f, 1f, tx = 1f)))
        assertEquals(3, RotationDiagnosis.detectBakedQuarterTurns(
            matrix(0f, -1f, -1f, 0f, tx = 1f, ty = 1f)))
    }

    @Test
    fun cropScaleAndTranslationAreIgnored() {
        // y-flip with a typical crop (scale < 1 plus offset) stays 0 turns.
        assertEquals(0, RotationDiagnosis.detectBakedQuarterTurns(
            matrix(0.97f, 0f, 0f, -0.9f, tx = 0.015f, ty = 0.95f)))
        // 90-degree rotation + flip with crop scales stays 1 turn.
        assertEquals(1, RotationDiagnosis.detectBakedQuarterTurns(
            matrix(0f, 0.9f, 0.97f, 0f, tx = 0.015f, ty = 0.05f)))
    }

    @Test
    fun offGridMatricesReturnNull() {
        // 45-degree rotation is not on the 90-degree grid.
        val s = 0.7071f
        assertNull(RotationDiagnosis.detectBakedQuarterTurns(
            matrix(s, s, -s, s)))
        // Degenerate (all zero) has no rotation to read.
        assertNull(RotationDiagnosis.detectBakedQuarterTurns(
            matrix(0f, 0f, 0f, 0f)))
        // Too short an array is rejected, not crashed on.
        assertNull(RotationDiagnosis.detectBakedQuarterTurns(FloatArray(4)))
    }
}
