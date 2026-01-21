import 'database_service.dart';
import '../models/workout.dart';

/// Service for gamification features: streaks, milestones, personal bests, etc.
class GamificationService {
  final DatabaseService _db;

  GamificationService(this._db);

  // ==================== Preference Keys ====================

  static const String prefGamificationEnabled = 'gamification_enabled';
  static const String prefShowStreak = 'show_streak_counter';
  static const String prefShowBeatYesterday = 'show_yesterday_comparison';
  static const String prefShowMilestones = 'show_milestone_notifications';
  static const String prefLastWeeklyDismissed = 'last_weekly_dismissed';
  static const String prefLastMilestoneDismissed = 'last_milestone_dismissed';

  // ==================== Streak Calculation ====================

  /// Calculate the current workout streak (consecutive days with workouts).
  /// Returns 0 if no streak, otherwise the number of consecutive days.
  Future<StreakInfo> getCurrentStreak() async {
    final workouts = await _db.getAllWorkouts();
    if (workouts.isEmpty) {
      return StreakInfo(currentStreak: 0, longestStreak: 0, graceDayAvailable: false);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Group workouts by date
    final workoutDates = <DateTime>{};
    for (final workout in workouts) {
      final date = DateTime(
        workout.startedAt.year,
        workout.startedAt.month,
        workout.startedAt.day,
      );
      workoutDates.add(date);
    }

    // Sort dates descending
    final sortedDates = workoutDates.toList()..sort((a, b) => b.compareTo(a));

    // Calculate current streak
    int currentStreak = 0;
    int consecutiveDays = 0;
    DateTime checkDate = today;

    // Check if we worked out today
    bool workedOutToday = workoutDates.contains(today);
    if (!workedOutToday) {
      // Check yesterday - if no workout yesterday either, streak is broken
      final yesterday = today.subtract(const Duration(days: 1));
      if (!workoutDates.contains(yesterday)) {
        // No workout today or yesterday - streak is 0
        currentStreak = 0;
      } else {
        // Worked out yesterday but not today - count from yesterday
        checkDate = yesterday;
      }
    }

    if (currentStreak == 0 && (workedOutToday || workoutDates.contains(today.subtract(const Duration(days: 1))))) {
      // Count consecutive days
      while (workoutDates.contains(checkDate)) {
        consecutiveDays++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
      currentStreak = consecutiveDays;
    }

    // Calculate longest streak ever
    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? lastDate;

    for (final date in sortedDates.reversed) {
      if (lastDate == null) {
        tempStreak = 1;
      } else {
        final diff = date.difference(lastDate).inDays;
        if (diff == 1) {
          tempStreak++;
        } else {
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
          tempStreak = 1;
        }
      }
      lastDate = date;
    }
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }

    // Grace day available after 7 consecutive days
    bool graceDayAvailable = currentStreak >= 7 && !workedOutToday;

    return StreakInfo(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      graceDayAvailable: graceDayAvailable,
    );
  }

  // ==================== Smart Rest Day Suggestions ====================

  /// Check if a rest day is recommended based on recent workout volume.
  /// Returns true if user has done 70+ reps on 2+ consecutive days.
  Future<RestDaySuggestion> getRestDaySuggestion() async {
    final now = DateTime.now();
    final threeDaysAgo = now.subtract(const Duration(days: 3));

    final recentWorkouts = await _db.getWorkoutsByDateRange(threeDaysAgo, now);
    if (recentWorkouts.isEmpty) {
      return RestDaySuggestion(suggested: false, reason: null);
    }

    // Group by date and sum reps
    final dailyReps = <DateTime, int>{};
    for (final workout in recentWorkouts) {
      final date = DateTime(
        workout.startedAt.year,
        workout.startedAt.month,
        workout.startedAt.day,
      );
      dailyReps[date] = (dailyReps[date] ?? 0) + workout.repsCompleted;
    }

    // Check for consecutive high-volume days
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    final todayReps = dailyReps[today] ?? 0;
    final yesterdayReps = dailyReps[yesterday] ?? 0;
    final twoDaysAgoReps = dailyReps[twoDaysAgo] ?? 0;

    const highVolumeThreshold = 70;

    // Check for 2+ consecutive high-volume days
    if (yesterdayReps >= highVolumeThreshold && twoDaysAgoReps >= highVolumeThreshold) {
      return RestDaySuggestion(
        suggested: true,
        reason: 'You\'ve done ${yesterdayReps + twoDaysAgoReps} reps over 2 days',
      );
    }

    if (todayReps >= highVolumeThreshold && yesterdayReps >= highVolumeThreshold) {
      return RestDaySuggestion(
        suggested: true,
        reason: 'You\'ve done ${todayReps + yesterdayReps} reps over 2 days',
      );
    }

    return RestDaySuggestion(suggested: false, reason: null);
  }

  // ==================== Beat Yesterday ====================

  /// Get yesterday's rep count for a specific exercise type.
  /// Returns null if no workout yesterday.
  Future<int?> getYesterdayReps(ExerciseType exerciseType) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayEnd = yesterday.add(const Duration(days: 1));

    final workouts = await _db.getWorkoutsByDateRange(yesterday, yesterdayEnd);
    final filtered = workouts.where((w) => w.exerciseType == exerciseType);

    if (filtered.isEmpty) return null;

    return filtered.fold<int>(0, (sum, w) => sum + w.repsCompleted);
  }

