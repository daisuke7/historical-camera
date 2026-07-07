import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  bool statsEnabled = false;
  String? lastResolutionPreset;
  String? lastLens;
  double? lastZoom;
  PlatformException? switchLensError;

  @override
  Stream<CameraEvent> get events => eventsController.stream;

  @override
  Future<PreviewInfo> initialize({
    String lens = 'back',
    String resolutionPreset = 'auto',
  }) async {
    calls.add('initialize');
    lastResolutionPreset = resolutionPreset;
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
  Future<void> setZoom(double zoom) async {
    calls.add('setZoom');
    lastZoom = zoom;
  }

  @override
  Future<void> setDebugStatsEnabled(bool enabled) async {
    calls.add('setDebugStatsEnabled:$enabled');
    statsEnabled = enabled;
  }

  @override
  Future<PreviewInfo> switchLens(String lens) async {
    calls.add('switchLens');
    lastLens = lens;
    final error = switchLensError;
    if (error != null) throw error;
    // The rebuilt session gets a new texture id (docs/02 §3.1).
    return const PreviewInfo(
      textureId: 8,
      previewWidth: 1280,
      previewHeight: 720,
      quarterTurns: 1,
    );
  }

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

class FakeWakelockService implements WakelockService {
  final states = <bool>[];

  bool get enabled => states.isNotEmpty && states.last;

  @override
  Future<void> setEnabled(bool enabled) async => states.add(enabled);
}

const testNowYear = 2026;

/// Wraps [child] in a ProviderScope whose camera providers are replaced by
/// the given fakes. (flutter_riverpod 3 does not export the `Override` type,
/// so the scope is built here instead of returning an override list.)
Widget buildTestScope({
  required FakeNativeCameraApi api,
  required FakePermissionService permissions,
  required Widget child,
  FakeWakelockService? wakelock,
  int nowYear = testNowYear,
}) {
  return ProviderScope(
    overrides: [
      nowYearProvider.overrideWithValue(nowYear),
      nativeCameraApiProvider.overrideWithValue(api),
      permissionServiceProvider.overrideWithValue(permissions),
      wakelockServiceProvider
          .overrideWithValue(wakelock ?? FakeWakelockService()),
    ],
    child: child,
  );
}

({
  ProviderContainer container,
  FakeNativeCameraApi api,
  FakePermissionService permissions,
}) makeHarness({bool granted = true}) {
  final api = FakeNativeCameraApi();
  final permissions = FakePermissionService(granted: granted);
  final container = ProviderContainer(overrides: [
    nowYearProvider.overrideWithValue(testNowYear),
    nativeCameraApiProvider.overrideWithValue(api),
    permissionServiceProvider.overrideWithValue(permissions),
  ]);
  addTearDown(container.dispose);
  addTearDown(api.eventsController.close);
  return (container: container, api: api, permissions: permissions);
}
