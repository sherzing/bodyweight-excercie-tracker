import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pushup_counter/models/exercise_counter.dart';
import 'package:pushup_counter/models/invalid_rep_reason.dart';
import 'package:pushup_counter/models/pushup_counter.dart';

/// Tests for the ExerciseCounter interface contract.
/// These tests verify behaviors that ALL ExerciseCounter implementations must satisfy.
/// The implementation can change, but these interface contracts must hold.
void main() {
  group('ExerciseCounter Interface Contract', () {
    late ExerciseCounter counter;

    setUp(() {
      // Use PushupCounter as the concrete implementation
      // Tests are written against the interface, not implementation details
      counter = PushupCounter();
    });

    group('Initial State', () {
      test('starts with zero rep count', () {
        expect(counter.repCount, equals(0));
      });

      test('starts with zero invalid rep count', () {
        expect(counter.invalidRepCount, equals(0));
      });

      test('starts with empty landmarks', () {
        expect(counter.landmarks, isEmpty);
      });

      test('has no last rep time initially', () {
        expect(counter.lastRepTime, isNull);
      });

      test('provides an exercise name', () {
        expect(counter.exerciseName, isNotEmpty);
      });

      test('provides a variant name', () {
        expect(counter.variant, isNotEmpty);
      });
    });

    group('updateLandmarks', () {
      test('stores provided landmarks', () {
        final landmarks = _createBasicPoseLandmarks();

        counter.updateLandmarks(landmarks);

        expect(counter.landmarks, equals(landmarks));
      });

      test('replaces previous landmarks', () {
        final landmarks1 = [_createLandmark(PoseLandmarkType.nose, 0, 0)];
        final landmarks2 = [_createLandmark(PoseLandmarkType.nose, 100, 100)];

        counter.updateLandmarks(landmarks1);
        counter.updateLandmarks(landmarks2);

        expect(counter.landmarks, equals(landmarks2));
      });
    });

    group('isValidPose', () {
      test('returns false with no landmarks', () {
        expect(counter.isValidPose(), isFalse);
      });

      test('returns boolean indicating pose validity', () {
        counter.updateLandmarks(_createBasicPoseLandmarks());

        // Result is a boolean (implementation determines true/false)
        expect(counter.isValidPose(), isA<bool>());
      });
    });

    group('getCurrentStage', () {
      test('returns a non-empty string', () {
        expect(counter.getCurrentStage(), isNotEmpty);
      });

      test('returns string describing current exercise stage', () {
        final stage = counter.getCurrentStage();

        // Stage should be a meaningful string (not null or empty)
        expect(stage, isA<String>());
        expect(stage.length, greaterThan(0));
      });
    });

    group('checkRepCompletion', () {
      test('returns false with no landmarks', () {
        expect(counter.checkRepCompletion(), isFalse);
      });

      test('returns boolean indicating if rep completed', () {
        counter.updateLandmarks(_createBasicPoseLandmarks());

        expect(counter.checkRepCompletion(), isA<bool>());
      });
    });

    group('getDebugAngles', () {
      test('returns empty map with no landmarks', () {
        expect(counter.getDebugAngles(), isEmpty);
      });

      test('returns map with angle values when landmarks present', () {
        counter.updateLandmarks(_createFullPoseLandmarks());

        final angles = counter.getDebugAngles();

        expect(angles, isA<Map<String, double>>());
        // Values should be valid angles
        for (final angle in angles.values) {
          expect(angle, greaterThanOrEqualTo(0));
          expect(angle, lessThanOrEqualTo(180));
        }
      });
    });

    group('getLandmark', () {
      test('returns null for missing landmark type', () {
        counter.updateLandmarks([]);

        expect(counter.getLandmark(PoseLandmarkType.nose), isNull);
      });

      test('returns landmark when present', () {
        final noseLandmark = _createLandmark(PoseLandmarkType.nose, 50, 50);
        counter.updateLandmarks([noseLandmark]);

        expect(counter.getLandmark(PoseLandmarkType.nose), equals(noseLandmark));
      });
    });

    group('hasConfidence', () {
      test('returns false for null landmark', () {
        expect(counter.hasConfidence(null), isFalse);
      });

      test('returns false for low confidence landmark', () {
        final lowConfidence = _createLandmark(
          PoseLandmarkType.nose,
          50,
          50,
          likelihood: 0.3,
        );

        expect(counter.hasConfidence(lowConfidence), isFalse);
      });

      test('returns true for high confidence landmark', () {
        final highConfidence = _createLandmark(
          PoseLandmarkType.nose,
          50,
          50,
          likelihood: 0.8,
        );

        expect(counter.hasConfidence(highConfidence), isTrue);
      });
    });

    group('canCountRep', () {
      test('returns true when no previous rep', () {
        expect(counter.canCountRep(), isTrue);
      });

      test('respects minimum interval between reps', () {
        counter.recordRep();

        // Immediately after recording, should be false (debounce)
        expect(counter.canCountRep(), isFalse);
      });
    });

    group('recordRep', () {
      test('increments rep count', () {
        expect(counter.repCount, equals(0));

        counter.recordRep();

        expect(counter.repCount, equals(1));
      });

      test('sets last rep time', () {
        expect(counter.lastRepTime, isNull);

        counter.recordRep();

        expect(counter.lastRepTime, isNotNull);
      });

      test('increments multiple times', () {
        counter.recordRep();
        counter.recordRep();
        counter.recordRep();

        expect(counter.repCount, equals(3));
      });
    });

    group('recordInvalidRep', () {
      test('increments invalid rep count', () {
        expect(counter.invalidRepCount, equals(0));

        counter.recordInvalidRep();

        expect(counter.invalidRepCount, equals(1));
      });

      test('does not affect valid rep count', () {
        counter.recordRep();
        counter.recordInvalidRep();

        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(1));
      });

      test('stores lastInvalidRepInfo when info is provided', () {
        final info = InvalidRepInfo(
          reason: InvalidRepReason.poorForm,
          timestamp: DateTime.now(),
          repIndex: 0,
          elbowAngle: 85.0,
          bodyDeviation: 35.0,
          formRatio: 0.4,
        );

        counter.recordInvalidRep(info);

        expect(counter.lastInvalidRepInfo, isNotNull);
        expect(counter.lastInvalidRepInfo!.reason, equals(InvalidRepReason.poorForm));
        expect(counter.lastInvalidRepInfo!.elbowAngle, equals(85.0));
        expect(counter.lastInvalidRepInfo!.formRatio, equals(0.4));
      });

      test('does not set lastInvalidRepInfo when called without info', () {
        counter.recordInvalidRep();

        expect(counter.lastInvalidRepInfo, isNull);
      });

      test('triggers onInvalidRep callback when info is provided', () {
        InvalidRepInfo? receivedInfo;
        counter.onInvalidRep = (info) {
          receivedInfo = info;
        };

        final info = InvalidRepInfo(
          reason: InvalidRepReason.partialRangeDown,
          timestamp: DateTime.now(),
          repIndex: 0,
        );

        counter.recordInvalidRep(info);

        expect(receivedInfo, isNotNull);
        expect(receivedInfo!.reason, equals(InvalidRepReason.partialRangeDown));
      });

      test('does not trigger callback when called without info', () {
        var callbackCalled = false;
        counter.onInvalidRep = (info) {
          callbackCalled = true;
        };

        counter.recordInvalidRep();

        expect(callbackCalled, isFalse);
      });

      test('updates lastInvalidRepInfo on subsequent calls', () {
        final info1 = InvalidRepInfo(
          reason: InvalidRepReason.poorForm,
          timestamp: DateTime.now(),
          repIndex: 0,
        );
        final info2 = InvalidRepInfo(
          reason: InvalidRepReason.partialRangeUp,
          timestamp: DateTime.now(),
          repIndex: 1,
        );

        counter.recordInvalidRep(info1);
        counter.recordInvalidRep(info2);

        expect(counter.lastInvalidRepInfo!.reason, equals(InvalidRepReason.partialRangeUp));
        expect(counter.lastInvalidRepInfo!.repIndex, equals(1));
      });
    });

    group('reset', () {
      test('resets rep count to zero', () {
        counter.recordRep();
        counter.recordRep();

        counter.reset();

        expect(counter.repCount, equals(0));
      });

      test('resets invalid rep count to zero', () {
        counter.recordInvalidRep();

        counter.reset();

        expect(counter.invalidRepCount, equals(0));
      });

      test('clears last rep time', () {
        counter.recordRep();

        counter.reset();

        expect(counter.lastRepTime, isNull);
      });

      test('clears landmarks', () {
        counter.updateLandmarks(_createBasicPoseLandmarks());

        counter.reset();

        expect(counter.landmarks, isEmpty);
      });

      test('clears lastInvalidRepInfo', () {
        final info = InvalidRepInfo(
          reason: InvalidRepReason.poorForm,
          timestamp: DateTime.now(),
          repIndex: 0,
        );
        counter.recordInvalidRep(info);
        expect(counter.lastInvalidRepInfo, isNotNull);

        counter.reset();

        expect(counter.lastInvalidRepInfo, isNull);
      });
    });
  });
}

