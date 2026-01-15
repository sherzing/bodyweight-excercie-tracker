/// Reason codes for why a rep was marked invalid.
enum InvalidRepReason {
  /// Body deviation >30° for >40% of frames during rep
  poorForm,

  /// Didn't reach full down position (elbow angle not low enough)
  partialRangeDown,

  /// Didn't reach full up position (elbow angle not high enough)
  partialRangeUp,

  /// Rep completed too quickly (<300ms)
  tooFast,

  /// Lost pose tracking mid-rep
  poseLost,
}

extension InvalidRepReasonExtension on InvalidRepReason {
  /// User-friendly message to display when rep is invalid
  String get userMessage {
    switch (this) {
      case InvalidRepReason.poorForm:
        return 'Keep body straight';
      case InvalidRepReason.partialRangeDown:
        return 'Go lower';
      case InvalidRepReason.partialRangeUp:
        return 'Extend arms fully';
      case InvalidRepReason.tooFast:
        return 'Slow down';
      case InvalidRepReason.poseLost:
        return 'Stay in frame';
    }
  }

  /// Technical description for debugging
  String get description {
    switch (this) {
      case InvalidRepReason.poorForm:
        return 'Body deviation exceeded threshold for majority of rep';
      case InvalidRepReason.partialRangeDown:
        return 'Elbow angle did not reach down position threshold';
      case InvalidRepReason.partialRangeUp:
        return 'Elbow angle did not reach up position threshold';
      case InvalidRepReason.tooFast:
        return 'Rep completed faster than minimum duration';
      case InvalidRepReason.poseLost:
        return 'Pose detection lost required landmarks mid-rep';
    }
  }
}

/// Detailed information about an invalid rep, including reason and metrics.
class InvalidRepInfo {
  /// The reason the rep was marked invalid
  final InvalidRepReason reason;

  /// Timestamp when the invalid rep was detected
  final DateTime timestamp;

  /// Rep index within the current workout (0-based)
  final int repIndex;

  /// Elbow angle at the time of invalidation (degrees)
  final double? elbowAngle;

  /// Body deviation angle at the time of invalidation (degrees)
  final double? bodyDeviation;

  /// Form ratio during the rep (0.0 - 1.0, percentage of good form frames)
  final double? formRatio;

  /// Duration of the rep attempt in milliseconds
  final int? durationMs;

  /// Minimum elbow angle reached during rep (for partial range detection)
  final double? minElbowAngle;

  /// Maximum elbow angle reached during rep (for partial range detection)
  final double? maxElbowAngle;

  InvalidRepInfo({
    required this.reason,
    required this.timestamp,
    required this.repIndex,
    this.elbowAngle,
    this.bodyDeviation,
    this.formRatio,
    this.durationMs,
    this.minElbowAngle,
    this.maxElbowAngle,
  });

  /// Convert to map for logging/serialization
  Map<String, dynamic> toMap() {
    return {
      'reason': reason.name,
      'timestamp': timestamp.toIso8601String(),
      'repIndex': repIndex,
      'elbowAngle': elbowAngle,
      'bodyDeviation': bodyDeviation,
      'formRatio': formRatio,
      'durationMs': durationMs,
      'minElbowAngle': minElbowAngle,
      'maxElbowAngle': maxElbowAngle,
    };
  }

  factory InvalidRepInfo.fromMap(Map<String, dynamic> map) {
    return InvalidRepInfo(
      reason: InvalidRepReason.values.byName(map['reason'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      repIndex: map['repIndex'] as int,
      elbowAngle: map['elbowAngle'] as double?,
      bodyDeviation: map['bodyDeviation'] as double?,
      formRatio: map['formRatio'] as double?,
      durationMs: map['durationMs'] as int?,
      minElbowAngle: map['minElbowAngle'] as double?,
      maxElbowAngle: map['maxElbowAngle'] as double?,
    );
  }

  @override
  String toString() {
    return 'InvalidRepInfo(reason: ${reason.name}, repIndex: $repIndex, '
        'formRatio: ${formRatio?.toStringAsFixed(2)}, '
        'elbowAngle: ${elbowAngle?.toStringAsFixed(1)}°, '
        'bodyDeviation: ${bodyDeviation?.toStringAsFixed(1)}°)';
  }
}
