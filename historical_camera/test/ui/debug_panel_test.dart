import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/domain/era_filter.dart';
import 'package:historical_camera/domain/filter_params.dart';
import 'package:historical_camera/platform/camera_event.dart';
import 'package:historical_camera/state/camera_state.dart';
import 'package:historical_camera/strings.dart';
import 'package:historical_camera/ui/camera_screen.dart';
import 'package:historical_camera/ui/debug_panel.dart';
import 'package:historical_camera/ui/era_label.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebugPanelController (docs/04 §8.2)', () {
    test('open enables debug stats, close disables and keeps manual mode',
        () async {
      final h = makeHarness();
      await h.container.read(cameraNotifierProvider.notifier).initialize();
      final debug = h.container.read(debugPanelProvider.notifier);

      debug.open();
      expect(h.api.statsEnabled, isTrue);
      expect(h.container.read(debugPanelProvider).visible, isTrue);

      debug.setManual(true);
      debug.close();
      expect(h.api.statsEnabled, isFalse);
      final state = h.container.read(debugPanelProvider);
      expect(state.visible, isFalse);
      expect(state.manual, isTrue,
          reason: 'closing the panel must keep manual mode (badge flow)');
    });

    test('manual mode seeds from paramsForYear, edits reach native, and '
        'returning to linked mode restores the era look', () async {
      final h = makeHarness();
      final camera = h.container.read(cameraNotifierProvider.notifier);
      await camera.initialize();
      camera.onYearChanged(1950);
      final debug = h.container.read(debugPanelProvider.notifier);

      debug.open();
      debug.setManual(true);
      final seeded = h.container.read(debugPanelProvider).manualParams;
      expect(seeded, paramsForYear(1950, testNowYear),
          reason: 'manual values start from the current year');

      final edited = seeded.copyWith(grain: 0.99);
      debug.updateManualParams(edited);
      expect(h.api.lastParams, edited,
          reason: 'manual edits go through setFilterParams');

      debug.setManual(false);
      expect(h.api.lastParams, paramsForYear(1950, testNowYear),
          reason: 'leaving manual mode restores the year-driven params');
    });

    test('moving the era slider while manual re-seeds the manual values',
        () async {
      final h = makeHarness();
      final camera = h.container.read(cameraNotifierProvider.notifier);
      await camera.initialize();
      final debug = h.container.read(debugPanelProvider.notifier);
      // Keep the provider (and its year listener) alive.
      h.container.listen(debugPanelProvider, (_, _) {});

      debug.open();
      debug.setManual(true);
      debug.updateManualParams(FilterParams.neutral.copyWith(sepia: 0.77));

      camera.onYearChanged(1880);
      expect(
        h.container.read(debugPanelProvider).manualParams,
        paramsForYear(1880, testNowYear),
        reason: 'docs/04 §8.2: background slider re-initializes manual values',
      );
    });

    test('gpuMs follows debugStats events while the panel is open', () async {
      final h = makeHarness();
      await h.container.read(cameraNotifierProvider.notifier).initialize();
      final debug = h.container.read(debugPanelProvider.notifier);

      debug.open();
      h.api.eventsController.add(const CameraEvent.debugStats(5.25));
      await pumpEventQueue();
      expect(h.container.read(debugPanelProvider).gpuMs, 5.25);
    });

    test('resolution override re-initializes with the preset and restores '
        'stats and manual params', () async {
      final h = makeHarness();
      await h.container.read(cameraNotifierProvider.notifier).initialize();
      final debug = h.container.read(debugPanelProvider.notifier);

      debug.open();
      debug.setManual(true);
      final manual = FilterParams.neutral.copyWith(vignette: 0.5);
      debug.updateManualParams(manual);

      await debug.setResolutionPreset('hd1080');
      await pumpEventQueue();

      expect(h.api.calls, contains('dispose'));
      expect(h.api.lastResolutionPreset, 'hd1080');
      expect(h.api.statsEnabled, isTrue,
          reason: 're-initialize must re-enable the stats stream');
      expect(h.api.lastParams, manual,
          reason: 'manual values survive the re-initialize');
      expect(
        h.container.read(cameraNotifierProvider).phase,
        CameraPhase.previewing,
      );
    });

    test('copyJson exports the 20 values with docs/02 §2 key names in '
        'declaration order', () async {
      final h = makeHarness();
      await h.container.read(cameraNotifierProvider.notifier).initialize();
      final debug = h.container.read(debugPanelProvider.notifier);

      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      debug.setManual(true);
      await debug.copyJson();

      expect(copied, isNotNull);
      final decoded = jsonDecode(copied!) as Map<String, dynamic>;
      expect(
        decoded.keys.toList(),
        FilterParams.neutral.toMap().keys.toList(),
        reason: 'keys and their order must match the docs/02 §2 declaration',
      );
      expect(decoded['saturation'], 1.0);
    });
  });

  group('debug panel UI', () {
    Future<FakeNativeCameraApi> pumpApp(WidgetTester tester) async {
      final api = FakeNativeCameraApi();
      await tester.pumpWidget(buildTestScope(
        api: api,
        permissions: FakePermissionService(granted: true),
        child: const MaterialApp(home: CameraScreen()),
      ));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('3-second long-press on the era label opens the panel '
        '(docs/04 §8.1)', (tester) async {
      final api = await pumpApp(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(EraLabel)));
      // Long-press recognizes at ~500 ms; the trigger waits 2500 ms more.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const Key('debug_panel')), findsNothing,
          reason: 'a plain long-press must not open the panel yet');
      await tester.pump(const Duration(milliseconds: 2500));
      await gesture.up();
      await tester.pump();

      expect(find.byKey(const Key('debug_panel')), findsOneWidget);
      expect(api.calls, contains('setDebugStatsEnabled:true'));
    });

    testWidgets('releasing before 3 seconds does not open the panel',
        (tester) async {
      await pumpApp(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(EraLabel)));
      await tester.pump(const Duration(milliseconds: 1500));
      await gesture.up();
      await tester.pump(const Duration(seconds: 3));

      expect(find.byKey(const Key('debug_panel')), findsNothing);
    });

    testWidgets('manual edits flow to native; close leaves the 手動 badge; '
        'badge tap returns to year-linked mode', (tester) async {
      final api = await pumpApp(tester);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(CameraScreen)));
      container.read(debugPanelProvider.notifier).open();
      await tester.pumpAndSettle();

      // Sliders are read-only until manual mode is on.
      expect(
          tester.widget<Slider>(find.byType(Slider).first).onChanged, isNull);
      await tester.tap(find.text(Strings.debugModeManual));
      await tester.pumpAndSettle();

      // First row is monochrome (docs/02 §2 order); drag it up from 0.
      await tester.drag(find.byType(Slider).first, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(api.lastParams, isNotNull);
      expect(api.lastParams!.monochrome, greaterThan(0));

      await tester.tap(find.byKey(const Key('debug_close_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debug_panel')), findsNothing);
      expect(api.calls, contains('setDebugStatsEnabled:false'));
      expect(find.byKey(const Key('debug_manual_badge')), findsOneWidget);

      await tester.tap(find.byKey(const Key('debug_manual_badge')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debug_manual_badge')), findsNothing);
      expect(container.read(debugPanelProvider).manual, isFalse);
    });

    testWidgets('GPU readout shows the latest value and turns red over 8 ms',
        (tester) async {
      final api = await pumpApp(tester);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(CameraScreen)));
      container.read(debugPanelProvider.notifier).open();
      await tester.pumpAndSettle();
      expect(find.text(Strings.debugGpuPlaceholder), findsOneWidget);

      api.eventsController.add(const CameraEvent.debugStats(5.25));
      await tester.pumpAndSettle();
      var readout = tester
          .widget<Text>(find.byKey(const Key('debug_gpu_readout')));
      expect(readout.data, Strings.debugGpu(5.25));
      expect(readout.style!.color, isNot(Colors.redAccent));

      api.eventsController.add(const CameraEvent.debugStats(9.10));
      await tester.pumpAndSettle();
      readout = tester
          .widget<Text>(find.byKey(const Key('debug_gpu_readout')));
      expect(readout.style!.color, Colors.redAccent,
          reason: 'over-budget readings render red (docs/04 §8.2)');
    });

    testWidgets('panel lists all 20 parameters in docs/02 §2 order',
        (tester) async {
      await pumpApp(tester);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(CameraScreen)));
      container.read(debugPanelProvider.notifier).open();
      await tester.pumpAndSettle();

      expect(find.text('monochrome'), findsOneWidget,
          reason: 'first field of the docs/02 §2 order');
      await tester.scrollUntilVisible(find.text('paperTexture'), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('paperTexture'), findsOneWidget,
          reason: 'last field of the docs/02 §2 order');
    });
  });
}