/// Create a single PoseLandmark for testing
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

/// Create minimal landmarks for basic pose detection
List<PoseLandmark> _createBasicPoseLandmarks() {
  return [
    _createLandmark(PoseLandmarkType.leftShoulder, 100, 100),
    _createLandmark(PoseLandmarkType.rightShoulder, 200, 100),
    _createLandmark(PoseLandmarkType.leftHip, 100, 200),
    _createLandmark(PoseLandmarkType.rightHip, 200, 200),
  ];
}

/// Create full set of landmarks for angle calculations
List<PoseLandmark> _createFullPoseLandmarks() {
  return [
    // Shoulders
    _createLandmark(PoseLandmarkType.leftShoulder, 100, 100),
    _createLandmark(PoseLandmarkType.rightShoulder, 200, 100),
    // Elbows
    _createLandmark(PoseLandmarkType.leftElbow, 50, 150),
    _createLandmark(PoseLandmarkType.rightElbow, 250, 150),
    // Wrists
    _createLandmark(PoseLandmarkType.leftWrist, 50, 200),
    _createLandmark(PoseLandmarkType.rightWrist, 250, 200),
    // Hips
    _createLandmark(PoseLandmarkType.leftHip, 100, 250),
    _createLandmark(PoseLandmarkType.rightHip, 200, 250),
    // Ankles
    _createLandmark(PoseLandmarkType.leftAnkle, 100, 400),
    _createLandmark(PoseLandmarkType.rightAnkle, 200, 400),
  ];
}
