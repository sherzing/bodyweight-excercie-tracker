import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/workout.dart';
import '../providers/workout_manager.dart';
import 'guide_lines_painter.dart';

/// Display mode for guide lines
enum GuideLineDisplayMode {
  /// Lines show target positions the user should reach
  targetPositions,
  /// Lines show the detection thresholds (elbow angles)
  thresholdIndicators,
}

/// Overlay widget that displays horizontal guide lines for pushup position feedback.
///
/// Uses a calibration phase to learn the user's up/down positions, then locks
/// the lines in place with gradual refinement during the workout.
class GuideLinesOverlay extends StatefulWidget {
  /// Current pose from ML Kit
  final Pose? pose;

  /// Size of the camera image for coordinate translation
  final Size imageSize;

  /// Current exercise stage ("Up", "Down", etc.)
  final String currentStage;

  /// Current workout state
  final WorkoutState workoutState;

  /// Whether the overlay is visible
  final bool isVisible;

  /// Whether using front camera (for mirroring)
  final bool isFrontCamera;

  /// Workout manager for calibration callbacks
  final WorkoutManager workoutManager;

  /// Display mode for the lines
  final GuideLineDisplayMode displayMode;

  const GuideLinesOverlay({
    super.key,
    required this.pose,
    required this.imageSize,
    required this.currentStage,
    required this.workoutState,
    required this.workoutManager,
    this.isVisible = true,
    this.isFrontCamera = true,
    this.displayMode = GuideLineDisplayMode.targetPositions,
  });

  @override
  State<GuideLinesOverlay> createState() => _GuideLinesOverlayState();
}

class _GuideLinesOverlayState extends State<GuideLinesOverlay> {
  // Locked line positions (screen Y-coordinates) after calibration
  double? _lockedUpperLineY;
  double? _lockedLowerLineY;

  // Flash state
  bool _upperLineFlash = false;
  bool _lowerLineFlash = false;
  Timer? _upperFlashTimer;
  Timer? _lowerFlashTimer;

  // Track previous stage for crossing detection and calibration
  String _previousStage = '';
  bool _wasDown = false; // Track if we've seen down position this rep

  // Gradual refinement tracking
  static const double _refinementRate = 0.05; // 5% adjustment per rep
  static const double _maxDriftPercent = 0.10; // Max 10% drift from calibrated position

  @override
  void didUpdateWidget(GuideLinesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.pose != null && widget.isVisible) {
      _processCurrentPose();
    }

