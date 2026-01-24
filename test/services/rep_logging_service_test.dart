import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushup_counter/models/invalid_rep_reason.dart';
import 'package:pushup_counter/services/rep_logging_service.dart';

void main() {
  group('RepLogEntry', () {
    test('toJson includes all fields for valid rep', () {
      final entry = RepLogEntry.valid(
        repIndex: 0,
        elbowAngle: 170.0,
        bodyDeviation: 5.0,
        formRatio: 0.95,
        durationMs: 1500,
        minElbowAngle: 85.0,
        maxElbowAngle: 175.0,
      );

      final json = entry.toJson();

      expect(json['isValid'], isTrue);
      expect(json['repIndex'], equals(0));
      expect(json['elbowAngle'], equals(170.0));
      expect(json['bodyDeviation'], equals(5.0));
      expect(json['formRatio'], equals(0.95));
      expect(json['durationMs'], equals(1500));
      expect(json['minElbowAngle'], equals(85.0));
      expect(json['maxElbowAngle'], equals(175.0));
      expect(json['timestamp'], isNotNull);
      expect(json.containsKey('invalidReason'), isFalse);
    });

    test('toJson includes invalidReason for invalid rep', () {
      final entry = RepLogEntry(
        timestamp: DateTime.now(),
        isValid: false,
        repIndex: 1,
        invalidReason: InvalidRepReason.poorForm,
        formRatio: 0.4,
      );

      final json = entry.toJson();

      expect(json['isValid'], isFalse);
      expect(json['invalidReason'], equals('poorForm'));
      expect(json['formRatio'], equals(0.4));
    });

    test('fromJson reconstructs entry correctly', () {
      final original = RepLogEntry(
        timestamp: DateTime(2026, 1, 24, 10, 30, 0),
        isValid: false,
        repIndex: 2,
        invalidReason: InvalidRepReason.partialRangeDown,
        elbowAngle: 95.0,
        minElbowAngle: 95.0,
        maxElbowAngle: 160.0,
      );

      final json = original.toJson();
      final reconstructed = RepLogEntry.fromJson(json);

      expect(reconstructed.isValid, equals(original.isValid));
      expect(reconstructed.repIndex, equals(original.repIndex));
      expect(reconstructed.invalidReason, equals(original.invalidReason));
      expect(reconstructed.elbowAngle, equals(original.elbowAngle));
      expect(reconstructed.minElbowAngle, equals(original.minElbowAngle));
      expect(reconstructed.maxElbowAngle, equals(original.maxElbowAngle));
    });

    test('fromInvalidRepInfo creates entry with correct data', () {
      final info = InvalidRepInfo(
        reason: InvalidRepReason.poorForm,
        timestamp: DateTime.now(),
        repIndex: 0,
        elbowAngle: 85.0,
        bodyDeviation: 35.0,
        formRatio: 0.4,
        durationMs: 1200,
        minElbowAngle: 80.0,
        maxElbowAngle: 165.0,
      );

      final entry = RepLogEntry.fromInvalidRepInfo(info, 5);

      expect(entry.isValid, isFalse);
      expect(entry.repIndex, equals(5));
      expect(entry.invalidReason, equals(InvalidRepReason.poorForm));
      expect(entry.elbowAngle, equals(85.0));
      expect(entry.bodyDeviation, equals(35.0));
      expect(entry.formRatio, equals(0.4));
      expect(entry.durationMs, equals(1200));
      expect(entry.minElbowAngle, equals(80.0));
      expect(entry.maxElbowAngle, equals(165.0));
    });

    test('valid factory creates entry with isValid=true', () {
      final entry = RepLogEntry.valid(repIndex: 3);

      expect(entry.isValid, isTrue);
      expect(entry.repIndex, equals(3));
      expect(entry.invalidReason, isNull);
    });
  });

  group('SessionMetadata', () {
    test('toJson includes all fields', () {
      final metadata = SessionMetadata(
        sessionId: '20260124_103000_123',
        exerciseType: 'Pushups',
        variant: 'Standard',
        startTime: DateTime(2026, 1, 24, 10, 30, 0),
        platform: 'iOS',
        validRepCount: 10,
        invalidRepCount: 2,
      );

      final json = metadata.toJson();

      expect(json['sessionId'], equals('20260124_103000_123'));
      expect(json['exerciseType'], equals('Pushups'));
      expect(json['variant'], equals('Standard'));
      expect(json['platform'], equals('iOS'));
      expect(json['validRepCount'], equals(10));
      expect(json['invalidRepCount'], equals(2));
    });

    test('fromJson reconstructs metadata correctly', () {
      final original = SessionMetadata(
        sessionId: 'test_session',
        exerciseType: 'Burpees',
        variant: 'Modified',
        startTime: DateTime(2026, 1, 24, 10, 0, 0),
        endTime: DateTime(2026, 1, 24, 10, 15, 0),
        platform: 'Android',
        validRepCount: 20,
        invalidRepCount: 3,
      );

      final json = original.toJson();
      final reconstructed = SessionMetadata.fromJson(json);

      expect(reconstructed.sessionId, equals(original.sessionId));
      expect(reconstructed.exerciseType, equals(original.exerciseType));
      expect(reconstructed.variant, equals(original.variant));
      expect(reconstructed.platform, equals(original.platform));
      expect(reconstructed.validRepCount, equals(original.validRepCount));
      expect(reconstructed.invalidRepCount, equals(original.invalidRepCount));
      expect(reconstructed.endTime, isNotNull);
    });

    test('endTime is optional in JSON', () {
      final json = {
        'sessionId': 'test',
        'exerciseType': 'Pushups',
        'variant': 'Standard',
        'startTime': '2026-01-24T10:00:00.000',
        'platform': 'iOS',
      };

      final metadata = SessionMetadata.fromJson(json);

      expect(metadata.endTime, isNull);
      expect(metadata.validRepCount, equals(0));
      expect(metadata.invalidRepCount, equals(0));
    });
  });

  group('RepLoggingService', () {
    late RepLoggingService service;

    setUp(() {
      service = RepLoggingService();
    });

    tearDown(() async {
      // Clean up any active sessions
      await service.endSession();
    });

    test('isSessionActive is false initially', () {
      expect(service.isSessionActive, isFalse);
      expect(service.currentSession, isNull);
    });

    test('currentSession is null when no session active', () {
      expect(service.currentSession, isNull);
    });
  });
}
