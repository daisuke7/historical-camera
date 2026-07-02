import Foundation

/// Filter parameters received from Dart (docs/02 §2).
///
/// Field order matches the Dart declaration; the shader uniform order in
/// `FilterUniforms` follows it as well. Defaults are the documented neutral
/// values — zero-initialization is forbidden (docs/02 §2).
struct FilterParams {
    var monochrome: Float = 0
    var sepia: Float = 0
    var saturation: Float = 1
    var contrast: Float = 1
    var brightness: Float = 0
    var warmth: Float = 0
    var fade: Float = 0
    var grain: Float = 0
    var grainSize: Float = 1
    var vignette: Float = 0
    var scratches: Float = 0
    var dust: Float = 0
    var jitter: Float = 0
    var halation: Float = 0
    var blur: Float = 0
    var orthochromatic: Float = 0
    var engraving: Float = 0
    var hatchScale: Float = 1
    var inkPainting: Float = 0
    var paperTexture: Float = 0

    static let neutral = FilterParams()

    init() {}

    /// Parses the channel map; missing keys keep their neutral value.
    init(map: [String: Any]) {
        func value(_ key: String, _ fallback: Float) -> Float {
            (map[key] as? NSNumber)?.floatValue ?? fallback
        }
        monochrome = value("monochrome", 0)
        sepia = value("sepia", 0)
        saturation = value("saturation", 1)
        contrast = value("contrast", 1)
        brightness = value("brightness", 0)
        warmth = value("warmth", 0)
        fade = value("fade", 0)
        grain = value("grain", 0)
        grainSize = value("grainSize", 1)
        vignette = value("vignette", 0)
        scratches = value("scratches", 0)
        dust = value("dust", 0)
        jitter = value("jitter", 0)
        halation = value("halation", 0)
        blur = value("blur", 0)
        orthochromatic = value("orthochromatic", 0)
        engraving = value("engraving", 0)
        hatchScale = value("hatchScale", 1)
        inkPainting = value("inkPainting", 0)
        paperTexture = value("paperTexture", 0)
    }
}
