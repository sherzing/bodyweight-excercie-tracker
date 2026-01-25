import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pushup_counter/services/rep_frame_capture_service.dart';

// Mock PathProvider for tests
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  String? _tempPath;

  void setTempPath(String path) {
    _tempPath = path;
  }

  @override
  Future<String?> getTemporaryPath() async => _tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RepFrameCaptureService service;
  late Directory tempDir;
  late MockPathProviderPlatform mockPathProvider;

  setUp(() async {
    // Create a temporary directory for tests
    tempDir = await Directory.systemTemp.createTemp('rep_frame_test_');

    // Set up mock path provider
    mockPathProvider = MockPathProviderPlatform();
    mockPathProvider.setTempPath(tempDir.path);
    PathProviderPlatform.instance = mockPathProvider;

    service = RepFrameCaptureService();
  });

  tearDown(() async {
    // Clean up temp directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CapturedFrame', () {
    test('creates with required parameters', () {
      final frame = CapturedFrame(
        path: '/path/to/frame.jpg',
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        positionType: 'down',
        repIndex: 0,
      );

      expect(frame.path, '/path/to/frame.jpg');
      expect(frame.positionType, 'down');
      expect(frame.repIndex, 0);
      expect(frame.elbowAngle, isNull);
    });

    test('creates with elbow angle', () {
      final frame = CapturedFrame(
        path: '/path/to/frame.jpg',
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        positionType: 'up',
        repIndex: 1,
        elbowAngle: 165.0,
      );

      expect(frame.elbowAngle, 165.0);
    });

    test('toMap and fromMap roundtrip', () {
      final original = CapturedFrame(
        path: '/path/to/frame.jpg',
        timestamp: DateTime(2026, 1, 25, 12, 30, 0),
        positionType: 'transition',
        repIndex: 2,
        elbowAngle: 120.5,
      );

      final map = original.toMap();
      final restored = CapturedFrame.fromMap(map);

      expect(restored.path, original.path);
      expect(restored.timestamp, original.timestamp);
      expect(restored.positionType, original.positionType);
      expect(restored.repIndex, original.repIndex);
      expect(restored.elbowAngle, original.elbowAngle);
    });
  });

  group('RepFrameCaptureService', () {
    test('starts uninitialized', () {
      expect(service.sessionId, isNull);
      expect(service.sessionFrames, isEmpty);
      expect(service.isCaptureEnabled, isFalse);
    });

    test('startSession initializes service', () async {
      await service.startSession();

      expect(service.sessionId, isNotNull);
      expect(service.sessionFrames, isEmpty);
    });

    test('endSession clears session', () async {
      await service.startSession();
      service.endSession();

      expect(service.sessionId, isNull);
    });

    test('enableCapture and disableCapture toggle capture state', () async {
      await service.startSession();

      expect(service.isCaptureEnabled, isFalse);

      service.enableCapture();
      expect(service.isCaptureEnabled, isTrue);

      service.disableCapture();
      expect(service.isCaptureEnabled, isFalse);
    });

    test('captureFrameFromBytes saves frame when enabled', () async {
      await service.startSession();
      service.startRep(0);
      service.enableCapture();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      final frame = await service.captureFrameFromBytes(
        bytes: bytes,
        positionType: 'down',
        elbowAngle: 85.0,
      );

      expect(frame, isNotNull);
      expect(frame!.positionType, 'down');
      expect(frame.elbowAngle, 85.0);
      expect(frame.repIndex, 0);
      expect(File(frame.path).existsSync(), isTrue);
    });

    test('captureFrameFromBytes returns null when not enabled', () async {
      await service.startSession();
      service.startRep(0);
      // Not calling enableCapture

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      final frame = await service.captureFrameFromBytes(
        bytes: bytes,
        positionType: 'down',
      );

      expect(frame, isNull);
    });

    test('captureFrameFromBytes respects max frames per rep', () async {
      await service.startSession();
      service.startRep(0);
      service.enableCapture();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);

      // Capture max frames (5)
      for (var i = 0; i < 5; i++) {
        final frame = await service.captureFrameFromBytes(
          bytes: bytes,
          positionType: 'frame_$i',
        );
        expect(frame, isNotNull);
      }

      // 6th frame should be null
      final extraFrame = await service.captureFrameFromBytes(
        bytes: bytes,
        positionType: 'extra',
      );
      expect(extraFrame, isNull);
    });

    test('completeRep keeps frames for invalid reps', () async {
      await service.startSession();
      service.startRep(0);
      service.enableCapture();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      await service.captureFrameFromBytes(bytes: bytes, positionType: 'down');
      await service.captureFrameFromBytes(bytes: bytes, positionType: 'up');

      final paths = service.completeRep(isInvalid: true);

      expect(paths.length, 2);
      expect(service.sessionFrames.length, 2);
    });

    test('completeRep discards frames for valid reps', () async {
      await service.startSession();
      service.startRep(0);
      service.enableCapture();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      final frame = await service.captureFrameFromBytes(
        bytes: bytes,
        positionType: 'down',
      );
      final framePath = frame!.path;

      final paths = service.completeRep(isInvalid: false);

      expect(paths, isEmpty);
      expect(service.sessionFrames, isEmpty);
      // Frame file should be deleted
      expect(File(framePath).existsSync(), isFalse);
    });

    test('startRep clears current rep frames', () async {
      await service.startSession();
      service.startRep(0);
      service.enableCapture();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      await service.captureFrameFromBytes(bytes: bytes, positionType: 'down');

      expect(service.currentRepFrames.length, 1);

      service.startRep(1);
      expect(service.currentRepFrames, isEmpty);
    });

    test('getFramesForRep returns frames for specific rep', () async {
      await service.startSession();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);

      // Rep 0
      service.startRep(0);
      service.enableCapture();
      await service.captureFrameFromBytes(bytes: bytes, positionType: 'down');
      service.completeRep(isInvalid: true);

      // Rep 1
      service.startRep(1);
      service.enableCapture();
      await service.captureFrameFromBytes(bytes: bytes, positionType: 'down');
      await service.captureFrameFromBytes(bytes: bytes, positionType: 'up');
      service.completeRep(isInvalid: true);

      expect(service.getFramesForRep(0).length, 1);
      expect(service.getFramesForRep(1).length, 2);
      expect(service.getFramesForRep(2), isEmpty);
    });

    test('getFramePathsForRep returns paths', () async {
      await service.startSession();
      service.startRep(0);
      service.enableCapture();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      await service.captureFrameFromBytes(bytes: bytes, positionType: 'down');
      await service.captureFrameFromBytes(bytes: bytes, positionType: 'up');
      service.completeRep(isInvalid: true);

      final paths = service.getFramePathsForRep(0);
      expect(paths.length, 2);
      expect(paths.every((p) => p.endsWith('.jpg')), isTrue);
    });

    test('cleanupSession removes all frames', () async {
      await service.startSession();
      service.startRep(0);
      service.enableCapture();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      final frame = await service.captureFrameFromBytes(
        bytes: bytes,
        positionType: 'down',
      );
      final framePath = frame!.path;
      service.completeRep(isInvalid: true);

      expect(File(framePath).existsSync(), isTrue);

      await service.cleanupSession();

      expect(service.sessionFrames, isEmpty);
      expect(File(framePath).existsSync(), isFalse);
    });

    test('cleanupReps removes specific rep frames', () async {
      await service.startSession();

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);

      // Rep 0
      service.startRep(0);
      service.enableCapture();
      final frame0 = await service.captureFrameFromBytes(
        bytes: bytes,
        positionType: 'down',
      );
      service.completeRep(isInvalid: true);

      // Rep 1
      service.startRep(1);
      service.enableCapture();
      final frame1 = await service.captureFrameFromBytes(
        bytes: bytes,
        positionType: 'down',
      );
      service.completeRep(isInvalid: true);

      expect(service.sessionFrames.length, 2);

      await service.cleanupReps([0]);

      expect(service.sessionFrames.length, 1);
      expect(service.getFramesForRep(0), isEmpty);
      expect(service.getFramesForRep(1).length, 1);
      expect(File(frame0!.path).existsSync(), isFalse);
      expect(File(frame1!.path).existsSync(), isTrue);
    });
  });
}
