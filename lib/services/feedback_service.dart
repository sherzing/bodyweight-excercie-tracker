import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for audio and haptic feedback during workouts.
///
/// Provides multi-modal feedback for accessibility:
/// - Audio sounds for rep completion, invalid reps, and countdown
/// - Haptic feedback for rep events
///
/// All feedback can be toggled via settings.
class FeedbackService {
  static const String _audioEnabledKey = 'audio_enabled';
  static const String _hapticEnabledKey = 'haptic_enabled';

  bool _audioEnabled = true;
  bool _hapticEnabled = true;
  bool _initialized = false;

  // Singleton pattern
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  /// Initialize the service and load preferences
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _audioEnabled = prefs.getBool(_audioEnabledKey) ?? true;
    _hapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;
    _initialized = true;
  }

  /// Whether audio feedback is enabled
  bool get isAudioEnabled => _audioEnabled;

  /// Whether haptic feedback is enabled
  bool get isHapticEnabled => _hapticEnabled;

  /// Toggle audio feedback
  Future<void> setAudioEnabled(bool enabled) async {
    _audioEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_audioEnabledKey, enabled);
  }

  /// Toggle haptic feedback
  Future<void> setHapticEnabled(bool enabled) async {
    _hapticEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticEnabledKey, enabled);
  }

  /// Play feedback for a valid rep completion
  void onRepCompleted() {
    if (_hapticEnabled) {
      HapticFeedback.lightImpact();
    }
    if (_audioEnabled) {
      _playSystemSound(SystemSoundType.click);
    }
  }

  /// Play feedback for an invalid rep attempt
  void onInvalidRep() {
    if (_hapticEnabled) {
      HapticFeedback.heavyImpact();
    }
    // Note: For invalid reps we use haptic only to differentiate from valid reps
    // A more negative sound could be added with audioplayers if sound assets are available
  }

  /// Play countdown tick feedback
  void onCountdownTick() {
    if (_hapticEnabled) {
      HapticFeedback.selectionClick();
    }
    if (_audioEnabled) {
      _playSystemSound(SystemSoundType.click);
    }
  }

  /// Play workout start feedback
  void onWorkoutStart() {
    if (_hapticEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (_audioEnabled) {
      _playSystemSound(SystemSoundType.click);
    }
  }

  /// Play workout completion feedback
  void onWorkoutCompleted() {
    if (_hapticEnabled) {
      // Double vibration for completion
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.heavyImpact();
      });
    }
    if (_audioEnabled) {
      // Play completion sound
      _playSystemSound(SystemSoundType.click);
    }
  }

  /// Play goal reached feedback (for rep goal mode)
  void onGoalReached() {
    if (_hapticEnabled) {
      // Triple vibration for goal reached
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.mediumImpact();
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  /// Play feedback for position warning
  void onPositionWarning() {
    if (_hapticEnabled) {
      HapticFeedback.vibrate();
    }
  }

  /// Play timer end warning (last few seconds)
  void onTimerWarning() {
    if (_hapticEnabled) {
      HapticFeedback.selectionClick();
    }
    if (_audioEnabled) {
      _playSystemSound(SystemSoundType.click);
    }
  }

  /// Play system sound using Flutter's built-in method
  void _playSystemSound(SystemSoundType type) {
    SystemSound.play(type);
  }

  /// Dispose of resources
  void dispose() {
    // No cleanup needed for system sounds
  }
}

/// Types of feedback events
enum FeedbackType {
  repCompleted,
  invalidRep,
  countdownTick,
  workoutStart,
  workoutCompleted,
  goalReached,
  positionWarning,
  timerWarning,
}
