import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/rep_record.dart';

/// Captured frame with metadata.
class CapturedFrame {
  /// Path to the saved frame image
  final String path;

  /// Timestamp when the frame was captured
  final DateTime timestamp;

  /// Position type (e.g., 'down', 'up', 'transition')
  final String positionType;

  /// Elbow angle at capture
  final double? elbowAngle;

  /// Rep index this frame belongs to
  final int repIndex;

  CapturedFrame({
    required this.path,
    required this.timestamp,
    required this.positionType,
    required this.repIndex,
    this.elbowAngle,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'timestamp': timestamp.toIso8601String(),
      'positionType': positionType,
      'elbowAngle': elbowAngle,
      'repIndex': repIndex,
    };
  }

  factory CapturedFrame.fromMap(Map<String, dynamic> map) {
    return CapturedFrame(
      path: map['path'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      positionType: map['positionType'] as String,
      repIndex: map['repIndex'] as int,
      elbowAngle: map['elbowAngle'] as double?,
    );
  }
}

/// Service for capturing camera frames during reps for later review.
///
/// Captures key frames (down position, up position, transitions) during
/// invalid reps and stores them temporarily in the app cache for
/// post-workout review.
class RepFrameCaptureService {
  /// Session identifier for organizing frames
  String? _sessionId;

  /// Directory for storing captured frames
  Directory? _captureDir;

  /// Current rep index
  int _currentRepIndex = 0;

  /// Frames captured for current rep
  final List<CapturedFrame> _currentRepFrames = [];

  /// All frames captured for the session
  final List<CapturedFrame> _sessionFrames = [];

  /// Whether capture is enabled for current rep
  bool _captureEnabled = false;

  /// Whether the service is initialized
  bool _isInitialized = false;

  /// Last captured frame timestamp (for rate limiting)
  DateTime? _lastCaptureTime;

  /// Minimum interval between captures (ms)
  static const int _minCaptureIntervalMs = 100;

  /// Maximum frames per rep
  static const int _maxFramesPerRep = 5;

  /// All captured frames for the session
  List<CapturedFrame> get sessionFrames => List.unmodifiable(_sessionFrames);

  /// Frames for current rep
  List<CapturedFrame> get currentRepFrames => List.unmodifiable(_currentRepFrames);

  /// Current session ID
  String? get sessionId => _sessionId;

  /// Whether capture is enabled
  bool get isCaptureEnabled => _captureEnabled;

  /// Initialize the capture service for a new workout session.
  Future<void> startSession() async {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentRepIndex = 0;
    _sessionFrames.clear();
    _currentRepFrames.clear();
    _captureEnabled = false;

    // Create capture directory in app cache
    final cacheDir = await getTemporaryDirectory();
    _captureDir = Directory('${cacheDir.path}/rep_frames/$_sessionId');
    await _captureDir!.create(recursive: true);

    _isInitialized = true;
  }

  /// End the current session.
  void endSession() {
    _isInitialized = false;
    _sessionId = null;
    _currentRepIndex = 0;
  }

  /// Start capturing frames for a new rep.
  /// Call this at the start of each rep.
  void startRep(int repIndex) {
    _currentRepIndex = repIndex;
    _currentRepFrames.clear();
    _lastCaptureTime = null;
  }

  /// Enable frame capture for the current rep.
  /// Only enable for reps that may be invalid to save storage.
  void enableCapture() {
    _captureEnabled = true;
  }

  /// Disable frame capture.
  void disableCapture() {
    _captureEnabled = false;
  }

  /// Mark the current rep as complete and save frames to session.
  ///
  /// [isInvalid] - If true, frames are kept for review. If false, frames are discarded.
  /// Returns list of frame paths if kept.
  List<String> completeRep({required bool isInvalid}) {
    if (isInvalid && _currentRepFrames.isNotEmpty) {
      _sessionFrames.addAll(_currentRepFrames);
      final paths = _currentRepFrames.map((f) => f.path).toList();
      _currentRepFrames.clear();
      _captureEnabled = false;
      return paths;
    } else {
      // Discard frames for valid reps
      _cleanupCurrentRepFrames();
      _captureEnabled = false;
      return [];
    }
  }

