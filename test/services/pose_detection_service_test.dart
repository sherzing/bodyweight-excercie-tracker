import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pushup_counter/services/pose_detection_service.dart';

/// Tests for PoseDetectionService.
/// Tests position feedback logic, body visibility detection, and pose validation.
void main() {
  group('PosePositionFeedback', () {
    test('has all expected feedback types', () {
      expect(PosePositionFeedback.values.length, equals(6));
      expect(PosePositionFeedback.values, contains(PosePositionFeedback.good));
      expect(PosePositionFeedback.values, contains(PosePositionFeedback.tooClose));
      expect(PosePositionFeedback.values, contains(PosePositionFeedback.tooFar));
      expect(PosePositionFeedback.values, contains(PosePositionFeedback.moveToCenter));
      expect(PosePositionFeedback.values, contains(PosePositionFeedback.noPoseDetected));
      expect(PosePositionFeedback.values, contains(PosePositionFeedback.lowConfidence));
    });

    group('message extension', () {
      test('good has empty message', () {
        expect(PosePositionFeedback.good.message, equals(''));
      });

      test('tooClose has step back message', () {
        expect(PosePositionFeedback.tooClose.message, equals('Step back from camera'));
      });

      test('tooFar has move closer message', () {
        expect(PosePositionFeedback.tooFar.message, equals('Move closer to camera'));
      });

      test('moveToCenter has center message', () {
        expect(PosePositionFeedback.moveToCenter.message, equals('Move to center of frame'));
      });

      test('noPoseDetected has position message', () {
        expect(PosePositionFeedback.noPoseDetected.message, equals('Position yourself in frame'));
      });

      test('lowConfidence has lighting message', () {
        expect(PosePositionFeedback.lowConfidence.message, equals('Improve lighting conditions'));
      });
    });

    group('icon extension', () {
      test('good has empty icon', () {
        expect(PosePositionFeedback.good.icon, equals(''));
      });

      test('tooClose has arrow_back icon', () {
        expect(PosePositionFeedback.tooClose.icon, equals('arrow_back'));
      });

      test('tooFar has arrow_forward icon', () {
        expect(PosePositionFeedback.tooFar.icon, equals('arrow_forward'));
      });

      test('moveToCenter has center_focus_strong icon', () {
        expect(PosePositionFeedback.moveToCenter.icon, equals('center_focus_strong'));
      });

      test('noPoseDetected has person_search icon', () {
        expect(PosePositionFeedback.noPoseDetected.icon, equals('person_search'));
      });

      test('lowConfidence has lightbulb icon', () {
        expect(PosePositionFeedback.lowConfidence.icon, equals('lightbulb'));
      });
    });
  });

  group('PoseDetectionService', () {
    late PoseDetectionService service;

    setUp(() {
      service = PoseDetectionService();
    });

    test('minLandmarksRequired is 25', () {
      expect(PoseDetectionService.minLandmarksRequired, equals(25));
    });

    group('isPoseValid', () {
      test('returns false for null pose', () {
        expect(service.isPoseValid(null), isFalse);
      });

      test('returns false for pose with insufficient landmarks', () {
        final pose = _createPoseWithLandmarkCount(20);
        expect(service.isPoseValid(pose), isFalse);
      });

      test('returns true for pose with exactly 25 landmarks', () {
        final pose = _createPoseWithLandmarkCount(25);
        expect(service.isPoseValid(pose), isTrue);
      });

      test('returns true for pose with more than 25 landmarks', () {
        final pose = _createPoseWithLandmarkCount(33);
        expect(service.isPoseValid(pose), isTrue);
      });
    });

    group('getBodyVisibility', () {
      test('returns all false for null pose', () {
        final visibility = service.getBodyVisibility(null);

        expect(visibility['upperBody'], isFalse);
        expect(visibility['arms'], isFalse);
        expect(visibility['legs'], isFalse);
      });

      test('detects upper body when shoulders and hips present', () {
        final landmarks = <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.leftShoulder: _createLandmark(100, 100, 0.9),
          PoseLandmarkType.rightShoulder: _createLandmark(200, 100, 0.9),
          PoseLandmarkType.leftHip: _createLandmark(100, 200, 0.9),
          PoseLandmarkType.rightHip: _createLandmark(200, 200, 0.9),
        };
        final pose = _createPose(landmarks);

        final visibility = service.getBodyVisibility(pose);
        expect(visibility['upperBody'], isTrue);
      });

      test('returns false for upper body with low confidence', () {
        final landmarks = <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.leftShoulder: _createLandmark(100, 100, 0.3),
          PoseLandmarkType.rightShoulder: _createLandmark(200, 100, 0.9),
          PoseLandmarkType.leftHip: _createLandmark(100, 200, 0.9),
          PoseLandmarkType.rightHip: _createLandmark(200, 200, 0.9),
        };
        final pose = _createPose(landmarks);

        final visibility = service.getBodyVisibility(pose);
        expect(visibility['upperBody'], isFalse);
      });

      test('detects left arm when elbow and wrist present', () {
        final landmarks = <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.leftElbow: _createLandmark(50, 150, 0.9),
          PoseLandmarkType.leftWrist: _createLandmark(50, 200, 0.9),
        };
        final pose = _createPose(landmarks);

        final visibility = service.getBodyVisibility(pose);
        expect(visibility['arms'], isTrue);
      });

      test('detects right arm when elbow and wrist present', () {
        final landmarks = <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.rightElbow: _createLandmark(250, 150, 0.9),
          PoseLandmarkType.rightWrist: _createLandmark(250, 200, 0.9),
        };
        final pose = _createPose(landmarks);

        final visibility = service.getBodyVisibility(pose);
        expect(visibility['arms'], isTrue);
      });

      test('detects left leg when knee and ankle present', () {
        final landmarks = <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.leftKnee: _createLandmark(100, 300, 0.9),
          PoseLandmarkType.leftAnkle: _createLandmark(100, 400, 0.9),
        };
        final pose = _createPose(landmarks);

        final visibility = service.getBodyVisibility(pose);
        expect(visibility['legs'], isTrue);
      });

      test('detects right leg when knee and ankle present', () {
        final landmarks = <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.rightKnee: _createLandmark(200, 300, 0.9),
          PoseLandmarkType.rightAnkle: _createLandmark(200, 400, 0.9),
        };
        final pose = _createPose(landmarks);

        final visibility = service.getBodyVisibility(pose);
        expect(visibility['legs'], isTrue);
      });
    });

    group('getPositionFeedback', () {
      const frameWidth = 640.0;
      const frameHeight = 480.0;

      test('returns noPoseDetected for null pose', () {
        final feedback = service.getPositionFeedback(null, frameWidth, frameHeight);
        expect(feedback, equals(PosePositionFeedback.noPoseDetected));
      });

      test('returns good for properly positioned pose', () {
        // Body takes up about 50% of frame, centered
        final landmarks = _createFullBodyLandmarks(
          centerX: frameWidth / 2,
          centerY: frameHeight / 2,
          width: frameWidth * 0.5,
          height: frameHeight * 0.5,
          confidence: 0.9,
        );
        final pose = _createPose(landmarks);

        final feedback = service.getPositionFeedback(pose, frameWidth, frameHeight);
        expect(feedback, equals(PosePositionFeedback.good));
      });

      test('returns tooClose when body is too large in frame', () {
        // Body takes up 95% of frame
        final landmarks = _createFullBodyLandmarks(
          centerX: frameWidth / 2,
          centerY: frameHeight / 2,
          width: frameWidth * 0.95,
          height: frameHeight * 0.95,
          confidence: 0.9,
        );
        final pose = _createPose(landmarks);

        final feedback = service.getPositionFeedback(pose, frameWidth, frameHeight);
        expect(feedback, equals(PosePositionFeedback.tooClose));
      });

      test('returns tooFar when body is too small in frame', () {
        // Body takes up only 30% of frame height
        final landmarks = _createFullBodyLandmarks(
          centerX: frameWidth / 2,
          centerY: frameHeight / 2,
          width: frameWidth * 0.2,
          height: frameHeight * 0.3,
          confidence: 0.9,
        );
        final pose = _createPose(landmarks);

        final feedback = service.getPositionFeedback(pose, frameWidth, frameHeight);
        expect(feedback, equals(PosePositionFeedback.tooFar));
      });

      test('returns moveToCenter when body is at left edge', () {
        // Body positioned at left edge (within 5% margin)
        final landmarks = _createFullBodyLandmarks(
          centerX: frameWidth * 0.15,
          centerY: frameHeight / 2,
          width: frameWidth * 0.25,
          height: frameHeight * 0.5,
          confidence: 0.9,
        );
        final pose = _createPose(landmarks);

        final feedback = service.getPositionFeedback(pose, frameWidth, frameHeight);
        expect(feedback, equals(PosePositionFeedback.moveToCenter));
      });

      test('returns moveToCenter when body is at right edge', () {
        // Body positioned at right edge
        final landmarks = _createFullBodyLandmarks(
          centerX: frameWidth * 0.85,
          centerY: frameHeight / 2,
          width: frameWidth * 0.25,
          height: frameHeight * 0.5,
          confidence: 0.9,
        );
        final pose = _createPose(landmarks);

        final feedback = service.getPositionFeedback(pose, frameWidth, frameHeight);
        expect(feedback, equals(PosePositionFeedback.moveToCenter));
      });

      test('returns lowConfidence when more than half landmarks have low confidence', () {
        // Create landmarks with mostly low confidence
        final landmarks = _createFullBodyLandmarks(
          centerX: frameWidth / 2,
          centerY: frameHeight / 2,
          width: frameWidth * 0.5,
          height: frameHeight * 0.5,
          confidence: 0.3, // Low confidence
        );
        final pose = _createPose(landmarks);

        final feedback = service.getPositionFeedback(pose, frameWidth, frameHeight);
        expect(feedback, equals(PosePositionFeedback.lowConfidence));
      });

      test('prioritizes lowConfidence over position issues', () {
        // Body is too close but also has low confidence
        final landmarks = _createFullBodyLandmarks(
          centerX: frameWidth / 2,
          centerY: frameHeight / 2,
          width: frameWidth * 0.95,
          height: frameHeight * 0.95,
          confidence: 0.3,
        );
        final pose = _createPose(landmarks);

        final feedback = service.getPositionFeedback(pose, frameWidth, frameHeight);
        // lowConfidence is checked before position
        expect(feedback, equals(PosePositionFeedback.lowConfidence));
      });
    });

    group('callback', () {
      test('onPoseDetected can be set', () {
        Pose? receivedPose;
        service.onPoseDetected = (pose) {
          receivedPose = pose;
        };

        expect(service.onPoseDetected, isNotNull);
      });
    });
  });
}

