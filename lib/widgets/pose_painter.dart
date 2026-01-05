import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Custom painter for drawing pose landmarks and skeleton on camera preview.
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final bool isValidPose;
  final bool isFrontCamera;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.isValidPose,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint for landmarks
    final landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4
      ..color = isValidPose ? Colors.green : Colors.red;

    // Paint for skeleton lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = isValidPose ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8);

    // Draw skeleton connections
    _drawSkeleton(canvas, size, linePaint);

    // Draw landmarks
    for (final landmark in pose.landmarks.values) {
      if (landmark.likelihood < 0.5) continue;

      final point = _translatePoint(landmark, size);
      canvas.drawCircle(point, 6, landmarkPaint);
    }
  }

  void _drawSkeleton(Canvas canvas, Size size, Paint paint) {
    // Body connections to draw
    final connections = [
      // Face
      [PoseLandmarkType.leftEar, PoseLandmarkType.leftEye],
      [PoseLandmarkType.leftEye, PoseLandmarkType.nose],
      [PoseLandmarkType.nose, PoseLandmarkType.rightEye],
      [PoseLandmarkType.rightEye, PoseLandmarkType.rightEar],

      // Torso
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],

      // Left arm
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb],
      [PoseLandmarkType.leftPinky, PoseLandmarkType.leftIndex],

      // Right arm
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb],
      [PoseLandmarkType.rightPinky, PoseLandmarkType.rightIndex],

      // Left leg
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
      [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],

      // Right leg
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
      [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
      [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
    ];

    for (final connection in connections) {
      final start = pose.landmarks[connection[0]];
      final end = pose.landmarks[connection[1]];

      if (start == null ||
          end == null ||
          start.likelihood < 0.5 ||
          end.likelihood < 0.5) {
        continue;
      }

      canvas.drawLine(
        _translatePoint(start, size),
        _translatePoint(end, size),
        paint,
      );
    }
  }

  Offset _translatePoint(PoseLandmark landmark, Size canvasSize) {
    // Scale coordinates from image size to canvas size
    final scaleX = canvasSize.width / imageSize.height;
    final scaleY = canvasSize.height / imageSize.width;

    // For front camera, mirror the x coordinate
    final x = isFrontCamera
        ? canvasSize.width - (landmark.x * scaleX)
        : landmark.x * scaleX;
    final y = landmark.y * scaleY;

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.isValidPose != isValidPose;
  }
}
