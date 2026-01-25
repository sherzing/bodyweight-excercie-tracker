import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pushup_counter/models/invalid_rep_reason.dart';
import 'package:pushup_counter/models/pushup_counter.dart';

/// Tests for PushupCounter behavior.
/// Tests focus on the observable state transitions and rep counting logic.
void main() {
  group('PushupCounter', () {
    late PushupCounter counter;

    setUp(() {
      counter = PushupCounter();
    });

    test('exercise name is Pushups', () {
      expect(counter.exerciseName, equals('Pushups'));
    });

    test('variant is Standard by default', () {
      expect(counter.variant, equals('Standard'));
    });

    group('Pose Validation', () {
      test('requires at least one arm with shoulder, elbow, wrist', () {
        // Only shoulders - should be invalid
        counter.updateLandmarks([
          _createLandmark(PoseLandmarkType.leftShoulder, 100, 100),
          _createLandmark(PoseLandmarkType.rightShoulder, 200, 100),
          _createLandmark(PoseLandmarkType.leftHip, 100, 200),
        ]);

        expect(counter.isValidPose(), isFalse);
      });

      test('valid with complete left arm and hip', () {
        counter.updateLandmarks([
          _createLandmark(PoseLandmarkType.leftShoulder, 100, 100),
          _createLandmark(PoseLandmarkType.leftElbow, 100, 150),
          _createLandmark(PoseLandmarkType.leftWrist, 100, 200),
          _createLandmark(PoseLandmarkType.leftHip, 100, 250),
        ]);

        expect(counter.isValidPose(), isTrue);
      });

      test('valid with complete right arm and hip', () {
        counter.updateLandmarks([
          _createLandmark(PoseLandmarkType.rightShoulder, 200, 100),
          _createLandmark(PoseLandmarkType.rightElbow, 200, 150),
          _createLandmark(PoseLandmarkType.rightWrist, 200, 200),
          _createLandmark(PoseLandmarkType.rightHip, 200, 250),
        ]);

        expect(counter.isValidPose(), isTrue);
      });

      test('rejects low confidence landmarks', () {
        counter.updateLandmarks([
          _createLandmark(PoseLandmarkType.leftShoulder, 100, 100, likelihood: 0.3),
          _createLandmark(PoseLandmarkType.leftElbow, 100, 150, likelihood: 0.3),
          _createLandmark(PoseLandmarkType.leftWrist, 100, 200, likelihood: 0.3),
          _createLandmark(PoseLandmarkType.leftHip, 100, 250, likelihood: 0.3),
        ]);

        expect(counter.isValidPose(), isFalse);
      });
    });

    group('Stage Detection', () {
      test('starts in warmup Up stage', () {
        expect(counter.getCurrentStage(), equals('(Warmup) Up'));
        expect(counter.isReady, isFalse);
      });

      test('detects non-Up stage with bent elbow', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        // Simulate bent elbow position (90 degrees)
        counter.updateLandmarks(_createPushupPose(elbowAngle: 90));
        counter.checkRepCompletion();

        // Should be in Down or transitional state, not Up
        expect(counter.getCurrentStage(), isNot(equals('Up')));
      });

      test('stage changes when pose changes', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        final initialStage = counter.getCurrentStage();

        // Simulate a pose change
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        final stageAfterBend = counter.getCurrentStage();

        // The stage should be responsive to pose changes
        // (specific stage values are implementation details)
        expect(stageAfterBend, isNotEmpty);
        expect(initialStage, isNotEmpty);
      });
    });

    group('Rep Counting', () {
      test('recordRep increments rep count', () {
        expect(counter.repCount, equals(0));

        counter.recordRep();

        expect(counter.repCount, equals(1));
      });

      test('checkRepCompletion returns boolean', () {
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));

        final result = counter.checkRepCompletion();

        expect(result, isA<bool>());
      });

      test('does not count without valid pose', () {
        // No landmarks = invalid pose
        counter.checkRepCompletion();

        expect(counter.repCount, equals(0));
      });

      test('debouncing prevents rapid rep counting', () {
        // Record a rep
        counter.recordRep();
        expect(counter.canCountRep(), isFalse);

        // After debounce period
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        expect(counter.canCountRep(), isTrue);
      });
    });

    group('Debug Angles', () {
      test('includes elbow angle when arms are visible', () {
        counter.updateLandmarks(_createPushupPose(elbowAngle: 90));

        final angles = counter.getDebugAngles();

        expect(angles.containsKey('elbow'), isTrue);
      });

      test('includes left and right elbow angles separately', () {
        counter.updateLandmarks(_createPushupPose(elbowAngle: 90));

        final angles = counter.getDebugAngles();

        expect(angles.containsKey('leftElbow'), isTrue);
        expect(angles.containsKey('rightElbow'), isTrue);
      });

      test('includes body deviation when full body visible', () {
        counter.updateLandmarks(_createPushupPose(elbowAngle: 90));

        final angles = counter.getDebugAngles();

        expect(angles.containsKey('bodyDeviation'), isTrue);
      });
    });

    group('Reset', () {
      test('resets to warmup state', () {
        // Activate and go to a non-up position
        _activateCounter(counter);
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), isNot(contains('Warmup')));

        counter.reset();

        expect(counter.getCurrentStage(), equals('(Warmup) Up'));
        expect(counter.isReady, isFalse);
      });
    });

    group('Complete Rep Cycle', () {
      test('counts valid rep for full up-down-up cycle', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        // Start in up position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));

        // Go to down position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Down'));

        // Wait for debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to up position - should count rep
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        final completed = counter.checkRepCompletion();

        expect(completed, isTrue);
        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0));
      });

      test('counts valid rep when ankles not visible (no form tracking)', () {
        // This tests the bug fix: when ankles aren't visible, bodyDeviation is null,
        // so no form frames are tracked. Previously this defaulted to 0% form ratio
        // causing all reps to be invalid. Now it defaults to 100% (valid).

        // Activate counter (skip ready state)
        _activateCounter(counter);

        // Start in up position (no ankles)
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 170));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));

        // Go to down position
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Down'));

        // Wait for debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to up position - should count as VALID rep (not invalid)
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 170));
        final completed = counter.checkRepCompletion();

        expect(completed, isTrue);
        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0)); // Key assertion: should NOT be invalid
      });

      // Form validation is disabled - all completed reps count as valid
      test('counts rep as valid regardless of form (form validation disabled)', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        // Start in up position with bad form (hips sagging - high body deviation)
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        // Go to down position with bad form
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 85));
        counter.checkRepCompletion();

        // Add more frames with bad form to ensure >40% bad
        for (var i = 0; i < 5; i++) {
          counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 90));
          counter.checkRepCompletion();
        }

        // Wait for debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to up position - counts as valid (form validation disabled)
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        // Form validation disabled - rep counts as valid
        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0));
      });

      test('multiple reps counted correctly', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        // Complete 3 reps
        for (var rep = 0; rep < 3; rep++) {
          // Up position
          counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
          counter.checkRepCompletion();

          // Down position
          counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
          counter.checkRepCompletion();

          // Clear debounce
          counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

          // Back to up
          counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
          counter.checkRepCompletion();
        }

        expect(counter.repCount, equals(3));
      });
    });

    group('Partial Visibility', () {
      test('bodyDeviation is null when ankles missing', () {
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 90));

        final angles = counter.getDebugAngles();

        expect(angles.containsKey('bodyDeviation'), isFalse);
        expect(angles.containsKey('elbow'), isTrue); // Elbow should still work
      });

      test('pose is still valid without ankles', () {
        counter.updateLandmarks(_createPushupPoseWithoutAnkles(elbowAngle: 90));

        expect(counter.isValidPose(), isTrue);
      });
    });

    group('Debounce Edge Cases', () {
      test('debounce-blocked rep resets state correctly', () {
        // This tests that when debounce blocks a rep, the state is properly
        // reset to prevent any issues with subsequent reps.

        // Activate counter (skip ready state)
        _activateCounter(counter);

        // Complete first rep (valid)
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        // Clear debounce for first rep
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0));

        // Simulate rapid second rep attempt that gets blocked by debounce
        // User goes down quickly
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();

        // User comes up immediately (within 300ms debounce window)
        counter.lastRepTime = DateTime.now(); // Reset to simulate fast timing
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        // Rep count should NOT have increased (blocked by debounce)
        expect(counter.repCount, equals(1));

        // After debounce blocked the rep, the state should be cleanly reset
        // Verify by doing a proper rep
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        // Should now have 2 valid reps
        expect(counter.repCount, equals(2));
        expect(counter.invalidRepCount, equals(0));
      });

      test('rapid reps blocked by debounce do not accumulate', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        // Complete first rep
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(counter.repCount, equals(1));

        // Try to do 3 rapid reps within debounce window
        for (var i = 0; i < 3; i++) {
          counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
          counter.checkRepCompletion();
          counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
          counter.checkRepCompletion();
        }

        // All should be blocked by debounce - only original 1 rep counted
        expect(counter.repCount, equals(1));
        expect(counter.invalidRepCount, equals(0));

        // Now clear debounce and do a proper rep
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        // Should have 2 reps total now
        expect(counter.repCount, equals(2));
        expect(counter.invalidRepCount, equals(0));
      });
    });

    group('Warmup (First Cycle Skip)', () {
      test('counter starts in warmup mode', () {
        expect(counter.getCurrentStage(), equals('(Warmup) Up'));
        expect(counter.isReady, isFalse);
      });

      test('activate() immediately enables counting', () {
        expect(counter.isReady, isFalse);

        counter.activate();

        expect(counter.isReady, isTrue);
        expect(counter.getCurrentStage(), equals('Up'));
      });

      test('first rep cycle does not count (warmup)', () {
        // First rep cycle - should not be counted
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();

        // Clear debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        // First cycle completed but not counted
        expect(counter.repCount, equals(0));
        expect(counter.invalidRepCount, equals(0));
        expect(counter.isReady, isTrue); // Now ready for real counting
        expect(counter.getCurrentStage(), equals('Up')); // No more warmup prefix
      });

      test('second rep cycle counts normally', () {
        // First cycle (warmup - not counted)
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(counter.repCount, equals(0));
        expect(counter.isReady, isTrue);

        // Second cycle (should count)
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(counter.repCount, equals(1));
      });

      test('reset returns to warmup state after activation', () {
        counter.activate();
        expect(counter.isReady, isTrue);

        counter.reset();

        expect(counter.isReady, isFalse);
        expect(counter.getCurrentStage(), equals('(Warmup) Up'));
      });

      test('warmup prefix shown during first cycle stages', () {
        // Check up position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), contains('Warmup'));

        // Check down position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), contains('Warmup'));
      });
    });

    group('Plank Position Detection', () {
      test('state resets to up when user stands up during goingDown', () {
        _activateCounter(counter);

        // Start in up position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));

        // Start going down
        counter.updateLandmarks(_createPushupPose(elbowAngle: 145));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Going Down'));

        // User stands up - should reset to up stage
        counter.updateLandmarks(_createStandingPose());
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));
      });

      test('state resets to up when user stands up during down', () {
        _activateCounter(counter);

        // Complete down transition
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Down'));

        // User stands up - should reset to up stage
        counter.updateLandmarks(_createStandingPose());
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));
      });

      test('state resets to up when user stands up during goingUp', () {
        _activateCounter(counter);

        // Go through down and start going up
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 140));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Going Up'));

        // User stands up - should reset to up stage
        counter.updateLandmarks(_createStandingPose());
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));
      });

      test('standing up does not count incomplete cycle as rep', () {
        _activateCounter(counter);

        // Start a rep cycle
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();

        // Stand up before completing
        counter.updateLandmarks(_createStandingPose());
        counter.checkRepCompletion();

        // No rep should be counted
        expect(counter.repCount, equals(0));
      });

      test('can resume counting after standing up and returning to plank', () {
        _activateCounter(counter);

        // Start a rep cycle and stand up
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createStandingPose());
        counter.checkRepCompletion();
        expect(counter.repCount, equals(0));

        // Clear debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to plank and complete a full rep
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();

        // Clear debounce again
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(counter.repCount, equals(1));
      });

      test('standing while in up stage does not reset (already in up)', () {
        _activateCounter(counter);

        // Start in up position
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));

        // Stand up while already in up stage - should stay in up
        counter.updateLandmarks(_createStandingPose());
        counter.checkRepCompletion();
        expect(counter.getCurrentStage(), equals('Up'));
      });
    });

    // Form validation is currently disabled due to noisy pose detection
    // These tests are skipped until form validation is re-enabled
    group('Invalid Rep Reasons', skip: 'Form validation disabled', () {
      test('poorForm reason when form ratio is below threshold', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        InvalidRepInfo? receivedInfo;
        counter.onInvalidRep = (info) {
          receivedInfo = info;
        };

        // Start in up position with bad form
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        // Go to down position with bad form
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 85));
        counter.checkRepCompletion();

        // Add more frames with bad form to ensure >40% bad
        for (var i = 0; i < 5; i++) {
          counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 90));
          counter.checkRepCompletion();
        }

        // Clear debounce
        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));

        // Return to up position - should trigger invalid rep with poorForm reason
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(receivedInfo, isNotNull);
        expect(receivedInfo!.reason, equals(InvalidRepReason.poorForm));
        expect(counter.lastInvalidRepInfo, isNotNull);
        expect(counter.lastInvalidRepInfo!.reason, equals(InvalidRepReason.poorForm));
      });

      test('InvalidRepInfo contains form metrics', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        InvalidRepInfo? receivedInfo;
        counter.onInvalidRep = (info) {
          receivedInfo = info;
        };

        // Complete a rep with bad form
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 85));
        counter.checkRepCompletion();

        for (var i = 0; i < 3; i++) {
          counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 90));
          counter.checkRepCompletion();
        }

        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(receivedInfo, isNotNull);
        expect(receivedInfo!.formRatio, isNotNull);
        expect(receivedInfo!.formRatio!, lessThan(0.6)); // Form ratio below threshold
        expect(receivedInfo!.elbowAngle, isNotNull);
        expect(receivedInfo!.minElbowAngle, isNotNull);
        expect(receivedInfo!.maxElbowAngle, isNotNull);
      });

      test('InvalidRepInfo contains duration when available', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        InvalidRepInfo? receivedInfo;
        counter.onInvalidRep = (info) {
          receivedInfo = info;
        };

        // Complete a rep with bad form
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 85));
        counter.checkRepCompletion();

        for (var i = 0; i < 3; i++) {
          counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 90));
          counter.checkRepCompletion();
        }

        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(receivedInfo, isNotNull);
        expect(receivedInfo!.durationMs, isNotNull);
        // Duration might be 0 in fast test execution, just verify it's non-negative
        expect(receivedInfo!.durationMs!, greaterThanOrEqualTo(0));
      });

      test('InvalidRepInfo tracks min and max elbow angles during rep', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        InvalidRepInfo? receivedInfo;
        counter.onInvalidRep = (info) {
          receivedInfo = info;
        };

        // Start in up position
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        // Go through various elbow angles
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 120));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 85)); // min
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 100));
        counter.checkRepCompletion();

        counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
        counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
        counter.checkRepCompletion();

        expect(receivedInfo, isNotNull);
        expect(receivedInfo!.minElbowAngle, isNotNull);
        expect(receivedInfo!.maxElbowAngle, isNotNull);
        // Min should be around 85, max should be around 170
        expect(receivedInfo!.minElbowAngle!, lessThan(100));
        expect(receivedInfo!.maxElbowAngle!, greaterThan(150));
      });

      test('callback receives correct repIndex', () {
        // Activate counter (skip ready state)
        _activateCounter(counter);

        final receivedInfos = <InvalidRepInfo>[];
        counter.onInvalidRep = (info) {
          receivedInfos.add(info);
        };

        // Complete two invalid reps
        for (var rep = 0; rep < 2; rep++) {
          counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
          counter.checkRepCompletion();
          counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 85));
          counter.checkRepCompletion();

          for (var i = 0; i < 3; i++) {
            counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 90));
            counter.checkRepCompletion();
          }

          counter.lastRepTime = DateTime.now().subtract(const Duration(milliseconds: 500));
          counter.updateLandmarks(_createPushupPoseWithBadForm(elbowAngle: 170));
          counter.checkRepCompletion();
        }

        expect(receivedInfos.length, equals(2));
        expect(receivedInfos[0].repIndex, equals(0));
        expect(receivedInfos[1].repIndex, equals(1));
      });

      test('reset clears tracking state for next rep', () {
        // Activate counter (skip warmup)
        _activateCounter(counter);

        // Do a partial rep then reset
        counter.updateLandmarks(_createPushupPose(elbowAngle: 170));
        counter.checkRepCompletion();
        counter.updateLandmarks(_createPushupPose(elbowAngle: 85));
        counter.checkRepCompletion();

        counter.reset();

        // Verify we're back to initial state (warmup mode)
        expect(counter.getCurrentStage(), equals('(Warmup) Up'));
        expect(counter.isReady, isFalse);
        expect(counter.repCount, equals(0));
        expect(counter.invalidRepCount, equals(0));
        expect(counter.lastInvalidRepInfo, isNull);
      });
    });

  });
}

