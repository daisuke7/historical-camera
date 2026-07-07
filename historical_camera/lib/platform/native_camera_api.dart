import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/filter_params.dart';
import 'camera_event.dart';

/// Error codes shared with the native side (docs/02 §3.1).
abstract final class CameraErrorCodes {
  static const cameraPermissionDenied = 'CAMERA_PERMISSION_DENIED';
  static const cameraUnavailable = 'CAMERA_UNAVAILABLE';
  static const captureFailed = 'CAPTURE_FAILED';
  static const saveFailed = 'SAVE_FAILED';
  static const recordingFailed = 'RECORDING_FAILED';
  static const badState = 'BAD_STATE';
}

/// Result of `initialize` / `switchLens` (docs/02 §3.1). Preview dimensions
/// are sensor-oriented (landscape) and never change on rotation (docs/02
/// §4.1); [quarterTurns] is the clockwise rotation that makes the texture
/// upright on screen.
class PreviewInfo {
  const PreviewInfo({
    required this.textureId,
    required this.previewWidth,
    required this.previewHeight,
    required this.quarterTurns,
  });

  final int textureId;
  final int previewWidth;
  final int previewHeight;
  final int quarterTurns;
}

/// Result of `capturePhoto`. [path] is a temp-file absolute path usable for
/// sharing; the photo itself is already saved to the gallery.
class CapturedPhoto {
  const CapturedPhoto({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

/// Result of `stopRecording` (P2).
class RecordingResult {
  const RecordingResult({required this.path, required this.durationMs});

  final String path;
  final int durationMs;
}

/// Typed wrapper around the platform channels (docs/02 §3). This is the only
/// Dart class that touches the channels.
class NativeCameraApi {
  NativeCameraApi({MethodChannel? methodChannel, EventChannel? eventChannel})
      : _method = methodChannel ?? const MethodChannel(_methodChannelName),
        _event = eventChannel ?? const EventChannel(_eventChannelName);

  static const _methodChannelName = 'historical_camera/method';
  static const _eventChannelName = 'historical_camera/event';

  /// Minimum interval between two `setFilterParams` sends (docs/02 §2).
  static const throttleInterval = Duration(milliseconds: 16);

  final MethodChannel _method;
  final EventChannel _event;

  Stream<CameraEvent>? _events;

  // Throttle state: while in cooldown, only the newest params are stashed and
  // flushed when the window closes, so the last value is always delivered.
  bool _inCooldown = false;
  FilterParams? _pendingParams;
  Timer? _cooldownTimer;

  /// Native event stream. Listen before calling [initialize]
  /// (docs/02 §3.2 subscription order).
  Stream<CameraEvent> get events =>
      _events ??= _event.receiveBroadcastStream().expand((raw) {
        final event = CameraEvent.fromMap(raw as Map<Object?, Object?>);
        return event == null ? const <CameraEvent>[] : [event];
      });

  Future<PreviewInfo> initialize({
    String lens = 'back',
    String resolutionPreset = 'hd720',
  }) async {
    final map = await _method.invokeMapMethod<String, Object?>('initialize', {
      'lens': lens,
      'resolutionPreset': resolutionPreset,
    });
    return _previewInfoFromMap(map!);
  }

  /// Sends the newest filter parameters, throttled to one send per 16 ms.
  /// The returned future completes when the immediate send completes; when
  /// the value is deferred by throttling it completes right away.
  Future<void> setFilterParams(FilterParams params) {
    if (_inCooldown) {
      _pendingParams = params;
      return Future<void>.value();
    }
    return _sendParams(params);
  }

  Future<CapturedPhoto> capturePhoto() async {
    final map = await _method.invokeMapMethod<String, Object?>('capturePhoto');
    return CapturedPhoto(
      path: map!['path']! as String,
      width: (map['width']! as num).toInt(),
      height: (map['height']! as num).toInt(),
    );
  }

  Future<void> startRecording() =>
      _method.invokeMethod<void>('startRecording');

  Future<RecordingResult> stopRecording() async {
    final map =
        await _method.invokeMapMethod<String, Object?>('stopRecording');
    return RecordingResult(
      path: map!['path']! as String,
      durationMs: (map['durationMs']! as num).toInt(),
    );
  }

  Future<void> pausePreview() => _method.invokeMethod<void>('pausePreview');

  Future<void> resumePreview() => _method.invokeMethod<void>('resumePreview');

  Future<void> setZoom(double zoom) =>
      _method.invokeMethod<void>('setZoom', {'zoom': zoom});

  /// Enables the 1 Hz `debugStats` event while the debug panel is visible
  /// (docs/02 §3.1). Off by default so normal runs carry no measurement
  /// overhead.
  Future<void> setDebugStatsEnabled(bool enabled) => _method
      .invokeMethod<void>('setDebugStatsEnabled', {'enabled': enabled});

  Future<PreviewInfo> switchLens(String lens) async {
    final map = await _method
        .invokeMapMethod<String, Object?>('switchLens', {'lens': lens});
    return _previewInfoFromMap(map!);
  }

  Future<void> dispose() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _pendingParams = null;
    _inCooldown = false;
    return _method.invokeMethod<void>('dispose');
  }

  Future<void> _sendParams(FilterParams params) {
    _inCooldown = true;
    _cooldownTimer = Timer(throttleInterval, _onCooldownEnd);
    return _method.invokeMethod<void>('setFilterParams', params.toMap());
  }

  void _onCooldownEnd() {
    final pending = _pendingParams;
    _pendingParams = null;
    if (pending != null) {
      _sendParams(pending);
    } else {
      _inCooldown = false;
    }
  }

  static PreviewInfo _previewInfoFromMap(Map<String, Object?> map) {
    return PreviewInfo(
      textureId: (map['textureId']! as num).toInt(),
      previewWidth: (map['previewWidth']! as num).toInt(),
      previewHeight: (map['previewHeight']! as num).toInt(),
      quarterTurns: (map['quarterTurns']! as num).toInt(),
    );
  }
}
