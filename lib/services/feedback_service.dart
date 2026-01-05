import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for audio and haptic feedback during workouts.
///
/// Provides multi-modal feedback for accessibility:
/// - Distinct audio sounds for rep completion, invalid reps, countdown, etc.
/// - Haptic feedback for rep events
///
/// All feedback can be toggled via settings.
class FeedbackService {
  static const String _audioEnabledKey = 'audio_enabled';
  static const String _hapticEnabledKey = 'haptic_enabled';

  bool _audioEnabled = true;
  bool _hapticEnabled = true;
  bool _initialized = false;

  // Audio players for different sounds
  final AudioPlayer _repCompletePlayer = AudioPlayer();
  final AudioPlayer _invalidRepPlayer = AudioPlayer();
  final AudioPlayer _countdownPlayer = AudioPlayer();
  final AudioPlayer _workoutStartPlayer = AudioPlayer();
  final AudioPlayer _workoutCompletePlayer = AudioPlayer();
  final AudioPlayer _goalReachedPlayer = AudioPlayer();

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

    // Pre-load audio sources for faster playback
    await _preloadAudio();

    _initialized = true;
  }

  /// Pre-load audio files for instant playback
  Future<void> _preloadAudio() async {
    try {
      await _repCompletePlayer.setSource(AssetSource('audio/rep_complete.wav'));
      await _invalidRepPlayer.setSource(AssetSource('audio/invalid_rep.wav'));
      await _countdownPlayer.setSource(AssetSource('audio/countdown.wav'));
      await _workoutStartPlayer.setSource(AssetSource('audio/workout_start.wav'));
      await _workoutCompletePlayer.setSource(AssetSource('audio/workout_complete.wav'));
      await _goalReachedPlayer.setSource(AssetSource('audio/goal_reached.wav'));
    } catch (e) {
      // Audio files may not be available, fallback to system sounds
    }
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
      _playSound(_repCompletePlayer);
    }
  }

  /// Play feedback for an invalid rep attempt
  void onInvalidRep() {
    if (_hapticEnabled) {
      HapticFeedback.heavyImpact();
    }
    if (_audioEnabled) {
      _playSound(_invalidRepPlayer);
    }
  }

  /// Play countdown tick feedback
  void onCountdownTick() {
    if (_hapticEnabled) {
      HapticFeedback.selectionClick();
    }
    if (_audioEnabled) {
      _playSound(_countdownPlayer);
    }
  }

  /// Play workout start feedback
  void onWorkoutStart() {
    if (_hapticEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (_audioEnabled) {
      _playSound(_workoutStartPlayer);
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
      _playSound(_workoutCompletePlayer);
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
    if (_audioEnabled) {
      _playSound(_goalReachedPlayer);
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
      _playSound(_countdownPlayer);
    }
  }

  /// Play a sound using the given audio player
  Future<void> _playSound(AudioPlayer player) async {
    try {
      await player.stop();
      await player.resume();
    } catch (e) {
      // Fallback to system sound if audio player fails
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Dispose of resources
  void dispose() {
    _repCompletePlayer.dispose();
    _invalidRepPlayer.dispose();
    _countdownPlayer.dispose();
    _workoutStartPlayer.dispose();
    _workoutCompletePlayer.dispose();
    _goalReachedPlayer.dispose();
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