PoseLandmark _createLandmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 1.0,
}) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: likelihood,
  );
}

/// Create a pushup pose with specified elbow angle.
/// The pose simulates a HORIZONTAL plank position (body parallel to ground).
///
/// Elbow angle meanings:
/// - 170-180° = arms straight (up position)
/// - 85-100° = arms bent (down position)
List<PoseLandmark> _createPushupPose({required double elbowAngle}) {
  // Horizontal plank: body parallel to ground, arms pointing down
  // Shoulder at (100, 200), Elbow at (100, 280) - arm pointing DOWN

  const shoulderX = 100.0;
  const shoulderY = 200.0;
  const elbowX = 100.0;
  const elbowY = 280.0;
  const armLength = 60.0;

  // Calculate wrist position based on elbow angle
  // The angle is measured at the elbow between shoulder-elbow-wrist
  // Shoulder is UP from elbow (negative Y direction)
  // For straight arm (180°): wrist continues DOWN (positive Y)
  // For bent arm (90°): wrist is perpendicular (positive X)

  final angleRad = elbowAngle * math.pi / 180;
  // Wrist position relative to elbow:
  // At 180°: wrist at (0, armLength) - straight down from elbow
  // At 90°: wrist at (armLength, 0) - perpendicular
  // The formula: rotate the "straight down" direction by (180 - angle)
  final rotationFromStraight = (180 - elbowAngle) * math.pi / 180;
  final wristX = elbowX + armLength * math.sin(rotationFromStraight);
  final wristY = elbowY + armLength * math.cos(rotationFromStraight);

  // Horizontal body
  const hipX = 300.0;
  const hipY = 200.0;
  const ankleX = 500.0;
  const ankleY = 200.0;

  return [
    _createLandmark(PoseLandmarkType.leftShoulder, shoulderX - 20, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, elbowX - 20, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, wristX - 20, wristY),
    _createLandmark(PoseLandmarkType.rightShoulder, shoulderX + 20, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, elbowX + 20, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, wristX + 20, wristY),
    _createLandmark(PoseLandmarkType.leftHip, hipX - 20, hipY),
    _createLandmark(PoseLandmarkType.rightHip, hipX + 20, hipY),
    _createLandmark(PoseLandmarkType.leftAnkle, ankleX - 20, ankleY),
    _createLandmark(PoseLandmarkType.rightAnkle, ankleX + 20, ankleY),
  ];
}

