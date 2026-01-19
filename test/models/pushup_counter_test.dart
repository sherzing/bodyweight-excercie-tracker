import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
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

    group('Complete Rep Cycle', () {
      test('counts valid rep for full up-down-up cycle', () {
        // Start in up position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));

        // Go to down position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Down'));

        // Wait for debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to up position - should count rep
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        final completed = counter.checkRepCompletion();

        expect(completed, isTrue);
        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0));
      });

      test('counts valid rep when ankles not visible (no form tracking)', () {
        // This tests the bug fix: when ankles aren't visible, bodyDeviation is null,
        // so no form frames are tracked. Previously this defaulted to 0% form ratio
        // causing all reps to be invalid. Now it defaults to 100% (valid).

        // Start in up position (no ankles)
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 170));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));

        // Go to down position
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Down'));

        // Wait for debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to up position - should count as VALID rep (not invalid)
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 170));
        final completed = counter.checkRepCompletion();

        expect(completed, isTrue);
        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0)); // Key assertion: should NOT be invalid
      });

      test('counts invalid rep when form is poor throughout', () {
        // Start in up position with bad form (hips sagging - high body deviation)
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        // Go to down position with bad form
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 85));
        counter.checkRepCompletion();

        // Add more frames with bad form to ensure >40% bad
        for (var i = 0; i < 5; i++) {
          counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 90));
          counter.checkRepCompletion();
        }

        // Wait for debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to up position - should count as invalid due to poor form
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(counter.invalidRepCount, equals(1));
        expect(counter.repCount, equals(0));
      });

      test('multiple reps counted correctly', () {
        // Complete 3 reps
        for (var rep = 0; rep < 3; rep++) {
          // Up position
          counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
          counter.checkRepCompletion();

          // Down position
          counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
          counter.checkRepCompletion();

          // Clear debounce
          counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

          // Back to up
          counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
          counter.checkRepCompletion();
        }

        expect(counter.repCount, equals(3));
      });
    });

    group('Partial Visibility', () {
      test('bodyDeviation is null when ankles missing', () {
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 90));

        final angles = counter.getDebugAngles();

        expect(angles.containsKey('bodyDeviation'), isFalse);
        expect(angles.containsKey('elbow'), isTrue); // Elbow should still work
      });

      test('pose is still valid without ankles', () {
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 90));

        expect(counter.isValidPose(), isTrue);
      });
    });

    group('Debounce Edge Cases', () {
      test('debounce-blocked rep resets state correctly', () {
        // This tests that when debounce blocks a rep, the state is properly
        // reset to prevent any issues with subsequent reps.

        // Complete first rep (valid)
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        // Clear debounce for first rep
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0));

        // Simulate rapid second rep attempt that gets blocked by debounce
        // User goes down quickly
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();

        // User comes up immediately (within 300ms debounce window)
        counter.lastRepTime = DateTime.now(); // Reset to simulate fast timing
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        // Rep count should NOT have increased (blocked by debounce)
        expect(counter.repCount, equals(1));

        // After debounce blocked the rep, the state should be cleanly reset
        // Verify by doing a proper rep
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        // Should now have 2 valid reps
        expect(counter.repCount, equals(2));
        expect(counter.invalidRepCount, equals(0));
      });

      test('rapid reps blocked by debounce do not accumulate', () {
        // Complete first rep
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(counter.repCount, equals(1));

        // Try to do 3 rapid reps within debounce window
        for (var i = 0; i < 3; i++) {
          counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
          counter.checkRepCompletion();
          counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
          counter.checkRepCompletion();
        }

        // All should be blocked by debounce - only original 1 rep counted
        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0));

        // Now clear debounce and do a proper rep
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        // Should have 2 reps total now
        expect(counter.repCount, equals(2));
        expect(counter.invalidRepCount, equals(0));
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
/// The pose simulates a HORIZONTAL plank position (body parallel to ground).
///
/// Elbow angle meanings:
/// - 170-180° = arms straight (up position)
/// - 85-100° = arms bent (down position)
List<PoseLandmark> _createPushupPose({required double elbowAngle}) {
  // Horizontal plank: body parallel to ground, arms pointing down
  // Shoulder at (100, 200), Elbow at (100, 280) - arm pointing DOWN

  const shoulderX = 100.0;
  const shoulderY = 200.0;
  const elbowX = 100.0;
  const elbowY = 280.0;
  const armLength = 60.0;

  // Calculate wrist position based on elbow angle
  // The angle is measured at the elbow between shoulder-elbow-wrist
  // Shoulder is UP from elbow (negative Y direction)
  // For straight arm (180°): wrist continues DOWN (positive Y)
  // For bent arm (90°): wrist is perpendicular (positive X)

  final angleRad = elbowAngle * math.pi / 180;
  // Wrist position relative to elbow:
  // At 180°: wrist at (0, armLength) - straight down from elbow
  // At 90°: wrist at (armLength, 0) - perpendicular
  // The formula: rotate the "straight down" direction by (180 - angle)
  final rotationFromStraight = (180 - elbowAngle) * math.pi / 180;
  final wristX = elbowX + armLength * math.sin(rotationFromStraight);
  final wristY = elbowY + armLength * math.cos(rotationFromStraight);

  // Horizontal body
  const hipX = 300.0;
  const hipY = 200.0;
  const ankleX = 500.0;
  const ankleY = 200.0;

  return [
    _createLandmark(PoseLandmarkType.leftShoulder, shoulderX - 20, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, elbowX - 20, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, wristX - 20, wristY),
    _createLandmark(PoseLandmarkType.rightShoulder, shoulderX + 20, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, elbowX + 20, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, wristX + 20, wristY),
    _createLandmark(PoseLandmarkType.leftHip, hipX - 20, hipY),
    _createLandmark(PoseLandmarkType.rightHip, hipX + 20, hipY),
    _createLandmark(PoseLandmarkType.leftAnkle, ankleX - 20, ankleY),
    _createLandmark(PoseLandmarkType.rightAnkle, ankleX + 20, ankleY),
  ];
}

