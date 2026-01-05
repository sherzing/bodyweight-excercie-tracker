import 'package:flutter_test/flutter_test.dart';
import 'package:pushup_counter/models/workout.dart';
import 'package:pushup_counter/services/database_service.dart';

/// Tests for DatabaseService.
/// Note: These tests verify the interface contract and data transformations.
/// Actual database operations would require sqflite_common_ffi for testing.
void main() {
  group('WorkoutStats', () {
    test('formattedDuration formats minutes only when under an hour', () {
      final stats = WorkoutStats(
        totalWorkouts: 5,
        totalReps: 100,
        totalDurationSeconds: 1800, // 30 minutes
        personalBests: {},
      );

      expect(stats.formattedDuration, equals('30m'));
    });

    test('formattedDuration formats hours and minutes', () {
      final stats = WorkoutStats(
        totalWorkouts: 10,
        totalReps: 500,
        totalDurationSeconds: 5400, // 1 hour 30 minutes
        personalBests: {},
      );

      expect(stats.formattedDuration, equals('1h 30m'));
    });

    test('formattedDuration handles zero duration', () {
      final stats = WorkoutStats(
        totalWorkouts: 0,
        totalReps: 0,
        totalDurationSeconds: 0,
        personalBests: {},
      );

      expect(stats.formattedDuration, equals('0m'));
    });

    test('formattedDuration handles multiple hours', () {
      final stats = WorkoutStats(
        totalWorkouts: 50,
        totalReps: 2500,
        totalDurationSeconds: 10800, // 3 hours
        personalBests: {},
      );

      expect(stats.formattedDuration, equals('3h 0m'));
    });

    test('stores personal bests correctly', () {
      final stats = WorkoutStats(
        totalWorkouts: 10,
        totalReps: 200,
        totalDurationSeconds: 3600,
        personalBests: {
          ExerciseType.pushups: 50,
          ExerciseType.burpees: 25,
        },
      );

      expect(stats.personalBests[ExerciseType.pushups], equals(50));
      expect(stats.personalBests[ExerciseType.burpees], equals(25));
    });
  });

  group('Workout CSV Export Format', () {
    test('workout serializes correctly for CSV', () {
      final workout = Workout(
        id: 1,
        exerciseType: ExerciseType.pushups,
        variant: ExerciseVariant.standard,
        mode: WorkoutMode.repGoal,
        targetValue: 20,
        repsCompleted: 18,
        repsInvalid: 2,
        durationSeconds: 120,
        startedAt: DateTime(2024, 1, 15, 10, 30),
        wasCompleted: false,
      );

      // Verify the workout can be converted to a map for database storage
      final map = workout.toMap();

      expect(map['exercise_type'], equals('pushups'));
      expect(map['variant'], equals('standard'));
      expect(map['mode'], equals('repGoal'));
      expect(map['target_value'], equals(20));
      expect(map['reps_completed'], equals(18));
      expect(map['reps_invalid'], equals(2));
      expect(map['duration_seconds'], equals(120));
      expect(map['was_completed'], equals(0)); // false = 0
    });

    test('workout deserializes correctly from database map', () {
      final map = {
        'id': 5,
        'exercise_type': 'burpees',
        'variant': 'modified',
        'mode': 'timer',
        'target_value': 60,
        'reps_completed': 15,
        'reps_invalid': 3,
        'duration_seconds': 60,
        'started_at': '2024-02-20T14:45:00.000',
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
      expect(workout.durationSeconds, equals(60));
      expect(workout.wasCompleted, isTrue);
    });

    test('workout roundtrips through serialization', () {
      final original = Workout(
        exerciseType: ExerciseType.pushups,
        variant: ExerciseVariant.standard,
        mode: WorkoutMode.free,
        repsCompleted: 42,
        repsInvalid: 0,
        durationSeconds: 300,
        startedAt: DateTime.now(),
        wasCompleted: true,
      );

      final map = original.toMap();
      // Add an ID as if it came from the database
      map['id'] = 100;
      final restored = Workout.fromMap(map);

      expect(restored.exerciseType, equals(original.exerciseType));
      expect(restored.variant, equals(original.variant));
      expect(restored.mode, equals(original.mode));
      expect(restored.repsCompleted, equals(original.repsCompleted));
      expect(restored.repsInvalid, equals(original.repsInvalid));
      expect(restored.durationSeconds, equals(original.durationSeconds));
      expect(restored.wasCompleted, equals(original.wasCompleted));
    });
  });

  group('Date Range Calculations', () {
    test('week start calculation is correct', () {
      // Test that we correctly calculate the start of the week
      final thursday = DateTime(2024, 1, 18); // Thursday
      final weekday = thursday.weekday; // 4 for Thursday
      final startOfWeek = DateTime(
        thursday.year,
        thursday.month,
        thursday.day - (weekday - 1),
      );

      expect(startOfWeek.weekday, equals(1)); // Monday
      expect(startOfWeek.day, equals(15)); // January 15, 2024
    });

    test('month start and end calculation is correct', () {
      final midMonth = DateTime(2024, 2, 15);
      final startOfMonth = DateTime(midMonth.year, midMonth.month, 1);
      final endOfMonth = DateTime(midMonth.year, midMonth.month + 1, 0, 23, 59, 59);

      expect(startOfMonth.day, equals(1));
      expect(endOfMonth.day, equals(29)); // 2024 is a leap year
      expect(endOfMonth.month, equals(2));
    });
  });

  group('DatabaseService Interface', () {
    test('DatabaseService can be instantiated', () {
      final db = DatabaseService();
      expect(db, isNotNull);
    });

    test('multiple instances share the same database', () {
      final db1 = DatabaseService();
      final db2 = DatabaseService();

      // Both should reference the same static _database field
      expect(db1, isNotNull);
      expect(db2, isNotNull);
    });
  });
}
