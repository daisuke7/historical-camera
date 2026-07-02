import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/domain/era_filter.dart';
import 'package:historical_camera/platform/native_camera_api.dart';
import 'package:historical_camera/state/camera_state.dart';
import 'package:historical_camera/strings.dart';
import 'package:historical_camera/ui/camera_screen.dart';
import 'package:historical_camera/ui/era_label.dart';
import 'package:historical_camera/ui/era_slider.dart';

import '../helpers/fakes.dart';

Future<
    ({
      FakeNativeCameraApi api,
      FakePermissionService permissions,
    })> pumpApp(
  WidgetTester tester, {
  bool granted = true,
  String? initializeErrorCode,
}) async {
  final api = FakeNativeCameraApi()..initializeErrorCode = initializeErrorCode;
  final permissions = FakePermissionService(granted: granted);
  await tester.pumpWidget(buildTestScope(
    api: api,
    permissions: permissions,
    child: const MaterialApp(home: CameraScreen()),
  ));
  return (api: api, permissions: permissions);
}

CameraState stateOf(WidgetTester tester) {
  final container =
      ProviderScope.containerOf(tester.element(find.byType(CameraScreen)));
  return container.read(cameraNotifierProvider);
}

/// Lets the EraLabel visibility timer expire so no timers leak out of tests.
Future<void> expireEraLabel(WidgetTester tester) async {
  await tester.pump(EraLabel.visibleDuration);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('previewing shows texture, slider and shutter', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.byType(Texture), findsOneWidget);
    expect(find.byType(EraSlider), findsOneWidget);
    expect(find.byKey(const Key('shutter_button')), findsOneWidget);
  });

  testWidgets('permission denied shows explanation and settings button',
      (tester) async {
    final h = await pumpApp(tester, granted: false);
    await tester.pumpAndSettle();

    expect(find.text(Strings.permissionDeniedTitle), findsOneWidget);
    await tester.tap(find.text(Strings.openSettings));
    expect(h.permissions.openAppSettingsCalls, 1);
  });

  testWidgets('error view shows message and retry recovers', (tester) async {
    final h = await pumpApp(
      tester,
      initializeErrorCode: CameraErrorCodes.cameraUnavailable,
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.errorTitle), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);

    h.api.initializeErrorCode = null;
    await tester.tap(find.text(Strings.retry));
    await tester.pumpAndSettle();
    expect(find.byType(Texture), findsOneWidget);
  });

  testWidgets('shutter captures once and ignores taps while capturing',
      (tester) async {
    final h = await pumpApp(tester);
    await tester.pumpAndSettle();

    h.api.pendingCapture = Completer();
    await tester.tap(find.byKey(const Key('shutter_button')));
    await tester.pump();
    expect(stateOf(tester).phase, CameraPhase.capturing);

    // Second tap while capturing must be ignored (docs/04 §4).
    await tester.tap(find.byKey(const Key('shutter_button')));
    await tester.pump();
    expect(h.api.calls.where((c) => c == 'capturePhoto'), hasLength(1));

    h.api.pendingCapture!.complete(
      const CapturedPhoto(path: '/tmp/p.jpg', width: 4032, height: 3024),
    );
    await tester.pumpAndSettle();
    expect(stateOf(tester).phase, CameraPhase.previewing);
    expect(stateOf(tester).lastSavedPath, '/tmp/p.jpg');
  });

  testWidgets('slider drag updates year, pushes params, then snaps',
      (tester) async {
    final h = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(EraSlider), const Offset(-80, 0));
    await tester.pumpAndSettle(); // snap animation (150 ms)

    final state = stateOf(tester);
    expect(state.year, lessThan(testNowYear.toDouble()));
    expect(state.year, state.quantizedYear.toDouble(),
        reason: 'after release the year snaps onto the quantized decade');
    expect(state.quantizedYear % 10, 0);
    expect(
      h.api.lastParams,
      paramsForYear(state.year, testNowYear),
      reason: 'the filter follows the snapped year',
    );

    // Era label became visible with a year text, then fades out.
    expect(find.textContaining('年'), findsWidgets);
    await expireEraLabel(tester);
    final opacity = tester.widget<AnimatedOpacity>(
      find
          .descendant(
            of: find.byType(EraLabel),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(opacity.opacity, 0);
  });

  testWidgets('preview subtree does not rebuild during slider drags',
      (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    final textureElement = tester.element(find.byType(Texture));

    await tester.drag(find.byType(EraSlider), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await expireEraLabel(tester);

    expect(
      identical(textureElement, tester.element(find.byType(Texture))),
      isTrue,
      reason: 'the Texture element must survive slider-driven rebuilds',
    );
  });
}
