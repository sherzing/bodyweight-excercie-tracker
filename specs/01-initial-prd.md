# Product Requirements Document (PRD): AI-Powered Bodyweight Exercise Tracker

## 1. Project Vision
A mobile application built with Flutter that uses on-device Computer Vision to track, validate, and count repetitions of bodyweight exercises (pushups, burpees, and future exercises) in real-time with intelligent form validation.

---

## 2. Technical Stack
* **Framework:** Flutter (Dart)
* **AI Engine:** Google ML Kit (Pose Detection API)
* **Local Storage:** SQLite (sqflite) or Hive
* **Camera Integration:** `camera` package with `CustomPainter` for skeletal overlays.

---

## 3. Functional Requirements

### 3.1 Exercise Detection & Logic
The app must detect 33 human body landmarks (ML Kit Pose Detection) to calculate joint angles and body alignment.

#### Pushup Logic
* **Elbow Angle Tracking:** Calculate angle at elbow joint using shoulder-elbow-wrist landmarks.
  * **Down Position:** Elbow angle ≤ 90° (tolerance: ±10°)
  * **Up Position:** Elbow angle ≥ 160° (tolerance: ±10°)
* **Body Alignment:** Shoulder-hip-ankle must maintain near-linear alignment (deviation < 15°).
* **Rep Validation:** Transition from Up → Down → Up completes one rep.

#### Burpee Logic
A multi-state machine tracking transitions through 4 stages:
1. **Standing:** Hip angle > 160°, body upright
2. **Squat/Plank:** Hip angle < 90°, hands on ground
3. **Pushup:**
   * **Standard Variant:** Must complete full pushup (elbow ≤ 90°)
   * **Modified Variant:** Skip pushup, go directly to jump
   * **User Selection:** Variant chosen at workout start
4. **Jump:** Full body extension with both feet off ground (hip angle > 170°)
* **Rep Validation:** Complete cycle through all 4 states.

#### Extensibility
* Must use an abstract class `ExerciseCounter` with methods:
  * `detectLandmarks(PoseData)`
  * `calculateAngles()`
  * `validateRep()`
  * `updateState()`
* New exercises (Squats, Lunges, Pull-ups) can be added as separate implementations.



### 3.2 Workout Modes
| Mode | Time Behavior | Goal | Progress Display |
| :--- | :--- | :--- | :--- |
| **Timer** | Count down from X seconds (e.g., 60s, 120s) | AMRAP (As Many Reps As Possible) | Time remaining + current rep count |
| **Rep Goal** | Count up from 0 | Stop once X reps reached (e.g., 20, 50, 100) | Reps completed/target + elapsed time |
| **Free Mode** | Count up from 0 | None (user manually stops) | Elapsed time + current rep count |

**Mode Behavior:**
* **Timer:** Workout ends automatically when time reaches 0. User sets duration (15s, 30s, 60s, 120s, 300s).
* **Rep Goal:** Workout ends automatically when target reps achieved. User sets target (10, 20, 50, 100).
* **Free Mode:** User presses stop button to end workout. No time/rep limits.

### 3.3 Data Persistence
All workout sessions must be saved to a local database (SQLite) with the following schema:

**Workouts Table:**
* `id`: INTEGER PRIMARY KEY AUTOINCREMENT
* `exercise_type`: TEXT (Pushup/Burpee/Squat)
* `exercise_variant`: TEXT (Standard/Modified) - for burpees
* `mode`: TEXT (Timer/RepGoal/Free)
* `target_value`: INTEGER (target seconds for Timer, target reps for RepGoal, NULL for Free)
* `reps_completed`: INTEGER (total valid reps)
* `reps_invalid`: INTEGER (attempted but invalid reps)
* `duration`: INTEGER (total time in seconds)
* `average_rep_time`: REAL (duration/reps in seconds)
* `date`: TEXT (ISO 8601 timestamp)
* `completed`: BOOLEAN (TRUE if target reached, FALSE if manually stopped)

