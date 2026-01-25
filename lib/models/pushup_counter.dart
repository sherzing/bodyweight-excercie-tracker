import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';
import 'invalid_rep_reason.dart';
import '../utils/angle_utils.dart';

/// Pushup stage in the exercise cycle
enum PushupStage { ready, up, goingDown, down, goingUp }

/// Tracks pushup reps by monitoring elbow angle transitions.
/// A complete rep: Up (elbow >= 160°) -> Down (elbow <= 90°) -> Up
class PushupCounter extends ExerciseCounter {
  /// Current stage in the pushup cycle
  PushupStage _stage = PushupStage.up;

  /// Threshold angles with tolerance
  static const double upAngleThreshold = 160.0; // Elbow angle for "up" position
  static const double downAngleThreshold = 120.0; // Elbow angle for "down" position (relaxed for camera angles)
  static const double angleTolerance = 10.0; // Tolerance for angle detection

  /// Body alignment threshold - increased to 30° to account for normal form variation and detection noise
  static const double maxBodyDeviation = 30.0;

  /// Whether the counter is ready to count reps (first cycle completed)
  bool _isReady = false;

  /// Track if we've seen a valid down position this cycle
  bool _wasDown = false;

  /// Track form quality throughout the rep cycle
  int _goodFormFrames = 0;
  int _badFormFrames = 0;

  /// Minimum percentage of good form frames required for a valid rep
  static const double minGoodFormRatio = 0.6; // 60% of frames must have good form

  /// Track min/max elbow angles during rep for partial range detection
  double? _minElbowAngle;
  double? _maxElbowAngle;

  /// Track when rep started for too-fast detection
  DateTime? _repStartTime;

  /// Thresholds for invalid rep detection
  static const double partialDownThreshold = 100.0; // Must reach <= this angle
  static const double partialUpThreshold = 150.0; // Must reach >= this angle at end

  @override
  String get exerciseName => 'Pushups';

  /// Whether the counter has completed warmup and is actively counting
  bool get isReady => _isReady;

