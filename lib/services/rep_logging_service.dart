import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invalid_rep_reason.dart';

/// Entry representing a single rep in the log
class RepLogEntry {
  /// Timestamp when the rep was completed
  final DateTime timestamp;

  /// Whether the rep was valid
  final bool isValid;

  /// Reason for invalid rep (null if valid)
  final InvalidRepReason? invalidReason;

  /// Elbow angle at completion (degrees)
  final double? elbowAngle;

  /// Body deviation at completion (degrees)
  final double? bodyDeviation;

  /// Form ratio during the rep (0.0 - 1.0)
  final double? formRatio;

  /// Duration of the rep in milliseconds
  final int? durationMs;

  /// Minimum elbow angle reached during rep
  final double? minElbowAngle;

  /// Maximum elbow angle reached during rep
  final double? maxElbowAngle;

  /// Rep index within the session (0-based)
  final int repIndex;

  RepLogEntry({
    required this.timestamp,
    required this.isValid,
    required this.repIndex,
    this.invalidReason,
    this.elbowAngle,
    this.bodyDeviation,
    this.formRatio,
    this.durationMs,
    this.minElbowAngle,
    this.maxElbowAngle,
  });

  /// Create from InvalidRepInfo for invalid reps
  factory RepLogEntry.fromInvalidRepInfo(InvalidRepInfo info, int sessionRepIndex) {
    return RepLogEntry(
      timestamp: info.timestamp,
      isValid: false,
      repIndex: sessionRepIndex,
      invalidReason: info.reason,
      elbowAngle: info.elbowAngle,
      bodyDeviation: info.bodyDeviation,
      formRatio: info.formRatio,
      durationMs: info.durationMs,
      minElbowAngle: info.minElbowAngle,
      maxElbowAngle: info.maxElbowAngle,
    );
  }

  /// Create for a valid rep
  factory RepLogEntry.valid({
    required int repIndex,
    double? elbowAngle,
    double? bodyDeviation,
    double? formRatio,
    int? durationMs,
    double? minElbowAngle,
    double? maxElbowAngle,
  }) {
    return RepLogEntry(
      timestamp: DateTime.now(),
      isValid: true,
      repIndex: repIndex,
      elbowAngle: elbowAngle,
      bodyDeviation: bodyDeviation,
      formRatio: formRatio,
      durationMs: durationMs,
      minElbowAngle: minElbowAngle,
      maxElbowAngle: maxElbowAngle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'isValid': isValid,
      'repIndex': repIndex,
      if (invalidReason != null) 'invalidReason': invalidReason!.name,
      if (elbowAngle != null) 'elbowAngle': elbowAngle,
      if (bodyDeviation != null) 'bodyDeviation': bodyDeviation,
      if (formRatio != null) 'formRatio': formRatio,
      if (durationMs != null) 'durationMs': durationMs,
      if (minElbowAngle != null) 'minElbowAngle': minElbowAngle,
      if (maxElbowAngle != null) 'maxElbowAngle': maxElbowAngle,
    };
  }

  factory RepLogEntry.fromJson(Map<String, dynamic> json) {
    return RepLogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      isValid: json['isValid'] as bool,
      repIndex: json['repIndex'] as int,
      invalidReason: json['invalidReason'] != null
          ? InvalidRepReason.values.byName(json['invalidReason'] as String)
          : null,
      elbowAngle: json['elbowAngle'] as double?,
      bodyDeviation: json['bodyDeviation'] as double?,
      formRatio: json['formRatio'] as double?,
      durationMs: json['durationMs'] as int?,
      minElbowAngle: json['minElbowAngle'] as double?,
      maxElbowAngle: json['maxElbowAngle'] as double?,
    );
  }
}

/// Metadata for a logging session
class SessionMetadata {
  /// Unique session identifier
  final String sessionId;

  /// Type of exercise (e.g., 'Pushups', 'Burpees')
  final String exerciseType;

  /// Exercise variant (e.g., 'Standard', 'Modified')
  final String variant;

  /// Session start time
  final DateTime startTime;

  /// Session end time (null if ongoing)
  DateTime? endTime;

  /// Device platform (iOS/Android)
  final String platform;

  /// Total valid reps in session
  int validRepCount;

  /// Total invalid reps in session
  int invalidRepCount;

  SessionMetadata({
    required this.sessionId,
    required this.exerciseType,
    required this.variant,
    required this.startTime,
    this.endTime,
    required this.platform,
    this.validRepCount = 0,
    this.invalidRepCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'exerciseType': exerciseType,
      'variant': variant,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      'platform': platform,
      'validRepCount': validRepCount,
      'invalidRepCount': invalidRepCount,
    };
  }

  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    return SessionMetadata(
      sessionId: json['sessionId'] as String,
      exerciseType: json['exerciseType'] as String,
      variant: json['variant'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      platform: json['platform'] as String,
      validRepCount: json['validRepCount'] as int? ?? 0,
      invalidRepCount: json['invalidRepCount'] as int? ?? 0,
    );
  }
}

/// Service for logging detailed per-rep data for debugging purposes.
/// Stores data in JSONL format (one JSON object per line) for easy parsing.
class RepLoggingService {
  static const String _logDirName = 'rep_logs';

  SessionMetadata? _currentSession;
  File? _currentLogFile;
  IOSink? _logSink;
  int _repCounter = 0;

  /// Whether a logging session is currently active
  bool get isSessionActive => _currentSession != null;

