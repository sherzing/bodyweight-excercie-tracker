import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Service for detecting human poses using Google ML Kit.
/// Processes camera frames and returns detected pose landmarks.
class PoseDetectionService {
  PoseDetector? _poseDetector;
  bool _isProcessing = false;

  /// Callback when a pose is detected
  void Function(Pose? pose)? onPoseDetected;

  /// Minimum number of landmarks required for valid pose
  static const int minLandmarksRequired = 25;

  /// Initialize the pose detector
  void initialize() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream, // Optimized for real-time video
        model: PoseDetectionModel.base, // Base model for speed
      ),
    );
  }

  /// Process an input image and detect poses
  Future<void> processImage(InputImage inputImage) async {
    if (_poseDetector == null) {
      throw StateError('PoseDetector not initialized');
    }

    // Skip if already processing
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final poses = await _poseDetector!.processImage(inputImage);

      // Get the first detected pose (we expect one person)
      final pose = poses.isNotEmpty ? poses.first : null;

      onPoseDetected?.call(pose);
    } catch (e) {
      // Silently handle detection errors to maintain frame rate
      onPoseDetected?.call(null);
    } finally {
      _isProcessing = false;
    }
  }

  /// Check if pose has sufficient landmarks for tracking
  bool isPoseValid(Pose? pose) {
    if (pose == null) return false;
    return pose.landmarks.length >= minLandmarksRequired;
  }

  /// Get visibility status of key body parts
  Map<String, bool> getBodyVisibility(Pose? pose) {
    if (pose == null) {
      return {
        'upperBody': false,
        'arms': false,
        'legs': false,
      };
    }

    final landmarks = pose.landmarks;

    // Check upper body (shoulders, hips)
    final hasUpperBody = _hasLandmarks(landmarks, [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ]);

    // Check arms (elbows, wrists)
    final hasArms = _hasLandmarks(landmarks, [
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftWrist,
        ]) ||
        _hasLandmarks(landmarks, [
          PoseLandmarkType.rightElbow,
          PoseLandmarkType.rightWrist,
        ]);

    // Check legs (knees, ankles)
    final hasLegs = _hasLandmarks(landmarks, [
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        ]) ||
        _hasLandmarks(landmarks, [
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.rightAnkle,
        ]);

    return {
      'upperBody': hasUpperBody,
      'arms': hasArms,
      'legs': hasLegs,
    };
  }

  bool _hasLandmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    List<PoseLandmarkType> types,
  ) {
    for (final type in types) {
      final landmark = landmarks[type];
      if (landmark == null || landmark.likelihood < 0.5) {
        return false;
      }
    }
    return true;
  }

  /// Get positioning feedback for the user
  PosePositionFeedback getPositionFeedback(Pose? pose, double frameWidth, double frameHeight) {
    if (pose == null) {
      return PosePositionFeedback.noPoseDetected;
    }

    final landmarks = pose.landmarks;

    // Calculate body bounds
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final landmark in landmarks.values) {
      if (landmark.x < minX) minX = landmark.x;
      if (landmark.x > maxX) maxX = landmark.x;
      if (landmark.y < minY) minY = landmark.y;
      if (landmark.y > maxY) maxY = landmark.y;
    }

    final bodyWidth = maxX - minX;
    final bodyHeight = maxY - minY;

    // Check if too close (body takes up too much of frame)
    if (bodyHeight > frameHeight * 0.9 || bodyWidth > frameWidth * 0.9) {
      return PosePositionFeedback.tooClose;
    }

    // Check if too far (body is too small in frame)
    if (bodyHeight < frameHeight * 0.4) {
      return PosePositionFeedback.tooFar;
    }

    // Check if body is at edge of frame
    final margin = frameWidth * 0.05;
    if (minX < margin || maxX > frameWidth - margin) {
      return PosePositionFeedback.moveToCenter;
    }

    return PosePositionFeedback.good;
  }

  /// Dispose of the pose detector
  Future<void> dispose() async {
    await _poseDetector?.close();
    _poseDetector = null;
  }
}

/// Feedback about user's position relative to camera
enum PosePositionFeedback {
  good,
  tooClose,
  tooFar,
  moveToCenter,
  noPoseDetected,
}

extension PosePositionFeedbackMessage on PosePositionFeedback {
  String get message {
    switch (this) {
      case PosePositionFeedback.good:
        return '';
      case PosePositionFeedback.tooClose:
        return 'Step back from camera';
      case PosePositionFeedback.tooFar:
        return 'Move closer to camera';
      case PosePositionFeedback.moveToCenter:
        return 'Move to center of frame';
      case PosePositionFeedback.noPoseDetected:
        return 'Position yourself in frame';
    }
  }
}
