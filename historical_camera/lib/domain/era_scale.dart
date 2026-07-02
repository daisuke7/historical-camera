/// Non-linear slider scale (docs/04 §2.1).
///
/// Piecewise-linear mapping between track position `p` (0 = left = year 1000,
/// 1 = right = now) and calendar year:
///
/// | p           | year               | intent                          |
/// |-------------|--------------------|---------------------------------|
/// | 0.50 - 1.00 | (now-100) - now    | dense photo-era changes         |
/// | 0.32 - 0.50 | 1800 - (now-100)   | early photography / transition  |
/// | 0.15 - 0.32 | 1500 - 1800        | engraving era                   |
/// | 0.00 - 0.15 | 1000 - 1500        | picture-scroll era              |
library;

List<({double p, double year})> _breakpoints(int nowYear) {
  assert(nowYear - 100 > 1800, 'scale assumes nowYear > 1900');
  return [
    (p: 0.0, year: 1000),
    (p: 0.15, year: 1500),
    (p: 0.32, year: 1800),
    (p: 0.50, year: (nowYear - 100).toDouble()),
    (p: 1.0, year: nowYear.toDouble()),
  ];
}

/// Maps a track position `p` in [0, 1] to a (continuous) calendar year.
/// Inputs outside [0, 1] are clamped.
double yearForPosition(double p, int nowYear) {
  final bp = _breakpoints(nowYear);
  final x = p.clamp(0.0, 1.0);
  for (var i = 0; i < bp.length - 1; i++) {
    final a = bp[i];
    final b = bp[i + 1];
    if (x <= b.p) {
      final t = (x - a.p) / (b.p - a.p);
      return a.year + (b.year - a.year) * t;
    }
  }
  return bp.last.year;
}

/// Inverse of [yearForPosition]. Years outside [1000, nowYear] are clamped.
/// Round-tripping through both functions keeps the error under 0.5 years.
double positionForYear(double year, int nowYear) {
  final bp = _breakpoints(nowYear);
  final y = year.clamp(bp.first.year, bp.last.year);
  for (var i = 0; i < bp.length - 1; i++) {
    final a = bp[i];
    final b = bp[i + 1];
    if (y <= b.year) {
      final t = (y - a.year) / (b.year - a.year);
      return a.p + (b.p - a.p) * t;
    }
  }
  return bp.last.p;
}
