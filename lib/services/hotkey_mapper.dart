import 'package:flutter/services.dart';

/// Canonical hotkey binding extracted from physical or legacy key inputs.
typedef HotkeyBinding = ({String code, String label});

/// Maps keyboard events and legacy key text into stable physical/logical codes.
///
/// Physical key matching ensures stage hotkeys keep firing reliably even when
/// an OS input method (such as Chinese IME) is active during live shows.
abstract final class HotkeyMapper {
  /// Keys reserved exclusively for global safety operations.
  static bool isReservedSafetyKey(KeyEvent event) {
    return event.physicalKey == PhysicalKeyboardKey.space ||
        event.physicalKey == PhysicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.escape;
  }

  /// Extracts a canonical cue hotkey binding from a hardware key event, or
  /// returns `null` if the key is a modifier or reserved safety key.
  static HotkeyBinding? fromKeyEvent(KeyEvent event) {
    if (isReservedSafetyKey(event)) return null;
    final fromPhysical = _physicalBindings[event.physicalKey];
    if (fromPhysical != null) return fromPhysical;

    final logical = event.logicalKey;
    if (_modifierLogicalKeys.contains(logical)) return null;

    final label = logical.keyLabel.trim();
    if (label.length == 1) {
      return parseLegacyString(label);
    }
    return null;
  }

  /// Matches a cue's bound `hotkeyCode` against a hardware [KeyEvent].
  static bool matchesEvent(String boundCode, KeyEvent event) {
    if (boundCode.isEmpty) return false;
    final eventBinding = fromKeyEvent(event);
    if (eventBinding != null && eventBinding.code == boundCode) {
      return true;
    }
    final char = event.character;
    if (char != null && char.trim().isNotEmpty) {
      final fromChar = parseLegacyString(char);
      if (fromChar.code.isNotEmpty && fromChar.code == boundCode) {
        return true;
      }
    }
    return false;
  }

  /// Normalizes a legacy string (e.g., `"1"`, `"a"`, `"f2"`) into a canonical
  /// `(code, label)` tuple. Returns empty tuple if empty or reserved (`space`).
  static HotkeyBinding parseLegacyString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return (code: '', label: '');
    final lower = trimmed.toLowerCase();
    if (lower == 'space' || lower == 'esc' || lower == 'escape') {
      return (code: '', label: '');
    }

    if (lower.length == 1) {
      final codeUnit = lower.codeUnitAt(0);
      if (codeUnit >= 0x30 && codeUnit <= 0x39) {
        return (code: 'Digit$lower', label: lower);
      }
      if (codeUnit >= 0x61 && codeUnit <= 0x7A) {
        final upper = lower.toUpperCase();
        return (code: 'Key$upper', label: upper);
      }
    }

    for (final entry in _physicalBindings.values) {
      if (entry.code.toLowerCase() == lower ||
          entry.label.toLowerCase() == lower) {
        return entry;
      }
    }

