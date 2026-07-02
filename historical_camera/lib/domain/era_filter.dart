import 'filter_params.dart';

/// One row of the era keyframe table (docs/03 §2.1).
class EraKeyframe {
  const EraKeyframe(this.year, this.params);

  final double year;
  final FilterParams params;
}

/// Raw keyframe table, kept in the exact same row/column layout as the table
/// in docs/03 §2.1 so the two can be diffed by eye. Column order:
/// year, mono, sepia, sat, cont, brig, warm, fade, grain, grSz, vign,
/// scr, dust, jit, hal, blur, ortho, engr, hatch, ink, paper
///
/// These are the initial tuning values; do not tweak during P0 (docs/08 §6.3).
const List<List<double>> _keyframeRows = [
  [2030, 0.00, 0.00, 1.00, 1.00, 0.00, 0.00, 0.00, 0.00, 1.0, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 1.00, 0.00, 0.00],
  [2010, 0.00, 0.00, 1.00, 1.00, 0.00, 0.00, 0.00, 0.03, 1.0, 0.03, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 1.00, 0.00, 0.00],
  [2000, 0.00, 0.00, 0.95, 1.02, 0.00, 0.05, 0.03, 0.08, 1.0, 0.08, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 1.00, 0.00, 0.00],
  [1990, 0.00, 0.00, 0.90, 1.03, 0.00, 0.15, 0.08, 0.15, 1.2, 0.12, 0.00, 0.00, 0.00, 0.05, 0.00, 0.00, 0.00, 1.00, 0.00, 0.00],
  [1975, 0.00, 0.10, 0.75, 0.97, 0.00, 0.35, 0.20, 0.25, 1.5, 0.20, 0.02, 0.02, 0.00, 0.08, 0.05, 0.00, 0.00, 1.00, 0.00, 0.00],
  [1968, 0.10, 0.12, 0.60, 0.96, 0.00, 0.32, 0.25, 0.30, 1.6, 0.22, 0.03, 0.03, 0.01, 0.09, 0.06, 0.00, 0.00, 1.00, 0.00, 0.00],
  [1958, 0.60, 0.14, 0.30, 1.00, 0.00, 0.20, 0.28, 0.38, 1.8, 0.26, 0.08, 0.06, 0.03, 0.10, 0.08, 0.00, 0.00, 1.00, 0.00, 0.00],
  [1950, 0.95, 0.10, 0.10, 1.10, 0.00, 0.10, 0.25, 0.45, 2.0, 0.30, 0.15, 0.10, 0.05, 0.12, 0.10, 0.00, 0.00, 1.00, 0.00, 0.00],
  [1920, 1.00, 0.15, 0.00, 1.15, 0.02, 0.00, 0.30, 0.60, 2.2, 0.40, 0.35, 0.30, 0.30, 0.20, 0.15, 0.50, 0.00, 1.00, 0.00, 0.05],
  [1880, 1.00, 0.80, 0.00, 1.05, 0.03, 0.00, 0.35, 0.55, 2.5, 0.55, 0.30, 0.40, 0.15, 0.30, 0.30, 0.90, 0.00, 1.00, 0.00, 0.20],
  [1845, 1.00, 0.90, 0.00, 0.95, 0.05, 0.00, 0.40, 0.50, 3.0, 0.70, 0.20, 0.50, 0.05, 0.35, 0.40, 1.00, 0.00, 1.00, 0.00, 0.35],
  [1840, 1.00, 0.90, 0.00, 0.95, 0.05, 0.00, 0.40, 0.45, 3.0, 0.70, 0.15, 0.45, 0.05, 0.30, 0.40, 1.00, 0.20, 1.00, 0.00, 0.55],
  [1810, 1.00, 0.55, 0.00, 1.00, 0.05, 0.00, 0.30, 0.15, 2.0, 0.45, 0.00, 0.25, 0.00, 0.10, 0.20, 1.00, 1.00, 1.00, 0.00, 0.70],
  [1650, 1.00, 0.52, 0.00, 1.00, 0.05, 0.00, 0.32, 0.12, 2.0, 0.42, 0.00, 0.28, 0.00, 0.00, 0.20, 1.00, 1.00, 0.75, 0.00, 0.72],
  [1550, 1.00, 0.50, 0.00, 1.00, 0.05, 0.00, 0.35, 0.10, 2.0, 0.40, 0.00, 0.30, 0.00, 0.00, 0.20, 1.00, 1.00, 0.50, 0.00, 0.75],
  [1450, 1.00, 0.45, 0.00, 0.95, 0.08, 0.10, 0.45, 0.08, 2.0, 0.40, 0.00, 0.35, 0.00, 0.00, 0.25, 1.00, 0.00, 0.50, 1.00, 0.85],
  [1300, 1.00, 0.40, 0.00, 0.88, 0.10, 0.25, 0.60, 0.05, 2.0, 0.42, 0.00, 0.40, 0.00, 0.00, 0.28, 1.00, 0.00, 0.50, 1.00, 0.92],
  [1100, 1.00, 0.40, 0.00, 0.85, 0.13, 0.30, 0.65, 0.05, 2.0, 0.45, 0.00, 0.48, 0.00, 0.00, 0.32, 1.00, 0.00, 0.50, 1.00, 1.00],
  [1000, 1.00, 0.40, 0.00, 0.84, 0.14, 0.32, 0.68, 0.05, 2.0, 0.45, 0.00, 0.50, 0.00, 0.00, 0.34, 1.00, 0.00, 0.50, 1.00, 1.00],
];

FilterParams _paramsFromRow(List<double> row) {
  assert(row.length == 21, 'keyframe row must be year + 20 params');
  return FilterParams(
    monochrome: row[1],
    sepia: row[2],
    saturation: row[3],
    contrast: row[4],
    brightness: row[5],
    warmth: row[6],
    fade: row[7],
    grain: row[8],
    grainSize: row[9],
    vignette: row[10],
    scratches: row[11],
    dust: row[12],
    jitter: row[13],
    halation: row[14],
    blur: row[15],
    orthochromatic: row[16],
    engraving: row[17],
    hatchScale: row[18],
    inkPainting: row[19],
    paperTexture: row[20],
  );
}

/// Keyframes in descending year order.
final List<EraKeyframe> eraKeyframes = List.unmodifiable(
  _keyframeRows.map((row) => EraKeyframe(row[0], _paramsFromRow(row))),
);

/// Converts a (continuous) calendar year into filter parameters
/// (docs/03 §2.2).
///
/// Years at or after [nowYear] return [FilterParams.neutral] exactly, so the
/// right end of the slider is a strict pass-through. Older years interpolate
/// linearly between the bracketing keyframes; years outside the table are
/// clamped to [1000, 2030].
FilterParams paramsForYear(double year, int nowYear) {
  if (year >= nowYear) return FilterParams.neutral;

  final keyframes = eraKeyframes;
  final y = year.clamp(keyframes.last.year, keyframes.first.year);
  if (y >= keyframes.first.year) return keyframes.first.params;
  if (y <= keyframes.last.year) return keyframes.last.params;

  // Binary search over the descending list for k0 (newer) / k1 (older)
  // such that k0.year >= y >= k1.year.
  var lo = 0;
  var hi = keyframes.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) ~/ 2;
    if (keyframes[mid].year >= y) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final k0 = keyframes[lo];
  final k1 = keyframes[hi];
  final t = (k0.year - y) / (k0.year - k1.year);
  return FilterParams.lerp(k0.params, k1.params, t);
}