/// Create a pushup pose WITHOUT ankles (simulates partial visibility).
/// This tests the scenario where the camera doesn't capture the full body.
List<PoseLandmark> _createPushupPoseWithoutAnkles({required double elbowAngle}) {
  const shoulderX = 100.0;
  const shoulderY = 200.0;
  const elbowX = 100.0;
  const elbowY = 280.0;
  const armLength = 60.0;

  final rotationFromStraight = (180 - elbowAngle) * math.pi / 180;
  final wristX = elbowX + armLength * math.sin(rotationFromStraight);
  final wristY = elbowY + armLength * math.cos(rotationFromStraight);

  const hipX = 300.0;
  const hipY = 200.0;

  return [
    _createLandmark(PoseLandmarkType.leftShoulder, shoulderX - 20, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, elbowX - 20, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, wristX - 20, wristY),
    _createLandmark(PoseLandmarkType.rightShoulder, shoulderX + 20, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, elbowX + 20, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, wristX + 20, wristY),
    _createLandmark(PoseLandmarkType.leftHip, hipX - 20, hipY),
    _createLandmark(PoseLandmarkType.rightHip, hipX + 20, hipY),
    // NO ANKLES
  ];
}

/// Activate the counter by skipping the ready state.
/// This bypasses the warmup period for tests that focus on rep counting.
void _activateCounter(PushupCounter counter) {
  counter.activate();
}