**Database Operations:**
* Insert new workout on session completion
* Query by date range for history view
* Aggregate statistics (total reps, avg duration, personal bests)

---

## 4. User Interface (UI) Requirements

### 4.1 Selection Screen
* **Exercise Selection:** Grid/list of available exercises (Pushup, Burpee) with icons
* **Variant Selection:** For burpees, toggle between Standard/Modified
* **Mode Selection:** Three buttons (Timer, Rep Goal, Free)
* **Target Input:** Number picker for Timer duration or Rep goal
* **Start Button:** Large, prominent CTA to begin workout

### 4.2 Tracking Screen
* **Camera Feed:** Full-screen live video with 9:16 or 16:9 aspect ratio
* **Skeletal Overlay:** CustomPainter wireframe connecting 33 pose landmarks
  * Green lines: Good form detected
  * Red lines: Poor form or body not fully visible
* **Rep Counter:** Extra-large digits (72pt+) in top center, high contrast
* **Current State Indicator:** Text showing "Up", "Down", or burpee state
* **Progress Indicator:**
  * Timer mode: Circular countdown (e.g., "45s remaining")
  * Rep Goal mode: Linear progress bar (e.g., "12/20 reps")
  * Free mode: Elapsed time (e.g., "2:34")
* **Stop Button:** Bottom center, clearly visible
* **Invalid Rep Counter:** Small badge showing attempts that didn't count

### 4.3 History Screen
* **Workout List:** Chronological list (most recent first) with cards showing:
  * Exercise type + variant
  * Date and time
  * Reps completed
  * Duration
  * Mode badge
* **Statistics Summary:**
  * Total workouts this week/month
  * Total reps across all time
  * Personal bests (most reps in Timer mode, fastest time to X reps)
* **Filter/Sort:** By exercise type, date range

### 4.4 User Feedback
* **Audio Feedback:**
  * Distinct sound on valid rep completion
  * Different sound for invalid rep attempt
  * 3-2-1 countdown beep for Timer mode start
  * Completion sound when workout goal reached
* **Haptic Feedback:**
  * Light vibration on rep completion
  * Double vibration on workout complete
* **Visual Feedback:**
  * Flash screen border green on valid rep
  * Flash screen border red on invalid rep
  * Celebration animation on workout completion

---

## 5. Edge Cases & Error Handling

### 5.1 Pose Detection Failures
| Scenario | Detection Criteria | App Behavior |
| :--- | :--- | :--- |
| **User too far from camera** | Landmarks detected but body height < 40% of frame | Display warning: "Move closer to camera" |
| **User too close** | Body extends beyond frame boundaries | Display warning: "Step back from camera" |
| **Poor lighting** | Pose confidence < 0.5 for >2 seconds | Display warning: "Improve lighting" |
| **Body not in frame** | < 25 of 33 landmarks detected | Pause rep counting, show warning overlay |
| **Side-facing camera** | Shoulders not aligned with camera | Display: "Face the camera" |

### 5.2 Invalid Rep Scenarios
* **Partial Range of Motion:** Elbow doesn't reach required angle thresholds
  * Action: Don't increment counter, increment `reps_invalid`, show red flash
* **Body Misalignment:** Shoulder-hip-ankle deviation > 15° during pushup
  * Action: Visual warning, don't count rep
* **Incomplete Burpee:** Skipping a state in the sequence
  * Action: Reset state machine to Standing, don't count
* **Too Fast Motion:** State transition in < 0.3 seconds (likely detection error)
  * Action: Ignore transition, require sustained position

### 5.3 Camera & Permission Handling
* **Camera Permission Denied:** Show explanation dialog with "Settings" button
* **Camera Unavailable:** Graceful error message, prevent workout start
* **App Backgrounded:** Pause workout, save current progress
* **App Interrupted (call, notification):** Auto-pause with resume option

