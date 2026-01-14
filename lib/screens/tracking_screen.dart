import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import '../providers/workout_manager.dart';
import '../services/camera_service.dart';
import '../services/database_service.dart';
import '../services/feedback_service.dart';
import '../services/pose_detection_service.dart';
import '../services/training_data_service.dart';
import '../widgets/pose_painter.dart';
import '../widgets/rep_flash_overlay.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/debug_overlay.dart';
import '../widgets/guide_lines_overlay.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with WidgetsBindingObserver {
  static const String _debugModeKey = 'debug_overlay_visible';
  static const String _guideLinesKey = 'guide_lines_visible';

  final CameraService _cameraService = CameraService();
  final PoseDetectionService _poseService = PoseDetectionService();
  final DatabaseService _db = DatabaseService();
  final FeedbackService _feedback = FeedbackService();
  final TrainingDataService _trainingService = TrainingDataService();
  final GlobalKey<RepFlashOverlayState> _flashKey = GlobalKey();
  bool _isInitializing = true;
  String? _errorMessage;
  bool _workoutSaved = false;
  int _lastCountdown = 0;
  bool _debugMode = false; // Hidden by default, persisted via SharedPreferences
  bool _guideLinesVisible = true; // Visible by default to help new users
  String _lastCapturedStage = ''; // Track last stage to avoid duplicate captures

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockOrientation();
    _initializeServices();
  }

  /// Lock orientation to current orientation during workout
  void _lockOrientation() {
    final orientation = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    ).orientation;

    if (orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// Restore all orientations when workout ends
  Future<void> _unlockOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initializeServices() async {
    try {
      // Load preferences
      final prefs = await SharedPreferences.getInstance();
      _debugMode = prefs.getBool(_debugModeKey) ?? false;
      _guideLinesVisible = prefs.getBool(_guideLinesKey) ?? true;

      // Initialize pose detection
      _poseService.initialize();

      // Initialize training data service
      await _trainingService.initialize();

      // Initialize camera
      await _cameraService.initialize();

      // Set camera controller for training capture
      _trainingService.setCameraController(_cameraService.controller);

      // Set up frame processing pipeline
      _cameraService.onFrame = (inputImage) {
        _poseService.processImage(inputImage);
      };

      _poseService.onPoseDetected = (pose) {
        if (!mounted) return;
        final workoutManager = context.read<WorkoutManager>();
        final controller = _cameraService.controller;
        if (controller != null) {
          workoutManager.updatePose(
            pose,
            controller.value.previewSize?.width ?? 0,
            controller.value.previewSize?.height ?? 0,
          );
        }
      };

      // Start camera stream
      await _cameraService.startImageStream();

      setState(() {
        _isInitializing = false;
      });

      // Start workout after camera is ready
      if (mounted) {
        final workoutManager = context.read<WorkoutManager>();

        // Set up feedback callbacks
        workoutManager.onRepCompleted = () {
          _feedback.onRepCompleted();
          _flashKey.currentState?.flashValid();
        };
        workoutManager.onInvalidRep = () {
          _feedback.onInvalidRep();
          _flashKey.currentState?.flashInvalid();
        };
        workoutManager.onWorkoutCompleted = () {
          _feedback.onWorkoutCompleted();
          _trainingService.endSession();
        };

        // Start training session if enabled
        _trainingService.startSession(workoutManager.exerciseType.name);

        workoutManager.startWorkout();
      }
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final workoutManager = context.read<WorkoutManager>();

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Auto-pause on background
      if (workoutManager.state == WorkoutState.active) {
        workoutManager.pauseWorkout();
      }
      _cameraService.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      // Resume camera when app comes back
      _cameraService.startImageStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlockOrientation();
    _cameraService.dispose();
    _poseService.dispose();
    _trainingService.endSession();
    super.dispose();
  }

  /// Capture training data when stage changes to Up or Down
  void _captureTrainingDataIfNeeded(WorkoutManager workoutManager) {
    if (!_trainingService.isEnabled) return;
    if (workoutManager.state != WorkoutState.active) return;

    final currentStage = workoutManager.currentStage;

    // Only capture on Up or Down, and only once per stage
    if ((currentStage == 'Up' || currentStage == 'Down') &&
        currentStage != _lastCapturedStage) {
      _lastCapturedStage = currentStage;
      _trainingService.captureAtStage(
        stage: currentStage,
        angles: workoutManager.debugAngles,
      );
    } else if (currentStage != 'Up' && currentStage != 'Down') {
      // Reset when in transition stages
      _lastCapturedStage = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: RepFlashOverlay(
            key: _flashKey,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Camera Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<WorkoutManager>(
      builder: (context, workoutManager, child) {
        // Capture training data on stage changes
        _captureTrainingDataIfNeeded(workoutManager);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            _buildCameraPreview(),

            // Pose overlay
            _buildPoseOverlay(workoutManager),

            // Guide lines overlay (shows down position threshold)
            if (workoutManager.state == WorkoutState.active ||
                workoutManager.state == WorkoutState.paused)
              GuideLinesOverlay(
                pose: workoutManager.currentPose,
                imageSize: _cameraService.controller?.value.previewSize ?? Size.zero,
                currentStage: workoutManager.currentStage,
                workoutState: workoutManager.state,
                isVisible: _guideLinesVisible,
                isFrontCamera:
                    _cameraService.camera?.lensDirection == CameraLensDirection.front,
              ),

            // Countdown overlay
            if (workoutManager.state == WorkoutState.countdown)
              _buildCountdownOverlay(workoutManager),

            // Workout info overlay
            if (workoutManager.state == WorkoutState.active ||
                workoutManager.state == WorkoutState.paused)
              _buildWorkoutOverlay(workoutManager),

            // Completion overlay
            if (workoutManager.state == WorkoutState.completed)
              _buildCompletionOverlay(workoutManager),

            // Position feedback
            if (workoutManager.state == WorkoutState.active &&
                workoutManager.positionFeedback.message.isNotEmpty)
              _buildPositionFeedback(workoutManager),

            // Debug overlay (always mounted for animation, visibility controlled by isExpanded)
            DebugOverlay(
              workoutManager: workoutManager,
              isVisible: workoutManager.state == WorkoutState.active ||
                  workoutManager.state == WorkoutState.paused,
              isExpanded: _debugMode,
            ),

            // Training capture toggle (top right)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () async {
                  final newEnabled = !_trainingService.isEnabled;
                  await _trainingService.setEnabled(newEnabled);
                  // Start session if enabling mid-workout
                  if (newEnabled && workoutManager.state == WorkoutState.active) {
                    await _trainingService.startSession(workoutManager.exerciseType.name);
                  }
                  setState(() {});
                },
                icon: Icon(
                  _trainingService.isEnabled ? Icons.camera_alt : Icons.camera_alt_outlined,
                  color: _trainingService.isEnabled ? Colors.orange : Colors.white54,
                ),
                tooltip: 'Training data capture',
              ),
            ),

            // Toggle FABs (bottom left)
            if (workoutManager.state == WorkoutState.active ||
                workoutManager.state == WorkoutState.paused)
              Positioned(
                bottom: 100,
                left: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Guide lines toggle FAB
                    FloatingActionButton.small(
                      heroTag: 'guideLines',
                      onPressed: () async {
                        final newVisible = !_guideLinesVisible;
                        setState(() => _guideLinesVisible = newVisible);
                        // Persist preference
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_guideLinesKey, newVisible);
                      },
                      backgroundColor: _guideLinesVisible ? Colors.green : Colors.black54,
                      child: Icon(
                        _guideLinesVisible ? Icons.straighten : Icons.straighten_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Debug overlay FAB
                    FloatingActionButton.small(
                      heroTag: 'debug',
                      onPressed: () async {
                        final newMode = !_debugMode;
                        setState(() => _debugMode = newMode);
                        // Persist preference
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_debugModeKey, newMode);
                      },
                      backgroundColor: _debugMode ? Colors.green : Colors.black54,
                      child: Icon(
                        _debugMode ? Icons.bug_report : Icons.bug_report_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

            // Controls
            _buildControls(workoutManager),
          ],
        );
      },
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return CameraPreview(controller);
  }

  Widget _buildPoseOverlay(WorkoutManager workoutManager) {
    final controller = _cameraService.controller;
    if (controller == null || workoutManager.currentPose == null) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: PosePainter(
        pose: workoutManager.currentPose!,
        imageSize: controller.value.previewSize!,
        isValidPose: workoutManager.isValidPose,
        isFrontCamera:
            _cameraService.camera?.lensDirection == CameraLensDirection.front,
      ),
    );
  }

  Widget _buildCountdownOverlay(WorkoutManager workoutManager) {
    // Trigger countdown feedback when countdown value changes
    if (workoutManager.countdownSeconds != _lastCountdown) {
      _lastCountdown = workoutManager.countdownSeconds;
      if (_lastCountdown > 0) {
        _feedback.onCountdownTick();
      } else {
        _feedback.onWorkoutStart();
      }
    }

    return Container(
      color: Colors.black54,
      child: Center(
        child: Text(
          '${workoutManager.countdownSeconds}',
          style: const TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutOverlay(WorkoutManager workoutManager) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Rep counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '${workoutManager.repCount}',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  workoutManager.currentStage,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Timer/progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildTimerDisplay(workoutManager),
          ),
          // Invalid rep badge
          if (workoutManager.invalidRepCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Invalid: ${workoutManager.invalidRepCount}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(WorkoutManager workoutManager) {
    switch (workoutManager.mode) {
      case WorkoutMode.timer:
        final remaining = workoutManager.remainingSeconds;
        final minutes = remaining ~/ 60;
        final seconds = remaining % 60;
        return Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      case WorkoutMode.repGoal:
        return Text(
          '${workoutManager.repCount} / ${workoutManager.targetValue}',
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        );
      case WorkoutMode.free:
        final elapsed = workoutManager.elapsedSeconds;
        final minutes = elapsed ~/ 60;
        final seconds = elapsed % 60;
        return Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white70,
          ),
        );
    }
  }

  Widget _buildCompletionOverlay(WorkoutManager workoutManager) {
    // Save workout when completion overlay is shown
    _saveWorkout(workoutManager);

    return Stack(
      children: [
        Container(
          color: Colors.black87,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Workout Complete!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStatCard('Reps Completed', '${workoutManager.repCount}'),
                  if (workoutManager.invalidRepCount > 0)
                    _buildStatCard('Invalid Reps', '${workoutManager.invalidRepCount}'),
                  _buildStatCard('Duration', _formatDuration(workoutManager.elapsedSeconds)),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () {
                      workoutManager.reset();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const CelebrationOverlay(),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionFeedback(WorkoutManager workoutManager) {
    return Positioned(
      bottom: 120,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          workoutManager.positionFeedback.message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildControls(WorkoutManager workoutManager) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Exit button
          FloatingActionButton(
            heroTag: 'exit',
            onPressed: _showExitDialog,
            backgroundColor: Colors.red,
            child: const Icon(Icons.close),
          ),
          // Pause/Resume button
          if (workoutManager.state == WorkoutState.active ||
              workoutManager.state == WorkoutState.paused)
            FloatingActionButton.large(
              heroTag: 'pauseResume',
              onPressed: () {
                if (workoutManager.state == WorkoutState.active) {
                  workoutManager.pauseWorkout();
                } else {
                  workoutManager.resumeWorkout();
                }
              },
              child: Icon(
                workoutManager.state == WorkoutState.active
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
          // Stop button
          if (workoutManager.state == WorkoutState.active ||
              workoutManager.state == WorkoutState.paused)
            FloatingActionButton(
              heroTag: 'stop',
              onPressed: () => workoutManager.stopWorkout(),
              backgroundColor: Colors.orange,
              child: const Icon(Icons.stop),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}m ${secs}s';
  }

  Future<void> _saveWorkout(WorkoutManager workoutManager) async {
    if (_workoutSaved) return;

    final workout = Workout(
      exerciseType: workoutManager.exerciseType,
      variant: workoutManager.variant,
      mode: workoutManager.mode,
      targetValue: workoutManager.targetValue,
      repsCompleted: workoutManager.repCount,
      repsInvalid: workoutManager.invalidRepCount,
      durationSeconds: workoutManager.elapsedSeconds,
      startedAt: DateTime.now().subtract(
        Duration(seconds: workoutManager.elapsedSeconds),
      ),
      wasCompleted: workoutManager.state == WorkoutState.completed,
    );

    await _db.insertWorkout(workout);
    _workoutSaved = true;
  }

  void _showExitDialog() {
    final workoutManager = context.read<WorkoutManager>();

    if (workoutManager.state == WorkoutState.idle ||
        workoutManager.state == WorkoutState.completed) {
      workoutManager.reset();
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Workout?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              workoutManager.reset();
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back
            },
            child: const Text('End Workout'),
          ),
        ],
      ),
    );
  }
}
