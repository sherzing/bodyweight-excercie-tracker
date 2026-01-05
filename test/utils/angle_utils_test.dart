import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pushup_counter/utils/angle_utils.dart';

void main() {
  group('AngleUtils', () {
    group('calculateAngle', () {
      test('returns 180 degrees for straight line', () {
        // Three points in a straight horizontal line
        final a = _createLandmark(0, 0);
        final b = _createLandmark(100, 0);
        final c = _createLandmark(200, 0);

        final angle = AngleUtils.calculateAngle(a, b, c);

        expect(angle, closeTo(180.0, 0.1));
      });

      test('returns 90 degrees for right angle', () {
        // Right angle at point B
        final a = _createLandmark(0, 0);
        final b = _createLandmark(0, 100);
        final c = _createLandmark(100, 100);

        final angle = AngleUtils.calculateAngle(a, b, c);

        expect(angle, closeTo(90.0, 0.1));
      });

      test('returns 0 degrees when points overlap', () {
        final a = _createLandmark(0, 0);
        final b = _createLandmark(0, 0);
        final c = _createLandmark(100, 0);

        final angle = AngleUtils.calculateAngle(a, b, c);

        expect(angle, equals(0.0));
      });

      test('returns 60 degrees for equilateral triangle', () {
        // Equilateral triangle - all angles are 60 degrees
        final a = _createLandmark(0, 0);
        final b = _createLandmark(100, 0);
        final c = _createLandmark(50, 86.6); // height = 100 * sqrt(3)/2

        final angle = AngleUtils.calculateAngle(a, b, c);

        expect(angle, closeTo(60.0, 0.5));
      });

      test('returns 90 degrees for right angle at corner', () {
        // Right angle at point B (the corner of an L shape)
        final a = _createLandmark(0, 0);
        final b = _createLandmark(100, 0);
        final c = _createLandmark(100, 100);

        final angle = AngleUtils.calculateAngle(a, b, c);

        // This forms a right angle at B
        expect(angle, closeTo(90.0, 0.1));
      });
    });

    group('calculateElbowAngle', () {
      test('returns null when any landmark is null', () {
        final shoulder = _createLandmark(0, 0);
        final elbow = _createLandmark(50, 50);

        expect(AngleUtils.calculateElbowAngle(shoulder, elbow, null), isNull);
        expect(AngleUtils.calculateElbowAngle(shoulder, null, elbow), isNull);
        expect(AngleUtils.calculateElbowAngle(null, elbow, shoulder), isNull);
      });

      test('calculates angle when all landmarks present', () {
        final shoulder = _createLandmark(0, 0);
        final elbow = _createLandmark(0, 100);
        final wrist = _createLandmark(100, 100);

        final angle = AngleUtils.calculateElbowAngle(shoulder, elbow, wrist);

        expect(angle, isNotNull);
        expect(angle, closeTo(90.0, 0.1));
      });
    });

    group('calculateBodyAlignment', () {
      test('returns 0 deviation for straight body', () {
        final shoulder = _createLandmark(100, 0);
        final hip = _createLandmark(100, 100);
        final ankle = _createLandmark(100, 200);

        final deviation = AngleUtils.calculateBodyAlignment(shoulder, hip, ankle);

        expect(deviation, closeTo(0.0, 0.1));
      });

      test('returns deviation for bent body', () {
        final shoulder = _createLandmark(100, 0);
        final hip = _createLandmark(150, 100); // Hip shifted right
        final ankle = _createLandmark(100, 200);

        final deviation = AngleUtils.calculateBodyAlignment(shoulder, hip, ankle);

        expect(deviation, greaterThan(0));
        expect(deviation, lessThan(90));
      });

      test('returns null when any landmark is null', () {
        final shoulder = _createLandmark(0, 0);
        final hip = _createLandmark(0, 100);

        expect(AngleUtils.calculateBodyAlignment(shoulder, hip, null), isNull);
      });
    });

    group('isBodyAligned', () {
      test('returns true for straight body within threshold', () {
        final shoulder = _createLandmark(100, 0);
        final hip = _createLandmark(100, 100);
        final ankle = _createLandmark(100, 200);

        expect(AngleUtils.isBodyAligned(shoulder, hip, ankle), isTrue);
      });

      test('returns false for body with deviation exceeding threshold', () {
        final shoulder = _createLandmark(100, 0);
        final hip = _createLandmark(200, 100); // Large hip shift
        final ankle = _createLandmark(100, 200);

        expect(
          AngleUtils.isBodyAligned(shoulder, hip, ankle, maxDeviation: 15.0),
          isFalse,
        );
      });

      test('respects custom maxDeviation parameter', () {
        final shoulder = _createLandmark(100, 0);
        final hip = _createLandmark(110, 100); // Small hip shift
        final ankle = _createLandmark(100, 200);

        // With strict threshold, should fail
        expect(
          AngleUtils.isBodyAligned(shoulder, hip, ankle, maxDeviation: 1.0),
          isFalse,
        );

        // With lenient threshold, should pass
        expect(
          AngleUtils.isBodyAligned(shoulder, hip, ankle, maxDeviation: 20.0),
          isTrue,
        );
      });
    });

    group('averageSideAngles', () {
      test('returns average of both values', () {
        expect(AngleUtils.averageSideAngles(90.0, 100.0), equals(95.0));
      });

      test('returns left when right is null', () {
        expect(AngleUtils.averageSideAngles(90.0, null), equals(90.0));
      });

      test('returns right when left is null', () {
        expect(AngleUtils.averageSideAngles(null, 100.0), equals(100.0));
      });

      test('returns null when both are null', () {
        expect(AngleUtils.averageSideAngles(null, null), isNull);
      });
    });
  });
}

/// Helper to create a PoseLandmark for testing
PoseLandmark _createLandmark(double x, double y, {double likelihood = 1.0}) {
  return PoseLandmark(
    type: PoseLandmarkType.nose, // Type doesn't matter for angle calculations
    x: x,
    y: y,
    z: 0,
    likelihood: likelihood,
  );
}
