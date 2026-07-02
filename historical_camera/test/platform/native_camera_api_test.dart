import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historical_camera/domain/filter_params.dart';
import 'package:historical_camera/platform/camera_event.dart';
import 'package:historical_camera/platform/native_camera_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('historical_camera/method');
  const eventChannel = EventChannel('historical_camera/event');

  late List<MethodCall> log;
  late Object? Function(MethodCall call) responder;

  setUp(() {
    log = [];
    responder = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      return responder(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('setFilterParams throttling (docs/02 §3.3)', () {
    test('sends at most once per 16ms and always delivers the last value',
        () {
      final api = NativeCameraApi();
      const p1 = FilterParams.neutral;
      final p2 = FilterParams.neutral.copyWith(monochrome: 0.2);
      final p3 = FilterParams.neutral.copyWith(monochrome: 0.9);

      fakeAsync((async) {
        api.setFilterParams(p1);
        async.flushMicrotasks();
        expect(log, hasLength(1), reason: 'idle -> immediate send');

        api.setFilterParams(p2);
        api.setFilterParams(p3);
        async.flushMicrotasks();
        expect(log, hasLength(1), reason: 'cooldown holds sends back');

        async.elapse(NativeCameraApi.throttleInterval);
        async.flushMicrotasks();
        expect(log, hasLength(2), reason: 'window close flushes pending');
        expect((log.last.arguments as Map)['monochrome'], 0.9,
            reason: 'the LAST value must be the one delivered');

        // A send right after the flush is throttled again.
        api.setFilterParams(p2);
        async.flushMicrotasks();
        expect(log, hasLength(2));
        async.elapse(NativeCameraApi.throttleInterval);
        async.flushMicrotasks();
        expect(log, hasLength(3));
        expect((log.last.arguments as Map)['monochrome'], 0.2);

        // After a fully idle window, sends are immediate again.
        async.elapse(const Duration(milliseconds: 20));
        api.setFilterParams(p1);
        async.flushMicrotasks();
        expect(log, hasLength(4));
      });
    });
  });

  group('method wrappers', () {
    test('initialize sends defaults and parses PreviewInfo', () async {
      responder = (call) {
        expect(call.method, 'initialize');
        expect(call.arguments, {'lens': 'back', 'resolutionPreset': 'hd720'});
        return <String, Object?>{
          'textureId': 42,
          'previewWidth': 1280,
          'previewHeight': 720,
          'quarterTurns': 1,
        };
      };
      final info = await NativeCameraApi().initialize();
      expect(info.textureId, 42);
      expect(info.previewWidth, 1280);
      expect(info.previewHeight, 720);
      expect(info.quarterTurns, 1);
    });

    test('capturePhoto parses CapturedPhoto', () async {
      responder = (_) => <String, Object?>{
            'path': '/tmp/photo.jpg',
            'width': 4032,
            'height': 3024,
          };
      final photo = await NativeCameraApi().capturePhoto();
      expect(photo.path, '/tmp/photo.jpg');
      expect(photo.width, 4032);
      expect(photo.height, 3024);
    });

    test('PlatformException from native propagates', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: CameraErrorCodes.badState);
      });
      expect(
        NativeCameraApi().capturePhoto(),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', CameraErrorCodes.badState)),
      );
    });
  });

  group('event stream', () {
    test('maps event maps to typed events and skips unknown types', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'type': 'initialized'});
            events.success({'type': 'orientationChanged', 'quarterTurns': 3});
            events.success({'type': 'some_future_event'});
            events.success({'type': 'photoSaved', 'path': '/tmp/x.jpg'});
            events.success({'type': 'thermal', 'level': 'serious'});
            events.success({'type': 'recordingProgress', 'elapsedMs': 1000});
            events
                .success({'type': 'error', 'code': 'SAVE_FAILED', 'message': 'disk full'});
            events.endOfStream();
          },
        ),
      );

      final received = await NativeCameraApi().events.toList();
      expect(received, const [
        CameraEvent.initialized(),
        CameraEvent.orientationChanged(3),
        CameraEvent.photoSaved('/tmp/x.jpg'),
        CameraEvent.thermal(ThermalLevel.serious),
        CameraEvent.recordingProgress(1000),
        CameraEvent.error('SAVE_FAILED', 'disk full'),
      ]);
    });
  });

  group('CameraEvent.fromMap', () {
    test('returns null for unknown types', () {
      expect(CameraEvent.fromMap(const {'type': 'nope'}), isNull);
      expect(CameraEvent.fromMap(const {}), isNull);
    });

    test('unknown thermal level falls back to nominal', () {
      expect(
        CameraEvent.fromMap(const {'type': 'thermal', 'level': 'volcanic'}),
        const CameraEvent.thermal(ThermalLevel.nominal),
      );
    });
  });
}
