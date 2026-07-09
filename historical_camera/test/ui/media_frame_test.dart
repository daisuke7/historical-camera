import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/state/camera_state.dart';
import 'package:historical_camera/ui/camera_screen.dart';
import 'package:historical_camera/ui/era_label.dart';
import 'package:historical_camera/ui/media_frame.dart';

import '../helpers/fakes.dart';

void main() {
  group('frameStyleForYear (docs/04 §7 table)', () {
    test('maps each era band to its frame', () {
      expect(frameStyleForYear(testNowYear), MediaFrameStyle.none);
      expect(frameStyleForYear(1980), MediaFrameStyle.none);
      expect(frameStyleForYear(1970), MediaFrameStyle.silverPrint);
      expect(frameStyleForYear(1960), MediaFrameStyle.silverPrint);
      expect(frameStyleForYear(1950), MediaFrameStyle.deckle,
          reason: 'the 1950s decade gets the deckle edge');
      expect(frameStyleForYear(1930), MediaFrameStyle.silverPrint);
      expect(frameStyleForYear(1920), MediaFrameStyle.none,
          reason: '1890-1930 is a gap in the docs/04 §7 table');
      expect(frameStyleForYear(1900), MediaFrameStyle.none);
      expect(frameStyleForYear(1890), MediaFrameStyle.cardMount);
      expect(frameStyleForYear(1850), MediaFrameStyle.cardMount);
      expect(frameStyleForYear(1840), MediaFrameStyle.engravingPlate);
      expect(frameStyleForYear(1500), MediaFrameStyle.engravingPlate);
      expect(frameStyleForYear(1490), MediaFrameStyle.scroll);
      expect(frameStyleForYear(1000), MediaFrameStyle.scroll);
    });
  });

  group('MediaFrameOverlay', () {
    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(buildTestScope(
        api: FakeNativeCameraApi(),
        permissions: FakePermissionService(granted: true),
        child: const MaterialApp(home: CameraScreen()),
      ));
      await tester.pumpAndSettle();
    }

    CameraNotifier notifier(WidgetTester tester) =>
        ProviderScopeCompat.of(tester);

    testWidgets('frame follows the era band and crossfades on change',
        (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const ValueKey(MediaFrameStyle.none)), findsOneWidget,
          reason: 'the current era has no frame');

      notifier(tester).onYearChanged(1952);
      await tester.pump();
      await tester.pump(MediaFrameOverlay.crossfadeDuration);
      expect(
          find.byKey(const ValueKey(MediaFrameStyle.deckle)), findsOneWidget);

      notifier(tester).onYearChanged(1100);
      await tester.pump();
      await tester.pump(MediaFrameOverlay.crossfadeDuration);
      expect(
          find.byKey(const ValueKey(MediaFrameStyle.scroll)), findsOneWidget);

      // Let the era label visibility timer expire so no timers leak.
      await tester.pump(EraLabel.visibleDuration);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(MediaFrameStyle.deckle)), findsNothing,
          reason: 'the previous frame is gone after the crossfade');
    });

    testWidgets('re-entering a band mid-crossfade does not duplicate keys '
        '(seen on device with fast slider drags)', (tester) async {
      await pumpApp(tester);
      final n = notifier(tester);

      // deckle -> silverPrint -> deckle within the 300 ms fade: the two
      // deckle entries must not collide inside the AnimatedSwitcher stack.
      n.onYearChanged(1950);
      await tester.pump(const Duration(milliseconds: 50));
      n.onYearChanged(1965);
      await tester.pump(const Duration(milliseconds: 50));
      n.onYearChanged(1950);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      await tester.pump(EraLabel.visibleDuration);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey(MediaFrameStyle.deckle)), findsOneWidget);
    });

    testWidgets('frame layer never blocks pointer events', (tester) async {
      await pumpApp(tester);
      notifier(tester).onYearChanged(1100); // scroll frame covers edges
      await tester.pumpAndSettle();

      // The shutter button (overlay above the frame) must stay tappable.
      await tester.tap(find.byKey(const Key('shutter_button')));
      await tester.pumpAndSettle();
      await tester.pump(EraLabel.visibleDuration);
      await tester.pumpAndSettle();
    });
  });
}

/// Small helper to reach the notifier from a pumped CameraScreen.
abstract final class ProviderScopeCompat {
  static CameraNotifier of(WidgetTester tester) {
    final context = tester.element(find.byType(CameraScreen));
    return ProviderScope.containerOf(context)
        .read(cameraNotifierProvider.notifier);
  }
}
