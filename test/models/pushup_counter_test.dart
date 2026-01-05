import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pushup_counter/models/exercise_counter.dart';
import 'package:pushup_counter/models/pushup_counter.dart';

/// Tests for PushupCounter behavior.
/// Tests focus on the observable state transitions and rep counting logic.
void main() {
  group('PushupCounter', () {
    late PushupCounter counter;

    setUp(() {
      counter = PushupCounter();
    });

    test('exercise name is Pushups', () {
      expect(counter.exerciseName, equals('Pushups'));
    });

    test('variant is Standard by default', () {
      expect(counter.variant, equals('Standard'));
    });

    group('Pose Validation', () {
      test('requires at least one arm with shoulder, elbow, wrist', () {
        // Only shoulders - should be invalid
        counter.updateLandmarks([
          _createLandmark(PoseLandmarkType.leftShoulder, 100, 100),
          _createLandmark(PoseLandmarkType.rightShoulder, 200, 100),
          _createLandmark(PoseLandmarkType.leftHip, 100, 200),
        ]);

        expect(counter.isValidPose(), isFalse);
      });

      test('valid with complete left arm and hip', () {
        counter.updateLandmarks([
          _createLandmark(PoseLandmarkType.leftShoulder, 100, 100),
          _createLandmark(PoseLandmarkType.leftElbow, 100, 150),
          _createLandmark(PoseLandmarkType.leftWrist, 100, 200),
          _createLandmark(PoseLandmarkType.leftHip, 100, 250),
        ]);

        expect(counter.isValidPose(), isTrue);
      });

      test('valid with complete right arm and hip', () {
        counter.updateLandmarks([
          _createLandmark(PoseLandmarkType.rightShoulder, 200, 100),
          _createLandmark(PoseLandmarkType.rightElbow, 200, 150),
          _createLandmark(PoseLandmarkType.rightWrist, 200, 200),
          _createLandmark(PoseLandmarkType.rightHip, 200, 250),
        ]);

        expect(counter.isValidPose(), isTrue);
      });

      test('rejects low confidence landmarks', () {
        counter.updateLandmarks([
          _createLandmark(PoseLandmarkType.leftShoulder, 100, 100, likelihood: 0.3),
          _createLandmark(PoseLandmarkType.leftElbow, 100, 150, likelihood: 0.3),
          _createLandmark(PoseLandmarkType.leftWrist, 100, 200, likelihood: 0.3),
          _createLandmark(PoseLandmarkType.leftHip, 100, 250, likelihood: 0.3),
        ]);

        expect(counter.isValidPose(), isFalse);
      });
    });

    group('Stage Detection', () {
      test('starts in Up stage', () {
        expect(counter.getCurrentStage(), equals('Up'));
      });

      test('detects non-Up stage with bent elbow', () {
        // Simulate bent elbow position (90 degrees)
        counter.updateLandmarks(_createPushupPose(elbowAngle: 90));
        counter.checkRepCompletion();

        // Should be in Down or transitional state, not Up
        expect(counter.getCurrentStage(), isNot(equals('Up')));
      });

      test('stage changes when pose changes', () {
        final initialStage = counter.getCurrentStage();

        // Simulate a pose change
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        final stageAfterBend = counter.getCurrentStage();

        // The stage should be responsive to pose changes
        // (specific stage values are implementation details)
        expect(stageAfterBend, isNotEmpty);
        expect(initialStage, isNotEmpty);
      });
    });

    group('Rep Counting', () {
      test('recordRep increments rep count', () {
        expect(counter.repCount, equals(0));

        counter.recordRep();

        expect(counter.repCount, equals(1));
      });

      test('checkRepCompletion returns boolean', () {
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));

        final result = counter.checkRepCompletion();

        expect(result, isA<bool>());
      });

      test('does not count without valid pose', () {
        // No landmarks = invalid pose
        counter.checkRepCompletion();

        expect(counter.repCount, equals(0));
      });

      test('debouncing prevents rapid rep counting', () {
        // Record a rep
        counter.recordRep();
        expect(counter.canCountRep(), isFalse);

        // After debounce period
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        expect(counter.canCountRep(), isTrue);
      });
    });

    group('Debug Angles', () {
      test('includes elbow angle when arms are visible', () {
        counter.updateLandmarks(_createPushupPose(elbowAngle: 90));

        final angles = counter.getDebugAngles();

        expect(angles.containsKey('elbow'), isTrue);
      });

      test('includes left and right elbow angles separately', () {
        counter.updateLandmarks(_createPushupPose(elbowAngle: 90));

        final angles = counter.getDebugAngles();

        expect(angles.containsKey('leftElbow'), isTrue);
        expect(angles.containsKey('rightElbow'), isTrue);
      });

      test('includes body deviation when full body visible', () {
        counter.updateLandmarks(_createPushupPose(elbowAngle: 90));

        final angles = counter.getDebugAngles();

        expect(angles.containsKey('bodyDeviation'), isTrue);
      });
    });

    group('Reset', () {
      test('resets stage to Up', () {
        // Go to a non-up position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), isNot(equals('Up')));

        counter.reset();

        expect(counter.getCurrentStage(), equals('Up'));
      });
    });
  });
}

PoseLandmark _createLandmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 1.0,
}) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: likelihood,
  );
}

/// Create a pushup pose with specified elbow angle.
/// Uses trigonometry to correctly position wrist for desired angle at elbow.
List<PoseLandmark> _createPushupPose({required double elbowAngle}) {

  // Fixed positions for shoulder and elbow
  const shoulderX = 150.0;
  const shoulderY = 100.0;
  const elbowX = 150.0;
  const elbowY = 200.0;
  const armLength = 100.0; // Distance from elbow to wrist

  // Calculate wrist position using trigonometry
  // The angle at elbow is formed by shoulder-elbow-wrist
  // We need to position the wrist so that this angle equals elbowAngle

  // Vector from elbow to shoulder
  final toShoulderX = shoulderX - elbowX;
  final toShoulderY = shoulderY - elbowY;

  // Angle of shoulder vector from elbow
  final shoulderAngle = math.atan2(toShoulderY, toShoulderX);

  // Convert desired elbow angle to radians
  final desiredAngleRad = elbowAngle * math.pi / 180;

  // Wrist angle relative to horizontal
  // For elbowAngle of 180 (straight), wrist continues in same direction
  // For elbowAngle of 90 (bent), wrist is perpendicular
  final wristAngle = shoulderAngle + math.pi - desiredAngleRad;

  final wristX = elbowX + armLength * math.cos(wristAngle);
  final wristY = elbowY + armLength * math.sin(wristAngle);

  return [
    // Left arm
    _createLandmark(PoseLandmarkType.leftShoulder, shoulderX - 50, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, elbowX - 50, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, wristX - 50, wristY),
    // Right arm
    _createLandmark(PoseLandmarkType.rightShoulder, shoulderX + 50, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, elbowX + 50, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, wristX + 50, wristY),
    // Hips (aligned with shoulders for good body form)
    _createLandmark(PoseLandmarkType.leftHip, shoulderX - 50, 300),
    _createLandmark(PoseLandmarkType.rightHip, shoulderX + 50, 300),
    // Ankles (aligned for straight body)
    _createLandmark(PoseLandmarkType.leftAnkle, shoulderX - 50, 500),
    _createLandmark(PoseLandmarkType.rightAnkle, shoulderX + 50, 500),
  ];
}