  /// Current session metadata (null if no active session)
  SessionMetadata? get currentSession => _currentSession;

  /// Start a new logging session
  Future<void> startSession({
    required String exerciseType,
    required String variant,
  }) async {
    // End any existing session first
    await endSession();

    final sessionId = _generateSessionId();
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'iOS'
        : defaultTargetPlatform == TargetPlatform.android
            ? 'Android'
            : 'Unknown';

    _currentSession = SessionMetadata(
      sessionId: sessionId,
      exerciseType: exerciseType,
      variant: variant,
      startTime: DateTime.now(),
      platform: platform,
    );

    // Create log file
    final logDir = await _getLogDirectory();
    _currentLogFile = File('${logDir.path}/$sessionId.jsonl');

    // Open file for appending
    _logSink = _currentLogFile!.openWrite(mode: FileMode.append);

    // Write session metadata as first line
    _logSink!.writeln(jsonEncode({
      'type': 'session_start',
      'metadata': _currentSession!.toJson(),
    }));

    _repCounter = 0;
  }

  /// Log a valid rep
  Future<void> logValidRep({
    double? elbowAngle,
    double? bodyDeviation,
    double? formRatio,
    int? durationMs,
    double? minElbowAngle,
    double? maxElbowAngle,
  }) async {
    if (!isSessionActive || _logSink == null) return;

    final entry = RepLogEntry.valid(
      repIndex: _repCounter,
      elbowAngle: elbowAngle,
      bodyDeviation: bodyDeviation,
      formRatio: formRatio,
      durationMs: durationMs,
      minElbowAngle: minElbowAngle,
      maxElbowAngle: maxElbowAngle,
    );

    _logSink!.writeln(jsonEncode({
      'type': 'rep',
      'data': entry.toJson(),
    }));

    _repCounter++;
    _currentSession!.validRepCount++;
  }

  /// Log an invalid rep from InvalidRepInfo
  Future<void> logInvalidRep(InvalidRepInfo info) async {
    if (!isSessionActive || _logSink == null) return;

    final entry = RepLogEntry.fromInvalidRepInfo(info, _repCounter);

    _logSink!.writeln(jsonEncode({
      'type': 'rep',
      'data': entry.toJson(),
    }));

    _repCounter++;
    _currentSession!.invalidRepCount++;
  }

  /// End the current logging session
  Future<void> endSession() async {
    if (!isSessionActive) return;

    _currentSession!.endTime = DateTime.now();

    // Write session end marker
    if (_logSink != null) {
      _logSink!.writeln(jsonEncode({
        'type': 'session_end',
        'metadata': _currentSession!.toJson(),
      }));

      await _logSink!.flush();
      await _logSink!.close();
    }

    _logSink = null;
    _currentLogFile = null;
    _currentSession = null;
    _repCounter = 0;
  }

  /// Get list of all logged sessions
  Future<List<SessionMetadata>> getSessions() async {
    final logDir = await _getLogDirectory();
    if (!await logDir.exists()) {
      return [];
    }

    final sessions = <SessionMetadata>[];

    await for (final entity in logDir.list()) {
      if (entity is File && entity.path.endsWith('.jsonl')) {
        try {
          final metadata = await _readSessionMetadata(entity);
          if (metadata != null) {
            sessions.add(metadata);
          }
        } catch (e) {
          // Skip corrupted files
        }
      }
    }

    // Sort by start time, newest first
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  /// Read all rep entries from a session file
  Future<List<RepLogEntry>> getSessionReps(String sessionId) async {
    final logDir = await _getLogDirectory();
    final file = File('${logDir.path}/$sessionId.jsonl');

    if (!await file.exists()) {
      return [];
    }

    final reps = <RepLogEntry>[];
    final lines = await file.readAsLines();

    for (final line in lines) {
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json['type'] == 'rep') {
          reps.add(RepLogEntry.fromJson(json['data'] as Map<String, dynamic>));
        }
      } catch (e) {
        // Skip malformed lines
      }
    }

    return reps;
  }

  /// Delete a specific session log
  Future<void> deleteSession(String sessionId) async {
    final logDir = await _getLogDirectory();
    final file = File('${logDir.path}/$sessionId.jsonl');

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Delete all session logs
  Future<void> clearAllLogs() async {
    final logDir = await _getLogDirectory();
    if (await logDir.exists()) {
      await logDir.delete(recursive: true);
    }
  }

  /// Get the log directory, creating it if needed
  Future<Directory> _getLogDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${appDir.path}/$_logDirName');

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    return logDir;
  }

  /// Generate a unique session ID
  String _generateSessionId() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}'
        '_${now.millisecond.toString().padLeft(3, '0')}';
  }

  /// Read session metadata from the first line of a log file
  Future<SessionMetadata?> _readSessionMetadata(File file) async {
    final lines = await file.readAsLines();
    if (lines.isEmpty) return null;

    // Try to find session_end first (has final counts), fall back to session_start
    for (final line in lines.reversed) {
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json['type'] == 'session_end') {
          return SessionMetadata.fromJson(json['metadata'] as Map<String, dynamic>);
        }
      } catch (e) {
        // Continue searching
      }
    }

    // Fall back to session_start
    try {
      final json = jsonDecode(lines.first) as Map<String, dynamic>;
      if (json['type'] == 'session_start') {
        return SessionMetadata.fromJson(json['metadata'] as Map<String, dynamic>);
      }
    } catch (e) {
      // Corrupted file
    }

    return null;
  }
}
