import 'dart:convert';

import '../../domain/button_assignment.dart';
import '../../domain/device_settings.dart';
import '../../domain/dpi_settings.dart';
import '../../domain/lighting_settings.dart';
import '../../domain/macro.dart';
import '../../domain/polling_rate.dart';
import '../../domain/power_settings.dart';
import '../../domain/rgb_color.dart';

const deviceSettingsJsonVersion = 1;

String encodeDeviceSettingsJson(DeviceSettings settings) =>
    jsonEncode(deviceSettingsToJson(settings));

DeviceSettings decodeDeviceSettingsJson(String source) =>
    deviceSettingsFromJson(_map(jsonDecode(source), 'settings'));

Map<String, Object?> deviceSettingsToJson(DeviceSettings s) => {
  'version': deviceSettingsJsonVersion,
  'dpi': {
    'activeStage': s.dpi.activeStageIndex,
    'stages': [
      for (final stage in s.dpi.stages)
        {
          'enabled': stage.enabled,
          'dpi': stage.dpi,
          'color': colorToJson(stage.color),
        },
    ],
  },
  'sensor': {'angleSnap': s.sensor.angleSnap, 'ripple': s.sensor.ripple},
  'lighting': {
    'mode': s.lighting.mode.name,
    'color': colorToJson(s.lighting.color),
    'brightness': s.lighting.brightness,
    'speed': s.lighting.speed,
  },
  'power': {
    'sleepMinutes': s.power.sleepMinutes,
    'deepSleepMinutes': s.power.deepSleepMinutes,
    'debounceMs': s.power.debounceMs,
  },
  'pollingHz': s.polling.hz,
  'buttons': [for (final b in s.buttons) buttonToJson(b)],
};

DeviceSettings deviceSettingsFromJson(Map<String, Object?> json) {
  final defaults = DeviceSettings.factoryDefaults;
  final version = json['version'];
  if (version is int && version > deviceSettingsJsonVersion) {
    throw FormatException('Unsupported settings version $version');
  }
  return DeviceSettings(
    dpi: _section(json, 'dpi', _dpiFromJson) ?? defaults.dpi,
    sensor: _section(json, 'sensor', _sensorFromJson) ?? defaults.sensor,
    lighting:
        _section(json, 'lighting', _lightingFromJson) ?? defaults.lighting,
    power: _section(json, 'power', _powerFromJson) ?? defaults.power,
    polling: json.containsKey('pollingHz')
        ? _pollingFromJson(json['pollingHz'])
        : defaults.polling,
    buttons: json.containsKey('buttons')
        ? _buttonsFromJson(json['buttons'])
        : defaults.buttons,
  );
}

String colorToJson(RgbColor c) =>
    '#${c.rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

RgbColor colorFromJson(Object? value) {
  if (value is String) {
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value);
    if (match != null) return RgbColor.hex(int.parse(match[1]!, radix: 16));
  }
  throw FormatException('Invalid colour $value');
}

Map<String, Object?> buttonToJson(ButtonAssignment b) => switch (b) {
  DisabledButton() => {'type': 'disabled'},
  FunctionButton(:final function) => {
    'type': 'function',
    'function': function.name,
  },
  KeyButton(:final usage, :final modifiers) => {
    'type': 'key',
    'usage': usage,
    'modifiers': [
      if (modifiers.ctrl) 'ctrl',
      if (modifiers.shift) 'shift',
      if (modifiers.alt) 'alt',
      if (modifiers.win) 'win',
    ],
  },
  MacroButton(:final macroId, :final playback) => {
    'type': 'macro',
    'macroId': ?macroId,
    'playback': playbackToJson(playback),
  },
  UnmappedButton(:final b0, :final b1, :final b2) => {
    'type': 'raw',
    'bytes': [b0, b1, b2],
  },
};

ButtonAssignment buttonFromJson(Object? value) {
  final json = _map(value, 'button');
  return switch (json['type']) {
    'disabled' => const DisabledButton(),
    'function' => FunctionButton(
      _enumByName(ButtonFunction.values, json['function'], 'function'),
    ),
    'key' => KeyButton(
      _byte(json['usage'], 'usage'),
      modifiers: _modifiersFromJson(json['modifiers']),
    ),
    'macro' => MacroButton(
      macroId: _optionalInt(json['macroId'], 'macroId'),
      playback: json.containsKey('playback')
          ? playbackFromJson(json['playback'])
          : MacroPlayback.defaults,
    ),
    'raw' => _rawFromJson(json['bytes']),
    final type => throw FormatException('Unknown button type $type'),
  };
}

Map<String, Object?> playbackToJson(MacroPlayback p) => {
  'mode': p.mode.name,
  'loopCount': p.loopCount,
};

