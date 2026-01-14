import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/workout.dart';
import 'guide_lines_painter.dart';

/// Overlay widget that displays a single horizontal guide line for the pushup
/// down position target.
///
/// The line position is set based on the first time the user reaches the "down"
/// position during the workout, then locked for the remainder of the session.
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

  const GuideLinesOverlay({
    super.key,
    required this.pose,
    required this.imageSize,
    required this.currentStage,
    required this.workoutState,
    this.isVisible = true,
    this.isFrontCamera = true,
  });

  @override
  State<GuideLinesOverlay> createState() => _GuideLinesOverlayState();
}

class _GuideLinesOverlayState extends State<GuideLinesOverlay> {
  // Locked line position (screen Y-coordinate)
  double? _lockedLineY;

  // Whether line position has been set
  bool _linePositionSet = false;

  // Flash state
  bool _lineFlash = false;
  Timer? _flashTimer;

  // Track previous stage for crossing detection
  String _previousStage = '';

  @override
  void didUpdateWidget(GuideLinesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset when workout starts
    if (oldWidget.workoutState != WorkoutState.active &&
        widget.workoutState == WorkoutState.active) {
      _linePositionSet = false;
      _lockedLineY = null;
    }

    if (widget.pose != null &&
        widget.isVisible &&
        widget.workoutState == WorkoutState.active) {
      _processCurrentPose();
    }
  }

  void _processCurrentPose() {
    final pose = widget.pose;
    if (pose == null) return;

    final shoulderY = _getAverageShoulderY(pose);
    if (shoulderY == null) return;

    final currentStage = widget.currentStage.toLowerCase();
    final previousStage = _previousStage.toLowerCase();

    // Set line position on first "down" detection
    if (!_linePositionSet && currentStage.contains('down')) {
      _lockedLineY = _translateY(shoulderY);
      _linePositionSet = true;
      setState(() {});
    }

    // Flash when crossing the line (entering down position)
    if (currentStage.contains('down') && !previousStage.contains('down')) {
      _triggerFlash();
    }

    _previousStage = widget.currentStage;
  }

  double? _getAverageShoulderY(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return null;
    if (leftShoulder.likelihood < 0.5 || rightShoulder.likelihood < 0.5) {
      return null;
    }

    return (leftShoulder.y + rightShoulder.y) / 2;
  }

  double _translateY(double imageY) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return imageY;

    final canvasSize = renderBox.size;
    final scaleY = canvasSize.height / widget.imageSize.width;

    return imageY * scaleY;
  }

  void _triggerFlash() {
    _flashTimer?.cancel();
    setState(() => _lineFlash = true);
    _flashTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _lineFlash = false);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return CustomPaint(
      painter: GuideLinesPainter(
        lineY: _lockedLineY,
        lineFlash: _lineFlash,
      ),
      size: Size.infinite,
    );
  }
}
