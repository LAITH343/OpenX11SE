import 'dart:typed_data';

import '../../domain/button_assignment.dart';
import '../../domain/device_settings.dart';
import '../../domain/dpi_settings.dart';
import '../../domain/lighting_settings.dart';
import '../../domain/macro.dart';
import '../../domain/polling_rate.dart';
import '../../domain/power_settings.dart';
import '../../domain/rgb_color.dart';
import '../protocol/dpi_codec.dart';

const vendorProfileOffset = 0x7BF38;
const vendorProfileLength = 0x18CA4;

class VendorMacro {
  const VendorMacro(this.macro, this.playback);

  final Macro macro;
  final MacroPlayback playback;
}

class VendorProfile {
  VendorProfile({
    required this.name,
    required this.settings,
    Map<int, VendorMacro> macros = const {},
    List<int> unmappedSlots = const [],
  }) : macros = Map.unmodifiable(macros),
       unmappedSlots = List.unmodifiable(unmappedSlots);

  final String name;
  final DeviceSettings settings;
  final Map<int, VendorMacro> macros;
  final List<int> unmappedSlots;
}

abstract final class _Field {
  static const nameChars = 0x8B4 ~/ 2;
  static const dpiRaw = 0x8C4;
  static const stageEnabled = 0x904;
  static const brightness = 0x924;
  static const speed = 0x928;
  static const deepSleep = 0x92C;
  static const sleep = 0x930;
  static const activeStage = 0x934;
  static const polling = 0x938;
  static const ripple = 0x944;
  static const angleSnap = 0x948;
  static const lightingMode = 0x950;
  static const debounceRaw = 0x95C;
  static const globalColor = 0x960;
  static const stageColors = 0x964;
  static const buttons = 0x9A4;
  static const buttonBlock = 0x1020;
}

abstract final class _Block {
  static const function = 0x001;
  static const keyUsage = 0x003;
  static const modifiers = 0x007;
  static const playMode = 0x00C;
  static const macroName = 0x010;
  static const macroNameChars = 24;
  static const loopCount = 0x040;
  static const eventCount = 0x044;
  static const events = 0x440;
  static const eventSize = 16;
}

const _vendorFunctions = {
  0x01: ButtonFunction.leftClick,
  0x02: ButtonFunction.rightClick,
  0x03: ButtonFunction.middleClick,
  0x04: ButtonFunction.forward,
  0x05: ButtonFunction.back,
  0x06: ButtonFunction.dpiCycle,
  0x07: ButtonFunction.dpiUp,
  0x08: ButtonFunction.dpiDown,
  0x09: ButtonFunction.doubleClick,
  0x0A: ButtonFunction.fireButton,
  0x0B: ButtonFunction.scrollUp,
  0x0C: ButtonFunction.scrollDown,
  0x0D: ButtonFunction.tiltLeft,
  0x0E: ButtonFunction.tiltRight,
  0x16: ButtonFunction.easyAim,
  0x17: ButtonFunction.ledModeCycle,
  0x36: ButtonFunction.profileCycle,
  0x37: ButtonFunction.profileUp,
  0x38: ButtonFunction.profileDown,
};

const _vendorKey = 0x10;
const _vendorMacro = 0x11;
const _firstMouseCode = 0xF1;

