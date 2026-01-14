import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to capture and store training data (images + angles) for improving accuracy
class TrainingDataService {
  static const String _enabledKey = 'training_data_capture_enabled';

  bool _isEnabled = false;
  bool _isCapturing = false;
  CameraController? _cameraController;
  String? _sessionDir;
  int _captureCount = 0;

  bool get isEnabled => _isEnabled;

  /// Initialize the service and load settings
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
  }

  /// Toggle training data capture on/off
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Set the camera controller for capturing images
  void setCameraController(CameraController? controller) {
    _cameraController = controller;
  }

  /// Start a new capture session
  Future<void> startSession(String exerciseType) async {
    if (!_isEnabled) return;

    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    _sessionDir = '${appDir.path}/training_data/${exerciseType}_$timestamp';

    final dir = Directory(_sessionDir!);
    await dir.create(recursive: true);

    _captureCount = 0;
    print('[TRAINING] Started session: $_sessionDir');
  }

  /// Capture image at a specific stage with angle data
  Future<void> captureAtStage({
    required String stage,
    required Map<String, double> angles,
  }) async {
    print('[TRAINING] captureAtStage called: stage=$stage, enabled=$_isEnabled, capturing=$_isCapturing, hasController=${_cameraController != null}, hasSession=${_sessionDir != null}');

    if (!_isEnabled) {
      print('[TRAINING] Skipping: not enabled');
      return;
    }
    if (_isCapturing) {
      print('[TRAINING] Skipping: already capturing');
      return;
    }
    if (_cameraController == null) {
      print('[TRAINING] Skipping: no camera controller');
      return;
    }
    if (_sessionDir == null) {
      print('[TRAINING] Skipping: no session directory');
      return;
    }

    // Only capture at key stages
    if (stage != 'Up' && stage != 'Down') {
      print('[TRAINING] Skipping: stage is $stage, not Up or Down');
      return;
    }

    _isCapturing = true;
    print('[TRAINING] Starting capture for stage: $stage');

    try {
      // Capture the image
      print('[TRAINING] Taking picture...');
      final XFile image = await _cameraController!.takePicture();
      print('[TRAINING] Picture taken: ${image.path}');

      // Generate filename with stage and angles
      _captureCount++;
      final elbowAngle = angles['elbow']?.toStringAsFixed(1) ?? 'NA';
      final bodyDev = angles['bodyDeviation']?.toStringAsFixed(1) ?? 'NA';
      final filename = '${_captureCount.toString().padLeft(4, '0')}_${stage}_elbow${elbowAngle}_body$bodyDev';

      // Save image
      final imagePath = '$_sessionDir/$filename.jpg';
      print('[TRAINING] Copying to: $imagePath');
      await File(image.path).copy(imagePath);
      print('[TRAINING] Image saved');

      // Save metadata
      final metadata = {
        'timestamp': DateTime.now().toIso8601String(),
        'stage': stage,
        'angles': angles,
        'imagePath': imagePath,
      };

      final metadataPath = '$_sessionDir/$filename.json';
      await File(metadataPath).writeAsString(jsonEncode(metadata));
      print('[TRAINING] Metadata saved');

      print('[TRAINING] SUCCESS: Captured $filename (elbow: $elbowAngle°, bodyDev: $bodyDev°)');
    } catch (e, stackTrace) {
      print('[TRAINING] Capture FAILED: $e');
      print('[TRAINING] Stack trace: $stackTrace');
    } finally {
      _isCapturing = false;
    }
  }

  /// End the current session
  Future<void> endSession() async {
    if (_sessionDir != null) {
      print('[TRAINING] Session ended. Captured $_captureCount images.');
    }
    _sessionDir = null;
    _captureCount = 0;
  }

  /// Get list of all training sessions
  Future<List<TrainingSession>> getSessions() async {
    final appDir = await getApplicationDocumentsDirectory();
    final trainingDir = Directory('${appDir.path}/training_data');

    if (!await trainingDir.exists()) {
      return [];
    }

    final sessions = <TrainingSession>[];
    await for (final entity in trainingDir.list()) {
      if (entity is Directory) {
        final name = entity.path.split('/').last;
        final files = await entity.list().where((f) => f.path.endsWith('.jpg')).length;
        sessions.add(TrainingSession(
          path: entity.path,
          name: name,
          imageCount: files,
        ));
      }
    }

    return sessions;
  }

  /// Delete all training data
  Future<void> clearAllData() async {
    final appDir = await getApplicationDocumentsDirectory();
    final trainingDir = Directory('${appDir.path}/training_data');

    if (await trainingDir.exists()) {
      await trainingDir.delete(recursive: true);
      print('[TRAINING] All training data deleted');
    }
  }
}

class TrainingSession {
  final String path;
  final String name;
  final int imageCount;

  TrainingSession({
    required this.path,
    required this.name,
    required this.imageCount,
  });
}