  /// Skip the first cycle warmup and immediately start counting.
  /// This is primarily for testing purposes.
  void activate() {
    _stage = PushupStage.up;
    _isReady = true;
  }

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
    // Show warmup indicator if first cycle hasn't completed
    final prefix = _isReady ? '' : '(Warmup) ';
    switch (_stage) {
      case PushupStage.ready:
        return '${prefix}Up'; // Legacy state, treat as Up
      case PushupStage.up:
        return '${prefix}Up';
      case PushupStage.goingDown:
        return '${prefix}Going Down';
      case PushupStage.down:
        return '${prefix}Down';
      case PushupStage.goingUp:
        return '${prefix}Going Up';
    }
  }

  @override
  bool checkRepCompletion() {
    if (!isValidPose()) {
      print('[PUSHUP] Invalid pose - missing landmarks');
      return false;
    }

    // Check if person is in horizontal plank position (not standing)
    if (!_isInPlankPosition()) {
      // Reset state when user stands up to prevent stuck cycles
      if (_stage != PushupStage.up) {
        print('[PUSHUP] Not in plank position - resetting to up stage');
        _stage = PushupStage.up;
        _wasDown = false;
        _resetFormTracking();
      } else {
        print('[PUSHUP] Not in plank position - likely standing');
      }
      return false;
    }

    final angles = getDebugAngles();
    final elbowAngle = angles['elbow'];

    if (elbowAngle == null) {
      print('[PUSHUP] No elbow angle detected');
      return false;
    }

    // Track min/max elbow angles during active rep
    if (_stage != PushupStage.up) {
      _minElbowAngle = _minElbowAngle == null
          ? elbowAngle
          : (elbowAngle < _minElbowAngle! ? elbowAngle : _minElbowAngle);
      _maxElbowAngle = _maxElbowAngle == null
          ? elbowAngle
          : (elbowAngle > _maxElbowAngle! ? elbowAngle : _maxElbowAngle);
    }

    // Check body alignment - only if ankles are reliably detected
    final bodyDeviation = angles['bodyDeviation'];
    final leftAnkle = getLandmark(PoseLandmarkType.leftAnkle);
    final rightAnkle = getLandmark(PoseLandmarkType.rightAnkle);
    final hasReliableAnkles = hasConfidence(leftAnkle) || hasConfidence(rightAnkle);

    // Good form: body deviation is known and within threshold
    // Bad form: body deviation is known and exceeds threshold (including high values that indicate standing)
    // Only consider form if ankles are reliably detected
    final hasGoodForm = bodyDeviation != null && bodyDeviation < maxBodyDeviation;
    final hasBadForm = hasReliableAnkles && bodyDeviation != null && bodyDeviation >= maxBodyDeviation;

    // Track form quality during active rep (goingDown, down, goingUp stages)
    // Only track if we have reliable ankle detection - otherwise skip form evaluation
    if (_stage != PushupStage.up && bodyDeviation != null && hasReliableAnkles) {
      if (hasGoodForm) {
        _goodFormFrames++;
      } else {
        _badFormFrames++;
      }
    }

    // Calculate current form ratio for logging
    final totalFrames = _goodFormFrames + _badFormFrames;
    final formRatio = totalFrames > 0 ? _goodFormFrames / totalFrames : 1.0;

    // Log angles for debugging
    final ankleStatus = hasReliableAnkles ? 'OK' : 'NO';
    print('[PUSHUP] Stage: $_stage | Elbow: ${elbowAngle.toStringAsFixed(1)}° | BodyDev: ${bodyDeviation?.toStringAsFixed(1) ?? "N/A"}° | Ankles: $ankleStatus | Form: ${(formRatio * 100).toInt()}% good (${_goodFormFrames}/${totalFrames})');

    // State machine for pushup detection
    switch (_stage) {
      case PushupStage.ready:
        // Legacy state - should not be reached, transition to up
        _stage = PushupStage.up;
        break;

      case PushupStage.up:
        // Looking for transition to down position
        if (elbowAngle <= downAngleThreshold + angleTolerance) {
          _resetFormTracking(); // Start fresh form tracking for new rep
          _repStartTime = DateTime.now();
          _stage = PushupStage.down;
          _wasDown = true;
        } else if (elbowAngle < upAngleThreshold - angleTolerance) {
          _resetFormTracking(); // Start fresh form tracking for new rep
          _repStartTime = DateTime.now();
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
            // First cycle is skipped (warmup/getting into position)
            if (!_isReady) {
              print('[PUSHUP] First cycle complete - counter now ready (not counted)');
              _isReady = true;
              _wasDown = false;
              _resetFormTracking();
              return false;
            }

            // Log form quality for debugging (but don't use it to reject reps)
            // Form validation disabled due to noisy pose detection causing false rejections
            final repTotalFrames = _goodFormFrames + _badFormFrames;
            final repFormRatio = repTotalFrames > 0 ? _goodFormFrames / repTotalFrames : 1.0;

            print('[PUSHUP] Rep complete! Form ratio: ${(repFormRatio * 100).toInt()}% frames=$repTotalFrames - VALID');

            recordRep();
            _wasDown = false;
            _resetFormTracking();
            return true;
          } else if (_wasDown) {
            // Debounce blocked this rep - reset state to prevent phantom reps
            // from angle fluctuations near the threshold
            print('[PUSHUP] Rep blocked by debounce - resetting state');
            _wasDown = false;
            _resetFormTracking();
          }
        } else if (elbowAngle > downAngleThreshold + angleTolerance) {
          _stage = PushupStage.goingUp;
        }
        break;

      case PushupStage.goingUp:
        if (elbowAngle >= upAngleThreshold - angleTolerance) {
          _stage = PushupStage.up;
          if (_wasDown && canCountRep()) {
            // First cycle is skipped (warmup/getting into position)
            if (!_isReady) {
              print('[PUSHUP] First cycle complete - counter now ready (not counted)');
              _isReady = true;
              _wasDown = false;
              _resetFormTracking();
              return false;
            }

            // Log form quality for debugging (but don't use it to reject reps)
            // Form validation disabled due to noisy pose detection causing false rejections
            final repTotalFrames = _goodFormFrames + _badFormFrames;
            final repFormRatio = repTotalFrames > 0 ? _goodFormFrames / repTotalFrames : 1.0;

            print('[PUSHUP] Rep complete! Form ratio: ${(repFormRatio * 100).toInt()}% frames=$repTotalFrames - VALID');

            recordRep();
            _wasDown = false;
            _resetFormTracking();
            return true;
          } else if (_wasDown) {
            // Debounce blocked this rep - reset state to prevent phantom reps
            // from angle fluctuations near the threshold
            print('[PUSHUP] Rep blocked by debounce - resetting state');
            _wasDown = false;
            _resetFormTracking();
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

  /// Check if the person is in a horizontal plank position (not standing upright)
  /// This prevents false positives when the user stands up after a workout
  bool _isInPlankPosition() {
    final leftShoulder = getLandmark(PoseLandmarkType.leftShoulder);
    final rightShoulder = getLandmark(PoseLandmarkType.rightShoulder);
    final leftHip = getLandmark(PoseLandmarkType.leftHip);
    final rightHip = getLandmark(PoseLandmarkType.rightHip);

    // Get the best available shoulder and hip
    final shoulder = (hasConfidence(leftShoulder) ? leftShoulder : rightShoulder);
    final hip = (hasConfidence(leftHip) ? leftHip : rightHip);

    if (shoulder == null || hip == null) return true; // Assume plank if we can't tell

    // Calculate vertical distance between shoulder and hip
    final verticalDiff = (shoulder.y - hip.y).abs();
    // Calculate horizontal distance between shoulder and hip
    final horizontalDiff = (shoulder.x - hip.x).abs();

    // In a plank position, the body is more horizontal than vertical
    // So horizontal distance should be greater than or close to vertical distance
    // When standing, vertical distance is much greater than horizontal distance

    // Calculate the ratio - if vertical diff is much larger than horizontal, person is standing
    final ratio = verticalDiff / (horizontalDiff + 1); // +1 to avoid division by zero

    // If vertical distance is more than 2x horizontal distance, person is likely standing
    final isPlank = ratio < 2.0;

    if (!isPlank) {
      print('[PUSHUP] Body orientation: vertical=$verticalDiff, horizontal=$horizontalDiff, ratio=$ratio - STANDING');
    }

    return isPlank;
  }

  /// Reset form tracking counters for next rep
  void _resetFormTracking() {
    _goodFormFrames = 0;
    _badFormFrames = 0;
    _minElbowAngle = null;
    _maxElbowAngle = null;
    _repStartTime = null;
  }

  /// Create InvalidRepInfo with the appropriate reason based on tracked metrics
  InvalidRepInfo _createInvalidRepInfo({
    required double elbowAngle,
    required double? bodyDeviation,
    required double formRatio,
  }) {
    // Determine the primary reason for the invalid rep
    // Priority: partialRangeDown > partialRangeUp > poorForm
    InvalidRepReason reason;

    if (_minElbowAngle != null && _minElbowAngle! > partialDownThreshold) {
      // Never reached low enough position
      reason = InvalidRepReason.partialRangeDown;
    } else if (elbowAngle < partialUpThreshold) {
      // Didn't fully extend at completion
      reason = InvalidRepReason.partialRangeUp;
    } else {
      // Form was poor (body deviation too high)
      reason = InvalidRepReason.poorForm;
    }

    // Calculate rep duration if we have start time
    final durationMs = _repStartTime != null
        ? DateTime.now().difference(_repStartTime!).inMilliseconds
        : null;

    return InvalidRepInfo(
      reason: reason,
      timestamp: DateTime.now(),
      repIndex: invalidRepCount, // Current count before increment
      elbowAngle: elbowAngle,
      bodyDeviation: bodyDeviation,
      formRatio: formRatio,
      durationMs: durationMs,
      minElbowAngle: _minElbowAngle,
      maxElbowAngle: _maxElbowAngle,
    );
  }

  @override
  void reset() {
    super.reset();
    _stage = PushupStage.up;
    _isReady = false;
    _wasDown = false;
    _resetFormTracking();
  }
}
