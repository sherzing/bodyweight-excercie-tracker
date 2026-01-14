import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'guide_lines_painter.dart';

/// Overlay widget that displays horizontal guide lines for pushup position feedback.
///
/// Dynamically positions lines based on shoulder height during up/down stages
/// and provides visual flash feedback when the user crosses a line.
class GuideLinesOverlay extends StatefulWidget {
  /// Current pose from ML Kit
  final Pose? pose;

  /// Size of the camera image for coordinate translation
  final Size imageSize;

  /// Current exercise stage ("Up", "Down", etc.)
  final String currentStage;

  /// Whether the overlay is visible
  final bool isVisible;

  /// Whether using front camera (for mirroring)
  final bool isFrontCamera;

  const GuideLinesOverlay({
    super.key,
    required this.pose,
    required this.imageSize,
    required this.currentStage,
    this.isVisible = true,
    this.isFrontCamera = true,
  });

  @override
  State<GuideLinesOverlay> createState() => _GuideLinesOverlayState();
}

class _GuideLinesOverlayState extends State<GuideLinesOverlay> {
  // Calibrated line positions (screen Y-coordinates)
  double? _upperLineY;
  double? _lowerLineY;

  // Track shoulder Y positions for calibration
  double? _upPositionShoulderY;
  double? _downPositionShoulderY;

  // Flash state
  bool _upperLineFlash = false;
  bool _lowerLineFlash = false;
  Timer? _upperFlashTimer;
  Timer? _lowerFlashTimer;

  // Track previous stage for crossing detection
  String _previousStage = '';

  // Smoothing: keep recent shoulder Y values for averaging
  final List<double> _recentShoulderYValues = [];
  static const int _smoothingWindow = 5;

  @override
  void didUpdateWidget(GuideLinesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.pose != null && widget.isVisible) {
      _updateLinePositions();
      _checkForLineCrossing();
    }
  }

  void _updateLinePositions() {
    final pose = widget.pose;
    if (pose == null) return;

    // Get average shoulder Y position
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return;
    if (leftShoulder.likelihood < 0.5 || rightShoulder.likelihood < 0.5) return;

    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;

    // Add to smoothing window
    _recentShoulderYValues.add(avgShoulderY);
    if (_recentShoulderYValues.length > _smoothingWindow) {
      _recentShoulderYValues.removeAt(0);
    }

    // Calculate smoothed shoulder Y
    final smoothedShoulderY = _recentShoulderYValues.reduce((a, b) => a + b) /
        _recentShoulderYValues.length;

    // Calibrate line positions based on current stage
    final stage = widget.currentStage.toLowerCase();

    if (stage.contains('up')) {
      // User is in up position - calibrate upper line
      if (_upPositionShoulderY == null) {
        _upPositionShoulderY = smoothedShoulderY;
      } else {
        // Exponential moving average for smooth updates
        _upPositionShoulderY =
            _upPositionShoulderY! * 0.9 + smoothedShoulderY * 0.1;
      }
    } else if (stage.contains('down')) {
      // User is in down position - calibrate lower line
      if (_downPositionShoulderY == null) {
        _downPositionShoulderY = smoothedShoulderY;
      } else {
        _downPositionShoulderY =
            _downPositionShoulderY! * 0.9 + smoothedShoulderY * 0.1;
      }
    }

    // Update screen positions if we have calibration data
    if (_upPositionShoulderY != null) {
      _upperLineY = _translateY(_upPositionShoulderY!);
    }
    if (_downPositionShoulderY != null) {
      _lowerLineY = _translateY(_downPositionShoulderY!);
    }
  }

  double _translateY(double imageY) {
    // Translate from image coordinates to screen coordinates
    final context = this.context;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return imageY;

    final canvasSize = renderBox.size;
    final scaleY = canvasSize.height / widget.imageSize.width;

    return imageY * scaleY;
  }

  void _checkForLineCrossing() {
    final currentStage = widget.currentStage.toLowerCase();
    final previousStage = _previousStage.toLowerCase();

    // Detect transition to "up" position (crossed upper line)
    if (currentStage.contains('up') && !previousStage.contains('up')) {
      _triggerUpperFlash();
    }

    // Detect transition to "down" position (crossed lower line)
    if (currentStage.contains('down') && !previousStage.contains('down')) {
      _triggerLowerFlash();
    }

    _previousStage = widget.currentStage;
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

    return CustomPaint(
      painter: GuideLinesPainter(
        upperLineY: _upperLineY,
        lowerLineY: _lowerLineY,
        upperLineFlash: _upperLineFlash,
        lowerLineFlash: _lowerLineFlash,
      ),
      size: Size.infinite,
    );
  }
}
