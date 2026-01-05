import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pushup_counter/models/burpee_counter.dart';

void main() {
  group('BurpeeCounter', () {
    late BurpeeCounter counter;

    setUp(() {
      counter = BurpeeCounter();
    });

    group('Interface Contract', () {
      test('implements exerciseName', () {
        expect(counter.exerciseName, equals('Burpees'));
      });

      test('implements variant for standard', () {
        expect(counter.variant, equals('Standard'));
      });

      test('implements variant for modified', () {
        final modifiedCounter = BurpeeCounter(isModifiedVariant: true);
        expect(modifiedCounter.variant, equals('Modified'));
      });

      test('starts with zero rep count', () {
        expect(counter.repCount, equals(0));
      });

      test('starts with zero invalid rep count', () {
        expect(counter.invalidRepCount, equals(0));
      });

      test('starts in standing stage', () {
        expect(counter.getCurrentStage(), equals('Standing'));
      });

      test('returns debug angles as a map', () {
        expect(counter.getDebugAngles(), isA<Map<String, double>>());
      });
    });

    group('isValidPose', () {
      test('returns false with empty landmarks', () {
        counter.updateLandmarks([]);
        expect(counter.isValidPose(), isFalse);
      });

      test('returns false with insufficient landmarks', () {
        // Only provide a few landmarks
        final landmarks = [
          _createLandmark(PoseLandmarkType.leftShoulder, 100, 100),
          _createLandmark(PoseLandmarkType.rightShoulder, 200, 100),
        ];
        counter.updateLandmarks(landmarks);
        expect(counter.isValidPose(), isFalse);
      });

      test('returns true with all required landmarks at high confidence', () {
        final landmarks = _createFullPoseLandmarks();
        counter.updateLandmarks(landmarks);
        expect(counter.isValidPose(), isTrue);
      });
    });

    group('State Machine', () {
      test('checkRepCompletion returns false when not a complete cycle', () {
        counter.updateLandmarks(_createStandingPose());
        // Single frame should not complete a rep
        expect(counter.checkRepCompletion(), isFalse);
      });

      test('getCurrentStage returns valid stage names', () {
        final stages = ['Standing', 'Squat/Plank', 'Pushup', 'Jump'];
        expect(stages, contains(counter.getCurrentStage()));
      });

      test('checkRepCompletion returns bool', () {
        counter.updateLandmarks(_createFullPoseLandmarks());
        final result = counter.checkRepCompletion();
        expect(result, isA<bool>());
      });

      test('stage name is always a non-empty string', () {
        expect(counter.getCurrentStage(), isNotEmpty);
      });
    });

    group('reset', () {
      test('resets rep count to zero', () {
        counter.repCount = 5;
        counter.reset();
        expect(counter.repCount, equals(0));
      });

      test('resets invalid rep count to zero', () {
        counter.invalidRepCount = 3;
        counter.reset();
        expect(counter.invalidRepCount, equals(0));
      });

      test('resets stage to standing', () {
        counter.updateLandmarks(_createSquatPose());
        counter.checkRepCompletion();
        counter.reset();
        expect(counter.getCurrentStage(), equals('Standing'));
      });

      test('clears landmarks', () {
        counter.updateLandmarks(_createFullPoseLandmarks());
        counter.reset();
        expect(counter.landmarks, isEmpty);
      });
    });
  });
}

/// Create a single pose landmark
PoseLandmark _createLandmark(PoseLandmarkType type, double x, double y,
    {double likelihood = 0.9}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}

/// Create a full set of pose landmarks for a valid pose
List<PoseLandmark> _createFullPoseLandmarks() {
  return [
    _createLandmark(PoseLandmarkType.leftShoulder, 100, 200),
    _createLandmark(PoseLandmarkType.rightShoulder, 200, 200),
    _createLandmark(PoseLandmarkType.leftHip, 110, 350),
    _createLandmark(PoseLandmarkType.rightHip, 190, 350),
    _createLandmark(PoseLandmarkType.leftKnee, 100, 500),
    _createLandmark(PoseLandmarkType.rightKnee, 200, 500),
    _createLandmark(PoseLandmarkType.leftAnkle, 100, 650),
    _createLandmark(PoseLandmarkType.rightAnkle, 200, 650),
    _createLandmark(PoseLandmarkType.leftElbow, 50, 300),
    _createLandmark(PoseLandmarkType.rightElbow, 250, 300),
    _createLandmark(PoseLandmarkType.leftWrist, 25, 400),
    _createLandmark(PoseLandmarkType.rightWrist, 275, 400),
  ];
}

/// Create a standing pose (hip angle > 160 degrees)
List<PoseLandmark> _createStandingPose() {
  // Standing upright - shoulder, hip, knee roughly aligned vertically
  return [
    _createLandmark(PoseLandmarkType.leftShoulder, 100, 100),
    _createLandmark(PoseLandmarkType.rightShoulder, 200, 100),
    _createLandmark(PoseLandmarkType.leftHip, 100, 250),
    _createLandmark(PoseLandmarkType.rightHip, 200, 250),
    _createLandmark(PoseLandmarkType.leftKnee, 100, 400),
    _createLandmark(PoseLandmarkType.rightKnee, 200, 400),
    _createLandmark(PoseLandmarkType.leftAnkle, 100, 550),
    _createLandmark(PoseLandmarkType.rightAnkle, 200, 550),
    _createLandmark(PoseLandmarkType.leftElbow, 50, 150),
    _createLandmark(PoseLandmarkType.rightElbow, 250, 150),
    _createLandmark(PoseLandmarkType.leftWrist, 50, 200),
    _createLandmark(PoseLandmarkType.rightWrist, 250, 200),
  ];
}

/// Create a squat pose (hip angle < 90 degrees)
List<PoseLandmark> _createSquatPose() {
  // Deep squat - shoulder forward, hip low, knee bent
  return [
    _createLandmark(PoseLandmarkType.leftShoulder, 100, 200),
    _createLandmark(PoseLandmarkType.rightShoulder, 200, 200),
    _createLandmark(PoseLandmarkType.leftHip, 100, 300), // Hip lower
    _createLandmark(PoseLandmarkType.rightHip, 200, 300),
    _createLandmark(PoseLandmarkType.leftKnee, 50, 350), // Knee forward
    _createLandmark(PoseLandmarkType.rightKnee, 250, 350),
    _createLandmark(PoseLandmarkType.leftAnkle, 100, 500),
    _createLandmark(PoseLandmarkType.rightAnkle, 200, 500),
    _createLandmark(PoseLandmarkType.leftElbow, 50, 250),
    _createLandmark(PoseLandmarkType.rightElbow, 250, 250),
    _createLandmark(PoseLandmarkType.leftWrist, 50, 350),
    _createLandmark(PoseLandmarkType.rightWrist, 250, 350),
  ];
}

