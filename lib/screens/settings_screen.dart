import 'package:flutter/material.dart';
import '../services/feedback_service.dart';
import '../services/database_service.dart';
import '../services/gamification_service.dart';

/// Settings screen for configuring app preferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FeedbackService _feedback = FeedbackService();
  late final GamificationService _gamification;
  bool _audioEnabled = true;
  bool _hapticEnabled = true;
  bool _gamificationEnabled = true;
  bool _showStreak = true;
  bool _showBeatYesterday = true;
  bool _showMilestones = true;

  @override
  void initState() {
    super.initState();
    _gamification = GamificationService(DatabaseService());
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _feedback.initialize();
    final gamificationEnabled = await _gamification.isGamificationEnabled();
    final showStreak = await _gamification.shouldShowStreak();
    final showBeatYesterday = await _gamification.shouldShowBeatYesterday();
    final showMilestones = await _gamification.shouldShowMilestones();
    setState(() {
      _audioEnabled = _feedback.isAudioEnabled;
      _hapticEnabled = _feedback.isHapticEnabled;
      _gamificationEnabled = gamificationEnabled;
      _showStreak = showStreak;
      _showBeatYesterday = showBeatYesterday;
      _showMilestones = showMilestones;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Feedback'),
          SwitchListTile(
            title: const Text('Audio Feedback'),
            subtitle: const Text('Play sounds for rep completion and events'),
            value: _audioEnabled,
            onChanged: (value) async {
              await _feedback.setAudioEnabled(value);
              setState(() => _audioEnabled = value);
            },
            secondary: const Icon(Icons.volume_up),
          ),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibrate on rep completion and events'),
            value: _hapticEnabled,
            onChanged: (value) async {
              await _feedback.setHapticEnabled(value);
              setState(() => _hapticEnabled = value);
            },
            secondary: const Icon(Icons.vibration),
          ),
          const Divider(),
          _buildSectionHeader('Gamification'),
          SwitchListTile(
            title: const Text('Enable Gamification'),
            subtitle: const Text('Show streaks, milestones, and challenges'),
            value: _gamificationEnabled,
            onChanged: (value) async {
              await _gamification.setGamificationEnabled(value);
              setState(() => _gamificationEnabled = value);
            },
            secondary: const Icon(Icons.emoji_events_outlined),
          ),
          if (_gamificationEnabled) ...[
            SwitchListTile(
              title: const Text('Show Streak Counter'),
              subtitle: const Text('Display consecutive workout days'),
              value: _showStreak,
              onChanged: (value) async {
                await _gamification.setShowStreak(value);
                setState(() => _showStreak = value);
              },
              secondary: const Icon(Icons.local_fire_department_outlined),
            ),
            SwitchListTile(
              title: const Text('Show Beat Yesterday'),
              subtitle: const Text('Compare with yesterday\'s performance'),
              value: _showBeatYesterday,
              onChanged: (value) async {
                await _gamification.setShowBeatYesterday(value);
                setState(() => _showBeatYesterday = value);
              },
              secondary: const Icon(Icons.trending_up),
            ),
            SwitchListTile(
              title: const Text('Show Milestones'),
              subtitle: const Text('Celebrate cumulative achievements'),
              value: _showMilestones,
              onChanged: (value) async {
                await _gamification.setShowMilestones(value);
                setState(() => _showMilestones = value);
              },
              secondary: const Icon(Icons.flag_outlined),
            ),
          ],
          const Divider(),
          _buildSectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            subtitle: const Text('All data stays on your device'),
            onTap: () => _showPrivacyInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy'),
        content: const Text(
          'This app operates 100% offline. All pose detection happens on-device '
          'and no video data ever leaves your phone. Your workout history is '
          'stored locally using SQLite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
