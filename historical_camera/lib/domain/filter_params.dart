import 'package:freezed_annotation/freezed_annotation.dart';

part 'filter_params.freezed.dart';

/// Effect parameters computed from an era year (docs/02 §2).
///
/// Field names and declaration order are the single source of truth:
/// platform-channel map keys match the field names exactly, and the native
/// shader uniform order follows this declaration order.
@freezed
abstract class FilterParams with _$FilterParams {
  const FilterParams._();

  const factory FilterParams({
    /// 0 = full color, 1 = fully monochrome.
    required double monochrome,

    /// Sepia toning strength.
    required double sepia,

    /// Saturation scale 0..2 (1 = unchanged).
    required double saturation,

    /// Contrast scale 0.5..1.5 (1 = unchanged).
    required double contrast,

    /// Brightness offset -0.3..0.3 (0 = unchanged).
    required double brightness,

    /// Color temperature shift -1 (blue) .. 1 (amber).
    required double warmth,

    /// Lifted blacks / sunk whites of a faded print.
    required double fade,

    /// Film grain intensity.
    required double grain,

    /// Grain size in pixel units, 1..4.
    required double grainSize,

    /// Peripheral darkening.
    required double vignette,

    /// Amount of vertical film scratches.
    required double scratches,

    /// Amount of dust specks and stains.
    required double dust,

    /// Frame wander + projector flicker of old footage.
    required double jitter,

    /// Highlight bloom.
    required double halation,

    /// Overall softness of an old lens.
    required double blur,

    /// Orthochromatic plate response 0..1 (red sinks dark, sky blows white).
    required double orthochromatic,

    /// Engraving-mode blend 0..1 (era 1500-1840).
    required double engraving,

    /// Engraving line density factor 0.5..1.0
    /// (1 = fine copperplate lines, 0.5 = coarse woodblock lines).
    required double hatchScale,

    /// Ink-painting / picture-scroll blend 0..1 (era 1000-1500).
    required double inkPainting,

    /// Paper texture blend.
    required double paperTexture,
  }) = _FilterParams;

  /// Neutral (= pass-through) values. The native side must initialize its
  /// params with this; zero-initialization is forbidden (docs/02 §2).
  static const neutral = FilterParams(
    monochrome: 0.0,
    sepia: 0.0,
    saturation: 1.0,
    contrast: 1.0,
    brightness: 0.0,
    warmth: 0.0,
    fade: 0.0,
    grain: 0.0,
    grainSize: 1.0,
    vignette: 0.0,
    scratches: 0.0,
    dust: 0.0,
    jitter: 0.0,
    halation: 0.0,
    blur: 0.0,
    orthochromatic: 0.0,
    engraving: 0.0,
    hatchScale: 1.0,
    inkPainting: 0.0,
    paperTexture: 0.0,
  );

  /// Serializes for the platform channel. Keys match field names exactly and
  /// every value is a double (docs/02 §2 type contract).
  Map<String, double> toMap() => <String, double>{
        'monochrome': monochrome,
        'sepia': sepia,
        'saturation': saturation,
        'contrast': contrast,
        'brightness': brightness,
        'warmth': warmth,
        'fade': fade,
        'grain': grain,
        'grainSize': grainSize,
        'vignette': vignette,
        'scratches': scratches,
        'dust': dust,
        'jitter': jitter,
        'halation': halation,
        'blur': blur,
        'orthochromatic': orthochromatic,
        'engraving': engraving,
        'hatchScale': hatchScale,
        'inkPainting': inkPainting,
        'paperTexture': paperTexture,
      };

  /// Field-wise linear interpolation between [a] (t=0) and [b] (t=1).
  static FilterParams lerp(FilterParams a, FilterParams b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return FilterParams(
      monochrome: l(a.monochrome, b.monochrome),
      sepia: l(a.sepia, b.sepia),
      saturation: l(a.saturation, b.saturation),
      contrast: l(a.contrast, b.contrast),
      brightness: l(a.brightness, b.brightness),
      warmth: l(a.warmth, b.warmth),
      fade: l(a.fade, b.fade),
      grain: l(a.grain, b.grain),
      grainSize: l(a.grainSize, b.grainSize),
      vignette: l(a.vignette, b.vignette),
      scratches: l(a.scratches, b.scratches),
      dust: l(a.dust, b.dust),
      jitter: l(a.jitter, b.jitter),
      halation: l(a.halation, b.halation),
      blur: l(a.blur, b.blur),
      orthochromatic: l(a.orthochromatic, b.orthochromatic),
      engraving: l(a.engraving, b.engraving),
      hatchScale: l(a.hatchScale, b.hatchScale),
      inkPainting: l(a.inkPainting, b.inkPainting),
      paperTexture: l(a.paperTexture, b.paperTexture),
    );
  }
}
