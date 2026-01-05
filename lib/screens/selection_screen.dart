import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout.dart';
import '../providers/workout_manager.dart';
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

  void _startWorkout() {
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