  // ==================== Milestones ====================

  /// Milestone thresholds for total reps
  static const List<int> repMilestones = [10, 100, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000];

  /// Milestone thresholds for total workouts
  static const List<int> workoutMilestones = [10, 25, 50, 100, 250, 500, 1000];

  /// Milestone thresholds for total time (in seconds)
  static const List<int> timeMilestones = [
    3600,      // 1 hour
    18000,     // 5 hours
    36000,     // 10 hours
    86400,     // 24 hours
    259200,    // 72 hours (3 days)
    604800,    // 168 hours (1 week)
  ];

  /// Check for any new milestones and record them.
  /// Returns list of newly achieved milestones.
  Future<List<MilestoneInfo>> checkAndRecordMilestones() async {
    final stats = await _db.getStats();
    final newMilestones = <MilestoneInfo>[];

    // Check rep milestones
    for (final threshold in repMilestones) {
      if (stats.totalReps >= threshold) {
        final id = 'milestone_reps_$threshold';
        if (!await _db.hasAchievement(id)) {
          await _db.recordAchievement(
            id: id,
            type: 'milestone',
            value: threshold,
          );
          newMilestones.add(MilestoneInfo(
            id: id,
            type: MilestoneType.reps,
            threshold: threshold,
            description: '$threshold total reps',
          ));
        }
      }
    }

    // Check workout milestones
    for (final threshold in workoutMilestones) {
      if (stats.totalWorkouts >= threshold) {
        final id = 'milestone_workouts_$threshold';
        if (!await _db.hasAchievement(id)) {
          await _db.recordAchievement(
            id: id,
            type: 'milestone',
            value: threshold,
          );
          newMilestones.add(MilestoneInfo(
            id: id,
            type: MilestoneType.workouts,
            threshold: threshold,
            description: '$threshold workouts completed',
          ));
        }
      }
    }

    // Check time milestones
    for (final threshold in timeMilestones) {
      if (stats.totalDurationSeconds >= threshold) {
        final id = 'milestone_time_$threshold';
        if (!await _db.hasAchievement(id)) {
          await _db.recordAchievement(
            id: id,
            type: 'milestone',
            value: threshold,
          );
          final hours = threshold ~/ 3600;
          newMilestones.add(MilestoneInfo(
            id: id,
            type: MilestoneType.time,
            threshold: threshold,
            description: '$hours hours of exercise',
          ));
        }
      }
    }

    return newMilestones;
  }

  /// Get all milestone progress
  Future<MilestoneProgress> getMilestoneProgress() async {
    final stats = await _db.getStats();
    final achievements = await _db.getAchievementsByType('milestone');
    final earnedIds = achievements.map((a) => a.id).toSet();

    int totalMilestones = repMilestones.length + workoutMilestones.length + timeMilestones.length;
    int earnedCount = earnedIds.length;

    // Find next milestones
    int? nextRepMilestone;
    for (final m in repMilestones) {
      if (stats.totalReps < m) {
        nextRepMilestone = m;
        break;
      }
    }

    int? nextWorkoutMilestone;
    for (final m in workoutMilestones) {
      if (stats.totalWorkouts < m) {
        nextWorkoutMilestone = m;
        break;
      }
    }

    return MilestoneProgress(
      totalMilestones: totalMilestones,
      earnedCount: earnedCount,
      nextRepMilestone: nextRepMilestone,
      currentReps: stats.totalReps,
      nextWorkoutMilestone: nextWorkoutMilestone,
      currentWorkouts: stats.totalWorkouts,
    );
  }

  // ==================== Weekly Statistics ====================

  /// Get statistics for last week (Monday to Sunday)
  Future<WeeklySummary> getLastWeekSummary() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Find last Monday
    final daysSinceMonday = (today.weekday - 1) % 7;
    final thisMonday = today.subtract(Duration(days: daysSinceMonday));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final lastSunday = thisMonday.subtract(const Duration(days: 1));

    // Get last week stats
    final lastWeekStats = await _db.getStatsByDateRange(lastMonday, lastSunday.add(const Duration(days: 1)));

