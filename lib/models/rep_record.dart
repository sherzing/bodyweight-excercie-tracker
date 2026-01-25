import 'invalid_rep_reason.dart';

/// Record of a single rep within a workout session.
///
/// Tracks validity, timing, angles at completion, and optional
/// captured images for post-workout review.
class RepRecord {
  /// Index of this rep within the workout (0-based)
  final int repIndex;

  /// Timestamp when the rep was completed
  final DateTime timestamp;

  /// Whether the rep was valid at time of detection
  final bool isValid;

  /// Reason for invalidation (null if valid)
  final InvalidRepReason? reason;

  /// Key angles at rep completion (e.g., 'elbow', 'bodyDeviation')
  final Map<String, double> angles;

  /// Paths to captured frame images (for review)
  final List<String> framePaths;

  /// Whether the user accepted this rep as valid during review.
  /// Users can override the automatic validity detection.
  bool userAccepted;

  RepRecord({
    required this.repIndex,
    required this.timestamp,
    required this.isValid,
    this.reason,
    Map<String, double>? angles,
    List<String>? framePaths,
    bool? userAccepted,
  })  : angles = angles ?? {},
        framePaths = framePaths ?? [],
        userAccepted = userAccepted ?? isValid;

  /// Create a valid rep record
  factory RepRecord.valid({
    required int repIndex,
    required DateTime timestamp,
    Map<String, double>? angles,
    List<String>? framePaths,
  }) {
    return RepRecord(
      repIndex: repIndex,
      timestamp: timestamp,
      isValid: true,
      angles: angles,
      framePaths: framePaths,
    );
  }

  /// Create an invalid rep record from InvalidRepInfo
  factory RepRecord.fromInvalidInfo({
    required InvalidRepInfo info,
    List<String>? framePaths,
  }) {
    return RepRecord(
      repIndex: info.repIndex,
      timestamp: info.timestamp,
      isValid: false,
      reason: info.reason,
      angles: {
        if (info.elbowAngle != null) 'elbow': info.elbowAngle!,
        if (info.bodyDeviation != null) 'bodyDeviation': info.bodyDeviation!,
        if (info.minElbowAngle != null) 'minElbow': info.minElbowAngle!,
        if (info.maxElbowAngle != null) 'maxElbow': info.maxElbowAngle!,
      },
      framePaths: framePaths,
    );
  }

  /// Final validity considering user override
  bool get finalValidity => userAccepted;

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'repIndex': repIndex,
      'timestamp': timestamp.toIso8601String(),
      'isValid': isValid,
      'reason': reason?.name,
      'angles': angles,
      'framePaths': framePaths,
      'userAccepted': userAccepted,
    };
  }

  /// Create from map
  factory RepRecord.fromMap(Map<String, dynamic> map) {
    return RepRecord(
      repIndex: map['repIndex'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isValid: map['isValid'] as bool,
      reason: map['reason'] != null
          ? InvalidRepReason.values.byName(map['reason'] as String)
          : null,
      angles: (map['angles'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      framePaths: (map['framePaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      userAccepted: map['userAccepted'] as bool?,
    );
  }

  @override
  String toString() {
    return 'RepRecord(#$repIndex, valid: $isValid${reason != null ? ', reason: ${reason!.name}' : ''}, accepted: $userAccepted)';
  }
}

/// Tracks all reps within a workout session.
class RepHistory {
  final List<RepRecord> _records = [];

  /// All rep records in order
  List<RepRecord> get records => List.unmodifiable(_records);

  /// Count of all reps
  int get totalCount => _records.length;

  /// Count of valid reps (by detection)
  int get validCount => _records.where((r) => r.isValid).length;

  /// Count of invalid reps (by detection)
  int get invalidCount => _records.where((r) => !r.isValid).length;

  /// Count of accepted reps (considering user overrides)
  int get acceptedCount => _records.where((r) => r.userAccepted).length;

  /// Get only invalid reps for review
  List<RepRecord> get invalidReps =>
      _records.where((r) => !r.isValid).toList();

  /// Add a valid rep
  void addValidRep({
    required DateTime timestamp,
    Map<String, double>? angles,
    List<String>? framePaths,
  }) {
    _records.add(RepRecord.valid(
      repIndex: _records.length,
      timestamp: timestamp,
      angles: angles,
      framePaths: framePaths,
    ));
  }

  /// Add an invalid rep from InvalidRepInfo
  void addInvalidRep({
    required InvalidRepInfo info,
    List<String>? framePaths,
  }) {
    _records.add(RepRecord.fromInvalidInfo(
      info: info,
      framePaths: framePaths,
    ));
  }

  /// Add a raw rep record
  void addRecord(RepRecord record) {
    _records.add(record);
  }

  /// Update user acceptance for a rep
  void setUserAccepted(int repIndex, bool accepted) {
    if (repIndex >= 0 && repIndex < _records.length) {
      _records[repIndex].userAccepted = accepted;
    }
  }

  /// Clear all records
  void clear() {
    _records.clear();
  }

  /// Get record by index
  RepRecord? getRecord(int index) {
    if (index >= 0 && index < _records.length) {
      return _records[index];
    }
    return null;
  }

  /// Convert to list of maps for serialization
  List<Map<String, dynamic>> toMapList() {
    return _records.map((r) => r.toMap()).toList();
  }

  /// Load from list of maps
  void loadFromMapList(List<Map<String, dynamic>> mapList) {
    _records.clear();
    for (final map in mapList) {
      _records.add(RepRecord.fromMap(map));
    }
  }
}
