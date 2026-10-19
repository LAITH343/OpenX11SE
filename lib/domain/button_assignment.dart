import 'keyboard_keys.dart';
import 'macro.dart';

abstract final class ButtonSlot {
  static const left = 0;
  static const right = 1;
  static const middle = 2;
  static const dpi = 5;
  static const forward = 6;
  static const back = 7;
  static const wheelUp = 16;
  static const wheelDown = 17;
  static const count = 18;

  static const main = [left, right, middle, forward, back];
  static const advanced = [dpi, wheelUp, wheelDown];
}

enum ButtonFunctionGroup {
  mouse,
  dpi,
  profile,
  lighting,
  media,
  browser,
  shortcuts,
  keyboard,
  macro,
}

enum ButtonFunction {
  leftClick('Left click', ButtonFunctionGroup.mouse),
  rightClick('Right click', ButtonFunctionGroup.mouse),
  middleClick('Middle click', ButtonFunctionGroup.mouse),
  forward('Forward', ButtonFunctionGroup.mouse),
  back('Back', ButtonFunctionGroup.mouse),
  doubleClick('Double click', ButtonFunctionGroup.mouse),
  fireButton('Fire button', ButtonFunctionGroup.mouse),
  scrollUp('Scroll up', ButtonFunctionGroup.mouse),
  scrollDown('Scroll down', ButtonFunctionGroup.mouse),
  tiltLeft('Tilt left', ButtonFunctionGroup.mouse),
  tiltRight('Tilt right', ButtonFunctionGroup.mouse),
  dpiCycle('DPI cycle', ButtonFunctionGroup.dpi),
  dpiUp('DPI up', ButtonFunctionGroup.dpi),
  dpiDown('DPI down', ButtonFunctionGroup.dpi),
  easyAim('Easy aim', ButtonFunctionGroup.dpi),
  profileCycle('Profile cycle', ButtonFunctionGroup.profile),
  profileUp('Profile up', ButtonFunctionGroup.profile),
  profileDown('Profile down', ButtonFunctionGroup.profile),
  ledModeCycle('LED mode cycle', ButtonFunctionGroup.lighting),
  mediaPlayer('Media player', ButtonFunctionGroup.media),
  playPause('Play / Pause', ButtonFunctionGroup.media),
  mediaStop('Stop', ButtonFunctionGroup.media),
  previousTrack('Previous track', ButtonFunctionGroup.media),
  nextTrack('Next track', ButtonFunctionGroup.media),
  volumeUp('Volume up', ButtonFunctionGroup.media),
  volumeDown('Volume down', ButtonFunctionGroup.media),
  mute('Mute', ButtonFunctionGroup.media),
  browserHome('Browser home', ButtonFunctionGroup.browser),
  browserBack('Browser back', ButtonFunctionGroup.browser),
  browserForward('Browser forward', ButtonFunctionGroup.browser),
  browserRefresh('Refresh', ButtonFunctionGroup.browser),
  browserStop('Stop loading', ButtonFunctionGroup.browser),
  browserSearch('Search', ButtonFunctionGroup.browser),
  email('Email', ButtonFunctionGroup.browser),
  calculator('Calculator', ButtonFunctionGroup.browser),
  myComputer('My Computer', ButtonFunctionGroup.browser);

  const ButtonFunction(this.label, this.group);

  final String label;
  final ButtonFunctionGroup group;
}

class KeyModifiers {
  const KeyModifiers({
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    this.win = false,
  });

  static const none = KeyModifiers();

  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool win;

  bool get isEmpty => !ctrl && !shift && !alt && !win;

  KeyModifiers copyWith({bool? ctrl, bool? shift, bool? alt, bool? win}) =>
      KeyModifiers(
        ctrl: ctrl ?? this.ctrl,
        shift: shift ?? this.shift,
        alt: alt ?? this.alt,
        win: win ?? this.win,
      );

  @override
  bool operator ==(Object other) =>
      other is KeyModifiers &&
      other.ctrl == ctrl &&
      other.shift == shift &&
      other.alt == alt &&
      other.win == win;

  @override
  int get hashCode => Object.hash(ctrl, shift, alt, win);

  @override
  String toString() => [
    if (ctrl) KeyLabels.ctrl,
    if (shift) 'Shift',
    if (alt) KeyLabels.alt,
    if (win) KeyLabels.win,
  ].join(' + ');
}

sealed class ButtonAssignment {
  const ButtonAssignment();
}

final class DisabledButton extends ButtonAssignment {
  const DisabledButton();

  @override
  bool operator ==(Object other) => other is DisabledButton;

  @override
  int get hashCode => (DisabledButton).hashCode;