    // Lock lines when transitioning from calibrating to active
    if (oldWidget.workoutState == WorkoutState.calibrating &&
        widget.workoutState == WorkoutState.active) {
      _lockLinesFromCalibration();
    }
  }

  void _processCurrentPose() {
    final pose = widget.pose;
    if (pose == null) return;

    final shoulderY = _getAverageShoulderY(pose);
    if (shoulderY == null) return;

    final currentStage = widget.currentStage.toLowerCase();
    final previousStage = _previousStage.toLowerCase();

    if (widget.workoutState == WorkoutState.calibrating) {
      _handleCalibration(shoulderY, currentStage, previousStage);
    } else if (widget.workoutState == WorkoutState.active) {
      _handleActiveWorkout(shoulderY, currentStage, previousStage);
    }

    _previousStage = widget.currentStage;
  }

  double? _getAverageShoulderY(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return null;
    if (leftShoulder.likelihood < 0.5 || rightShoulder.likelihood < 0.5) return null;

    return (leftShoulder.y + rightShoulder.y) / 2;
  }

  void _handleCalibration(double shoulderY, String currentStage, String previousStage) {
    // Record positions during calibration
    if (currentStage.contains('up')) {
      widget.workoutManager.recordCalibrationPosition(isUp: true, shoulderY: shoulderY);

      // Check if we completed a rep (went down and came back up)
      if (_wasDown) {
        _wasDown = false;
        widget.workoutManager.completeCalibrationRep();
      }
    } else if (currentStage.contains('down')) {
      widget.workoutManager.recordCalibrationPosition(isUp: false, shoulderY: shoulderY);
      _wasDown = true;
    }
  }

  void _lockLinesFromCalibration() {
    final calibratedUpY = widget.workoutManager.calibratedUpY;
    final calibratedDownY = widget.workoutManager.calibratedDownY;

    if (calibratedUpY != null) {
      _lockedUpperLineY = _translateY(calibratedUpY);
    }
    if (calibratedDownY != null) {
      _lockedLowerLineY = _translateY(calibratedDownY);
    }

    setState(() {});
  }

  void _handleActiveWorkout(double shoulderY, String currentStage, String previousStage) {
    // Check for line crossings and flash
    if (currentStage.contains('up') && !previousStage.contains('up')) {
      _triggerUpperFlash();
      // Apply gradual refinement
      _applyRefinement(isUp: true, shoulderY: shoulderY);
    }
    if (currentStage.contains('down') && !previousStage.contains('down')) {
      _triggerLowerFlash();
      // Apply gradual refinement
      _applyRefinement(isUp: false, shoulderY: shoulderY);
    }
  }

  void _applyRefinement({required bool isUp, required double shoulderY}) {
    final screenY = _translateY(shoulderY);
    final calibratedUpY = widget.workoutManager.calibratedUpY;
    final calibratedDownY = widget.workoutManager.calibratedDownY;

    if (isUp && _lockedUpperLineY != null && calibratedUpY != null) {
      final originalY = _translateY(calibratedUpY);
      final maxDrift = MediaQuery.of(context).size.height * _maxDriftPercent;

      // Only adjust if within max drift range
      if ((screenY - originalY).abs() <= maxDrift) {
        _lockedUpperLineY = _lockedUpperLineY! * (1 - _refinementRate) + screenY * _refinementRate;
      }
    } else if (!isUp && _lockedLowerLineY != null && calibratedDownY != null) {
      final originalY = _translateY(calibratedDownY);
      final maxDrift = MediaQuery.of(context).size.height * _maxDriftPercent;

      if ((screenY - originalY).abs() <= maxDrift) {
        _lockedLowerLineY = _lockedLowerLineY! * (1 - _refinementRate) + screenY * _refinementRate;
      }
    }
  }

  double _translateY(double imageY) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return imageY;

    final canvasSize = renderBox.size;
    final scaleY = canvasSize.height / widget.imageSize.width;

    return imageY * scaleY;
  }

  void _triggerUpperFlash() {
    _upperFlashTimer?.cancel();
    setState(() => _upperLineFlash = true);
    _upperFlashTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _upperLineFlash = false);
    });
  }

  void _triggerLowerFlash() {
    _lowerFlashTimer?.cancel();
    setState(() => _lowerLineFlash = true);
    _lowerFlashTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _lowerLineFlash = false);
    });
  }

  @override
  void dispose() {
    _upperFlashTimer?.cancel();
    _lowerFlashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    // During calibration, show lines as they're being calibrated (live preview)
    double? upperY = _lockedUpperLineY;
    double? lowerY = _lockedLowerLineY;

    if (widget.workoutState == WorkoutState.calibrating) {
      // Show live preview during calibration
      final calibratedUpY = widget.workoutManager.calibratedUpY;
      final calibratedDownY = widget.workoutManager.calibratedDownY;

      if (calibratedUpY != null) {
        upperY = _translateY(calibratedUpY);
      }
      if (calibratedDownY != null) {
        lowerY = _translateY(calibratedDownY);
      }
    }

    return CustomPaint(
      painter: GuideLinesPainter(
        upperLineY: upperY,
        lowerLineY: lowerY,
        upperLineFlash: _upperLineFlash,
        lowerLineFlash: _lowerLineFlash,
        displayMode: widget.displayMode,
      ),
      size: Size.infinite,
    );
  }
}