    // Get the week before for comparison
    final twoWeeksAgoMonday = lastMonday.subtract(const Duration(days: 7));
    final twoWeeksAgoSunday = lastMonday.subtract(const Duration(days: 1));
    final previousWeekStats = await _db.getStatsByDateRange(twoWeeksAgoMonday, twoWeeksAgoSunday.add(const Duration(days: 1)));

    // Count active days
    final lastWeekWorkouts = await _db.getWorkoutsByDateRange(lastMonday, lastSunday.add(const Duration(days: 1)));
    final activeDays = <DateTime>{};
    for (final w in lastWeekWorkouts) {
      activeDays.add(DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day));
    }

    // Calculate week-over-week change
    int? repChange;
    if (previousWeekStats.totalReps > 0) {
      repChange = lastWeekStats.totalReps - previousWeekStats.totalReps;
    }

    return WeeklySummary(
      weekStartDate: lastMonday,
      daysActive: activeDays.length,
      totalReps: lastWeekStats.totalReps,
      totalWorkouts: lastWeekStats.totalWorkouts,
      repChangeFromPreviousWeek: repChange,
    );
  }

  // ==================== Preferences ====================

  Future<bool> isGamificationEnabled() async {
    return _db.getBoolPreference(prefGamificationEnabled, defaultValue: true);
  }

  Future<bool> shouldShowStreak() async {
    return _db.getBoolPreference(prefShowStreak, defaultValue: true);
  }

  Future<bool> shouldShowBeatYesterday() async {
    return _db.getBoolPreference(prefShowBeatYesterday, defaultValue: true);
  }

  Future<bool> shouldShowMilestones() async {
    return _db.getBoolPreference(prefShowMilestones, defaultValue: true);
  }

  Future<void> setGamificationEnabled(bool enabled) async {
    await _db.setBoolPreference(prefGamificationEnabled, enabled);
  }

  Future<void> setShowStreak(bool show) async {
    await _db.setBoolPreference(prefShowStreak, show);
  }

  Future<void> setShowBeatYesterday(bool show) async {
    await _db.setBoolPreference(prefShowBeatYesterday, show);
  }

  Future<void> setShowMilestones(bool show) async {
    await _db.setBoolPreference(prefShowMilestones, show);
  }

  /// Mark weekly summary as dismissed for this week
  Future<void> dismissWeeklySummary() async {
    final now = DateTime.now();
    await _db.setPreference(prefLastWeeklyDismissed, now.toIso8601String());
  }

  /// Check if weekly summary should be shown (Monday and not yet dismissed this week)
  Future<bool> shouldShowWeeklySummary() async {
    final now = DateTime.now();
    if (now.weekday != DateTime.monday) return false;

    final lastDismissed = await _db.getPreference(prefLastWeeklyDismissed);
    if (lastDismissed == null) return true;

    final dismissedDate = DateTime.parse(lastDismissed);
    final today = DateTime(now.year, now.month, now.day);
    final dismissedDay = DateTime(dismissedDate.year, dismissedDate.month, dismissedDate.day);

    // Show if last dismissed was before today
    return dismissedDay.isBefore(today);
  }
}

// ==================== Data Classes ====================

class StreakInfo {
  final int currentStreak;
  final int longestStreak;
  final bool graceDayAvailable;

  StreakInfo({
    required this.currentStreak,
    required this.longestStreak,
    required this.graceDayAvailable,
  });
}

class RestDaySuggestion {
  final bool suggested;
  final String? reason;

  RestDaySuggestion({required this.suggested, this.reason});
}

enum MilestoneType { reps, workouts, time }

class MilestoneInfo {
  final String id;
  final MilestoneType type;
  final int threshold;
  final String description;

  MilestoneInfo({
    required this.id,
    required this.type,
    required this.threshold,
    required this.description,
  });
}

class MilestoneProgress {
  final int totalMilestones;
  final int earnedCount;
  final int? nextRepMilestone;
  final int currentReps;
  final int? nextWorkoutMilestone;
  final int currentWorkouts;

  MilestoneProgress({
    required this.totalMilestones,
    required this.earnedCount,
    this.nextRepMilestone,
    required this.currentReps,
    this.nextWorkoutMilestone,
    required this.currentWorkouts,
  });
}

class WeeklySummary {
  final DateTime weekStartDate;
  final int daysActive;
  final int totalReps;
  final int totalWorkouts;
  final int? repChangeFromPreviousWeek;

  WeeklySummary({
    required this.weekStartDate,
    required this.daysActive,
    required this.totalReps,
    required this.totalWorkouts,
    this.repChangeFromPreviousWeek,
  });

  String get formattedChange {
    if (repChangeFromPreviousWeek == null) return '';
    if (repChangeFromPreviousWeek! > 0) return '+$repChangeFromPreviousWeek reps';
    if (repChangeFromPreviousWeek! < 0) return '$repChangeFromPreviousWeek reps';
    return 'same as last week';
  }
}