/// Create a mock PoseLandmark
PoseLandmark _createLandmark(double x, double y, double likelihood) {
  return PoseLandmark(
    type: PoseLandmarkType.nose, // Type doesn't matter for the mock
    x: x,
    y: y,
    z: 0,
    likelihood: likelihood,
  );
}

/// Create a mock Pose with specified landmarks
Pose _createPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
  return _MockPose(landmarks);
}

/// Create a mock Pose with a specific number of landmarks
Pose _createPoseWithLandmarkCount(int count) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};
  final types = PoseLandmarkType.values;

  for (int i = 0; i < count && i < types.length; i++) {
    landmarks[types[i]] = PoseLandmark(
      type: types[i],
      x: 100.0 + i * 10,
      y: 100.0 + i * 10,
      z: 0,
      likelihood: 0.9,
    );
  }

  return _MockPose(landmarks);
}

/// Create landmarks for a full body positioned at given location
Map<PoseLandmarkType, PoseLandmark> _createFullBodyLandmarks({
  required double centerX,
  required double centerY,
  required double width,
  required double height,
  required double confidence,
}) {
  final halfWidth = width / 2;
  final halfHeight = height / 2;

  return {
    // Head
    PoseLandmarkType.nose: PoseLandmark(
      type: PoseLandmarkType.nose,
      x: centerX,
      y: centerY - halfHeight * 0.9,
      z: 0,
      likelihood: confidence,
    ),
    // Shoulders
    PoseLandmarkType.leftShoulder: PoseLandmark(
      type: PoseLandmarkType.leftShoulder,
      x: centerX - halfWidth * 0.4,
      y: centerY - halfHeight * 0.6,
      z: 0,
      likelihood: confidence,
    ),
    PoseLandmarkType.rightShoulder: PoseLandmark(
      type: PoseLandmarkType.rightShoulder,
      x: centerX + halfWidth * 0.4,
      y: centerY - halfHeight * 0.6,
      z: 0,
      likelihood: confidence,
    ),
    // Elbows
    PoseLandmarkType.leftElbow: PoseLandmark(
      type: PoseLandmarkType.leftElbow,
      x: centerX - halfWidth * 0.5,
      y: centerY - halfHeight * 0.3,
      z: 0,
      likelihood: confidence,
    ),
    PoseLandmarkType.rightElbow: PoseLandmark(
      type: PoseLandmarkType.rightElbow,
      x: centerX + halfWidth * 0.5,
      y: centerY - halfHeight * 0.3,
      z: 0,
      likelihood: confidence,
    ),
    // Wrists
    PoseLandmarkType.leftWrist: PoseLandmark(
      type: PoseLandmarkType.leftWrist,
      x: centerX - halfWidth,
      y: centerY,
      z: 0,
      likelihood: confidence,
    ),
    PoseLandmarkType.rightWrist: PoseLandmark(
      type: PoseLandmarkType.rightWrist,
      x: centerX + halfWidth,
      y: centerY,
      z: 0,
      likelihood: confidence,
    ),
    // Hips
    PoseLandmarkType.leftHip: PoseLandmark(
      type: PoseLandmarkType.leftHip,
      x: centerX - halfWidth * 0.3,
      y: centerY + halfHeight * 0.1,
      z: 0,
      likelihood: confidence,
    ),
    PoseLandmarkType.rightHip: PoseLandmark(
      type: PoseLandmarkType.rightHip,
      x: centerX + halfWidth * 0.3,
      y: centerY + halfHeight * 0.1,
      z: 0,
      likelihood: confidence,
    ),
    // Knees
    PoseLandmarkType.leftKnee: PoseLandmark(
      type: PoseLandmarkType.leftKnee,
      x: centerX - halfWidth * 0.3,
      y: centerY + halfHeight * 0.5,
      z: 0,
      likelihood: confidence,
    ),
    PoseLandmarkType.rightKnee: PoseLandmark(
      type: PoseLandmarkType.rightKnee,
      x: centerX + halfWidth * 0.3,
      y: centerY + halfHeight * 0.5,
      z: 0,
      likelihood: confidence,
    ),
    // Ankles
    PoseLandmarkType.leftAnkle: PoseLandmark(
      type: PoseLandmarkType.leftAnkle,
      x: centerX - halfWidth * 0.3,
      y: centerY + halfHeight,
      z: 0,
      likelihood: confidence,
    ),
    PoseLandmarkType.rightAnkle: PoseLandmark(
      type: PoseLandmarkType.rightAnkle,
      x: centerX + halfWidth * 0.3,
      y: centerY + halfHeight,
      z: 0,
      likelihood: confidence,
    ),
  };
}

/// Mock Pose class that holds landmarks
class _MockPose implements Pose {
  @override
  final Map<PoseLandmarkType, PoseLandmark> landmarks;

  _MockPose(this.landmarks);
}
