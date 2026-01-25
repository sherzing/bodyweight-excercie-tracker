import 'package:flutter_test/flutter_test.dart';
import 'package:pushup_counter/models/invalid_rep_reason.dart';
import 'package:pushup_counter/models/rep_record.dart';

void main() {
  group('RepRecord', () {
    test('creates valid rep with defaults', () {
      final record = RepRecord(
        repIndex: 0,
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        isValid: true,
      );

      expect(record.repIndex, 0);
      expect(record.isValid, true);
      expect(record.reason, isNull);
      expect(record.angles, isEmpty);
      expect(record.framePaths, isEmpty);
      expect(record.userAccepted, true);
    });

    test('creates invalid rep with reason', () {
      final record = RepRecord(
        repIndex: 1,
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        isValid: false,
        reason: InvalidRepReason.partialRangeDown,
        angles: {'elbow': 95.0, 'minElbow': 95.0},
      );

      expect(record.isValid, false);
      expect(record.reason, InvalidRepReason.partialRangeDown);
      expect(record.angles['elbow'], 95.0);
      expect(record.userAccepted, false);
    });

    test('factory valid creates valid rep', () {
      final record = RepRecord.valid(
        repIndex: 2,
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        angles: {'elbow': 165.0},
      );

      expect(record.isValid, true);
      expect(record.userAccepted, true);
      expect(record.angles['elbow'], 165.0);
    });

    test('factory fromInvalidInfo creates record from InvalidRepInfo', () {
      final info = InvalidRepInfo(
        reason: InvalidRepReason.poorForm,
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        repIndex: 3,
        elbowAngle: 88.0,
        bodyDeviation: 25.0,
        minElbowAngle: 75.0,
        maxElbowAngle: 160.0,
      );

      final record = RepRecord.fromInvalidInfo(
        info: info,
        framePaths: ['/path/to/frame.jpg'],
      );

      expect(record.repIndex, 3);
      expect(record.isValid, false);
      expect(record.reason, InvalidRepReason.poorForm);
      expect(record.angles['elbow'], 88.0);
      expect(record.angles['bodyDeviation'], 25.0);
      expect(record.angles['minElbow'], 75.0);
      expect(record.angles['maxElbow'], 160.0);
      expect(record.framePaths, ['/path/to/frame.jpg']);
      expect(record.userAccepted, false);
    });

    test('userAccepted can be modified', () {
      final record = RepRecord(
        repIndex: 0,
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        isValid: false,
        reason: InvalidRepReason.tooFast,
      );

      expect(record.userAccepted, false);
      record.userAccepted = true;
      expect(record.userAccepted, true);
      expect(record.finalValidity, true);
    });

    test('toMap and fromMap roundtrip', () {
      final original = RepRecord(
        repIndex: 5,
        timestamp: DateTime(2026, 1, 25, 12, 30, 0),
        isValid: false,
        reason: InvalidRepReason.partialRangeUp,
        angles: {'elbow': 140.0, 'bodyDeviation': 5.0},
        framePaths: ['/path/a.jpg', '/path/b.jpg'],
        userAccepted: true,
      );

      final map = original.toMap();
      final restored = RepRecord.fromMap(map);

      expect(restored.repIndex, original.repIndex);
      expect(restored.timestamp, original.timestamp);
      expect(restored.isValid, original.isValid);
      expect(restored.reason, original.reason);
      expect(restored.angles, original.angles);
      expect(restored.framePaths, original.framePaths);
      expect(restored.userAccepted, original.userAccepted);
    });

    test('toString provides readable output', () {
      final record = RepRecord(
        repIndex: 2,
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        isValid: false,
        reason: InvalidRepReason.poseLost,
      );

      expect(record.toString(), contains('#2'));
      expect(record.toString(), contains('valid: false'));
      expect(record.toString(), contains('poseLost'));
    });
  });

  group('RepHistory', () {
    late RepHistory history;

    setUp(() {
      history = RepHistory();
    });

    test('starts empty', () {
      expect(history.records, isEmpty);
      expect(history.totalCount, 0);
      expect(history.validCount, 0);
      expect(history.invalidCount, 0);
    });

    test('addValidRep adds valid record', () {
      history.addValidRep(
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        angles: {'elbow': 165.0},
      );

      expect(history.totalCount, 1);
      expect(history.validCount, 1);
      expect(history.invalidCount, 0);
      expect(history.records.first.repIndex, 0);
      expect(history.records.first.isValid, true);
    });

    test('addInvalidRep adds invalid record', () {
      final info = InvalidRepInfo(
        reason: InvalidRepReason.poorForm,
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        repIndex: 0,
      );

      history.addInvalidRep(info: info);

      expect(history.totalCount, 1);
      expect(history.validCount, 0);
      expect(history.invalidCount, 1);
      expect(history.invalidReps.length, 1);
    });

    test('records are indexed correctly', () {
      history.addValidRep(timestamp: DateTime.now());
      history.addValidRep(timestamp: DateTime.now());
      history.addValidRep(timestamp: DateTime.now());

      expect(history.records[0].repIndex, 0);
      expect(history.records[1].repIndex, 1);
      expect(history.records[2].repIndex, 2);
    });

    test('setUserAccepted updates record', () {
      final info = InvalidRepInfo(
        reason: InvalidRepReason.tooFast,
        timestamp: DateTime.now(),
        repIndex: 0,
      );
      history.addInvalidRep(info: info);

      expect(history.acceptedCount, 0);

      history.setUserAccepted(0, true);

      expect(history.acceptedCount, 1);
      expect(history.records.first.userAccepted, true);
    });

    test('clear removes all records', () {
      history.addValidRep(timestamp: DateTime.now());
      history.addValidRep(timestamp: DateTime.now());

      expect(history.totalCount, 2);

      history.clear();

      expect(history.totalCount, 0);
      expect(history.records, isEmpty);
    });

    test('getRecord returns record by index', () {
      history.addValidRep(timestamp: DateTime.now());
      history.addValidRep(timestamp: DateTime.now());

      expect(history.getRecord(0), isNotNull);
      expect(history.getRecord(1), isNotNull);
      expect(history.getRecord(2), isNull);
      expect(history.getRecord(-1), isNull);
    });

    test('invalidReps returns only invalid records', () {
      history.addValidRep(timestamp: DateTime.now());

      final info = InvalidRepInfo(
        reason: InvalidRepReason.partialRangeDown,
        timestamp: DateTime.now(),
        repIndex: 1,
      );
      history.addInvalidRep(info: info);

      history.addValidRep(timestamp: DateTime.now());

      expect(history.invalidReps.length, 1);
      expect(history.invalidReps.first.reason, InvalidRepReason.partialRangeDown);
    });

    test('toMapList and loadFromMapList roundtrip', () {
      history.addValidRep(
        timestamp: DateTime(2026, 1, 25, 12, 0, 0),
        angles: {'elbow': 165.0},
      );

      final info = InvalidRepInfo(
        reason: InvalidRepReason.poorForm,
        timestamp: DateTime(2026, 1, 25, 12, 0, 5),
        repIndex: 1,
        elbowAngle: 88.0,
      );
      history.addInvalidRep(info: info);

      final mapList = history.toMapList();

      final restored = RepHistory();
      restored.loadFromMapList(mapList);

      expect(restored.totalCount, 2);
      expect(restored.validCount, 1);
      expect(restored.invalidCount, 1);
      expect(restored.records[0].isValid, true);
      expect(restored.records[1].reason, InvalidRepReason.poorForm);
    });

    test('records list is unmodifiable', () {
      history.addValidRep(timestamp: DateTime.now());

      expect(
        () => history.records.add(RepRecord(
          repIndex: 99,
          timestamp: DateTime.now(),
          isValid: true,
        )),
        throwsUnsupportedError,
      );
    });
  });
}
