import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/domain/era_filter.dart';
import 'package:historical_camera/domain/filter_params.dart';

void main() {
  const nowYear = 2026;
  // A far-future nowYear disables the neutral shortcut so the raw keyframe
  // table can be tested across its full range.
  const tableOnly = 2100;

  group('paramsForYear neutral shortcut (docs/03 §2.2 step 0)', () {
    test('returns exact neutral for year >= nowYear', () {
      expect(paramsForYear(nowYear.toDouble(), nowYear), FilterParams.neutral);
      expect(paramsForYear(2030, nowYear), FilterParams.neutral);
      expect(paramsForYear(3000, nowYear), FilterParams.neutral);
    });
  });

  group('paramsForYear boundaries', () {
    test('clamps below 1000 to the year-1000 keyframe', () {
      expect(paramsForYear(500, nowYear), paramsForYear(1000, nowYear));
    });

    test('year 2030 equals the top keyframe (which is neutral)', () {
      expect(paramsForYear(2030, tableOnly), FilterParams.neutral);
    });
  });

  group('paramsForYear on keyframe years returns table values', () {
    test('1950 row', () {
      final p = paramsForYear(1950, nowYear);
      expect(p.monochrome, closeTo(0.95, 1e-9));
      expect(p.sepia, closeTo(0.10, 1e-9));
      expect(p.saturation, closeTo(0.10, 1e-9));
      expect(p.contrast, closeTo(1.10, 1e-9));
      expect(p.grain, closeTo(0.45, 1e-9));
      expect(p.grainSize, closeTo(2.0, 1e-9));
      expect(p.vignette, closeTo(0.30, 1e-9));
      expect(p.scratches, closeTo(0.15, 1e-9));
      expect(p.orthochromatic, closeTo(0.0, 1e-9));
      expect(p.engraving, closeTo(0.0, 1e-9));
    });

    test('1810 row (full engraving)', () {
      final p = paramsForYear(1810, nowYear);
      expect(p.engraving, closeTo(1.0, 1e-9));
      expect(p.hatchScale, closeTo(1.0, 1e-9));
      expect(p.inkPainting, closeTo(0.0, 1e-9));
      expect(p.paperTexture, closeTo(0.70, 1e-9));
      expect(p.orthochromatic, closeTo(1.0, 1e-9));
    });

    test('1000 row (full ink painting)', () {
      final p = paramsForYear(1000, nowYear);
      expect(p.inkPainting, closeTo(1.0, 1e-9));
      expect(p.engraving, closeTo(0.0, 1e-9));
      expect(p.paperTexture, closeTo(1.0, 1e-9));
      expect(p.fade, closeTo(0.68, 1e-9));
    });
  });

  group('paramsForYear interpolation between keyframes', () {
    test('1963 is the midpoint of the 1968 and 1958 rows', () {
      final p = paramsForYear(1963, nowYear);
      expect(p.monochrome, closeTo((0.10 + 0.60) / 2, 1e-9));
      expect(p.saturation, closeTo((0.60 + 0.30) / 2, 1e-9));
      expect(p.grain, closeTo((0.30 + 0.38) / 2, 1e-9));
      expect(p.grainSize, closeTo((1.6 + 1.8) / 2, 1e-9));
    });

    test('engraving cross-fades continuously through 1840-1810', () {
      final mid = paramsForYear(1825, nowYear);
      expect(mid.engraving, closeTo((0.20 + 1.00) / 2, 1e-9));
    });
  });

  group('paramsForYear monotonicity (docs/03 §2.2 tests)', () {
    test('monochrome and paperTexture never decrease going back in time', () {
      var prev = paramsForYear(2030, tableOnly);
      for (var year = 2029; year >= 1000; year--) {
        final p = paramsForYear(year.toDouble(), tableOnly);
        expect(p.monochrome, greaterThanOrEqualTo(prev.monochrome - 1e-9),
            reason: 'monochrome decreased at year $year');
        expect(p.paperTexture, greaterThanOrEqualTo(prev.paperTexture - 1e-9),
            reason: 'paperTexture decreased at year $year');
        prev = p;
      }
    });

    test('grain never decreases going back in time within [1920, 2030]', () {
      var prev = paramsForYear(2030, tableOnly);
      for (var year = 2029; year >= 1920; year--) {
        final p = paramsForYear(year.toDouble(), tableOnly);
        expect(p.grain, greaterThanOrEqualTo(prev.grain - 1e-9),
            reason: 'grain decreased at year $year');
        prev = p;
      }
    });
  });

  group('keyframe table sanity', () {
    test('years are strictly descending', () {
      for (var i = 0; i < eraKeyframes.length - 1; i++) {
        expect(eraKeyframes[i].year, greaterThan(eraKeyframes[i + 1].year));
      }
    });

    test('engraving and inkPainting are never 1.0 at the same time', () {
      for (final kf in eraKeyframes) {
        expect(kf.params.engraving == 1.0 && kf.params.inkPainting == 1.0,
            isFalse,
            reason: 'both fully on at year ${kf.year}');
      }
    });

    test('values respect the documented ranges (docs/02 §2)', () {
      for (final kf in eraKeyframes) {
        final p = kf.params;
        expect(p.saturation, inInclusiveRange(0, 2));
        expect(p.contrast, inInclusiveRange(0.5, 1.5));
        expect(p.brightness, inInclusiveRange(-0.3, 0.3));
        expect(p.warmth, inInclusiveRange(-1, 1));
        expect(p.grainSize, inInclusiveRange(1, 4));
        expect(p.hatchScale, inInclusiveRange(0.5, 1.0));
        for (final entry in p.toMap().entries) {
          if (const {
            'saturation',
            'contrast',
            'brightness',
            'warmth',
            'grainSize',
            'hatchScale',
          }.contains(entry.key)) {
            continue;
          }
          expect(entry.value, inInclusiveRange(0, 1),
              reason: '${entry.key} out of [0,1] at year ${kf.year}');
        }
      }
    });
  });
}
