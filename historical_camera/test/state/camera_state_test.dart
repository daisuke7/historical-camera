import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/domain/era_filter.dart';
import 'package:historical_camera/domain/filter_params.dart';
import 'package:historical_camera/platform/camera_event.dart';
import 'package:historical_camera/platform/native_camera_api.dart';
import 'package:historical_camera/state/camera_state.dart';

class FakeNativeCameraApi implements NativeCameraApi {
  final calls = <String>[];
  FilterParams? lastParams;
  final eventsController = StreamController<CameraEvent>.broadcast();
  String? initializeErrorCode;
  Completer<CapturedPhoto>? pendingCapture;

  @override
  Stream<CameraEvent> get events => eventsController.stream;

  @override
  Future<PreviewInfo> initialize({
    String lens = 'back',
    String resolutionPreset = 'hd720',
  }) async {
    calls.add('initialize');
    final code = initializeErrorCode;
    if (code != null) {
      throw PlatformException(code: code, message: 'boom');
    }
    return const PreviewInfo(
      textureId: 7,
      previewWidth: 1280,
      previewHeight: 720,
      quarterTurns: 1,
    );
  }

  @override
  Future<void> setFilterParams(FilterParams params) async {
    calls.add('setFilterParams');
    lastParams = params;
  }

  @override
  Future<CapturedPhoto> capturePhoto() {
    calls.add('capturePhoto');
    final pending = pendingCapture;
    if (pending != null) return pending.future;
    return Future.value(
      const CapturedPhoto(path: '/tmp/p.jpg', width: 4032, height: 3024),
    );
  }

  @override
  Future<void> pausePreview() async => calls.add('pausePreview');

  @override
  Future<void> resumePreview() async => calls.add('resumePreview');

  @override
  Future<void> startRecording() async => calls.add('startRecording');

  @override
  Future<RecordingResult> stopRecording() async =>
      const RecordingResult(path: '', durationMs: 0);

  @override
  Future<void> setZoom(double zoom) async => calls.add('setZoom');

  @override
  Future<PreviewInfo> switchLens(String lens) => throw UnimplementedError();

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class FakePermissionService implements PermissionService {
  FakePermissionService({required this.granted});

  bool granted;
  int openAppSettingsCalls = 0;

  @override
  Future<bool> requestCamera() async => granted;

  @override
  Future<void> openAppSettings() async => openAppSettingsCalls++;
}

const nowYear = 2026;

({
  ProviderContainer container,
  FakeNativeCameraApi api,
  FakePermissionService permissions,
}) makeHarness({bool granted = true}) {
  final api = FakeNativeCameraApi();
  final permissions = FakePermissionService(granted: granted);
  final container = ProviderContainer(overrides: [
    nowYearProvider.overrideWithValue(nowYear),
    nativeCameraApiProvider.overrideWithValue(api),
    permissionServiceProvider.overrideWithValue(permissions),
  ]);
  addTearDown(container.dispose);
  addTearDown(api.eventsController.close);
  return (container: container, api: api, permissions: permissions);
}

Future<void> pumpEvents() => Future<void>.delayed(Duration.zero);

void main() {
  group('initial state', () {
    test('starts uninitialized at the current year', () {
      final h = makeHarness();
      final state = h.container.read(cameraNotifierProvider);
      expect(state.phase, CameraPhase.uninitialized);
      expect(state.year, nowYear.toDouble());
      expect(state.quantizedYear, nowYear);
      expect(state.mode, CaptureMode.photo);
      expect(state.textureId, isNull);
    });
  });

  group('initialize (docs/04 §5)', () {
    test('success: permission -> native init -> previewing', () async {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();

      final state = h.container.read(cameraNotifierProvider);
      expect(state.phase, CameraPhase.previewing);
      expect(state.textureId, 7);
      expect(state.previewWidth, 1280);
      expect(state.previewHeight, 720);
      expect(state.quarterTurns, 1);
      // Initial params push: neutral because year == nowYear.
      expect(h.api.lastParams, FilterParams.neutral);
    });

    test('permission denied: native is never touched', () async {
      final h = makeHarness(granted: false);
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();

      expect(h.container.read(cameraNotifierProvider).phase,
          CameraPhase.permissionDenied);
      expect(h.api.calls, isEmpty);
    });

    test('native CAMERA_PERMISSION_DENIED maps to permissionDenied', () async {
      final h = makeHarness();
      h.api.initializeErrorCode = CameraErrorCodes.cameraPermissionDenied;
      await h.container.read(cameraNotifierProvider.notifier).initialize();
      expect(h.container.read(cameraNotifierProvider).phase,
          CameraPhase.permissionDenied);
    });

    test('other native error maps to error with message', () async {
      final h = makeHarness();
      h.api.initializeErrorCode = CameraErrorCodes.cameraUnavailable;
      await h.container.read(cameraNotifierProvider.notifier).initialize();

      final state = h.container.read(cameraNotifierProvider);
      expect(state.phase, CameraPhase.error);
      expect(state.errorMessage, 'boom');
    });

    test('retry from error is allowed and clears the message', () async {
      final h = makeHarness();
      h.api.initializeErrorCode = CameraErrorCodes.cameraUnavailable;
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();
      expect(
          h.container.read(cameraNotifierProvider).phase, CameraPhase.error);

      h.api.initializeErrorCode = null;
      await notifier.initialize();
      final state = h.container.read(cameraNotifierProvider);
      expect(state.phase, CameraPhase.previewing);
      expect(state.errorMessage, isNull);
    });

    test('initialize is a no-op while previewing', () async {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();
      await notifier.initialize();
      expect(h.api.calls.where((c) => c == 'initialize'), hasLength(1));
    });
  });

  group('year changes (docs/04 §2.2)', () {
    test('updates continuous + quantized year and pushes params', () async {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();

      notifier.onYearChanged(1973.4);
      final state = h.container.read(cameraNotifierProvider);
      expect(state.year, 1973.4);
      expect(state.quantizedYear, 1970);
      expect(h.api.lastParams, paramsForYear(1973.4, nowYear));
    });

    test('quantized year is capped at nowYear and clamped at 1000', () {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);

      notifier.onYearChanged(nowYear.toDouble());
      expect(h.container.read(cameraNotifierProvider).quantizedYear, nowYear);

      notifier.onYearChanged(999);
      final state = h.container.read(cameraNotifierProvider);
      expect(state.year, 1000);
      expect(state.quantizedYear, 1000);
    });

    test('onYearChangeEnd snaps to the quantized year', () {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      notifier.onYearChangeEnd(1970);
      final state = h.container.read(cameraNotifierProvider);
      expect(state.year, 1970.0);
      expect(state.quantizedYear, 1970);
    });
  });