### 5.4 Device Compatibility
* **Minimum Requirements:**
  * iOS 12+ or Android 7.0+
  * Rear or front camera with 720p resolution
  * 2GB+ RAM for ML Kit processing
* **Orientation:** Lock to portrait or landscape based on user preference at workout start
* **Low-End Devices:** Reduce ML Kit detection frequency to 15fps if lag detected

---

## 6. Implementation Guide for Claude Code

### Phase 1: Setup
* Initialize Flutter project.
* Add dependencies: `google_mlkit_pose_detection`, `camera`, `sqflite`, `provider`.

### Phase 2: Pose Calculation
To validate exercises, calculate joint angles using the Law of Cosines.

**Elbow Angle Formula:**
For landmarks A (shoulder), B (elbow), C (wrist), find angle θ at elbow:
$$\cos(\theta) = \frac{a^2 + b^2 - c^2}{2ab}$$

Where:
* $a$ = distance from shoulder to elbow
* $b$ = distance from elbow to wrist
* $c$ = distance from shoulder to wrist

**Helper Functions:**
```dart
double calculateDistance(PoseLandmark a, PoseLandmark b)
double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c)
bool isBodyAligned(PoseLandmark shoulder, hip, ankle, threshold)
```

### Phase 3: State Management
Create a `WorkoutManager` class (using Provider or Riverpod) to handle:
* **Pose State:**
  * `landmarks`: List<PoseLandmark> (33 points)
  * `poseConfidence`: double (0.0 - 1.0)
  * `isFullBodyDetected`: bool
* **Exercise State:**
  * `currentExercise`: ExerciseCounter (polymorphic)
  * `currentStage`: String ("Up"/"Down" for pushups, state for burpees)
  * `repCount`: int
  * `invalidRepCount`: int
* **Workout State:**
  * `mode`: WorkoutMode enum
  * `targetValue`: int?
  * `elapsedTime`: Duration
  * `isActive`: bool
  * `isPaused`: bool

### Phase 4: Exercise Counter Architecture
```dart
abstract class ExerciseCounter {
  List<PoseLandmark> landmarks;

  void updateLandmarks(List<PoseLandmark> newLandmarks);
  bool isValidPose(); // Check if all required landmarks detected
  String getCurrentStage();
  bool checkRepCompletion(); // Returns true when full rep completed
  Map<String, double> getDebugAngles(); // For developer overlay
}

class PushupCounter extends ExerciseCounter { /* ... */ }
class BurpeeCounter extends ExerciseCounter { /* ... */ }
```

---

## 7. Constraints & Ethics

### 7.1 Privacy & Security
* **Local Processing Only:** All video processing must happen **on-device** using ML Kit. Zero video frames or pose data transmitted to servers.
* **No Cloud Dependencies:** App must function 100% offline after installation.
* **Data Storage:** All workout data stored locally in SQLite. No cloud sync in v1.0.
* **Camera Access:** Only request camera permission when user starts a workout, not on app launch.

### 7.2 Performance Requirements
* **Frame Rate:** Target 30fps for pose detection to ensure real-time feedback.
* **Latency:** Rep registration must occur within 100ms of completion for responsive feel.
* **Battery:** Optimize ML processing to avoid excessive battery drain (test for <10% drain per 10-minute workout).
* **Startup Time:** App should be ready to start workout within 2 seconds of launch.

### 7.3 Accessibility & Inclusivity
* **Body Diversity:** Algorithm should work across different body types, heights, and proportions.
* **Adaptive Thresholds:** Consider making angle thresholds configurable for users with limited mobility.
* **Sound Options:** All audio feedback must be optional (toggle on/off).
* **Color Blind Modes:** Don't rely solely on red/green for feedback (use icons/text too).

### 7.4 Safety & Disclaimers
* **Form Guidance:** App should not claim to replace professional fitness coaching.
* **Disclaimer:** Include warning that users should consult healthcare provider before starting new exercise program.
* **Injury Prevention:** Consider adding form tips screen before first use of each exercise.