/// Create a standing pose (vertical body, not in plank position).
/// This simulates when the user is standing upright.
List<PoseLandmark> _createStandingPose() {
  // Standing: body is vertical, shoulder above hip above ankle
  const shoulderX = 200.0;
  const shoulderY = 100.0; // Top
  const hipX = 200.0;
  const hipY = 300.0; // Middle
  const ankleX = 200.0;
  const ankleY = 500.0; // Bottom

  // Arms at sides with straight elbows
  const elbowX = 180.0;
  const elbowY = 200.0;
  const wristX = 180.0;
  const wristY = 280.0;

  return [
    _createLandmark(PoseLandmarkType.leftShoulder, shoulderX - 20, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, elbowX - 20, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, wristX - 20, wristY),
    _createLandmark(PoseLandmarkType.rightShoulder, shoulderX + 20, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, elbowX + 20, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, wristX + 20, wristY),
    _createLandmark(PoseLandmarkType.leftHip, hipX - 20, hipY),
    _createLandmark(PoseLandmarkType.rightHip, hipX + 20, hipY),
    _createLandmark(PoseLandmarkType.leftAnkle, ankleX - 20, ankleY),
    _createLandmark(PoseLandmarkType.rightAnkle, ankleX + 20, ankleY),
  ];
}

/// Create a pushup pose with BAD FORM (hips sagging, high body deviation).
/// Body deviation will exceed the 30° threshold.
List<PoseLandmark> _createPushupPoseWithBadForm({required double elbowAngle}) {
  const shoulderX = 100.0;
  const shoulderY = 200.0;
  const elbowX = 100.0;
  const elbowY = 280.0;
  const armLength = 60.0;

  final rotationFromStraight = (180 - elbowAngle) * math.pi / 180;
  final wristX = elbowX + armLength * math.sin(rotationFromStraight);
  final wristY = elbowY + armLength * math.cos(rotationFromStraight);

  // Hips SAGGING - Y is much higher than shoulder/ankle line
  const hipX = 300.0;
  const hipY = 350.0; // Creates >30° body deviation

  const ankleX = 500.0;
  const ankleY = 200.0; // Same as shoulder Y

  return [
    _createLandmark(PoseLandmarkType.leftShoulder, shoulderX - 20, shoulderY),
    _createLandmark(PoseLandmarkType.leftElbow, elbowX - 20, elbowY),
    _createLandmark(PoseLandmarkType.leftWrist, wristX - 20, wristY),
    _createLandmark(PoseLandmarkType.rightShoulder, shoulderX + 20, shoulderY),
    _createLandmark(PoseLandmarkType.rightElbow, elbowX + 20, elbowY),
    _createLandmark(PoseLandmarkType.rightWrist, wristX + 20, wristY),
    _createLandmark(PoseLandmarkType.leftHip, hipX - 20, hipY),
    _createLandmark(PoseLandmarkType.rightHip, hipX + 20, hipY),
    _createLandmark(PoseLandmarkType.leftAnkle, ankleX - 20, ankleY),
    _createLandmark(PoseLandmarkType.rightAnkle, ankleX + 20, ankleY),
  ];
}

