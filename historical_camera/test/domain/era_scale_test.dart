import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/domain/era_scale.dart';

void main() {
  const nowYear = 2026;

  group('yearForPosition breakpoints (docs/04 §2.1)', () {
    test('maps segment boundaries exactly', () {
      expect(yearForPosition(1.0, nowYear), closeTo(2026, 1e-9));
      expect(yearForPosition(0.50, nowYear), closeTo(1926, 1e-9));
      expect(yearForPosition(0.32, nowYear), closeTo(1800, 1e-9));
      expect(yearForPosition(0.15, nowYear), closeTo(1500, 1e-9));
      expect(yearForPosition(0.0, nowYear), closeTo(1000, 1e-9));
    });

    test('interpolates linearly inside a segment', () {
      // Midpoint of the right half: (1926 + 2026) / 2.
      expect(yearForPosition(0.75, nowYear), closeTo(1976, 1e-9));
      // Midpoint of the leftmost segment: (1000 + 1500) / 2.
      expect(yearForPosition(0.075, nowYear), closeTo(1250, 1e-9));
    });

    test('clamps out-of-range positions', () {
      expect(yearForPosition(-0.1, nowYear), closeTo(1000, 1e-9));
      expect(yearForPosition(1.1, nowYear), closeTo(2026, 1e-9));
    });
  });

  group('positionForYear', () {
    test('maps boundary years exactly', () {
      expect(positionForYear(2026, nowYear), closeTo(1.0, 1e-9));
      expect(positionForYear(1926, nowYear), closeTo(0.50, 1e-9));
      expect(positionForYear(1800, nowYear), closeTo(0.32, 1e-9));
      expect(positionForYear(1500, nowYear), closeTo(0.15, 1e-9));
      expect(positionForYear(1000, nowYear), closeTo(0.0, 1e-9));
    });

    test('clamps out-of-range years', () {
      expect(positionForYear(900, nowYear), closeTo(0.0, 1e-9));
      expect(positionForYear(2100, nowYear), closeTo(1.0, 1e-9));
    });
  });

  group('round trip (docs/04 §2.1: error < 0.5 years)', () {
    test('year -> position -> year stays within 0.5 years', () {
      for (final year in [1000, 1234, 1500, 1650, 1800, 1926, 1999, 2026]) {
        final p = positionForYear(year.toDouble(), nowYear);
        final back = yearForPosition(p, nowYear);
        expect((back - year).abs(), lessThan(0.5), reason: 'year $year');
      }
    });

    test('position -> year -> position is stable', () {
      for (var i = 0; i <= 20; i++) {
        final p = i / 20;
        final y = yearForPosition(p, nowYear);
        expect(positionForYear(y, nowYear), closeTo(p, 1e-6));
      }
    });
  });
}
