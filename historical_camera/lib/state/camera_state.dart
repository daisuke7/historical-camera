import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/era_filter.dart';
import '../platform/camera_event.dart';
import '../platform/native_camera_api.dart';

part 'camera_state.freezed.dart';

/// App phase (docs/04 §5 state machine).
enum CameraPhase {
  uninitialized,
  initializing,
  previewing,
  capturing,
  recording,
  paused,
  permissionDenied,
  error,
}

/// Shutter mode. Video stays hidden in the UI until P2 (docs/04 §4).
enum CaptureMode { photo, video }

/// Immutable app state held by [CameraNotifier] (docs/04 §5).
@freezed
abstract class CameraState with _$CameraState {
  const CameraState._();

  const factory CameraState({
    required CameraPhase phase,
    required int nowYear,

    /// Continuous slider year; drives the filter during a drag.
    required double year,

    /// Year quantized to decades, capped at [nowYear] (docs/04 §2.2).
    required int quantizedYear,
    required CaptureMode mode,

    /// Clockwise 90-degree turns to display the preview upright.
    required int quarterTurns,
    required ThermalLevel thermal,
    required int recordingElapsedMs,
    int? textureId,
    int? previewWidth,
    int? previewHeight,
    String? lastSavedPath,
    String? errorMessage,
  }) = _CameraState;

  factory CameraState.initial(int nowYear) => CameraState(
        phase: CameraPhase.uninitialized,
        nowYear: nowYear,
        year: nowYear.toDouble(),
        quantizedYear: nowYear,
        mode: CaptureMode.photo,
        quarterTurns: 0,
        thermal: ThermalLevel.nominal,
        recordingElapsedMs: 0,
      );
}

/// Thin wrapper around permission_handler so tests can substitute it.
class PermissionService {
  const PermissionService();

  Future<bool> requestCamera() async =>
      (await ph.Permission.camera.request()).isGranted;

  Future<void> openAppSettings() => ph.openAppSettings();
}

/// Thin wrapper around wakelock_plus so tests can substitute it
/// (docs/04 §6: screen sleep is disabled while previewing).
class WakelockService {
  const WakelockService();

  Future<void> setEnabled(bool enabled) =>
      WakelockPlus.toggle(enable: enabled);
}

/// Current calendar year (docs/08 §6.4: `DateTime.now().year`).
final nowYearProvider = Provider<int>((_) => DateTime.now().year);

final wakelockServiceProvider = Provider<WakelockService>(
  (_) => const WakelockService(),
);

final nativeCameraApiProvider = Provider<NativeCameraApi>(
  (_) => NativeCameraApi(),
);

final permissionServiceProvider = Provider<PermissionService>(
  (_) => const PermissionService(),
);

final cameraNotifierProvider =
    NotifierProvider<CameraNotifier, CameraState>(CameraNotifier.new);

/// Owns the docs/04 §5 state machine and is the only caller of
/// [NativeCameraApi].
class CameraNotifier extends Notifier<CameraState> {
  StreamSubscription<CameraEvent>? _eventSub;

  /// Preset passed to native `initialize`. "auto" is the default since T14:
  /// native resolves it from the persisted 1080p gate result (docs/01 §1.1,
  /// 08 §8.3). The debug panel can override it explicitly (docs/04 §8.2).
  String _resolutionPreset = 'auto';

  @override
  CameraState build() {
    ref.onDispose(() {
      _eventSub?.cancel();
      _eventSub = null;
    });
    return CameraState.initial(ref.watch(nowYearProvider));
  }

  NativeCameraApi get _api => ref.read(nativeCameraApiProvider);

  /// Requests the camera permission (via permission_handler, before touching
  /// the channel — docs/02 §3.1) and starts the native session.
  Future<void> initialize() async {
    if (state.phase != CameraPhase.uninitialized &&
        state.phase != CameraPhase.permissionDenied &&
        state.phase != CameraPhase.error) {
      return;
    }
    state = state.copyWith(phase: CameraPhase.initializing, errorMessage: null);

    final granted =
        await ref.read(permissionServiceProvider).requestCamera();
    if (!granted) {
      state = state.copyWith(phase: CameraPhase.permissionDenied);
      return;
    }

    // Subscribe before initialize (docs/02 §3.2 subscription order).
    _eventSub ??= _api.events.listen(_onEvent);

    try {
      final info =
          await _api.initialize(resolutionPreset: _resolutionPreset);
      state = state.copyWith(
        phase: CameraPhase.previewing,
        textureId: info.textureId,
        previewWidth: info.previewWidth,
        previewHeight: info.previewHeight,
        quarterTurns: info.quarterTurns,
      );
      // Make native reflect the current slider position (relevant after
      // a re-initialize; sends neutral on a fresh boot).
      unawaited(_api.setFilterParams(paramsForYear(state.year, state.nowYear)));
    } on PlatformException catch (e) {
      state = state.copyWith(
        phase: e.code == CameraErrorCodes.cameraPermissionDenied
            ? CameraPhase.permissionDenied
            : CameraPhase.error,
        errorMessage: e.message ?? e.code,
      );
    } on MissingPluginException {
      // Native side not implemented yet (before tasks T5/T8): fail visibly
      // instead of spinning forever.
      state = state.copyWith(
        phase: CameraPhase.error,
        errorMessage: 'native camera plugin is not implemented yet',
      );
    }
  }

