import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/workout.dart';
import '../models/exercise_counter.dart';
import '../models/pushup_counter.dart';
import '../models/burpee_counter.dart';
import '../services/pose_detection_service.dart';

/// Central state manager for workout sessions.
/// Manages exercise state, timing, and rep counting.
class WorkoutManager extends ChangeNotifier {
  // Workout configuration
  ExerciseType _exerciseType = ExerciseType.pushups;
  ExerciseVariant _variant = ExerciseVariant.standard;
  WorkoutMode _mode = WorkoutMode.free;
  int _targetValue = 0;

  // Workout state
  WorkoutState _state = WorkoutState.idle;
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;
  int _countdownSeconds = 3;

  // Calibration state
  int _calibrationRepsCompleted = 0;
  int _calibrationRepsTarget = 2;
  bool _calibrationEnabled = true;
  List<double> _calibrationUpPositions = [];
  List<double> _calibrationDownPositions = [];

  // Exercise tracking
  ExerciseCounter? _exerciseCounter;
  Pose? _currentPose;
  PosePositionFeedback _positionFeedback = PosePositionFeedback.noPoseDetected;

  // Timers
  Timer? _workoutTimer;
  Timer? _countdownTimer;

  // Callbacks
  VoidCallback? onRepCompleted;
  VoidCallback? onInvalidRep;
  VoidCallback? onWorkoutCompleted;
  VoidCallback? onCalibrationRepCompleted;
  VoidCallback? onCalibrationCompleted;

  // Getters
  ExerciseType get exerciseType => _exerciseType;
  ExerciseVariant get variant => _variant;
  WorkoutMode get mode => _mode;
  int get targetValue => _targetValue;
  WorkoutState get state => _state;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _remainingSeconds;
  int get countdownSeconds => _countdownSeconds;
  int get repCount => _exerciseCounter?.repCount ?? 0;
  int get invalidRepCount => _exerciseCounter?.invalidRepCount ?? 0;
  String get currentStage => _exerciseCounter?.getCurrentStage() ?? '';
  Pose? get currentPose => _currentPose;
  PosePositionFeedback get positionFeedback => _positionFeedback;
  Map<String, double> get debugAngles => _exerciseCounter?.getDebugAngles() ?? {};
  bool get isValidPose => _exerciseCounter?.isValidPose() ?? false;

  // Calibration getters
  int get calibrationRepsCompleted => _calibrationRepsCompleted;
  int get calibrationRepsTarget => _calibrationRepsTarget;
  bool get calibrationEnabled => _calibrationEnabled;
  double? get calibratedUpY => _calibrationUpPositions.isEmpty
      ? null
      : _calibrationUpPositions.reduce((a, b) => a + b) / _calibrationUpPositions.length;
  double? get calibratedDownY => _calibrationDownPositions.isEmpty
      ? null
      : _calibrationDownPositions.reduce((a, b) => a + b) / _calibrationDownPositions.length;

  /// Configure the workout before starting
  void configure({
    required ExerciseType exerciseType,
    ExerciseVariant variant = ExerciseVariant.standard,
    required WorkoutMode mode,
    int targetValue = 0,
    bool enableCalibration = true,
  }) {
    _exerciseType = exerciseType;
    _variant = variant;
    _mode = mode;
    _targetValue = targetValue;
    _calibrationEnabled = enableCalibration;

    // Create appropriate exercise counter
    _exerciseCounter = _createExerciseCounter();

    notifyListeners();
  }

  ExerciseCounter _createExerciseCounter() {
    switch (_exerciseType) {
      case ExerciseType.pushups:
        return PushupCounter();
      case ExerciseType.burpees:
        return BurpeeCounter(
          isModifiedVariant: _variant == ExerciseVariant.modified,
        );
    }
  }

