package com.daisuke7.historical.camera.historicalcamera

/**
 * Filter parameters received from Dart (docs/02 §2).
 *
 * Field order matches the Dart declaration; defaults are the documented
 * neutral values — zero-initialization is forbidden (docs/02 §2).
 */
data class FilterParams(
    val monochrome: Float = 0f,
    val sepia: Float = 0f,
    val saturation: Float = 1f,
    val contrast: Float = 1f,
    val brightness: Float = 0f,
    val warmth: Float = 0f,
    val fade: Float = 0f,
    val grain: Float = 0f,
    val grainSize: Float = 1f,
    val vignette: Float = 0f,
    val scratches: Float = 0f,
    val dust: Float = 0f,
    val jitter: Float = 0f,
    val halation: Float = 0f,
    val blur: Float = 0f,
    val orthochromatic: Float = 0f,
    val engraving: Float = 0f,
    val hatchScale: Float = 1f,
    val inkPainting: Float = 0f,
    val paperTexture: Float = 0f,
) {
    /** Values in the docs/02 §2 declaration order, for `uniform float[20]`. */
    fun toFloatArray(): FloatArray = floatArrayOf(
        monochrome, sepia, saturation, contrast, brightness, warmth, fade,
        grain, grainSize, vignette, scratches, dust, jitter, halation, blur,
        orthochromatic, engraving, hatchScale, inkPainting, paperTexture,
    )

    companion object {
        val NEUTRAL = FilterParams()

        /** Channel values arrive as Number (docs/02 §2 type contract). */
        fun fromMap(map: Map<*, *>): FilterParams {
            fun f(key: String, fallback: Float): Float =
                (map[key] as? Number)?.toFloat() ?: fallback
            return FilterParams(
                monochrome = f("monochrome", 0f),
                sepia = f("sepia", 0f),
                saturation = f("saturation", 1f),
                contrast = f("contrast", 1f),
                brightness = f("brightness", 0f),
                warmth = f("warmth", 0f),
                fade = f("fade", 0f),
                grain = f("grain", 0f),
                grainSize = f("grainSize", 1f),
                vignette = f("vignette", 0f),
                scratches = f("scratches", 0f),
                dust = f("dust", 0f),
                jitter = f("jitter", 0f),
                halation = f("halation", 0f),
                blur = f("blur", 0f),
                orthochromatic = f("orthochromatic", 0f),
                engraving = f("engraving", 0f),
                hatchScale = f("hatchScale", 1f),
                inkPainting = f("inkPainting", 0f),
                paperTexture = f("paperTexture", 0f),
            )
        }
    }
}
