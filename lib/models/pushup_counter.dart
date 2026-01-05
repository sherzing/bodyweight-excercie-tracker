import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';
import '../utils/angle_utils.dart';

/// Pushup stage in the exercise cycle
enum PushupStage { up, goingDown, down, goingUp }

/// Tracks pushup reps by monitoring elbow angle transitions.
/// A complete rep: Up (elbow >= 160°) -> Down (elbow <= 90°) -> Up
class PushupCounter extends ExerciseCounter {
  /// Current stage in the pushup cycle
  PushupStage _stage = PushupStage.up;

  /// Threshold angles with tolerance
  static const double upAngleThreshold = 160.0; // Elbow angle for "up" position
  static const double downAngleThreshold = 90.0; // Elbow angle for "down" position
  static const double angleTolerance = 10.0; // Tolerance for angle detection

  /// Body alignment threshold
  static const double maxBodyDeviation = 15.0;

  /// Track if we've seen a valid down position this cycle
  bool _wasDown = false;

  @override
  String get exerciseName => 'Pushups';

  @override
  bool isValidPose() {
    // Check if we have all required landmarks with sufficient confidence
    final leftShoulder = getLandmark(PoseLandmarkType.leftShoulder);
    final rightShoulder = getLandmark(PoseLandmarkType.rightShoulder);
    final leftElbow = getLandmark(PoseLandmarkType.leftElbow);
    final rightElbow = getLandmark(PoseLandmarkType.rightElbow);
    final leftWrist = getLandmark(PoseLandmarkType.leftWrist);
    final rightWrist = getLandmark(PoseLandmarkType.rightWrist);
    final leftHip = getLandmark(PoseLandmarkType.leftHip);
    final rightHip = getLandmark(PoseLandmarkType.rightHip);

    // Need at least one side with shoulder, elbow, wrist
    final hasLeftArm = hasConfidence(leftShoulder) &&
        hasConfidence(leftElbow) &&
        hasConfidence(leftWrist);
    final hasRightArm = hasConfidence(rightShoulder) &&
        hasConfidence(rightElbow) &&
        hasConfidence(rightWrist);

    // Need at least one hip for body position reference
    final hasHip = hasConfidence(leftHip) || hasConfidence(rightHip);

    return (hasLeftArm || hasRightArm) && hasHip;
  }

  @override
  String getCurrentStage() {
    switch (_stage) {
      case PushupStage.up:
        return 'Up';
      case PushupStage.goingDown:
        return 'Going Down';
      case PushupStage.down:
        return 'Down';
      case PushupStage.goingUp:
        return 'Going Up';
    }
  }

  @override
  bool checkRepCompletion() {
    if (!isValidPose()) return false;

    final angles = getDebugAngles();
    final elbowAngle = angles['elbow'];

    if (elbowAngle == null) return false;

    // Check body alignment
    final bodyDeviation = angles['bodyDeviation'];
    final isAligned = bodyDeviation == null || bodyDeviation < maxBodyDeviation;

    // State machine for pushup detection
    switch (_stage) {
      case PushupStage.up:
        // Looking for transition to down position
        if (elbowAngle <= downAngleThreshold + angleTolerance) {
          _stage = PushupStage.down;
          _wasDown = true;
        } else if (elbowAngle < upAngleThreshold - angleTolerance) {
          _stage = PushupStage.goingDown;
        }
        break;

      case PushupStage.goingDown:
        if (elbowAngle <= downAngleThreshold + angleTolerance) {
          _stage = PushupStage.down;
          _wasDown = true;
        }
        break;

      case PushupStage.down:
        // Looking for transition back to up position
        if (elbowAngle >= upAngleThreshold - angleTolerance) {
          _stage = PushupStage.up;
          if (_wasDown && canCountRep()) {
            if (isAligned) {
              recordRep();
              _wasDown = false;
              return true;
            } else {
              // Poor form - count as invalid
              recordInvalidRep();
              _wasDown = false;
            }
          }
        } else if (elbowAngle > downAngleThreshold + angleTolerance) {
          _stage = PushupStage.goingUp;
        }
        break;

      case PushupStage.goingUp:
        if (elbowAngle >= upAngleThreshold - angleTolerance) {
          _stage = PushupStage.up;
          if (_wasDown && canCountRep()) {
            if (isAligned) {
              recordRep();
              _wasDown = false;
              return true;
            } else {
              recordInvalidRep();
              _wasDown = false;
            }
          }
        } else if (elbowAngle <= downAngleThreshold + angleTolerance) {
          // Went back down
          _stage = PushupStage.down;
        }
        break;
    }

    return false;
  }

  @override
  Map<String, double> getDebugAngles() {
    final angles = <String, double>{};

    // Get landmarks
    final leftShoulder = getLandmark(PoseLandmarkType.leftShoulder);
    final rightShoulder = getLandmark(PoseLandmarkType.rightShoulder);
    final leftElbow = getLandmark(PoseLandmarkType.leftElbow);
    final rightElbow = getLandmark(PoseLandmarkType.rightElbow);
    final leftWrist = getLandmark(PoseLandmarkType.leftWrist);
    final rightWrist = getLandmark(PoseLandmarkType.rightWrist);
    final leftHip = getLandmark(PoseLandmarkType.leftHip);
    final rightHip = getLandmark(PoseLandmarkType.rightHip);
    final leftAnkle = getLandmark(PoseLandmarkType.leftAnkle);
    final rightAnkle = getLandmark(PoseLandmarkType.rightAnkle);

    // Calculate elbow angles
    final leftElbowAngle = AngleUtils.calculateElbowAngle(
      leftShoulder,
      leftElbow,
      leftWrist,
    );
    final rightElbowAngle = AngleUtils.calculateElbowAngle(
      rightShoulder,
      rightElbow,
      rightWrist,
    );

    if (leftElbowAngle != null) angles['leftElbow'] = leftElbowAngle;
    if (rightElbowAngle != null) angles['rightElbow'] = rightElbowAngle;

    // Average elbow angle for rep detection
    final avgElbow = AngleUtils.averageSideAngles(leftElbowAngle, rightElbowAngle);
    if (avgElbow != null) angles['elbow'] = avgElbow;

    // Calculate body alignment (deviation from straight line)
    final leftDeviation = AngleUtils.calculateBodyAlignment(
      leftShoulder,
      leftHip,
      leftAnkle,
    );
    final rightDeviation = AngleUtils.calculateBodyAlignment(
      rightShoulder,
      rightHip,
      rightAnkle,
    );

    final avgDeviation = AngleUtils.averageSideAngles(leftDeviation, rightDeviation);
    if (avgDeviation != null) angles['bodyDeviation'] = avgDeviation;

    return angles;
  }

  @override
  void reset() {
    super.reset();
    _stage = PushupStage.up;
    _wasDown = false;
  }
}