  /// Slider drag (continuous year). Updates state and pushes filter params
  /// (throttling happens inside [NativeCameraApi]).
  void onYearChanged(double year) {
    final clamped = year.clamp(1000.0, state.nowYear.toDouble());
    state = state.copyWith(
      year: clamped,
      quantizedYear: _quantize(clamped),
    );
    unawaited(_api.setFilterParams(paramsForYear(clamped, state.nowYear)));
  }

  /// Slider release: snap target year (docs/04 §2.2).
  void onYearChangeEnd(int quantizedYear) {
    onYearChanged(quantizedYear.toDouble());
  }

  void setMode(CaptureMode mode) {
    if (state.phase == CameraPhase.recording) return;
    state = state.copyWith(mode: mode);
  }

  Future<void> capturePhoto() async {
    if (state.phase != CameraPhase.previewing) return;
    state = state.copyWith(phase: CameraPhase.capturing);
    try {
      final photo = await _api.capturePhoto();
      state = state.copyWith(
        phase: CameraPhase.previewing,
        lastSavedPath: photo.path,
      );
    } on PlatformException catch (e) {
      // Capture failures are transient: stay in preview, surface the message.
      state = state.copyWith(
        phase: CameraPhase.previewing,
        errorMessage: e.message ?? e.code,
      );
    }
  }

  Future<void> pause() async {
    if (state.phase != CameraPhase.previewing) return;
    await _api.pausePreview();
    state = state.copyWith(phase: CameraPhase.paused);
  }

  Future<void> resume() async {
    if (state.phase != CameraPhase.paused) return;
    await _api.resumePreview();
    state = state.copyWith(phase: CameraPhase.previewing);
  }

  /// Debug-panel resolution override (docs/04 §8.2): tears the native
  /// session down and re-initializes with the given preset.
  Future<void> reinitializeWithPreset(String resolutionPreset) async {
    if (state.phase == CameraPhase.initializing ||
        state.phase == CameraPhase.capturing ||
        state.phase == CameraPhase.recording) {
      return;
    }
    _resolutionPreset = resolutionPreset;
    try {
      await _api.dispose();
    } on PlatformException {
      // A half-open session must not block the re-initialize.
    }
    state = state.copyWith(
      phase: CameraPhase.uninitialized,
      textureId: null,
      previewWidth: null,
      previewHeight: null,
    );
    await initialize();
  }

  Future<void> openAppSettings() =>
      ref.read(permissionServiceProvider).openAppSettings();

  int _quantize(double year) =>
      math.min(state.nowYear, (year / 10).round() * 10);

  void _onEvent(CameraEvent event) {
    switch (event) {
      case OrientationChangedEvent(:final quarterTurns):
        state = state.copyWith(quarterTurns: quarterTurns);
      case PhotoSavedEvent(:final path):
        state = state.copyWith(lastSavedPath: path);
      case ThermalEvent(:final level):
        state = state.copyWith(thermal: level);
      case RecordingProgressEvent(:final elapsedMs):
        state = state.copyWith(recordingElapsedMs: elapsedMs);
      case CameraErrorEvent(:final code, :final message):
        if (code == CameraErrorCodes.rotationModelMismatch) {
          // Diagnostic only (docs/02 §3.2): log, never touch UI state.
          debugPrint('rotation model mismatch: $message');
          break;
        }
        state = state.copyWith(
          errorMessage: message.isEmpty ? code : message,
        );
      case DebugStatsEvent():
        // Consumed by the debug panel's own provider (docs/04 §8.3).
        break;
      case CameraInitializedEvent():
        // Auxiliary only; never drive transitions from it (docs/02 §3.2).
        break;
    }
  }
}
