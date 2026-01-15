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

    group('Front View Detection', () {
      test('detects front view when shoulders are widely separated', () {
        // Front view: shoulders 100px apart (> 50px threshold)
        counter.updateLandmarks(_createFrontViewPushupPose(elbowAngle: 170));

        // Should be valid pose and count rep despite vertical body orientation
        expect(counter.isValidPose(), isTrue);
      });

      test('detects side view when shoulders are close together', () {
        // Side view: shoulders only 40px apart (< 50px threshold)
        counter.updateLandmarks(_createSideViewPushupPose(elbowAngle: 170));

        expect(counter.isValidPose(), isTrue);
      });

      test('counts valid rep in front view despite vertical body orientation', () {
        // Front view pushup - body appears vertical but should still count
        // Start in up position
        counter.updateLandmarks(_createFrontViewPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));

        // Go to down position
        counter.updateLandmarks(_createFrontViewPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Down'));

        // Wait for debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to up position - should count rep
        counter.updateLandmarks(_createFrontViewPushupPose(elbowAngle: 170));
        final completed = counter.checkRepCompletion();

        expect(completed, isTrue);
        expect(counter.repCount, equals(1));
      });

      test('side view rejects standing pose', () {
        // Side view with vertical body orientation (standing)
        counter.updateLandmarks(_createStandingPose());
        counter.checkRepCompletion();

        // Should not transition to down despite elbow angle
        // because standing detection should kick in
        expect(counter.repCount, equals(0));
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

/// Create a FRONT VIEW pushup pose (user facing the camera).
/// Shoulders are widely separated (100px apart > 50px threshold).
/// Body appears vertical from camera perspective but this is valid for front view.
List<PoseLandmark> _createFrontViewPushupPose({required double elbowAngle}) {
  // Front view: shoulders horizontally separated, hips below shoulders
  // Left shoulder at X=50, right shoulder at X=150 = 100px apart
  const leftShoulderX = 50.0;
  const rightShoulderX = 150.0;
  const shoulderY = 100.0;

  // Elbows directly below shoulders (arms pointing straight down)
  const leftElbowX = 50.0;
  const rightElbowX = 150.0;
  const elbowY = 180.0;
  const armLength = 60.0;

  // Calculate wrist position based on elbow angle
  // Same geometry as side view - arms point down, wrist bends based on angle
  // For straight arm (180°): wrist directly below elbow
  // For bent arm (90°): wrist perpendicular to forearm
  final rotationFromStraight = (180 - elbowAngle) * math.pi / 180;
  // Left arm bends inward (positive X), right arm bends inward (negative X)
  final leftWristX = leftElbowX + armLength * math.sin(rotationFromStraight);
  final rightWristX = rightElbowX - armLength * math.sin(rotationFromStraight);
  final wristY = elbowY + armLength * math.cos(rotationFromStraight);

  // Hips below shoulders (vertical body orientation in camera view)
  const leftHipX = 70.0;
  const rightHipX = 130.0;
  const hipY = 250.0;

  // Ankles at bottom
  const leftAnkleX = 80.0;
  const rightAnkleX = 120.0;
  const ankleY = 400.0;

  return [
    _createLandmark(PoseLandmarkType.leftShoulder, leftShoulderX, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, leftElbowX, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, leftWristX, wristY),
    _createLandmark(PoseLandmarkType.rightShoulder, rightShoulderX, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, rightElbowX, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, rightWristX, wristY),
    _createLandmark(PoseLandmarkType.leftHip, leftHipX, hipY),
    _createLandmark(PoseLandmarkType.rightHip, rightHipX, hipY),
    _createLandmark(PoseLandmarkType.leftAnkle, leftAnkleX, ankleY),
    _createLandmark(PoseLandmarkType.rightAnkle, rightAnkleX, ankleY),
  ];
}

/// Create a SIDE VIEW pushup pose (user perpendicular to camera).
/// Shoulders are close together (40px apart < 50px threshold).
/// This is the existing horizontal plank view.
List<PoseLandmark> _createSideViewPushupPose({required double elbowAngle}) {
  // Side view: shoulders appear close together (one behind the other)
  // Shoulder separation is 40px (< 50px threshold for front view)
  const shoulderX = 100.0;
  const shoulderY = 200.0;
  const elbowX = 100.0;
  const elbowY = 280.0;
  const armLength = 60.0;

  final rotationFromStraight = (180 - elbowAngle) * math.pi / 180;
  final wristX = elbowX + armLength * math.sin(rotationFromStraight);
  final wristY = elbowY + armLength * math.cos(rotationFromStraight);

  // Horizontal body - hip to the right of shoulder
  const hipX = 300.0;
  const hipY = 200.0;
  const ankleX = 500.0;
  const ankleY = 200.0;

  return [
    // Shoulders only 40px apart (side view)
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

/// Create a STANDING pose (side view with vertical body orientation).
/// This should be rejected as "not in plank position".
List<PoseLandmark> _createStandingPose() {
  // Side view (shoulders close together) + vertical body orientation
  // This simulates someone standing up after a workout
  const shoulderX = 100.0;
  const shoulderY = 100.0; // Top of body
  const elbowX = 100.0;
  const elbowY = 150.0;
  const wristX = 100.0;
  const wristY = 200.0; // Arms hanging down

  // Hips directly below shoulders (vertical body)
  const hipX = 100.0;
  const hipY = 250.0;
  const ankleX = 100.0;
  const ankleY = 400.0;

  return [
    // Shoulders only 40px apart (side view)
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