  group('capturePhoto (docs/04 §5)', () {
    test('previewing -> capturing -> previewing with saved path', () async {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();

      h.api.pendingCapture = Completer<CapturedPhoto>();
      final capture = notifier.capturePhoto();
      expect(h.container.read(cameraNotifierProvider).phase,
          CameraPhase.capturing);

      // A second tap while capturing is ignored (docs/04 §4 double-tap guard).
      await notifier.capturePhoto();
      expect(h.api.calls.where((c) => c == 'capturePhoto'), hasLength(1));

      h.api.pendingCapture!.complete(
        const CapturedPhoto(path: '/tmp/p.jpg', width: 4032, height: 3024),
      );
      await capture;

      final state = h.container.read(cameraNotifierProvider);
      expect(state.phase, CameraPhase.previewing);
      expect(state.lastSavedPath, '/tmp/p.jpg');
    });

    test('is ignored unless previewing', () async {
      final h = makeHarness();
      await h.container.read(cameraNotifierProvider.notifier).capturePhoto();
      expect(h.api.calls, isEmpty);
    });

    test('failure returns to previewing and surfaces the message', () async {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();

      h.api.pendingCapture = Completer<CapturedPhoto>()
        ..completeError(PlatformException(
            code: CameraErrorCodes.captureFailed, message: 'no space'));
      await notifier.capturePhoto();

      final state = h.container.read(cameraNotifierProvider);
      expect(state.phase, CameraPhase.previewing);
      expect(state.errorMessage, 'no space');
    });
  });

  group('pause / resume', () {
    test('previewing <-> paused', () async {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();

      await notifier.pause();
      expect(
          h.container.read(cameraNotifierProvider).phase, CameraPhase.paused);
      expect(h.api.calls, contains('pausePreview'));

      await notifier.resume();
      expect(h.container.read(cameraNotifierProvider).phase,
          CameraPhase.previewing);
      expect(h.api.calls, contains('resumePreview'));
    });

    test('pause is a no-op when not previewing', () async {
      final h = makeHarness();
      await h.container.read(cameraNotifierProvider.notifier).pause();
      expect(h.api.calls, isEmpty);
    });
  });

  group('native events update state', () {
    test('orientationChanged / thermal / photoSaved / error', () async {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      await notifier.initialize();

      h.api.eventsController
        ..add(const CameraEvent.orientationChanged(3))
        ..add(const CameraEvent.thermal(ThermalLevel.serious))
        ..add(const CameraEvent.photoSaved('/tmp/saved.jpg'))
        ..add(const CameraEvent.error('CAMERA_UNAVAILABLE', 'interrupted'));
      await pumpEvents();

      final state = h.container.read(cameraNotifierProvider);
      expect(state.quarterTurns, 3);
      expect(state.thermal, ThermalLevel.serious);
      expect(state.lastSavedPath, '/tmp/saved.jpg');
      expect(state.errorMessage, 'interrupted');
      // Runtime error events do not kill the preview.
      expect(state.phase, CameraPhase.previewing);
    });
  });

  group('mode & settings', () {
    test('setMode switches shutter mode', () {
      final h = makeHarness();
      final notifier = h.container.read(cameraNotifierProvider.notifier);
      notifier.setMode(CaptureMode.video);
      expect(
          h.container.read(cameraNotifierProvider).mode, CaptureMode.video);
    });

    test('openAppSettings delegates to the permission service', () async {
      final h = makeHarness();
      await h.container.read(cameraNotifierProvider.notifier).openAppSettings();
      expect(h.permissions.openAppSettingsCalls, 1);
    });
  });
}