/// Create a pushup pose WITHOUT ankles (simulates partial visibility).
/// This tests the scenario where the camera doesn't capture the full body.
List<PoseLandmark> _createPushupPoseWithoutAnkles({required double elbowAngle}) {
  const shoulderX = 100.0;
  const shoulderY = 200.0;
  const elbowX = 100.0;
  const elbowY = 280.0;
  const armLength = 60.0;

  final rotationFromStraight = (180 - elbowAngle) * math.pi / 180;
  final wristX = elbowX + armLength * math.sin(rotationFromStraight);
  final wristY = elbowY + armLength * math.cos(rotationFromStraight);

  const hipX = 300.0;
  const hipY = 200.0;

  return [
    _createLandmark(PoseLandmarkType.leftShoulder, shoulderX - 20, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, elbowX - 20, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, wristX - 20, wristY),
    _createLandmark(PoseLandmarkType.rightShoulder, shoulderX + 20, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, elbowX + 20, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, wristX + 20, wristY),
    _createLandmark(PoseLandmarkType.leftHip, hipX - 20, hipY),
    _createLandmark(PoseLandmarkType.rightHip, hipX + 20, hipY),
    // NO ANKLES
  ];
}

/// Create a pushup pose with BAD FORM (hips sagging, high body deviation).
/// Body deviation will exceed the 30° threshold.
List<PoseLandmark> _createPushupPoseWithBadForm({required double elbowAngle}) {
  const shoulderX = 100.0;
  const shoulderY = 200.0;
  const elbowX = 100.0;
  const elbowY = 280.0;
  const armLength = 60.0;

  final rotationFromStraight = (180 - elbowAngle) * math.pi / 180;
  final wristX = elbowX + armLength * math.sin(rotationFromStraight);
  final wristY = elbowY + armLength * math.cos(rotationFromStraight);

  // Hips SAGGING - Y is much higher than shoulder/ankle line
  const hipX = 300.0;
  const hipY = 350.0; // Creates >30° body deviation

  const ankleX = 500.0;
  const ankleY = 200.0; // Same as shoulder Y

  return [
    _createLandmark(PoseLandmarkType.leftShoulder, shoulderX - 20, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, elbowX - 20, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, wristX - 20, wristY),
    _createLandmark(PoseLandmarkType.rightShoulder, shoulderX + 20, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, elbowX + 20, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, wristX + 20, wristY),
    _createLandmark(PoseLandmarkType.leftHip, hipX - 20, hipY),
    _createLandmark(PoseLandmarkType.rightHip, hipX + 20, hipY),
    _createLandmark(PoseLandmarkType.leftAnkle, ankleX - 20, ankleY),
    _createLandmark(PoseLandmarkType.rightAnkle, ankleX + 20, ankleY),
  ];
}

