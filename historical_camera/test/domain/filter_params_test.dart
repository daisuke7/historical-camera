import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/domain/filter_params.dart';

void main() {
  group('FilterParams.neutral', () {
    test('has the documented neutral values (docs/02 §2)', () {
      const n = FilterParams.neutral;
      expect(n.saturation, 1.0);
      expect(n.contrast, 1.0);
      expect(n.grainSize, 1.0);
      expect(n.hatchScale, 1.0);
      final zeros = n.toMap()
        ..remove('saturation')
        ..remove('contrast')
        ..remove('grainSize')
        ..remove('hatchScale');
      expect(zeros.length, 16);
      for (final entry in zeros.entries) {
        expect(entry.value, 0.0, reason: '${entry.key} must default to 0');
      }
    });
  });

  group('FilterParams.toMap', () {
    test('has exactly the 20 documented keys, all double', () {
      final map = FilterParams.neutral.toMap();
      expect(map.keys, [
        'monochrome',
        'sepia',
        'saturation',
        'contrast',
        'brightness',
        'warmth',
        'fade',
        'grain',
        'grainSize',
        'vignette',
        'scratches',
        'dust',
        'jitter',
        'halation',
        'blur',
        'orthochromatic',
        'engraving',
        'hatchScale',
        'inkPainting',
        'paperTexture',
      ]);
      for (final value in map.values) {
        expect(value, isA<double>());
      }
    });
  });

  group('FilterParams.lerp', () {
    const a = FilterParams.neutral;
    final b = FilterParams.lerp(a, a, 0); // same as neutral
    final other = a.copyWith(monochrome: 1.0, saturation: 0.0, grain: 0.4);

    test('t=0 returns a, t=1 returns b', () {
      expect(FilterParams.lerp(a, other, 0), a);
      expect(FilterParams.lerp(a, other, 1), other);
      expect(b, a);
    });

    test('t=0.5 is the field-wise midpoint', () {
      final mid = FilterParams.lerp(a, other, 0.5);
      expect(mid.monochrome, closeTo(0.5, 1e-9));
      expect(mid.saturation, closeTo(0.5, 1e-9));
      expect(mid.grain, closeTo(0.2, 1e-9));
      expect(mid.contrast, closeTo(1.0, 1e-9)); // unchanged field
    });
  });
}
