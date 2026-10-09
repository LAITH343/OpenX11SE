import 'button_assignment.dart';

abstract final class HidUsage {
  static const page = 0x07;
  static const firstKey = 0x04;
  static const leftCtrl = 0xE0;
  static const leftShift = 0xE1;
  static const leftAlt = 0xE2;
  static const leftWin = 0xE3;
  static const rightCtrl = 0xE4;
  static const rightShift = 0xE5;
  static const rightAlt = 0xE6;
  static const rightWin = 0xE7;
}

const Map<int, String> _namedKeys = {
  0x28: 'Enter',
  0x29: 'Esc',
  0x2A: 'Backspace',
  0x2B: 'Tab',
  0x2C: 'Space',
  0x2D: '-',
  0x2E: '=',
  0x2F: '[',
  0x30: ']',
  0x31: r'\',
  0x32: '#',
  0x33: ';',
  0x34: "'",
  0x35: '`',
  0x36: ',',
  0x37: '.',
  0x38: '/',
  0x39: 'Caps Lock',
  0x46: 'PrtSc',
  0x47: 'Scroll Lock',
  0x48: 'Pause',
  0x49: 'Insert',
  0x4A: 'Home',
  0x4B: 'Page Up',
  0x4C: 'Delete',
  0x4D: 'End',
  0x4E: 'Page Down',
  0x4F: 'Right',
  0x50: 'Left',
  0x51: 'Down',
  0x52: 'Up',
  0x53: 'Num Lock',
  0x54: 'Num /',
  0x55: 'Num *',
  0x56: 'Num -',
  0x57: 'Num +',
  0x58: 'Num Enter',
  0x62: 'Num 0',
  0x63: 'Num .',
  0x64: r'\',
  0x65: 'Menu',
};

String hidKeyName(int usage) {
  if (usage >= 0x04 && usage <= 0x1D) {
    return String.fromCharCode(0x41 + usage - 0x04);
  }
  if (usage >= 0x1E && usage <= 0x26) return '${usage - 0x1D}';
  if (usage == 0x27) return '0';
  if (usage >= 0x3A && usage <= 0x45) return 'F${usage - 0x39}';
  if (usage >= 0x68 && usage <= 0x73) return 'F${usage - 0x5B}';
  if (usage >= 0x59 && usage <= 0x61) return 'Num ${usage - 0x58}';
  return _namedKeys[usage] ??
      'Key 0x${usage.toRadixString(16).toUpperCase().padLeft(2, '0')}';
}

bool isModifierUsage(int usage) =>
    usage >= HidUsage.leftCtrl && usage <= HidUsage.rightWin;

bool isAssignableKey(int usage) =>
    usage >= HidUsage.firstKey && usage <= 0xA4 && !isModifierUsage(usage);

KeyModifiers modifierForUsage(int usage) => switch (usage) {
  HidUsage.leftCtrl || HidUsage.rightCtrl => const KeyModifiers(ctrl: true),
  HidUsage.leftShift || HidUsage.rightShift => const KeyModifiers(shift: true),
  HidUsage.leftAlt || HidUsage.rightAlt => const KeyModifiers(alt: true),
  HidUsage.leftWin || HidUsage.rightWin => const KeyModifiers(win: true),
  _ => KeyModifiers.none,
};

KeyModifiers combineModifiers(KeyModifiers a, KeyModifiers b) => KeyModifiers(
  ctrl: a.ctrl || b.ctrl,
  shift: a.shift || b.shift,
  alt: a.alt || b.alt,
  win: a.win || b.win,
);

String keyComboLabel(KeyButton key) => [
  if (key.modifiers.ctrl) 'Ctrl',
  if (key.modifiers.shift) 'Shift',
  if (key.modifiers.alt) 'Alt',
  if (key.modifiers.win) 'Win',
  hidKeyName(key.usage),
].join(' + ');
