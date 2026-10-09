import 'dart:typed_data';

import '../../domain/button_assignment.dart';
import 'report_format.dart';

const buttonBodyLength = ButtonSlot.count * 3;

const _disabledCode = 0x01;
const _keyCode = 0x11;
const _macroCode = 0x12;

abstract final class _Mod {
  static const ctrl = 0x01;
  static const shift = 0x02;
  static const alt = 0x04;
  static const win = 0x08;
}

const Map<ButtonFunction, (int, int)> _functionCodes = {
  ButtonFunction.leftClick: (0x02, 0x00),
  ButtonFunction.rightClick: (0x03, 0x00),
  ButtonFunction.middleClick: (0x04, 0x00),
  ButtonFunction.back: (0x05, 0x00),
  ButtonFunction.forward: (0x06, 0x00),
  ButtonFunction.doubleClick: (0x07, 0x00),
  ButtonFunction.fireButton: (0x08, 0x00),
  ButtonFunction.scrollUp: (0x09, 0x00),
  ButtonFunction.scrollDown: (0x0A, 0x00),
  ButtonFunction.tiltLeft: (0x0B, 0x00),
  ButtonFunction.tiltRight: (0x0C, 0x00),
  ButtonFunction.dpiCycle: (0x0D, 0x00),
  ButtonFunction.dpiUp: (0x0E, 0x00),
  ButtonFunction.dpiDown: (0x0F, 0x00),
  ButtonFunction.easyAim: (0x10, 0x03),
  ButtonFunction.mediaPlayer: (0x15, 0x00),
  ButtonFunction.previousTrack: (0x16, 0x00),
  ButtonFunction.nextTrack: (0x17, 0x00),
  ButtonFunction.playPause: (0x18, 0x00),
  ButtonFunction.mediaStop: (0x19, 0x00),
  ButtonFunction.mute: (0x1A, 0x00),
  ButtonFunction.volumeUp: (0x1B, 0x00),
  ButtonFunction.volumeDown: (0x1C, 0x00),
  ButtonFunction.calculator: (0x1D, 0x00),
  ButtonFunction.email: (0x1E, 0x00),
  ButtonFunction.browserForward: (0x20, 0x00),
  ButtonFunction.browserBack: (0x21, 0x00),
  ButtonFunction.browserStop: (0x22, 0x00),
  ButtonFunction.myComputer: (0x23, 0x00),
  ButtonFunction.browserRefresh: (0x24, 0x00),
  ButtonFunction.browserHome: (0x25, 0x00),
  ButtonFunction.browserSearch: (0x26, 0x00),
  ButtonFunction.ledModeCycle: (0x29, 0x03),
  ButtonFunction.profileCycle: (0x34, 0x00),
  ButtonFunction.profileUp: (0x35, 0x00),
  ButtonFunction.profileDown: (0x36, 0x00),
};

final Map<int, ButtonFunction> _functionsByCode = {
  for (final e in _functionCodes.entries) e.value.$1: e.key,
};

const List<int> _macroSlotIds = [1, 5, 9, 0, 0, 0, 13, 17];

int macroSlotId(int buttonSlot) =>
    buttonSlot < _macroSlotIds.length ? _macroSlotIds[buttonSlot] : 0;

bool supportsMacro(int buttonSlot) => macroSlotId(buttonSlot) != 0;

int encodeModifiers(KeyModifiers m) =>
    (m.ctrl ? _Mod.ctrl : 0) |
    (m.shift ? _Mod.shift : 0) |
    (m.alt ? _Mod.alt : 0) |
    (m.win ? _Mod.win : 0);

KeyModifiers decodeModifiers(int mask) => KeyModifiers(
  ctrl: mask & _Mod.ctrl != 0,
  shift: mask & _Mod.shift != 0,
  alt: mask & _Mod.alt != 0,
  win: mask & _Mod.win != 0,
);

(int, int, int) encodeButtonEntry(int slot, ButtonAssignment assignment) =>
    switch (assignment) {
      DisabledButton() => (_disabledCode, 0, 0),
      FunctionButton(:final function) => (
        _functionCodes[function]!.$1,
        0,
        _functionCodes[function]!.$2,
      ),
      KeyButton(:final usage, :final modifiers) => (
        _keyCode,
        encodeModifiers(modifiers),
        usage & 0xFF,
      ),
      MacroButton() =>
        supportsMacro(slot)
            ? (_macroCode, 0, macroSlotId(slot))
            : throw ArgumentError.value(
                slot,
                'slot',
                'Slot cannot hold a macro',
              ),
      UnmappedButton(:final b0, :final b1, :final b2) => (b0, b1, b2),
    };

ButtonAssignment decodeButtonEntry(int b0, int b1, int b2) {
  if (b0 == 0x00 || b0 == _disabledCode) return const DisabledButton();
  if (b0 == _keyCode) return KeyButton(b2, modifiers: decodeModifiers(b1));
  if (b0 == _macroCode) return const MacroButton();
  final function = _functionsByCode[b0];
  if (function != null && _functionCodes[function]!.$2 == b2 && b1 == 0) {
    return FunctionButton(function);
  }
  return UnmappedButton(b0, b1, b2);
}

Uint8List encodeButtonReport(List<ButtonAssignment> buttons) {
  final buffer = Uint8List(ReportLength.buttons);
  buffer[0] = ReportId.buttons;
  buffer[1] = ReportLength.buttons;
  buffer[2] = 0x01;
  writeButtonBody(buffer, 3, buttons);
  writeUint16Be(buffer, 57, sumBytes(buffer, 3, 56));
  return buffer;
}

List<ButtonAssignment> decodeButtonReport(List<int> bytes) {
  expectHeader(bytes, const [
    ReportId.buttons,
    ReportLength.buttons,
    0x01,
  ], ReportLength.buttons);
  expectChecksum(sumBytes(bytes, 3, 56), readUint16Be(bytes, 57), '0x08');
  return readButtonBody(bytes, 3);
}

void writeButtonBody(
  Uint8List buffer,
  int offset,
  List<ButtonAssignment> buttons,
) {
  if (buttons.length != ButtonSlot.count) {
    throw ArgumentError.value(buttons.length, 'buttons', 'Expected 18 slots');
  }
  for (var slot = 0; slot < ButtonSlot.count; slot++) {
    final (b0, b1, b2) = encodeButtonEntry(slot, buttons[slot]);
    final o = offset + slot * 3;
    buffer[o] = b0;
    buffer[o + 1] = b1;
    buffer[o + 2] = b2;
  }
}

List<ButtonAssignment> readButtonBody(List<int> bytes, int offset) =>
    List.generate(ButtonSlot.count, (slot) {
      final o = offset + slot * 3;
      return decodeButtonEntry(bytes[o], bytes[o + 1], bytes[o + 2]);
    });