  @override
  String toString() => 'DisabledButton()';
}

final class FunctionButton extends ButtonAssignment {
  const FunctionButton(this.function);

  final ButtonFunction function;

  @override
  bool operator ==(Object other) =>
      other is FunctionButton && other.function == function;

  @override
  int get hashCode => function.hashCode;

  @override
  String toString() => 'FunctionButton(${function.name})';
}

final class KeyButton extends ButtonAssignment {
  const KeyButton(this.usage, {this.modifiers = KeyModifiers.none});

  final int usage;
  final KeyModifiers modifiers;

  KeyButton copyWith({int? usage, KeyModifiers? modifiers}) =>
      KeyButton(usage ?? this.usage, modifiers: modifiers ?? this.modifiers);

  @override
  bool operator ==(Object other) =>
      other is KeyButton &&
      other.usage == usage &&
      other.modifiers == modifiers;

  @override
  int get hashCode => Object.hash(usage, modifiers);

  @override
  String toString() =>
      'KeyButton(0x${usage.toRadixString(16)}, modifiers: $modifiers)';
}

final class MacroButton extends ButtonAssignment {
  const MacroButton({this.macroId, this.playback = MacroPlayback.defaults});

  final int? macroId;
  final MacroPlayback playback;

  MacroButton copyWith({int? macroId, MacroPlayback? playback}) => MacroButton(
    macroId: macroId ?? this.macroId,
    playback: playback ?? this.playback,
  );

  @override
  bool operator ==(Object other) =>
      other is MacroButton &&
      other.macroId == macroId &&
      other.playback == playback;

  @override
  int get hashCode => Object.hash(macroId, playback);

  @override
  String toString() => 'MacroButton($macroId, $playback)';
}

final class UnmappedButton extends ButtonAssignment {
  const UnmappedButton(this.b0, this.b1, this.b2);

  final int b0;
  final int b1;
  final int b2;

  @override
  bool operator ==(Object other) =>
      other is UnmappedButton &&
      other.b0 == b0 &&
      other.b1 == b1 &&
      other.b2 == b2;

  @override
  int get hashCode => Object.hash(b0, b1, b2);

  @override
  String toString() => 'UnmappedButton($b0, $b1, $b2)';
}

class ButtonShortcut {
  const ButtonShortcut(this.label, this.group, this.key);

  final String label;
  final ButtonFunctionGroup group;
  final KeyButton key;
}

const _ctrl = KeyModifiers(ctrl: true);
const _alt = KeyModifiers(alt: true);
const _win = KeyModifiers(win: true);

const buttonShortcuts = [
  ButtonShortcut(
    'Cut',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x1B, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Copy',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x06, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Paste',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x19, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Undo',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x1D, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Redo',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x1C, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Select all',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x04, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Find',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x09, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Open',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x12, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Save',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x16, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Print',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x13, modifiers: _ctrl),
  ),
  ButtonShortcut(
    'Close window',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x3D, modifiers: _alt),
  ),
  ButtonShortcut(
    'Switch windows',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x2B, modifiers: _alt),
  ),
  ButtonShortcut(
    'Show desktop',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x07, modifiers: _win),
  ),
  ButtonShortcut(
    'Run',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x15, modifiers: _win),
  ),
  ButtonShortcut(
    'Lock PC',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x0F, modifiers: _win),
  ),
  ButtonShortcut(
    'Screen capture',
    ButtonFunctionGroup.shortcuts,
    KeyButton(0x16, modifiers: KeyModifiers(shift: true, win: true)),
  ),
  ButtonShortcut(
    'Favourites',
    ButtonFunctionGroup.browser,
    KeyButton(0x12, modifiers: KeyModifiers(ctrl: true, shift: true)),
  ),
];

final List<ButtonAssignment> factoryButtonAssignments = List.unmodifiable(
  List<ButtonAssignment>.generate(
    ButtonSlot.count,
    (slot) => switch (slot) {
      ButtonSlot.left => const FunctionButton(ButtonFunction.leftClick),
      ButtonSlot.right => const FunctionButton(ButtonFunction.rightClick),
      ButtonSlot.middle => const FunctionButton(ButtonFunction.middleClick),
      ButtonSlot.dpi => const FunctionButton(ButtonFunction.dpiCycle),
      ButtonSlot.forward => const FunctionButton(ButtonFunction.forward),
      ButtonSlot.back => const FunctionButton(ButtonFunction.back),
      ButtonSlot.wheelUp => const FunctionButton(ButtonFunction.scrollUp),
      ButtonSlot.wheelDown => const FunctionButton(ButtonFunction.scrollDown),
      _ => const DisabledButton(),
    },
  ),
);
