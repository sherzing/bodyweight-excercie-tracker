import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';

/// Service for persisting workout data using SQLite.
class DatabaseService {
  static Database? _database;
  static const String _tableName = 'workouts';
  static const String _preferencesTable = 'user_preferences';
  static const String _achievementsTable = 'achievements';
  static const int _dbVersion = 2;

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

    // Create gamification tables
    await _createGamificationTables(db);
  }

  Future<void> _createGamificationTables(Database db) async {
    // User preferences for gamification settings
    await db.execute('''
      CREATE TABLE $_preferencesTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Achievements tracking (milestones, personal bests, streaks)
    await db.execute('''
      CREATE TABLE $_achievementsTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        achieved_at TEXT NOT NULL,
        value INTEGER NOT NULL
      )
    ''');

    // Create index for achievement type queries
    await db.execute('''
      CREATE INDEX idx_achievement_type ON $_achievementsTable (type)
    ''');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add gamification tables (user_preferences and achievements)
      await _createGamificationTables(db);
    }
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

  // ==================== User Preferences ====================

  /// Get a user preference value by key
  Future<String?> getPreference(String key) async {
    final db = await database;
    final maps = await db.query(
      _preferencesTable,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  /// Get a boolean preference (defaults to true if not set)
  Future<bool> getBoolPreference(String key, {bool defaultValue = true}) async {
    final value = await getPreference(key);
    if (value == null) return defaultValue;
    return value == 'true';
  }

  /// Set a user preference value
  Future<void> setPreference(String key, String value) async {
    final db = await database;
    await db.insert(
      _preferencesTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Set a boolean preference
  Future<void> setBoolPreference(String key, bool value) async {
    await setPreference(key, value.toString());
  }

  /// Delete a user preference
  Future<void> deletePreference(String key) async {
    final db = await database;
    await db.delete(
      _preferencesTable,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // ==================== Achievements ====================

  /// Record an achievement
  Future<void> recordAchievement({
    required String id,
    required String type,
    required int value,
  }) async {
    final db = await database;
    await db.insert(
      _achievementsTable,
      {
        'id': id,
        'type': type,
        'achieved_at': DateTime.now().toIso8601String(),
        'value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Don't overwrite existing
    );
  }

  /// Check if an achievement has been earned
  Future<bool> hasAchievement(String id) async {
    final db = await database;
    final maps = await db.query(
      _achievementsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty;
  }

  /// Get all achievements of a specific type
  Future<List<Achievement>> getAchievementsByType(String type) async {
    final db = await database;
    final maps = await db.query(
      _achievementsTable,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'achieved_at DESC',
    );
    return maps.map((m) => Achievement.fromMap(m)).toList();
  }

  /// Get all achievements
  Future<List<Achievement>> getAllAchievements() async {
    final db = await database;
    final maps = await db.query(
      _achievementsTable,
      orderBy: 'achieved_at DESC',
    );
    return maps.map((m) => Achievement.fromMap(m)).toList();
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Get statistics for a specific date range
  Future<WorkoutStats> getStatsByDateRange(DateTime start, DateTime end) async {
    final db = await database;

    // Total workouts in range
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE started_at >= ? AND started_at <= ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final totalWorkouts = Sqflite.firstIntValue(countResult) ?? 0;

    // Total reps in range
    final repsResult = await db.rawQuery(
      'SELECT SUM(reps_completed) as total FROM $_tableName WHERE started_at >= ? AND started_at <= ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final totalReps = Sqflite.firstIntValue(repsResult) ?? 0;

    // Total duration in range
    final durationResult = await db.rawQuery(
      'SELECT SUM(duration_seconds) as total FROM $_tableName WHERE started_at >= ? AND started_at <= ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final totalSeconds = Sqflite.firstIntValue(durationResult) ?? 0;

    // Personal bests in range by exercise type
    final personalBests = <ExerciseType, int>{};
    for (final type in ExerciseType.values) {
      final pbResult = await db.rawQuery(
        'SELECT MAX(reps_completed) as max FROM $_tableName WHERE exercise_type = ? AND started_at >= ? AND started_at <= ?',
        [type.name, start.toIso8601String(), end.toIso8601String()],
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

  /// Get this week's statistics (Monday to Sunday)
  Future<WorkoutStats> getThisWeekStats() async {
    final now = DateTime.now();
    final weekday = now.weekday;
    final startOfWeek = DateTime(now.year, now.month, now.day - (weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return getStatsByDateRange(startOfWeek, endOfWeek);
  }

  /// Get this month's statistics
  Future<WorkoutStats> getThisMonthStats() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return getStatsByDateRange(startOfMonth, endOfMonth);
  }

  /// Export all workouts as CSV string
  Future<String> exportToCsv() async {
    final workouts = await getAllWorkouts();

    final buffer = StringBuffer();

    // CSV header
    buffer.writeln(
      'Date,Time,Exercise,Variant,Mode,Target,Reps Completed,Invalid Reps,Duration (s),Completed',
    );

    // CSV rows
    for (final workout in workouts) {
      final date = '${workout.startedAt.year}-${workout.startedAt.month.toString().padLeft(2, '0')}-${workout.startedAt.day.toString().padLeft(2, '0')}';
      final time = '${workout.startedAt.hour.toString().padLeft(2, '0')}:${workout.startedAt.minute.toString().padLeft(2, '0')}';

      buffer.writeln([
        date,
        time,
        workout.exerciseType.name,
        workout.variant.name,
        workout.mode.name,
        workout.targetValue ?? '',
        workout.repsCompleted,
        workout.repsInvalid,
        workout.durationSeconds,
        workout.wasCompleted ? 'Yes' : 'No',
      ].join(','));
    }

    return buffer.toString();
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

/// Represents an earned achievement
class Achievement {
  final String id;
  final String type;
  final DateTime achievedAt;
  final int value;

  Achievement({
    required this.id,
    required this.type,
    required this.achievedAt,
    required this.value,
  });

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as String,
      type: map['type'] as String,
      achievedAt: DateTime.parse(map['achieved_at'] as String),
      value: map['value'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'achieved_at': achievedAt.toIso8601String(),
      'value': value,
    };
  }
}