MacroPlayback playbackFromJson(Object? value) {
  final json = _map(value, 'playback');
  final loopCount = json.containsKey('loopCount')
      ? _int(json['loopCount'], 'loopCount')
      : 1;
  if (loopCount < MacroPlayback.minLoopCount ||
      loopCount > MacroPlayback.maxLoopCount) {
    throw FormatException('Invalid loop count $loopCount');
  }
  return MacroPlayback(
    mode: _enumByName(MacroPlaybackMode.values, json['mode'], 'mode'),
    loopCount: loopCount,
  );
}

DpiSettings _dpiFromJson(Map<String, Object?> json) {
  final stages = _list(json['stages'], 'stages');
  if (stages.length != DpiSettings.stageCount) {
    throw const FormatException('Expected 8 DPI stages');
  }
  final active = _int(json['activeStage'], 'activeStage');
  if (active < 0 || active >= DpiSettings.stageCount) {
    throw FormatException('Invalid active stage $active');
  }
  return DpiSettings(
    activeStageIndex: active,
    stages: [
      for (final raw in stages)
        () {
          final stage = _map(raw, 'stage');
          return DpiStage(
            enabled: _bool(stage['enabled'], 'enabled'),
            dpi: _int(stage['dpi'], 'dpi'),
            color: colorFromJson(stage['color']),
          );
        }(),
    ],
  );
}

SensorOptions _sensorFromJson(Map<String, Object?> json) => SensorOptions(
  angleSnap: _bool(json['angleSnap'], 'angleSnap'),
  ripple: _bool(json['ripple'], 'ripple'),
);

LightingSettings _lightingFromJson(Map<String, Object?> json) =>
    LightingSettings(
      mode: _enumByName(LightingMode.values, json['mode'], 'mode'),
      color: colorFromJson(json['color']),
      brightness: _level(json['brightness'], 'brightness'),
      speed: _level(json['speed'], 'speed'),
    );

PowerSettings _powerFromJson(Map<String, Object?> json) => PowerSettings(
  sleepMinutes: _int(json['sleepMinutes'], 'sleepMinutes'),
  deepSleepMinutes: _int(json['deepSleepMinutes'], 'deepSleepMinutes'),
  debounceMs: _int(json['debounceMs'], 'debounceMs'),
);

PollingRate _pollingFromJson(Object? value) {
  final hz = _int(value, 'pollingHz');
  for (final rate in PollingRate.values) {
    if (rate.hz == hz) return rate;
  }
  throw FormatException('Unsupported polling rate $hz');
}

List<ButtonAssignment> _buttonsFromJson(Object? value) {
  final list = _list(value, 'buttons');
  if (list.length != ButtonSlot.count) {
    throw const FormatException('Expected 18 button slots');
  }
  return [for (final b in list) buttonFromJson(b)];
}

KeyModifiers _modifiersFromJson(Object? value) {
  if (value == null) return KeyModifiers.none;
  final names = _list(value, 'modifiers');
  return KeyModifiers(
    ctrl: names.contains('ctrl'),
    shift: names.contains('shift'),
    alt: names.contains('alt'),
    win: names.contains('win'),
  );
}

UnmappedButton _rawFromJson(Object? value) {
  final bytes = _list(value, 'bytes');
  if (bytes.length != 3) throw const FormatException('Expected 3 raw bytes');
  return UnmappedButton(
    _byte(bytes[0], 'bytes'),
    _byte(bytes[1], 'bytes'),
    _byte(bytes[2], 'bytes'),
  );
}

T? _section<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?>) parse,
) => json.containsKey(key) ? parse(_map(json[key], key)) : null;

Map<String, Object?> _map(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('Expected an object for $field');
}

List<Object?> _list(Object? value, String field) {
  if (value is List<Object?>) return value;
  throw FormatException('Expected a list for $field');
}

int _int(Object? value, String field) {
  if (value is int) return value;
  throw FormatException('Expected an integer for $field');
}

int? _optionalInt(Object? value, String field) =>
    value == null ? null : _int(value, field);

int _byte(Object? value, String field) {
  final v = _int(value, field);
  if (v < 0 || v > 0xFF) throw FormatException('Invalid byte for $field');
  return v;
}

int _level(Object? value, String field) {
  final v = _int(value, field);
  if (v < LightingSettings.minLevel || v > LightingSettings.maxLevel) {
    throw FormatException('Invalid $field $v');
  }
  return v;
}

bool _bool(Object? value, String field) {
  if (value is bool) return value;
  throw FormatException('Expected a boolean for $field');
}

T _enumByName<T extends Enum>(List<T> values, Object? name, String field) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('Unknown $field $name');
}