    return (code: trimmed, label: trimmed.toUpperCase());
  }

  static final Set<LogicalKeyboardKey> _modifierLogicalKeys = {
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.numLock,
    LogicalKeyboardKey.scrollLock,
    LogicalKeyboardKey.fn,
  };

  static final Map<PhysicalKeyboardKey, HotkeyBinding> _physicalBindings = {
    PhysicalKeyboardKey.digit1: (code: 'Digit1', label: '1'),
    PhysicalKeyboardKey.digit2: (code: 'Digit2', label: '2'),
    PhysicalKeyboardKey.digit3: (code: 'Digit3', label: '3'),
    PhysicalKeyboardKey.digit4: (code: 'Digit4', label: '4'),
    PhysicalKeyboardKey.digit5: (code: 'Digit5', label: '5'),
    PhysicalKeyboardKey.digit6: (code: 'Digit6', label: '6'),
    PhysicalKeyboardKey.digit7: (code: 'Digit7', label: '7'),
    PhysicalKeyboardKey.digit8: (code: 'Digit8', label: '8'),
    PhysicalKeyboardKey.digit9: (code: 'Digit9', label: '9'),
    PhysicalKeyboardKey.digit0: (code: 'Digit0', label: '0'),
    PhysicalKeyboardKey.numpad1: (code: 'Numpad1', label: 'Num 1'),
    PhysicalKeyboardKey.numpad2: (code: 'Numpad2', label: 'Num 2'),
    PhysicalKeyboardKey.numpad3: (code: 'Numpad3', label: 'Num 3'),
    PhysicalKeyboardKey.numpad4: (code: 'Numpad4', label: 'Num 4'),
    PhysicalKeyboardKey.numpad5: (code: 'Numpad5', label: 'Num 5'),
    PhysicalKeyboardKey.numpad6: (code: 'Numpad6', label: 'Num 6'),
    PhysicalKeyboardKey.numpad7: (code: 'Numpad7', label: 'Num 7'),
    PhysicalKeyboardKey.numpad8: (code: 'Numpad8', label: 'Num 8'),
    PhysicalKeyboardKey.numpad9: (code: 'Numpad9', label: 'Num 9'),
    PhysicalKeyboardKey.numpad0: (code: 'Numpad0', label: 'Num 0'),
    PhysicalKeyboardKey.keyA: (code: 'KeyA', label: 'A'),
    PhysicalKeyboardKey.keyB: (code: 'KeyB', label: 'B'),
    PhysicalKeyboardKey.keyC: (code: 'KeyC', label: 'C'),
    PhysicalKeyboardKey.keyD: (code: 'KeyD', label: 'D'),
    PhysicalKeyboardKey.keyE: (code: 'KeyE', label: 'E'),
    PhysicalKeyboardKey.keyF: (code: 'KeyF', label: 'F'),
    PhysicalKeyboardKey.keyG: (code: 'KeyG', label: 'G'),
    PhysicalKeyboardKey.keyH: (code: 'KeyH', label: 'H'),
    PhysicalKeyboardKey.keyI: (code: 'KeyI', label: 'I'),
    PhysicalKeyboardKey.keyJ: (code: 'KeyJ', label: 'J'),
    PhysicalKeyboardKey.keyK: (code: 'KeyK', label: 'K'),
    PhysicalKeyboardKey.keyL: (code: 'KeyL', label: 'L'),
    PhysicalKeyboardKey.keyM: (code: 'KeyM', label: 'M'),
    PhysicalKeyboardKey.keyN: (code: 'KeyN', label: 'N'),
    PhysicalKeyboardKey.keyO: (code: 'KeyO', label: 'O'),
    PhysicalKeyboardKey.keyP: (code: 'KeyP', label: 'P'),
    PhysicalKeyboardKey.keyQ: (code: 'KeyQ', label: 'Q'),
    PhysicalKeyboardKey.keyR: (code: 'KeyR', label: 'R'),
    PhysicalKeyboardKey.keyS: (code: 'KeyS', label: 'S'),
    PhysicalKeyboardKey.keyT: (code: 'KeyT', label: 'T'),
    PhysicalKeyboardKey.keyU: (code: 'KeyU', label: 'U'),
    PhysicalKeyboardKey.keyV: (code: 'KeyV', label: 'V'),
    PhysicalKeyboardKey.keyW: (code: 'KeyW', label: 'W'),
    PhysicalKeyboardKey.keyX: (code: 'KeyX', label: 'X'),
    PhysicalKeyboardKey.keyY: (code: 'KeyY', label: 'Y'),
    PhysicalKeyboardKey.keyZ: (code: 'KeyZ', label: 'Z'),
    PhysicalKeyboardKey.f1: (code: 'F1', label: 'F1'),
    PhysicalKeyboardKey.f2: (code: 'F2', label: 'F2'),
    PhysicalKeyboardKey.f3: (code: 'F3', label: 'F3'),
    PhysicalKeyboardKey.f4: (code: 'F4', label: 'F4'),
    PhysicalKeyboardKey.f5: (code: 'F5', label: 'F5'),
    PhysicalKeyboardKey.f6: (code: 'F6', label: 'F6'),
    PhysicalKeyboardKey.f7: (code: 'F7', label: 'F7'),
    PhysicalKeyboardKey.f8: (code: 'F8', label: 'F8'),
    PhysicalKeyboardKey.f9: (code: 'F9', label: 'F9'),
    PhysicalKeyboardKey.f10: (code: 'F10', label: 'F10'),
    PhysicalKeyboardKey.f11: (code: 'F11', label: 'F11'),
    PhysicalKeyboardKey.f12: (code: 'F12', label: 'F12'),
    PhysicalKeyboardKey.minus: (code: 'Minus', label: '-'),
    PhysicalKeyboardKey.equal: (code: 'Equal', label: '='),
    PhysicalKeyboardKey.bracketLeft: (code: 'BracketLeft', label: '['),
    PhysicalKeyboardKey.bracketRight: (code: 'BracketRight', label: ']'),
    PhysicalKeyboardKey.semicolon: (code: 'Semicolon', label: ';'),
    PhysicalKeyboardKey.quote: (code: 'Quote', label: "'"),
    PhysicalKeyboardKey.comma: (code: 'Comma', label: ','),
    PhysicalKeyboardKey.period: (code: 'Period', label: '.'),
    PhysicalKeyboardKey.slash: (code: 'Slash', label: '/'),
    PhysicalKeyboardKey.backquote: (code: 'Backquote', label: '`'),
    PhysicalKeyboardKey.enter: (code: 'Enter', label: 'Enter'),
    PhysicalKeyboardKey.numpadEnter: (code: 'NumpadEnter', label: 'Num Enter'),
    PhysicalKeyboardKey.arrowUp: (code: 'ArrowUp', label: '↑'),
    PhysicalKeyboardKey.arrowDown: (code: 'ArrowDown', label: '↓'),
    PhysicalKeyboardKey.arrowLeft: (code: 'ArrowLeft', label: '←'),
    PhysicalKeyboardKey.arrowRight: (code: 'ArrowRight', label: '→'),
  };
}
