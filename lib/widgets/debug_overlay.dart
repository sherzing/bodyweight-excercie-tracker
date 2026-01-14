import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../providers/workout_manager.dart';

/// Debug overlay showing real-time pose detection data with slide animation
class DebugOverlay extends StatelessWidget {
  final WorkoutManager workoutManager;
  final bool isVisible;
  final bool isExpanded;

  const DebugOverlay({
    super.key,
    required this.workoutManager,
    this.isVisible = true,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final debugAngles = workoutManager.debugAngles;
    final pose = workoutManager.currentPose;

    return Positioned(
      top: 180,
      left: 12,
      right: 12,
      child: AnimatedSlide(
        offset: isExpanded ? Offset.zero : const Offset(0, -2),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: isExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !isExpanded,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: workoutManager.isValidPose ? Colors.green : Colors.red,
                  width: 3,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white30, height: 1),
                  const SizedBox(height: 12),
                  _buildAngleRow('ELBOW', debugAngles['elbow'],
                      threshold: '≤90 down, ≥160 up',
                      isGood: _isElbowGood(debugAngles['elbow'])),
                  _buildAngleRow('L Elbow', debugAngles['leftElbow']),
                  _buildAngleRow('R Elbow', debugAngles['rightElbow']),
                  const SizedBox(height: 8),
                  _buildAngleRow('Body Dev', debugAngles['bodyDeviation'],
                      threshold: '<30',
                      isGood: _isBodyAligned(debugAngles['bodyDeviation'])),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white30, height: 1),
                  const SizedBox(height: 12),
                  _buildConfidenceSection(pose),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          workoutManager.isValidPose ? Icons.check_circle : Icons.warning,
          color: workoutManager.isValidPose ? Colors.green : Colors.orange,
          size: 28,
        ),
        const SizedBox(width: 8),
        Text(
          'DEBUG',
          style: TextStyle(
            color: workoutManager.isValidPose ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStageColor(),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            workoutManager.currentStage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStageColor() {
    final stage = workoutManager.currentStage.toLowerCase();
    if (stage.contains('up')) return Colors.green;
    if (stage.contains('down')) return Colors.blue;
    return Colors.orange;
  }

  Widget _buildAngleRow(String label, double? value, {String? threshold, bool? isGood}) {
    final displayValue = value != null ? value.toStringAsFixed(1) : '--';
    final color = isGood == null
        ? Colors.white70
        : (isGood ? Colors.green : Colors.red);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '$displayValue°',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (threshold != null)
            Flexible(
              child: Text(
                '($threshold)',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  bool _isElbowGood(double? angle) {
    if (angle == null) return false;
    // Good if clearly in up (>=150) or down (<=100) position
    return angle >= 150 || angle <= 100;
  }

  bool _isBodyAligned(double? deviation) {
    if (deviation == null) return true; // Assume good if unknown
    if (deviation > 45) return true; // Ignore unrealistic values (detection noise)
    return deviation < 30;
  }

  Widget _buildConfidenceSection(Pose? pose) {
    if (pose == null) {
      return const Text(
        'No pose detected',
        style: TextStyle(color: Colors.red, fontSize: 18),
      );
    }

    final landmarks = pose.landmarks;
    final keyPoints = [
      (PoseLandmarkType.leftShoulder, 'L Shoulder'),
      (PoseLandmarkType.rightShoulder, 'R Shoulder'),
      (PoseLandmarkType.leftElbow, 'L Elbow'),
      (PoseLandmarkType.rightElbow, 'R Elbow'),
      (PoseLandmarkType.leftWrist, 'L Wrist'),
      (PoseLandmarkType.rightWrist, 'R Wrist'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Landmark Confidence (need >50%):',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...keyPoints.map((point) {
          final landmark = landmarks[point.$1];
          final confidence = landmark?.likelihood ?? 0.0;
          final isGood = confidence >= 0.5;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    point.$2,
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: confidence,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isGood ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${(confidence * 100).toInt()}%',
                    style: TextStyle(
                      color: isGood ? Colors.green : Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