  /// Start the workout with a countdown
  void startWorkout() {
    if (_state != WorkoutState.idle) return;

    _state = WorkoutState.countdown;
    _countdownSeconds = 3;
    _exerciseCounter?.reset();
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;
      notifyListeners();

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _beginWorkout();
      }
    });
  }

  void _beginWorkout() {
    // Start calibration phase if enabled
    if (_calibrationEnabled) {
      _state = WorkoutState.calibrating;
      _calibrationRepsCompleted = 0;
      _calibrationUpPositions = [];
      _calibrationDownPositions = [];
      notifyListeners();
    } else {
      _startActiveWorkout();
    }
  }

  void _startActiveWorkout() {
    _state = WorkoutState.active;
    _startTime = DateTime.now();
    _elapsedSeconds = 0;

    if (_mode == WorkoutMode.timer) {
      _remainingSeconds = _targetValue;
    }

    notifyListeners();

    // Start the workout timer
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != WorkoutState.active) return;

      _elapsedSeconds++;

      if (_mode == WorkoutMode.timer) {
        _remainingSeconds = _targetValue - _elapsedSeconds;
        if (_remainingSeconds <= 0) {
          _completeWorkout();
          return;
        }
      }

      notifyListeners();
    });
  }

  /// Skip calibration and start workout immediately
  void skipCalibration() {
    if (_state != WorkoutState.calibrating) return;
    _startActiveWorkout();
  }

  /// Record a calibration position (called by GuideLinesOverlay)
  void recordCalibrationPosition({required bool isUp, required double shoulderY}) {
    if (_state != WorkoutState.calibrating) return;

    if (isUp) {
      _calibrationUpPositions.add(shoulderY);
    } else {
      _calibrationDownPositions.add(shoulderY);
    }
  }

  /// Complete a calibration rep
  void completeCalibrationRep() {
    if (_state != WorkoutState.calibrating) return;

    _calibrationRepsCompleted++;
    onCalibrationRepCompleted?.call();
    notifyListeners();

    // Check if calibration is complete
    if (_calibrationRepsCompleted >= _calibrationRepsTarget) {
      _finishCalibration();
    }
  }

  void _finishCalibration() {
    onCalibrationCompleted?.call();
    _startActiveWorkout();
  }

  /// Pause the workout
  void pauseWorkout() {
    if (_state != WorkoutState.active) return;
    _state = WorkoutState.paused;
    notifyListeners();
  }

  /// Resume a paused workout
  void resumeWorkout() {
    if (_state != WorkoutState.paused) return;
    _state = WorkoutState.active;
    notifyListeners();
  }

  /// Stop the workout manually
  void stopWorkout() {
    _workoutTimer?.cancel();
    _countdownTimer?.cancel();
    _state = WorkoutState.completed;
    notifyListeners();
  }

  void _completeWorkout() {
    _workoutTimer?.cancel();
    _state = WorkoutState.completed;
    onWorkoutCompleted?.call();
    notifyListeners();
  }

  /// Process a new pose from the camera
  void updatePose(Pose? pose, double frameWidth, double frameHeight) {
    _currentPose = pose;

    if (pose != null && _exerciseCounter != null) {
      // Update landmarks on the exercise counter
      _exerciseCounter!.updateLandmarks(pose.landmarks.values.toList());

      // Check for rep completion if workout is active
      if (_state == WorkoutState.active) {
        final previousInvalidCount = _exerciseCounter!.invalidRepCount;

        final completed = _exerciseCounter!.checkRepCompletion();

        if (completed) {
          onRepCompleted?.call();

          // Check if rep goal reached
          if (_mode == WorkoutMode.repGoal &&
              _exerciseCounter!.repCount >= _targetValue) {
            _completeWorkout();
          }
        } else if (_exerciseCounter!.invalidRepCount > previousInvalidCount) {
          onInvalidRep?.call();
        }
      }
    }

    // Update position feedback
    final poseService = PoseDetectionService();
    _positionFeedback = poseService.getPositionFeedback(pose, frameWidth, frameHeight);

    notifyListeners();
  }

  /// Get the current workout data for saving
  Workout? getCurrentWorkout() {
    if (_startTime == null) return null;

    return Workout(
      exerciseType: _exerciseType,
      variant: _variant,
      mode: _mode,
      targetValue: _targetValue > 0 ? _targetValue : null,
      repsCompleted: repCount,
      repsInvalid: invalidRepCount,
      durationSeconds: _elapsedSeconds,
      startedAt: _startTime!,
      wasCompleted: _state == WorkoutState.completed &&
          (_mode != WorkoutMode.repGoal || repCount >= _targetValue),
    );
  }

  /// Reset the manager to initial state
  void reset() {
    _workoutTimer?.cancel();
    _countdownTimer?.cancel();
    _state = WorkoutState.idle;
    _startTime = null;
    _elapsedSeconds = 0;
    _remainingSeconds = 0;
    _currentPose = null;
    _exerciseCounter?.reset();
    // Reset calibration state
    _calibrationRepsCompleted = 0;
    _calibrationUpPositions = [];
    _calibrationDownPositions = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
