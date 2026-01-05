# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-Powered Bodyweight Exercise Tracker built with Flutter that uses on-device Computer Vision (Google ML Kit Pose Detection) to track and validate pushups, burpees, and other bodyweight exercises in real-time.

**Key Technical Constraints:**
- 100% offline operation - all processing happens on-device
- No video data leaves the device
- Local SQLite storage for workout history
- Target 30fps pose detection with <100ms rep registration latency

## Development Commands

### Flutter Commands
```bash
# Run app in debug mode
flutter run

# Run on specific device
flutter devices
flutter run -d <device-id>

# Build for production
flutter build apk          # Android
flutter build ios          # iOS
flutter build appbundle    # Android App Bundle

# Run tests
flutter test                    # Run all tests
flutter test test/path/to/test  # Run specific test

# Analyze code
flutter analyze

# Clean build artifacts
flutter clean
```

### Dependencies
Core packages required:
- `google_mlkit_pose_detection` - ML Kit for pose detection (33 landmarks)
- `camera` - Camera integration
- `sqflite` - Local SQLite database
- `provider` or `riverpod` - State management

## Architecture Overview

### Exercise Detection System

The app uses a **polymorphic exercise counter architecture** with an abstract base class:

```dart
abstract class ExerciseCounter {
  List<PoseLandmark> landmarks;

  void updateLandmarks(List<PoseLandmark> newLandmarks);
  bool isValidPose();          // Check if all required landmarks detected
  String getCurrentStage();     // "Up"/"Down" for pushups, state for burpees
  bool checkRepCompletion();    // Returns true when full rep completed
  Map<String, double> getDebugAngles();
}
```

Each exercise implements this interface:
- **PushupCounter**: Tracks elbow angle transitions (Up ≥160° → Down ≤90° → Up)
- **BurpeeCounter**: 4-state machine (Standing → Squat/Plank → Pushup → Jump)

### Angle Calculation

All joint angles use **Law of Cosines** on ML Kit pose landmarks:

```dart
// For angle θ at joint B between points A-B-C:
// cos(θ) = (a² + b² - c²) / (2ab)
// where a = distance(A,B), b = distance(B,C), c = distance(A,C)

double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c)
```

Key validation angles:
- **Elbow**: shoulder → elbow → wrist
- **Hip**: shoulder → hip → knee/ankle
- **Body alignment**: Check shoulder-hip-ankle linearity (deviation <15°)

### State Management

Use a centralized `WorkoutManager` (via Provider/Riverpod) managing:

1. **Pose State**: Current landmarks, confidence scores, body visibility
2. **Exercise State**: Active ExerciseCounter instance, current stage, rep counts (valid + invalid)
3. **Workout State**: Mode (Timer/RepGoal/Free), target values, elapsed time, pause state

### Workout Modes

Three distinct modes with different termination criteria:

| Mode | Timer Behavior | Goal | Auto-Complete |
|------|----------------|------|---------------|
| Timer | Countdown from X seconds | AMRAP | Yes (time reaches 0) |
| Rep Goal | Count up | X reps target | Yes (target reached) |
| Free | Count up | None | No (manual stop) |

### Database Schema

**Workouts Table** tracks all sessions with:
- Exercise type + variant (Standard/Modified for burpees)
- Mode and target value
- `reps_completed` vs `reps_invalid` (attempts that didn't meet form criteria)
- Duration, average rep time, completion status
- ISO 8601 timestamp

Query patterns needed:
- Date range filtering for history view
- Aggregations for statistics (total reps, personal bests)

### UI Layers

1. **Selection Screen**: Exercise + variant picker → Mode selector → Start
2. **Tracking Screen**:
   - Full-screen camera feed with CustomPainter skeletal overlay (green = good form, red = poor)
   - Large rep counter (72pt+)
   - Mode-specific progress indicator (countdown timer/progress bar/elapsed time)
   - Invalid rep badge
3. **History Screen**: Workout list + statistics summary with filtering

## Form Validation Rules

### Pushup Validation
- Elbow angle ≤90° (±10° tolerance) = Down position
- Elbow angle ≥160° (±10° tolerance) = Up position
- Body alignment: shoulder-hip-ankle deviation must be <15°
- Rep = Complete Up → Down → Up cycle

### Burpee Validation (4-state machine)
1. **Standing**: Hip angle >160°
2. **Squat/Plank**: Hip angle <90°, hands on ground
3. **Pushup**: Elbow ≤90° (Standard) OR skip (Modified variant)
4. **Jump**: Hip >170°, feet off ground
- Rep = Complete 1 → 2 → 3 → 4 → 1 cycle

### Invalid Rep Handling
- Partial range of motion → increment `reps_invalid`, show red flash
- Body misalignment → visual warning, don't count
- Incomplete state transitions → reset state machine
- Too-fast transitions (<0.3s) → ignore (likely detection error)

## Edge Cases & Detection Failures

When pose detection fails or quality is poor:

| Issue | Detection | UI Response |
|-------|-----------|-------------|
| User too far | Body height <40% of frame | "Move closer to camera" |
| User too close | Body beyond frame boundaries | "Step back from camera" |
| Poor lighting | Confidence <0.5 for >2s | "Improve lighting" |
| Body not visible | <25 of 33 landmarks detected | Pause counting, show warning |
| Wrong orientation | Shoulders not aligned | "Face the camera" |

## Performance Requirements

- **Frame rate**: 30fps pose detection minimum
- **Rep latency**: <100ms from completion to UI update
- **Startup time**: <2s from launch to ready state
- **Battery usage**: <10% drain per 10-minute workout

## Audio & Haptic Feedback

Provide multi-modal feedback for accessibility:
- Valid rep: distinct sound + light vibration + green flash
- Invalid rep: different sound + red flash
- Workout complete: completion sound + double vibration + celebration animation
- Timer mode: 3-2-1 countdown beeps at start

All audio must be toggleable for accessibility.

## Camera & Permissions

- Request camera permission only when starting workout, not at app launch
- Handle denial with explanation dialog + Settings button
- Auto-pause on app backgrounding/interruption
- Lock orientation (portrait/landscape) at workout start based on user preference

## Testing Approach

When testing exercise counters:
- Use recorded pose data streams to test state transitions
- Verify angle thresholds with edge cases (exactly 90°, 89°, 91°)
- Test rapid pose changes to catch debouncing issues
- Validate invalid rep detection with intentional form breaks
- Test all burpee variants (Standard/Modified) separately
