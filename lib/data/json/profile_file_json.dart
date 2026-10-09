import 'dart:convert';

import '../../domain/button_assignment.dart';
import '../../domain/device_settings.dart';
import '../../domain/macro.dart';
import 'device_settings_json.dart';

const profileFileExtension = 'x11profile';
const profileFileFormat = 'openx11se-profile';
const profileFileVersion = 1;

class ProfileFile {
  ProfileFile({
    required this.name,
    required this.settings,
    Map<int, Macro> macros = const {},
  }) : macros = Map.unmodifiable(macros);

  final String name;
  final DeviceSettings settings;
  final Map<int, Macro> macros;
}

String encodeProfileFile(ProfileFile file) {
  final used = {
    for (final b in file.settings.buttons)
      if (b case MacroButton(:final macroId?)) macroId,
  };
  return const JsonEncoder.withIndent('  ').convert({
    'format': profileFileFormat,
    'version': profileFileVersion,
    'name': file.name,
    'settings': deviceSettingsToJson(file.settings),
    'macros': [
      for (final MapEntry(:key, :value) in file.macros.entries)
        if (used.contains(key))
          {
            'id': key,
            'name': value.name,
            'events': [for (final e in value.events) _eventToJson(e)],
          },
    ],
  });
}

ProfileFile decodeProfileFile(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const FormatException('Not a profile file');
  }
  if (decoded is! Map<String, Object?> ||
      decoded['format'] != profileFileFormat) {
    throw const FormatException('Not a profile file');
  }
  final version = decoded['version'];
  if (version is! int || version > profileFileVersion) {
    throw FormatException('Unsupported profile file version $version');
  }
  final name = decoded['name'];
  final settings = decoded['settings'];
  if (name is! String || name.trim().isEmpty) {
    throw const FormatException('Missing profile name');
  }
  if (settings is! Map<String, Object?>) {
    throw const FormatException('Missing profile settings');
  }
  final macros = <int, Macro>{};
  final list = decoded['macros'] ?? const <Object?>[];
  if (list is! List<Object?>) throw const FormatException('Invalid macros');
  for (final item in list) {
    if (item is! Map<String, Object?>) {
      throw const FormatException('Invalid macro');
    }
    final id = item['id'];
    final macroName = item['name'];
    final events = item['events'];
    if (id is! int || macroName is! String || events is! List<Object?>) {
      throw const FormatException('Invalid macro');
    }
    macros[id] = Macro(
      name: macroName,
      events: [for (final e in events) _eventFromJson(e)],
    );
  }
  return ProfileFile(
    name: name.trim(),
    settings: deviceSettingsFromJson(settings),
    macros: macros,
  );
}

Map<String, Object?> _eventToJson(MacroEvent e) => {
  'kind': e.kind.name,
  if (!e.isDelay) 'code': e.code,
  if (!e.isDelay) 'action': e.action.name,
  'delayMs': e.delayMs,
};

MacroEvent _eventFromJson(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Invalid macro event');
  }
  final kind = MacroEventKind.values.asNameMap()[value['kind']];
  final delay = value['delayMs'];
  if (kind == null || delay is! int || delay < 0) {
    throw const FormatException('Invalid macro event');
  }
  if (kind == MacroEventKind.delay) return MacroEvent.delay(delay);
  final code = value['code'];
  final action = MacroAction.values.asNameMap()[value['action']];
  if (code is! int || code < 0 || code > 0xFF || action == null) {
    throw const FormatException('Invalid macro event');
  }
  return MacroEvent(kind: kind, code: code, action: action, delayMs: delay);
}