VendorProfile decodeVendorProfile(Uint8List bytes) {
  if (bytes.length < vendorProfileOffset + vendorProfileLength) {
    throw const FormatException('Not a vendor profile file');
  }
  final data = ByteData.sublistView(
    bytes,
    vendorProfileOffset,
    vendorProfileOffset + vendorProfileLength,
  );
  int i32(int offset) => data.getInt32(offset, Endian.little);
  int level(int offset, int min, int max, int fallback) {
    final v = i32(offset);
    return v < min || v > max ? fallback : v;
  }

  RgbColor color(int offset) => RgbColor(
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );

  final defaults = DeviceSettings.factoryDefaults;
  final active = level(
    _Field.activeStage,
    0,
    DpiSettings.stageCount - 1,
    defaults.dpi.activeStageIndex,
  );
  final stages = [
    for (var s = 0; s < DpiSettings.stageCount; s++)
      DpiStage(
        enabled: i32(_Field.stageEnabled + 4 * s) != 0,
        dpi: rawToDpi(
          i32(_Field.dpiRaw + 4 * s).clamp(minDpiRaw, maxDpiRaw).toInt(),
        ),
        color: color(_Field.stageColors + 4 * s),
      ),
  ];
  if (!stages.any((s) => s.enabled)) {
    stages[active] = stages[active].copyWith(enabled: true);
  }
  final pollingIndex = i32(_Field.polling);
  final modeIndex = i32(_Field.lightingMode);
  const power = PowerSettings.factoryDefaults;
  final debounce = i32(_Field.debounceRaw) * 2;

  final buttons = <ButtonAssignment>[];
  final macros = <int, VendorMacro>{};
  final unmapped = <int>[];
  for (var slot = 0; slot < ButtonSlot.count; slot++) {
    final block = _Field.buttons + slot * _Field.buttonBlock;
    final code = data.getUint8(block + _Block.function);
    final function = _vendorFunctions[code];
    if (code == 0) {
      buttons.add(const DisabledButton());
    } else if (function != null) {
      buttons.add(FunctionButton(function));
    } else if (code == _vendorKey &&
        data.getUint8(block + _Block.keyUsage) != 0) {
      buttons.add(_keyButton(data, block));
    } else if (code == _vendorMacro) {
      final macro = _macro(data, block, slot);
      macros[slot] = macro;
      buttons.add(MacroButton(playback: macro.playback));
    } else {
      unmapped.add(slot);
      buttons.add(defaults.buttons[slot]);
    }
  }

  return VendorProfile(
    name: _utf16(data, 0, _Field.nameChars),
    settings: DeviceSettings(
      dpi: DpiSettings(stages: stages, activeStageIndex: active),
      sensor: SensorOptions(
        angleSnap: i32(_Field.angleSnap) != 0,
        ripple: i32(_Field.ripple) != 0,
      ),
      lighting: LightingSettings(
        mode: modeIndex >= 0 && modeIndex < LightingMode.values.length
            ? LightingMode.values[modeIndex]
            : defaults.lighting.mode,
        color: color(_Field.globalColor),
        brightness: level(
          _Field.brightness,
          LightingSettings.minLevel,
          LightingSettings.maxLevel,
          defaults.lighting.brightness,
        ),
        speed: level(
          _Field.speed,
          LightingSettings.minLevel,
          LightingSettings.maxLevel,
          defaults.lighting.speed,
        ),
      ),
      power: PowerSettings(
        sleepMinutes: level(
          _Field.sleep,
          PowerSettings.minMinutes,
          PowerSettings.maxMinutes,
          power.sleepMinutes,
        ),
        deepSleepMinutes: level(
          _Field.deepSleep,
          PowerSettings.minMinutes,
          PowerSettings.maxMinutes,
          power.deepSleepMinutes,
        ),
        debounceMs:
            debounce < PowerSettings.minDebounceMs ||
                debounce > PowerSettings.maxDebounceMs
            ? power.debounceMs
            : debounce,
      ),
      polling: pollingIndex >= 0 && pollingIndex < PollingRate.values.length
          ? PollingRate.values[pollingIndex]
          : defaults.polling,
      buttons: buttons,
    ),
    macros: macros,
    unmappedSlots: unmapped,
  );
}

KeyButton _keyButton(ByteData data, int block) {
  final mask = data.getUint8(block + _Block.modifiers);
  return KeyButton(
    data.getUint8(block + _Block.keyUsage),
    modifiers: KeyModifiers(
      ctrl: mask & 0x01 != 0,
      shift: mask & 0x02 != 0,
      alt: mask & 0x04 != 0,
      win: mask & 0x08 != 0,
    ),
  );
}

VendorMacro _macro(ByteData data, int block, int slot) {
  final mode = data.getInt32(block + _Block.playMode, Endian.little);
  final loops = data.getInt32(block + _Block.loopCount, Endian.little);
  const maxEvents = (0x1020 - _Block.events) ~/ _Block.eventSize;
  final count = data
      .getUint16(block + _Block.eventCount, Endian.little)
      .clamp(0, maxEvents);
  final events = [
    for (var e = 0; e < count; e++)
      () {
        final at = block + _Block.events + e * _Block.eventSize;
        final code = data.getUint8(at + 1);
        return MacroEvent(
          kind: code >= _firstMouseCode
              ? MacroEventKind.mouse
              : MacroEventKind.key,
          code: code,
          action: data.getUint8(at + 2) == 1
              ? MacroAction.press
              : MacroAction.release,
          delayMs: data.getUint16(at + 4, Endian.little),
        );
      }(),
  ];
  final name = _utf16(data, block + _Block.macroName, _Block.macroNameChars);
  return VendorMacro(
    Macro(name: name.isEmpty ? 'Macro ${slot + 1}' : name, events: events),
    MacroPlayback(
      mode: mode >= 0 && mode < MacroPlaybackMode.values.length
          ? MacroPlaybackMode.values[mode]
          : MacroPlaybackMode.once,
      loopCount: loops
          .clamp(MacroPlayback.minLoopCount, MacroPlayback.maxLoopCount)
          .toInt(),
    ),
  );
}

String _utf16(ByteData data, int offset, int maxChars) {
  final units = <int>[];
  for (var c = 0; c < maxChars; c++) {
    final unit = data.getUint16(offset + 2 * c, Endian.little);
    if (unit == 0) break;
    units.add(unit);
  }
  return String.fromCharCodes(units).trim();
}
