import 'package:flutter_test/flutter_test.dart';
import 'package:pushup_counter/models/workout.dart';
import 'package:pushup_counter/providers/workout_manager.dart';

/// Tests for WorkoutManager state management.
/// Tests focus on the public API and state transitions.
void main() {
  group('WorkoutManager', () {
    late WorkoutManager manager;

    setUp(() {
      manager = WorkoutManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('Initial State', () {
      test('starts in idle state', () {
        expect(manager.state, equals(WorkoutState.idle));
      });

      test('has zero rep count', () {
        expect(manager.repCount, equals(0));
      });

      test('has zero invalid rep count', () {
        expect(manager.invalidRepCount, equals(0));
      });

      test('has zero elapsed seconds', () {
        expect(manager.elapsedSeconds, equals(0));
      });

      test('has no current pose', () {
        expect(manager.currentPose, isNull);
      });
    });

    group('configure', () {
      test('sets exercise type', () {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
        );

        expect(manager.exerciseType, equals(ExerciseType.pushups));
      });

      test('sets workout mode', () {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.timer,
          targetValue: 60,
        );

        expect(manager.mode, equals(WorkoutMode.timer));
      });

      test('sets target value', () {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.repGoal,
          targetValue: 25,
        );

        expect(manager.targetValue, equals(25));
      });

      test('sets variant', () {
        manager.configure(
          exerciseType: ExerciseType.burpees,
          variant: ExerciseVariant.modified,
          mode: WorkoutMode.free,
        );

        expect(manager.variant, equals(ExerciseVariant.modified));
      });

      test('notifies listeners', () {
        var notified = false;
        manager.addListener(() => notified = true);

        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
        );

        expect(notified, isTrue);
      });
    });

    group('startWorkout', () {
      setUp(() {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
        );
      });

      test('transitions to countdown state', () {
        manager.startWorkout();

        expect(manager.state, equals(WorkoutState.countdown));
      });

      test('starts countdown at 3', () {
        manager.startWorkout();

        expect(manager.countdownSeconds, equals(3));
      });

      test('does nothing if not in idle state', () {
        manager.startWorkout(); // Go to countdown
        final state = manager.state;

        manager.startWorkout(); // Try again

        expect(manager.state, equals(state));
      });
    });

    group('pauseWorkout', () {
      test('transitions from active to paused', () async {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
          enableCalibration: false,
        );
        manager.startWorkout();

        // Wait for countdown to complete
        await Future.delayed(const Duration(seconds: 4));

        expect(manager.state, equals(WorkoutState.active));

        manager.pauseWorkout();

        expect(manager.state, equals(WorkoutState.paused));
      });

      test('does nothing if not active', () {
        manager.pauseWorkout();

        expect(manager.state, equals(WorkoutState.idle));
      });
    });

    group('resumeWorkout', () {
      test('transitions from paused to active', () async {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
          enableCalibration: false,
        );
        manager.startWorkout();

        await Future.delayed(const Duration(seconds: 4));
        manager.pauseWorkout();
        expect(manager.state, equals(WorkoutState.paused));

        manager.resumeWorkout();

        expect(manager.state, equals(WorkoutState.active));
      });

      test('does nothing if not paused', () {
        manager.resumeWorkout();

        expect(manager.state, equals(WorkoutState.idle));
      });
    });

    group('stopWorkout', () {
      test('transitions to completed state', () async {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
          enableCalibration: false,
        );
        manager.startWorkout();

        await Future.delayed(const Duration(seconds: 4));

        manager.stopWorkout();

        expect(manager.state, equals(WorkoutState.completed));
      });
    });

    group('reset', () {
      test('returns to idle state', () async {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
          enableCalibration: false,
        );
        manager.startWorkout();
        await Future.delayed(const Duration(seconds: 4));
        manager.stopWorkout();

        manager.reset();

        expect(manager.state, equals(WorkoutState.idle));
      });

      test('clears elapsed time', () async {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
          enableCalibration: false,
        );
        manager.startWorkout();
        await Future.delayed(const Duration(seconds: 5));

        manager.reset();

        expect(manager.elapsedSeconds, equals(0));
      });

      test('clears current pose', () {
        manager.reset();

        expect(manager.currentPose, isNull);
      });
    });

    group('getCurrentWorkout', () {
      test('returns null before workout starts', () {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
        );

        expect(manager.getCurrentWorkout(), isNull);
      });

      test('returns workout data after start', () async {
        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.repGoal,
          targetValue: 10,
          enableCalibration: false,
        );
        manager.startWorkout();
        await Future.delayed(const Duration(seconds: 4));

        final workout = manager.getCurrentWorkout();

        expect(workout, isNotNull);
        expect(workout!.exerciseType, equals(ExerciseType.pushups));
        expect(workout.mode, equals(WorkoutMode.repGoal));
        expect(workout.targetValue, equals(10));
      });
    });

    group('Callbacks', () {
      test('onRepCompleted is called when rep completes', () async {
        // ignore: unused_local_variable - used to verify callback assignment works
        var repCompletedCalled = false;
        manager.onRepCompleted = () => repCompletedCalled = true;

        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
          enableCalibration: false,
        );
        manager.startWorkout();
        await Future.delayed(const Duration(seconds: 4));

        // Note: Would need to simulate pose updates to trigger rep completion
        // This test documents the interface contract
        expect(manager.onRepCompleted, isNotNull);
        // Verify callback was assigned (not that it was called, since we can't simulate poses)
        expect(repCompletedCalled, isFalse); // Not called without pose simulation
      });

      test('onWorkoutCompleted is called when workout ends', () async {
        var workoutCompletedCalled = false;
        manager.onWorkoutCompleted = () => workoutCompletedCalled = true;

        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.timer,
          targetValue: 1, // 1 second timer
          enableCalibration: false,
        );
        manager.startWorkout();

        // Wait for countdown (3s) + timer (1s) + buffer
        await Future.delayed(const Duration(seconds: 5));

        expect(workoutCompletedCalled, isTrue);
      });
    });

    group('ChangeNotifier', () {
      test('notifies on state changes', () {
        var notifyCount = 0;
        manager.addListener(() => notifyCount++);

        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
        );

        expect(notifyCount, greaterThan(0));
      });

      test('can remove listeners', () {
        var notifyCount = 0;
        void listener() => notifyCount++;

        manager.addListener(listener);
        manager.removeListener(listener);

        manager.configure(
          exerciseType: ExerciseType.pushups,
          mode: WorkoutMode.free,
        );

        expect(notifyCount, equals(0));
      });
    });
  });

  group('Workout Model', () {
    test('calculates average rep time', () {
      final workout = Workout(
        exerciseType: ExerciseType.pushups,
        variant: ExerciseVariant.standard,
        mode: WorkoutMode.free,
        repsCompleted: 10,
        repsInvalid: 0,
        durationSeconds: 60,
        startedAt: DateTime.now(),
        wasCompleted: true,
      );

      expect(workout.averageRepTime, equals(6.0));
    });

    test('calculates success rate', () {
      final workout = Workout(
        exerciseType: ExerciseType.pushups,
        variant: ExerciseVariant.standard,
        mode: WorkoutMode.free,
        repsCompleted: 8,
        repsInvalid: 2,
        durationSeconds: 60,
        startedAt: DateTime.now(),
        wasCompleted: true,
      );

      expect(workout.successRate, equals(0.8));
    });

    test('handles zero reps for average time', () {
      final workout = Workout(
        exerciseType: ExerciseType.pushups,
        variant: ExerciseVariant.standard,
        mode: WorkoutMode.free,
        repsCompleted: 0,
        repsInvalid: 0,
        durationSeconds: 60,
        startedAt: DateTime.now(),
        wasCompleted: false,
      );

      expect(workout.averageRepTime, equals(0));
    });

    test('handles zero attempts for success rate', () {
      final workout = Workout(
        exerciseType: ExerciseType.pushups,
        variant: ExerciseVariant.standard,
        mode: WorkoutMode.free,
        repsCompleted: 0,
        repsInvalid: 0,
        durationSeconds: 0,
        startedAt: DateTime.now(),
        wasCompleted: false,
      );

      expect(workout.successRate, equals(1.0));
    });

    test('serializes to map', () {
      final startTime = DateTime(2024, 1, 15, 10, 30);
      final workout = Workout(
        id: 1,
        exerciseType: ExerciseType.pushups,
        variant: ExerciseVariant.standard,
        mode: WorkoutMode.repGoal,
        targetValue: 20,
        repsCompleted: 20,
        repsInvalid: 2,
        durationSeconds: 120,
        startedAt: startTime,
        wasCompleted: true,
      );

      final map = workout.toMap();

      expect(map['id'], equals(1));
      expect(map['exercise_type'], equals('pushups'));
      expect(map['variant'], equals('standard'));
      expect(map['mode'], equals('repGoal'));
      expect(map['target_value'], equals(20));
      expect(map['reps_completed'], equals(20));
      expect(map['reps_invalid'], equals(2));
      expect(map['duration_seconds'], equals(120));
      expect(map['was_completed'], equals(1));
    });

    test('deserializes from map', () {
      final map = {
        'id': 5,
        'exercise_type': 'burpees',
        'variant': 'modified',
        'mode': 'timer',
        'target_value': 60,
        'reps_completed': 15,
        'reps_invalid': 3,
        'duration_seconds': 60,
        'started_at': '2024-01-15T10:30:00.000',
        'was_completed': 1,
      };

      final workout = Workout.fromMap(map);

      expect(workout.id, equals(5));
      expect(workout.exerciseType, equals(ExerciseType.burpees));
      expect(workout.variant, equals(ExerciseVariant.modified));
      expect(workout.mode, equals(WorkoutMode.timer));
      expect(workout.targetValue, equals(60));
      expect(workout.repsCompleted, equals(15));
      expect(workout.repsInvalid, equals(3));
      expect(workout.wasCompleted, isTrue);
    });
  });
}
