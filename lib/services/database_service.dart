import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';

/// Service for persisting workout data using SQLite.
class DatabaseService {
  static Database? _database;
  static const String _tableName = 'workouts';
  static const int _dbVersion = 1;

  /// Get the database instance, initializing if needed
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/pushup_counter.db';

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_type TEXT NOT NULL,
        variant TEXT NOT NULL,
        mode TEXT NOT NULL,
        target_value INTEGER,
        reps_completed INTEGER NOT NULL,
        reps_invalid INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        was_completed INTEGER NOT NULL
      )
    ''');

    // Create index for date-based queries
    await db.execute('''
      CREATE INDEX idx_started_at ON $_tableName (started_at)
    ''');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  /// Insert a new workout record
  Future<int> insertWorkout(Workout workout) async {
    final db = await database;
    return await db.insert(_tableName, workout.toMap());
  }

  /// Get all workouts, ordered by date descending
  Future<List<Workout>> getAllWorkouts() async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'started_at DESC',
    );
    return maps.map((map) => Workout.fromMap(map)).toList();
  }

  /// Get workouts within a date range
  Future<List<Workout>> getWorkoutsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'started_at >= ? AND started_at <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'started_at DESC',
    );
    return maps.map((map) => Workout.fromMap(map)).toList();
  }

  /// Get workouts for a specific exercise type
  Future<List<Workout>> getWorkoutsByExercise(ExerciseType type) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'exercise_type = ?',
      whereArgs: [type.name],
      orderBy: 'started_at DESC',
    );
    return maps.map((map) => Workout.fromMap(map)).toList();
  }

  /// Get workout statistics
  Future<WorkoutStats> getStats() async {
    final db = await database;

    // Total workouts
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    final totalWorkouts = Sqflite.firstIntValue(countResult) ?? 0;

    // Total reps
    final repsResult = await db.rawQuery(
      'SELECT SUM(reps_completed) as total FROM $_tableName',
    );
    final totalReps = Sqflite.firstIntValue(repsResult) ?? 0;

    // Total duration
    final durationResult = await db.rawQuery(
      'SELECT SUM(duration_seconds) as total FROM $_tableName',
    );
    final totalSeconds = Sqflite.firstIntValue(durationResult) ?? 0;

    // Personal bests by exercise type
    final personalBests = <ExerciseType, int>{};
    for (final type in ExerciseType.values) {
      final pbResult = await db.rawQuery(
        'SELECT MAX(reps_completed) as max FROM $_tableName WHERE exercise_type = ?',
        [type.name],
      );
      final pb = Sqflite.firstIntValue(pbResult);
      if (pb != null && pb > 0) {
        personalBests[type] = pb;
      }
    }

    return WorkoutStats(
      totalWorkouts: totalWorkouts,
      totalReps: totalReps,
      totalDurationSeconds: totalSeconds,
      personalBests: personalBests,
    );
  }

  /// Get the most recent workout
  Future<Workout?> getLastWorkout() async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Workout.fromMap(maps.first);
  }

  /// Delete a workout by ID
  Future<int> deleteWorkout(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all workouts (use with caution)
  Future<int> deleteAllWorkouts() async {
    final db = await database;
    return await db.delete(_tableName);
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

/// Statistics about workouts
class WorkoutStats {
  final int totalWorkouts;
  final int totalReps;
  final int totalDurationSeconds;
  final Map<ExerciseType, int> personalBests;

  WorkoutStats({
    required this.totalWorkouts,
    required this.totalReps,
    required this.totalDurationSeconds,
    required this.personalBests,
  });

  /// Get formatted total duration
  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
