import 'package:flutter_test/flutter_test.dart';
import 'package:vigiliate_app/bridge.dart';

void main() {
  group('BridgeMessage.tryParse', () {
    test('parses google-sign-in without extra data', () {
      final msg = BridgeMessage.tryParse('{"type":"google-sign-in"}');
      expect(msg, isNotNull);
      expect(msg!.type, BridgeMessageType.googleSignIn);
      expect(msg.data, isEmpty);
    });

    test('parses google-sign-out', () {
      final msg = BridgeMessage.tryParse('{"type":"google-sign-out"}');
      expect(msg?.type, BridgeMessageType.googleSignOut);
    });

    test('parses schedule-alarms with slots', () {
      final msg = BridgeMessage.tryParse(
        '{"type":"schedule-alarms","slots":[{"time":"08:00","meds":"Prednisona"}]}',
      );
      expect(msg, isNotNull);
      expect(msg!.type, BridgeMessageType.scheduleAlarms);
      final slots = msg.extractSlots();
      expect(slots, hasLength(1));
      expect(slots.first['time'], '08:00');
      expect(slots.first['meds'], 'Prednisona');
    });

    test('parses cancel-alarms', () {
      final msg = BridgeMessage.tryParse('{"type":"cancel-alarms"}');
      expect(msg?.type, BridgeMessageType.cancelAlarms);
    });

    test('returns null for invalid JSON', () {
      expect(BridgeMessage.tryParse('not json'), isNull);
      expect(BridgeMessage.tryParse(''), isNull);
      expect(BridgeMessage.tryParse('{'), isNull);
    });

    test('returns null for non-object JSON', () {
      expect(BridgeMessage.tryParse('[]'), isNull);
      expect(BridgeMessage.tryParse('"string"'), isNull);
      expect(BridgeMessage.tryParse('42'), isNull);
      expect(BridgeMessage.tryParse('null'), isNull);
    });

    test('returns null when type is missing or not a string', () {
      expect(BridgeMessage.tryParse('{}'), isNull);
      expect(BridgeMessage.tryParse('{"type":null}'), isNull);
      expect(BridgeMessage.tryParse('{"type":42}'), isNull);
      expect(BridgeMessage.tryParse('{"type":""}'), isNull);
    });

    test('accepts unknown types without crashing', () {
      final msg = BridgeMessage.tryParse('{"type":"future-feature"}');
      expect(msg?.type, 'future-feature');
    });

    test('preserves extra fields on data but removes type', () {
      final msg = BridgeMessage.tryParse(
        '{"type":"schedule-alarms","slots":[],"dryRun":true}',
      );
      expect(msg!.data.keys, containsAll(['slots', 'dryRun']));
      expect(msg.data.containsKey('type'), isFalse);
    });
  });

  group('BridgeMessage.extractSlots', () {
    BridgeMessage parse(String raw) => BridgeMessage.tryParse(raw)!;

    test('returns empty list when slots missing', () {
      expect(parse('{"type":"schedule-alarms"}').extractSlots(), isEmpty);
    });

    test('returns empty list when slots is not a list', () {
      expect(
        parse('{"type":"schedule-alarms","slots":"nope"}').extractSlots(),
        isEmpty,
      );
    });

    test('filters out non-map entries silently', () {
      final slots = parse(
        '{"type":"schedule-alarms","slots":[{"time":"09:00","meds":"A"},"bad",42,{"time":"21:00","meds":"B"}]}',
      ).extractSlots();
      expect(slots, hasLength(2));
      expect(slots[0]['time'], '09:00');
      expect(slots[1]['time'], '21:00');
    });
  });
}
