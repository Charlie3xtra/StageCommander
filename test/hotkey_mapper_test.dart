import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stage_commander/services/hotkey_mapper.dart';

void main() {
  group('HotkeyMapper', () {
    test('maps physical digit/letter/function keys regardless of IME character', () {
      const digitEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit3,
        logicalKey: LogicalKeyboardKey.digit3,
        timeStamp: Duration.zero,
      );
      final b1 = HotkeyMapper.fromKeyEvent(digitEvent);
      expect(b1?.code, 'Digit3');
      expect(b1?.label, '3');

      // Simulate Chinese IME emitting full-width or unexpected character on KeyA
      const imeLetterEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        character: 'ａ',
        timeStamp: Duration.zero,
      );
      expect(HotkeyMapper.matchesEvent('KeyA', imeLetterEvent), isTrue);

      const f5Event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.f5,
        logicalKey: LogicalKeyboardKey.f5,
        timeStamp: Duration.zero,
      );
      final bF5 = HotkeyMapper.fromKeyEvent(f5Event);
      expect(bF5?.code, 'F5');
      expect(bF5?.label, 'F5');
    });

    test('reserves Space and Escape exclusively for safety controls', () {
      const spaceEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
      const escEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );

      expect(HotkeyMapper.isReservedSafetyKey(spaceEvent), isTrue);
      expect(HotkeyMapper.isReservedSafetyKey(escEvent), isTrue);
      expect(HotkeyMapper.fromKeyEvent(spaceEvent), isNull);
      expect(HotkeyMapper.fromKeyEvent(escEvent), isNull);
    });
  });
}
