import 'package:freezed_annotation/freezed_annotation.dart';

part 'camera_event.freezed.dart';

/// Device thermal level reported by the native side (docs/02 §3.2, §6.1).
enum ThermalLevel { nominal, fair, serious, critical }

/// Native-to-Dart notifications delivered over the EventChannel
/// `historical_camera/event` (docs/02 §3.2).
///
/// Sealed union so `switch` expressions get exhaustiveness checking.
@freezed
sealed class CameraEvent with _$CameraEvent {
  /// Session start completed. Auxiliary only: state transitions must rely on
  /// the `initialize()` future, never on this event (docs/02 §3.2).
  const factory CameraEvent.initialized() = CameraInitializedEvent;

  /// Display rotation changed; update the RotatedBox (docs/02 §4.1).
  const factory CameraEvent.orientationChanged(int quarterTurns) =
      OrientationChangedEvent;

  /// A captured photo finished saving to the gallery.
  const factory CameraEvent.photoSaved(String path) = PhotoSavedEvent;

  /// Device thermal state changed.
  const factory CameraEvent.thermal(ThermalLevel level) = ThermalEvent;

  /// Recording progress tick, once per second (P2).
  const factory CameraEvent.recordingProgress(int elapsedMs) =
      RecordingProgressEvent;

  /// Runtime error (session interruption, disk full, ...).
  const factory CameraEvent.error(String code, String message) =
      CameraErrorEvent;

  /// Parses an event map from the EventChannel. Returns null for unknown
  /// types so future native-side additions don't break older Dart code.
  static CameraEvent? fromMap(Map<Object?, Object?> map) {
    switch (map['type']) {
      case 'initialized':
        return const CameraEvent.initialized();
      case 'orientationChanged':
        return CameraEvent.orientationChanged(
          (map['quarterTurns']! as num).toInt(),
        );
      case 'photoSaved':
        return CameraEvent.photoSaved(map['path']! as String);
      case 'thermal':
        return CameraEvent.thermal(ThermalLevel.values.firstWhere(
          (level) => level.name == map['level'],
          orElse: () => ThermalLevel.nominal,
        ));
      case 'recordingProgress':
        return CameraEvent.recordingProgress(
          (map['elapsedMs']! as num).toInt(),
        );
      case 'error':
        return CameraEvent.error(
          map['code'] as String? ?? 'UNKNOWN',
          map['message'] as String? ?? '',
        );
      default:
        return null;
    }
  }
}
