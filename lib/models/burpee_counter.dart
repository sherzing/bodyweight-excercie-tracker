import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';
import '../utils/angle_utils.dart';

/// State machine stages for burpee detection
enum BurpeeStage {
  standing,      // Upright position, hip angle >160°
  squatPlank,    // Squat down or plank position, hip angle <90°
  pushup,        // Down position of pushup, elbow ≤90° (Standard only)
  jump,          // Jump phase, hip >170°, vertical movement
}

/// Counter for tracking burpee repetitions using pose detection.
///
/// Uses a 4-state machine:
/// 1. Standing → 2. Squat/Plank → 3. Pushup (Standard) → 4. Jump → 1. Standing
///
/// Modified variant skips the pushup phase.
class BurpeeCounter extends ExerciseCounter {
  BurpeeStage _currentStage = BurpeeStage.standing;
  final bool isModifiedVariant;

  // Angle thresholds
  static const double standingHipAngle = 160.0;
  static const double squatHipAngle = 90.0;
  static const double jumpHipAngle = 170.0;
  static const double pushupElbowAngle = 90.0;
  static const double angleTolerance = 10.0;

  BurpeeCounter({this.isModifiedVariant = false});

  @override
  String get exerciseName => 'Burpees';

  @override
  String get variant => isModifiedVariant ? 'Modified' : 'Standard';

  @override
  bool isValidPose() {
    // Check for key landmarks needed for burpee detection
    final requiredTypes = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ];

    for (final type in requiredTypes) {
      final landmark = getLandmark(type);
      if (!hasConfidence(landmark)) {
        return false;
      }
    }

    return true;
  }

  @override
  String getCurrentStage() {
    switch (_currentStage) {
      case BurpeeStage.standing:
        return 'Standing';
      case BurpeeStage.squatPlank:
        return 'Squat/Plank';
      case BurpeeStage.pushup:
        return 'Pushup';
      case BurpeeStage.jump:
        return 'Jump';
    }
  }

  @override
  bool checkRepCompletion() {
    if (!isValidPose()) return false;

    final hipAngle = _getAverageHipAngle();
    final elbowAngle = _getAverageElbowAngle();

    if (hipAngle == null) return false;

    final prevStage = _currentStage;

    switch (_currentStage) {
      case BurpeeStage.standing:
        // Transition to squat/plank when hip angle drops below threshold
        if (hipAngle < squatHipAngle + angleTolerance) {
          _currentStage = BurpeeStage.squatPlank;
        }
        break;

      case BurpeeStage.squatPlank:
        if (isModifiedVariant) {
          // Modified variant: skip pushup, go directly to jump
          if (hipAngle > jumpHipAngle - angleTolerance && _isJumpDetected()) {
            _currentStage = BurpeeStage.jump;
          }
        } else {
          // Standard variant: require pushup
          if (elbowAngle != null && elbowAngle <= pushupElbowAngle + angleTolerance) {
            _currentStage = BurpeeStage.pushup;
          }
        }
        break;

      case BurpeeStage.pushup:
        // After pushup, need to return to plank/standing position then jump
        if (elbowAngle != null && elbowAngle > standingHipAngle - angleTolerance) {
          // Arms extended again, look for jump
          if (hipAngle > jumpHipAngle - angleTolerance && _isJumpDetected()) {
            _currentStage = BurpeeStage.jump;
          }
        }
        break;

      case BurpeeStage.jump:
        // Complete rep when returning to standing position
        if (hipAngle > standingHipAngle - angleTolerance && !_isJumpDetected()) {
          _currentStage = BurpeeStage.standing;

          // Check debounce timing
          if (!canCountRep()) {
            return false;
          }

          recordRep();
          return true;
        }
        break;
    }

    // Detect invalid rep: going back to standing without completing cycle
    if (prevStage != BurpeeStage.standing &&
        prevStage != BurpeeStage.jump &&
        _currentStage == BurpeeStage.standing) {
      // Check if we went back to standing prematurely
      if (hipAngle > standingHipAngle - angleTolerance) {
        recordInvalidRep();
        _currentStage = BurpeeStage.standing;
        return false;
      }
    }

    return false;
  }

  @override
  Map<String, double> getDebugAngles() {
    final angles = <String, double>{};

    final hipAngle = _getAverageHipAngle();
    if (hipAngle != null) {
      angles['hipAngle'] = hipAngle;
    }

    final elbowAngle = _getAverageElbowAngle();
    if (elbowAngle != null) {
      angles['elbowAngle'] = elbowAngle;
    }

    final kneeAngle = _getAverageKneeAngle();
    if (kneeAngle != null) {
      angles['kneeAngle'] = kneeAngle;
    }

    return angles;
  }

  @override
  void reset() {
    super.reset();
    _currentStage = BurpeeStage.standing;
  }

  /// Get average hip angle (shoulder-hip-knee)
  double? _getAverageHipAngle() {
    final leftAngle = _getHipAngle(isLeft: true);
    final rightAngle = _getHipAngle(isLeft: false);

    return AngleUtils.averageSideAngles(leftAngle, rightAngle);
  }

  double? _getHipAngle({required bool isLeft}) {
    final shoulder = getLandmark(
      isLeft ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder,
    );
    final hip = getLandmark(
      isLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip,
    );
    final knee = getLandmark(
      isLeft ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee,
    );

    return AngleUtils.calculateHipAngle(shoulder, hip, knee);
  }

  /// Get average elbow angle (shoulder-elbow-wrist)
  double? _getAverageElbowAngle() {
    final leftAngle = _getElbowAngle(isLeft: true);
    final rightAngle = _getElbowAngle(isLeft: false);

    return AngleUtils.averageSideAngles(leftAngle, rightAngle);
  }

  double? _getElbowAngle({required bool isLeft}) {
    final shoulder = getLandmark(
      isLeft ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder,
    );
    final elbow = getLandmark(
      isLeft ? PoseLandmarkType.leftElbow : PoseLandmarkType.rightElbow,
    );
    final wrist = getLandmark(
      isLeft ? PoseLandmarkType.leftWrist : PoseLandmarkType.rightWrist,
    );

    return AngleUtils.calculateElbowAngle(shoulder, elbow, wrist);
  }

  /// Get average knee angle
  double? _getAverageKneeAngle() {
    final leftAngle = _getKneeAngle(isLeft: true);
    final rightAngle = _getKneeAngle(isLeft: false);

    return AngleUtils.averageSideAngles(leftAngle, rightAngle);
  }

  double? _getKneeAngle({required bool isLeft}) {
    final hip = getLandmark(
      isLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip,
    );
    final knee = getLandmark(
      isLeft ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee,
    );
    final ankle = getLandmark(
      isLeft ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle,
    );

    return AngleUtils.calculateKneeAngle(hip, knee, ankle);
  }

  /// Detect if user is in a jump position
  /// Uses knee extension as a proxy for jump detection
  bool _isJumpDetected() {
    final kneeAngle = _getAverageKneeAngle();

    // Knees should be relatively straight during jump
    if (kneeAngle != null && kneeAngle > 160) {
      return true;
    }
    return false;
  }
}
