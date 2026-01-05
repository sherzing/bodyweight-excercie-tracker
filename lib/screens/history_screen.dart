import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<Workout> _workouts = [];
  WorkoutStats? _stats;
  WorkoutStats? _weekStats;
  WorkoutStats? _monthStats;
  bool _isLoading = true;
  ExerciseType? _filterType;
  int _selectedStatsPeriod = 0; // 0 = All time, 1 = This Week, 2 = This Month

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final workouts = _filterType == null
          ? await _db.getAllWorkouts()
          : await _db.getWorkoutsByExercise(_filterType!);
      final stats = await _db.getStats();
      final weekStats = await _db.getThisWeekStats();
      final monthStats = await _db.getThisMonthStats();

      setState(() {
        _workouts = workouts;
        _stats = stats;
        _weekStats = weekStats;
        _monthStats = monthStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final csv = await _db.exportToCsv();
      await Share.share(
        csv,
        subject: 'Workout History Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Data',
            onPressed: _workouts.isEmpty ? null : _exportData,
          ),
          PopupMenuButton<ExerciseType?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) {
              setState(() => _filterType = type);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Exercises'),
              ),
              ...ExerciseType.values.map((type) => PopupMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  )),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  if (_stats != null) _buildStatsHeader(),
                  if (_workouts.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('No workouts yet. Start exercising!'),
                      ),
                    )
                  else
                    _buildWorkoutList(),
                ],
              ),
            ),
    );
  }

  WorkoutStats? get _currentStats {
    switch (_selectedStatsPeriod) {
      case 1:
        return _weekStats;
      case 2:
        return _monthStats;
      default:
        return _stats;
    }
  }

  String get _currentStatsLabel {
    switch (_selectedStatsPeriod) {
      case 1:
        return 'This Week';
      case 2:
        return 'This Month';
      default:
        return 'All Time';
    }
  }

  Widget _buildStatsHeader() {
    final stats = _currentStats;
    if (stats == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('All')),
                    ButtonSegment(value: 1, label: Text('Week')),
                    ButtonSegment(value: 2, label: Text('Month')),
                  ],
                  selected: {_selectedStatsPeriod},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedStatsPeriod = selection.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Workouts',
                  '${stats.totalWorkouts}',
                  Icons.fitness_center,
                ),
                _buildStatItem(
                  'Total Reps',
                  '${stats.totalReps}',
                  Icons.repeat,
                ),
                _buildStatItem(
                  'Time',
                  stats.formattedDuration,
                  Icons.timer,
                ),
              ],
            ),
            if (stats.personalBests.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Best in $_currentStatsLabel',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats.personalBests.entries.map((entry) {
                  return Chip(
                    avatar: const Icon(Icons.emoji_events, size: 18),
                    label: Text('${entry.key.displayName}: ${entry.value}'),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildWorkoutList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final workout = _workouts[index];
          return _buildWorkoutCard(workout);
        },
        childCount: _workouts.length,
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: workout.wasCompleted
              ? Colors.green.withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          child: Icon(
            workout.exerciseType == ExerciseType.pushups
                ? Icons.fitness_center
                : Icons.directions_run,
            color: workout.wasCompleted ? Colors.green : Colors.orange,
          ),
        ),
        title: Row(
          children: [
            Text(workout.exerciseType.displayName),
            if (workout.variant != ExerciseVariant.standard)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text(
                    workout.variant.displayName,
                    style: const TextStyle(fontSize: 10),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${dateFormat.format(workout.startedAt)} at ${timeFormat.format(workout.startedAt)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${workout.repsCompleted} reps',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              _formatDuration(workout.durationSeconds),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        onTap: () => _showWorkoutDetails(workout),
      ),
    );
  }

  void _showWorkoutDetails(Workout workout) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${workout.exerciseType.displayName} Workout',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Mode', workout.mode.displayName),
            if (workout.targetValue != null)
              _buildDetailRow(
                'Target',
                workout.mode == WorkoutMode.timer
                    ? '${workout.targetValue}s'
                    : '${workout.targetValue} reps',
              ),
            _buildDetailRow('Reps Completed', '${workout.repsCompleted}'),
            if (workout.repsInvalid > 0)
              _buildDetailRow('Invalid Reps', '${workout.repsInvalid}'),
            _buildDetailRow('Duration', _formatDuration(workout.durationSeconds)),
            _buildDetailRow(
              'Avg Rep Time',
              '${workout.averageRepTime.toStringAsFixed(1)}s',
            ),
            _buildDetailRow(
              'Success Rate',
              '${(workout.successRate * 100).toStringAsFixed(0)}%',
            ),
            _buildDetailRow(
              'Completed',
              workout.wasCompleted ? 'Yes' : 'No',
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deleteWorkout(workout);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWorkout(Workout workout) async {
    if (workout.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteWorkout(workout.id!);
      _loadData();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }
}
