import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Utility class for calculating joint angles from pose landmarks.
/// Uses the Law of Cosines: cos(theta) = (a^2 + b^2 - c^2) / (2ab)
class AngleUtils {
  /// Calculate the angle at point B in the triangle formed by points A, B, C.
  /// Returns the angle in degrees.
  ///
  /// For example, to calculate elbow angle:
  /// - A = shoulder, B = elbow, C = wrist
  /// - Returns the angle at the elbow joint
  static double calculateAngle(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark c,
  ) {
    // Get coordinates
    final ax = a.x;
    final ay = a.y;
    final bx = b.x;
    final by = b.y;
    final cx = c.x;
    final cy = c.y;

    // Calculate distances between points
    final ab = _distance(ax, ay, bx, by); // side a (B to A)
    final bc = _distance(bx, by, cx, cy); // side b (B to C)
    final ac = _distance(ax, ay, cx, cy); // side c (A to C)

    // Avoid division by zero
    if (ab == 0 || bc == 0) return 0;

    // Law of Cosines: cos(theta) = (a^2 + b^2 - c^2) / (2ab)
    final cosAngle = (ab * ab + bc * bc - ac * ac) / (2 * ab * bc);

    // Clamp to valid range [-1, 1] to handle floating point errors
    final clampedCos = cosAngle.clamp(-1.0, 1.0);

    // Convert to degrees
    final angleRadians = math.acos(clampedCos);
    final angleDegrees = angleRadians * 180 / math.pi;

    return angleDegrees;
  }

  /// Calculate distance between two points
  static double _distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calculate the elbow angle (shoulder -> elbow -> wrist)
  static double? calculateElbowAngle(
    PoseLandmark? shoulder,
    PoseLandmark? elbow,
    PoseLandmark? wrist,
  ) {
    if (shoulder == null || elbow == null || wrist == null) return null;
    return calculateAngle(shoulder, elbow, wrist);
  }

  /// Calculate the hip angle (shoulder -> hip -> knee or ankle)
  static double? calculateHipAngle(
    PoseLandmark? shoulder,
    PoseLandmark? hip,
    PoseLandmark? kneeOrAnkle,
  ) {
    if (shoulder == null || hip == null || kneeOrAnkle == null) return null;
    return calculateAngle(shoulder, hip, kneeOrAnkle);
  }

  /// Calculate the knee angle (hip -> knee -> ankle)
  static double? calculateKneeAngle(
    PoseLandmark? hip,
    PoseLandmark? knee,
    PoseLandmark? ankle,
  ) {
    if (hip == null || knee == null || ankle == null) return null;
    return calculateAngle(hip, knee, ankle);
  }

  /// Check body alignment by measuring deviation from a straight line.
  /// Returns the deviation angle in degrees.
  /// For pushups: shoulder -> hip -> ankle should be roughly straight (<15 degrees deviation)
  static double? calculateBodyAlignment(
    PoseLandmark? shoulder,
    PoseLandmark? hip,
    PoseLandmark? ankle,
  ) {
    if (shoulder == null || hip == null || ankle == null) return null;

    // Calculate the angle at hip - should be close to 180 for straight body
    final angle = calculateAngle(shoulder, hip, ankle);

    // Return deviation from straight (180 degrees)
    return (180 - angle).abs();
  }

  /// Check if body alignment is acceptable (deviation < threshold)
  static bool isBodyAligned(
    PoseLandmark? shoulder,
    PoseLandmark? hip,
    PoseLandmark? ankle, {
    double maxDeviation = 15.0,
  }) {
    final deviation = calculateBodyAlignment(shoulder, hip, ankle);
    if (deviation == null) return false;
    return deviation < maxDeviation;
  }

  /// Calculate the average of left and right side angles
  static double? averageSideAngles(double? left, double? right) {
    if (left == null && right == null) return null;
    if (left == null) return right;
    if (right == null) return left;
    return (left + right) / 2;
  }
}
