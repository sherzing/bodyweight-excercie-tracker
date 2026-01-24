import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'invalid_rep_reason.dart';

/// Abstract base class for all exercise counters.
/// Each exercise type implements this interface to track reps and validate form.
abstract class ExerciseCounter {
  /// Current pose landmarks from ML Kit
  List<PoseLandmark> landmarks = [];

  /// Current rep count
  int repCount = 0;

  /// Count of invalid reps (partial range of motion, poor form)
  int invalidRepCount = 0;

  /// Minimum confidence threshold for landmarks
  static const double minConfidence = 0.5;

  /// Minimum time between reps to avoid false positives (ms)
  static const int minRepIntervalMs = 300;

  /// Timestamp of last completed rep
  DateTime? lastRepTime;

  /// Information about the last invalid rep (null if no invalid rep recorded)
  InvalidRepInfo? lastInvalidRepInfo;

  /// Callback triggered when an invalid rep is recorded
  void Function(InvalidRepInfo info)? onInvalidRep;

  /// Update the current pose landmarks
  void updateLandmarks(List<PoseLandmark> newLandmarks) {
    landmarks = newLandmarks;
  }

  /// Check if all required landmarks are detected with sufficient confidence
  bool isValidPose();

  /// Get the current stage of the exercise (e.g., "Up", "Down")
  String getCurrentStage();

  /// Check if a rep was just completed. Returns true when a full rep cycle completes.
  /// This method should be called after updateLandmarks() on each frame.
  bool checkRepCompletion();

  /// Get debug information about current joint angles
  Map<String, double> getDebugAngles();

  /// Get a specific landmark by type, or null if not found
  PoseLandmark? getLandmark(PoseLandmarkType type) {
    try {
      return landmarks.firstWhere((l) => l.type == type);
    } catch (_) {
      return null;
    }
  }

  /// Check if a landmark has sufficient confidence
  bool hasConfidence(PoseLandmark? landmark) {
    return landmark != null && landmark.likelihood >= minConfidence;
  }

  /// Check if enough time has passed since the last rep
  bool canCountRep() {
    if (lastRepTime == null) return true;
    final elapsed = DateTime.now().difference(lastRepTime!).inMilliseconds;
    return elapsed >= minRepIntervalMs;
  }

  /// Record that a rep was completed
  void recordRep() {
    repCount++;
    lastRepTime = DateTime.now();
  }

  /// Record an invalid rep attempt with optional structured reason information.
  /// When [info] is provided, stores the reason and triggers the callback.
  void recordInvalidRep([InvalidRepInfo? info]) {
    invalidRepCount++;
    if (info != null) {
      lastInvalidRepInfo = info;
      onInvalidRep?.call(info);
    }
  }

  /// Reset the counter state
  void reset() {
    repCount = 0;
    invalidRepCount = 0;
    lastRepTime = null;
    lastInvalidRepInfo = null;
    landmarks = [];
  }

  /// Get the exercise name for display
  String get exerciseName;

  /// Get the exercise variant (if applicable)
  String get variant => 'Standard';
}
