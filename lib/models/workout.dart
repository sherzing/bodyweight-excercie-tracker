/// Type of exercise being performed
enum ExerciseType {
  pushups,
  burpees,
}

extension ExerciseTypeExtension on ExerciseType {
  String get displayName {
    switch (this) {
      case ExerciseType.pushups:
        return 'Pushups';
      case ExerciseType.burpees:
        return 'Burpees';
    }
  }
}

/// Variant of the exercise (affects validation rules)
enum ExerciseVariant {
  standard,
  modified, // e.g., modified burpees without pushup
}

extension ExerciseVariantExtension on ExerciseVariant {
  String get displayName {
    switch (this) {
      case ExerciseVariant.standard:
        return 'Standard';
      case ExerciseVariant.modified:
        return 'Modified';
    }
  }
}

/// Workout mode determines timing and completion behavior
enum WorkoutMode {
  timer,    // Countdown timer, AMRAP
  repGoal,  // Count up to target reps
  free,     // No target, manual stop
}

extension WorkoutModeExtension on WorkoutMode {
  String get displayName {
    switch (this) {
      case WorkoutMode.timer:
        return 'Timer';
      case WorkoutMode.repGoal:
        return 'Rep Goal';
      case WorkoutMode.free:
        return 'Free';
    }
  }

  String get description {
    switch (this) {
      case WorkoutMode.timer:
        return 'Complete as many reps as possible in the time limit';
      case WorkoutMode.repGoal:
        return 'Complete a target number of reps';
      case WorkoutMode.free:
        return 'No target - stop when ready';
    }
  }
}

/// Current state of the workout
enum WorkoutState {
  idle,        // Not started
  countdown,   // 3-2-1 countdown before start
  calibrating, // Calibration phase - user does 2 reps to set guide line positions
  active,      // Workout in progress
  paused,      // Workout paused
  completed,   // Workout finished (goal reached or timer ended)
}

/// Represents a completed workout session
class Workout {
  final int? id;
  final ExerciseType exerciseType;
  final ExerciseVariant variant;
  final WorkoutMode mode;
  final int? targetValue; // Target reps or seconds depending on mode
  final int repsCompleted;
  final int repsInvalid;
  final int durationSeconds;
  final DateTime startedAt;
  final bool wasCompleted; // True if goal was reached

  Workout({
    this.id,
    required this.exerciseType,
    required this.variant,
    required this.mode,
    this.targetValue,
    required this.repsCompleted,
    required this.repsInvalid,
    required this.durationSeconds,
    required this.startedAt,
    required this.wasCompleted,
  });

  /// Average time per rep in seconds
  double get averageRepTime {
    if (repsCompleted == 0) return 0;
    return durationSeconds / repsCompleted;
  }

  /// Success rate (valid reps / total attempts)
  double get successRate {
    final total = repsCompleted + repsInvalid;
    if (total == 0) return 1.0;
    return repsCompleted / total;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_type': exerciseType.name,
      'variant': variant.name,
      'mode': mode.name,
      'target_value': targetValue,
      'reps_completed': repsCompleted,
      'reps_invalid': repsInvalid,
      'duration_seconds': durationSeconds,
      'started_at': startedAt.toIso8601String(),
      'was_completed': wasCompleted ? 1 : 0,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as int?,
      exerciseType: ExerciseType.values.byName(map['exercise_type'] as String),
      variant: ExerciseVariant.values.byName(map['variant'] as String),
      mode: WorkoutMode.values.byName(map['mode'] as String),
      targetValue: map['target_value'] as int?,
      repsCompleted: map['reps_completed'] as int,
      repsInvalid: map['reps_invalid'] as int,
      durationSeconds: map['duration_seconds'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      wasCompleted: (map['was_completed'] as int) == 1,
    );
  }
}
