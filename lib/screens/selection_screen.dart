import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout.dart';
import '../providers/workout_manager.dart';
import '../services/permission_service.dart';
import '../services/database_service.dart';
import '../services/gamification_service.dart';
import 'tracking_screen.dart';

class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  ExerciseType _selectedExercise = ExerciseType.pushups;
  ExerciseVariant _selectedVariant = ExerciseVariant.standard;
  WorkoutMode _selectedMode = WorkoutMode.free;
  int _targetValue = 10;

  late final GamificationService _gamification;
  StreakInfo? _streakInfo;
  RestDaySuggestion? _restSuggestion;
  bool _showStreak = true;
  bool _gamificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _gamification = GamificationService(DatabaseService());
    _loadGamificationData();
  }

  Future<void> _loadGamificationData() async {
    final enabled = await _gamification.isGamificationEnabled();
    final showStreak = await _gamification.shouldShowStreak();
    if (!enabled) {
      setState(() {
        _gamificationEnabled = false;
      });
      return;
    }

    final streakInfo = await _gamification.getCurrentStreak();
    final restSuggestion = await _gamification.getRestDaySuggestion();

    if (mounted) {
      setState(() {
        _gamificationEnabled = enabled;
        _showStreak = showStreak;
        _streakInfo = streakInfo;
        _restSuggestion = restSuggestion;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Setup'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_gamificationEnabled && _showStreak && _streakInfo != null && _streakInfo!.currentStreak >= 2)
                _buildStreakBadge(),
              if (_gamificationEnabled && _restSuggestion != null && _restSuggestion!.suggested)
                _buildRestSuggestion(),
              _buildSectionTitle('Exercise'),
              const SizedBox(height: 12),
              _buildExerciseSelector(),
              const SizedBox(height: 24),
              if (_selectedExercise == ExerciseType.burpees) ...[
                _buildSectionTitle('Variant'),
                const SizedBox(height: 12),
                _buildVariantSelector(),
                const SizedBox(height: 24),
              ],
              _buildSectionTitle('Mode'),
              const SizedBox(height: 12),
              _buildModeSelector(),
              const SizedBox(height: 24),
              if (_selectedMode != WorkoutMode.free) ...[
                _buildSectionTitle(_selectedMode == WorkoutMode.timer
                    ? 'Duration (seconds)'
                    : 'Target Reps'),
                const SizedBox(height: 12),
                _buildTargetValueSelector(),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 32),
              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildStreakBadge() {
    final streak = _streakInfo!.currentStreak;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department,
            color: Colors.orange.shade600,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            '$streak day streak',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          if (_streakInfo!.graceDayAvailable) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Rest day available - your streak is protected',
              child: Icon(
                Icons.shield_outlined,
                color: Colors.green.shade600,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestSuggestion() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.bedtime_outlined, color: Colors.blue.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Recovery day suggested',
                style: TextStyle(color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSelector() {
    return SegmentedButton<ExerciseType>(
      segments: ExerciseType.values.map((type) {
        return ButtonSegment(
          value: type,
          label: Text(type.displayName),
          icon: Icon(type == ExerciseType.pushups
              ? Icons.fitness_center
              : Icons.directions_run),
        );
      }).toList(),
      selected: {_selectedExercise},
      onSelectionChanged: (selection) {
        setState(() {
          _selectedExercise = selection.first;
        });
      },
    );
  }

  Widget _buildVariantSelector() {
    return SegmentedButton<ExerciseVariant>(
      segments: ExerciseVariant.values.map((variant) {
        return ButtonSegment(
          value: variant,
          label: Text(variant.displayName),
        );
      }).toList(),
      selected: {_selectedVariant},
      onSelectionChanged: (selection) {
        setState(() {
          _selectedVariant = selection.first;
        });
      },
    );
  }

  Widget _buildModeSelector() {
    return Column(
      children: WorkoutMode.values.map((mode) {
        return RadioListTile<WorkoutMode>(
          title: Text(mode.displayName),
          subtitle: Text(mode.description),
          value: mode,
          groupValue: _selectedMode,
          onChanged: (value) {
            setState(() {
              _selectedMode = value!;
              // Set default target values
              if (_selectedMode == WorkoutMode.timer) {
                _targetValue = 60; // 60 seconds default
              } else if (_selectedMode == WorkoutMode.repGoal) {
                _targetValue = 10; // 10 reps default
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildTargetValueSelector() {
    final isTimer = _selectedMode == WorkoutMode.timer;
    final presets = isTimer ? [30, 60, 90, 120, 180] : [5, 10, 15, 20, 25, 50];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((value) {
            final isSelected = _targetValue == value;
            final label = isTimer ? '${value}s' : '$value';
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _targetValue = value;
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              onPressed: _targetValue > 1
                  ? () => setState(() => _targetValue--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: Text(
                isTimer ? '$_targetValue seconds' : '$_targetValue reps',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _targetValue++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return FilledButton.icon(
      onPressed: _startWorkout,
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start Workout'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18),
      ),
    );
  }

  Future<void> _startWorkout() async {
    final permissionService = PermissionService();

    // Check and request camera permission
    final hasPermission = await permissionService.requestCameraPermission(context);

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to track exercises'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Configure the workout manager
    final workoutManager = context.read<WorkoutManager>();
    workoutManager.configure(
      exerciseType: _selectedExercise,
      variant: _selectedVariant,
      mode: _selectedMode,
      targetValue: _selectedMode != WorkoutMode.free ? _targetValue : 0,
    );

    // Navigate to tracking screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TrackingScreen(),
      ),
    );
  }
}