  /// Capture a frame at a specific position.
  ///
  /// [image] - Camera image to capture
  /// [positionType] - Type of position ('down', 'up', 'transition')
  /// [elbowAngle] - Current elbow angle
  Future<CapturedFrame?> captureFrame({
    required CameraImage image,
    required String positionType,
    double? elbowAngle,
  }) async {
    if (!_isInitialized || _captureDir == null) return null;
    if (!_captureEnabled) return null;
    if (_currentRepFrames.length >= _maxFramesPerRep) return null;

    // Rate limit captures
    final now = DateTime.now();
    if (_lastCaptureTime != null) {
      final elapsed = now.difference(_lastCaptureTime!).inMilliseconds;
      if (elapsed < _minCaptureIntervalMs) return null;
    }
    _lastCaptureTime = now;

    try {
      final filename = '${_currentRepIndex}_${positionType}_${now.millisecondsSinceEpoch}.jpg';
      final filePath = '${_captureDir!.path}/$filename';

      // Convert CameraImage to bytes and save
      final bytes = _convertCameraImageToJpeg(image);
      if (bytes == null) return null;

      await File(filePath).writeAsBytes(bytes);

      final frame = CapturedFrame(
        path: filePath,
        timestamp: now,
        positionType: positionType,
        repIndex: _currentRepIndex,
        elbowAngle: elbowAngle,
      );

      _currentRepFrames.add(frame);
      return frame;
    } catch (e) {
      debugPrint('Failed to capture frame: $e');
      return null;
    }
  }

  /// Capture frame from raw bytes (for testing or pre-converted images).
  Future<CapturedFrame?> captureFrameFromBytes({
    required Uint8List bytes,
    required String positionType,
    double? elbowAngle,
  }) async {
    if (!_isInitialized || _captureDir == null) return null;
    if (!_captureEnabled) return null;
    if (_currentRepFrames.length >= _maxFramesPerRep) return null;

    final now = DateTime.now();
    _lastCaptureTime = now;

    try {
      final filename = '${_currentRepIndex}_${positionType}_${now.millisecondsSinceEpoch}.jpg';
      final filePath = '${_captureDir!.path}/$filename';

      await File(filePath).writeAsBytes(bytes);

      final frame = CapturedFrame(
        path: filePath,
        timestamp: now,
        positionType: positionType,
        repIndex: _currentRepIndex,
        elbowAngle: elbowAngle,
      );

      _currentRepFrames.add(frame);
      return frame;
    } catch (e) {
      debugPrint('Failed to capture frame from bytes: $e');
      return null;
    }
  }

  /// Get frames for a specific rep index.
  List<CapturedFrame> getFramesForRep(int repIndex) {
    return _sessionFrames.where((f) => f.repIndex == repIndex).toList();
  }

  /// Associate captured frames with a RepRecord.
  void attachFramesToRepRecord(RepRecord record) {
    final frames = getFramesForRep(record.repIndex);
    // Note: RepRecord.framePaths is final, so we need to ensure
    // frames are captured before the RepRecord is created.
    // This method is for documentation purposes - actual integration
    // should pass frame paths during RepRecord creation.
  }

  /// Get frame paths for a rep index (for RepRecord creation).
  List<String> getFramePathsForRep(int repIndex) {
    return getFramesForRep(repIndex).map((f) => f.path).toList();
  }

  /// Clean up all frames for the current session.
  Future<void> cleanupSession() async {
    if (_captureDir != null && await _captureDir!.exists()) {
      await _captureDir!.delete(recursive: true);
    }
    _sessionFrames.clear();
    _currentRepFrames.clear();
  }

  /// Clean up frames for specific rep indices (after review).
  Future<void> cleanupReps(List<int> repIndices) async {
    for (final repIndex in repIndices) {
      final frames = getFramesForRep(repIndex);
      for (final frame in frames) {
        try {
          final file = File(frame.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Failed to delete frame: ${frame.path}');
        }
      }
      _sessionFrames.removeWhere((f) => f.repIndex == repIndex);
    }
  }

  /// Clean up old sessions (call periodically or at app start).
  Future<void> cleanupOldSessions({int maxAgeHours = 24}) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final framesDir = Directory('${cacheDir.path}/rep_frames');

      if (!await framesDir.exists()) return;

      final cutoff = DateTime.now().subtract(Duration(hours: maxAgeHours));

      await for (final entity in framesDir.list()) {
        if (entity is Directory) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete(recursive: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup old sessions: $e');
    }
  }

  void _cleanupCurrentRepFrames() {
    for (final frame in _currentRepFrames) {
      try {
        File(frame.path).deleteSync();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
    _currentRepFrames.clear();
  }

  /// Convert CameraImage to JPEG bytes.
  ///
  /// Note: This is a simplified conversion. For production, consider using
  /// platform-specific image conversion or the `image` package for better
  /// quality and format support.
  Uint8List? _convertCameraImageToJpeg(CameraImage image) {
    try {
      // For NV21/YUV formats (Android) and BGRA (iOS), we need proper conversion.
      // This is a placeholder that stores raw bytes - in production, use proper
      // image encoding library.

      if (image.planes.isEmpty) return null;

      // Concatenate all planes into raw bytes
      // Note: This won't produce a valid JPEG without proper encoding
      // For MVP, we store raw bytes and the review screen can render them
      // or we can add proper JPEG encoding later.
      final WriteBuffer buffer = WriteBuffer();
      for (final plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }
      return buffer.done().buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to convert camera image: $e');
      return null;
    }
  }
}
