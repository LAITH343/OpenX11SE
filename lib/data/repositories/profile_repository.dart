import 'package:sqlite3/common.dart';

import '../../domain/button_assignment.dart';
import '../../domain/device_settings.dart';
import '../../domain/macro.dart';
import '../../domain/profile.dart';
import '../db/app_database.dart';
import '../db/schema.dart';
import '../json/device_settings_json.dart';

const defaultProfileName = 'Default';

class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  static const _tables = {Tables.profiles, Tables.buttonMacroLinks};

  CommonDatabase get _raw => _db.raw;

  Stream<List<Profile>> watchProfiles() => _db.watch(_tables, _all);

  Stream<Profile> watchActive() => _db.watch(_tables, _active);

  Future<List<Profile>> profiles() async => _all();

  Future<Profile?> profile(int id) async => _byId(id);

  Future<Profile> activeProfile() async => _active();

  Future<Profile> ensureDefault() async {
    final changed = _db.transaction(() {
      final count = _raw.select('SELECT COUNT(*) AS n FROM profiles').first;
      if (count['n'] == 0) {
        _insert(defaultProfileName, DeviceSettings.factoryDefaults, true);
        return true;
      }
      final active = _raw.select('SELECT 1 FROM profiles WHERE is_active = 1');
      if (active.isNotEmpty) return false;
      _raw.execute(
        'UPDATE profiles SET is_active = 1 '
        'WHERE id = (SELECT MIN(id) FROM profiles)',
      );
      return true;
    });
    if (changed) _db.notify(_tables);
    return _active();
  }

  Future<Profile> create(
    String name, {
    DeviceSettings? settings,
    bool activate = false,
  }) async {
    final id = _db.transaction(() {
      if (activate) _raw.execute('UPDATE profiles SET is_active = 0');
      return _insert(
        _validName(name),
        settings ?? DeviceSettings.factoryDefaults,
        activate,
      );
    });
    _db.notify(_tables);
    return _byId(id)!;
  }

  Future<Profile> duplicate(int id, {String? name}) async {
    final source = _require(id);
    return create(name ?? '${source.name} copy', settings: source.settings);
  }

  Future<void> rename(int id, String name) async {
    _require(id);
    _raw.execute('UPDATE profiles SET name = ?, updated_at = ? WHERE id = ?', [
      _validName(name),
      _db.nowMs,
      id,
    ]);
    _db.notify(_tables);
  }

  Future<void> saveSettings(int id, DeviceSettings settings) async {
    _require(id);
    _db.transaction(() {
      _raw.execute(
        'UPDATE profiles SET settings_json = ?, updated_at = ? WHERE id = ?',
        [_encode(settings), _db.nowMs, id],
      );
      _writeLinks(id, settings);
    });
    _db.notify(_tables);
  }

  Future<void> activate(int id) async {
    _require(id);
    _db.transaction(() {
      _raw.execute('UPDATE profiles SET is_active = 0 WHERE is_active = 1');
      _raw.execute('UPDATE profiles SET is_active = 1 WHERE id = ?', [id]);
    });
    _db.notify(_tables);
  }

  Future<void> delete(int id) async {
    final profile = _require(id);
    _db.transaction(() {
      final count = _raw.select('SELECT COUNT(*) AS n FROM profiles').first;
      if (count['n'] == 1) {
        throw StateError('The last profile cannot be deleted');
      }
      _raw.execute('DELETE FROM profiles WHERE id = ?', [id]);
      if (profile.isActive) {
        _raw.execute(
          'UPDATE profiles SET is_active = 1 '
          'WHERE id = (SELECT MIN(id) FROM profiles)',
        );
      }
    });
    _db.notify(_tables);
  }

  int _insert(String name, DeviceSettings settings, bool active) {
    final now = _db.nowMs;
    _raw.execute(
      'INSERT INTO profiles '
      '(name, settings_json, is_active, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [name, _encode(settings), active ? 1 : 0, now, now],
    );
    final id = _raw.lastInsertRowId;
    _writeLinks(id, settings);
    return id;
  }

  void _writeLinks(int profileId, DeviceSettings settings) {
    _raw.execute('DELETE FROM button_macro_links WHERE profile_id = ?', [
      profileId,
    ]);
    for (var slot = 0; slot < settings.buttons.length; slot++) {
      final button = settings.buttons[slot];
      if (button is! MacroButton) continue;
      final macroId = button.macroId;
      if (macroId == null) continue;
      _raw.execute(
        'INSERT INTO button_macro_links '
        '(profile_id, slot, macro_id, playback_mode, loop_count) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          profileId,
          slot,
          macroId,
          button.playback.mode.name,
          button.playback.loopCount,
        ],
      );
    }
  }

  List<Profile> _all() => _query('SELECT * FROM profiles ORDER BY id');

  Profile _active() {
    final found = _query('SELECT * FROM profiles WHERE is_active = 1');
    if (found.isEmpty) throw StateError('No active profile');
    return found.single;
  }

  Profile? _byId(int id) {
    final found = _query('SELECT * FROM profiles WHERE id = ?', [id]);
    return found.isEmpty ? null : found.single;
  }

  Profile _require(int id) =>
      _byId(id) ?? (throw StateError('Profile $id does not exist'));

  List<Profile> _query(String sql, [List<Object?> args = const []]) {
    final rows = _raw.select(sql, args);
    if (rows.isEmpty) return const [];
    final links = _links(rows.map((r) => r['id'] as int));
    return [
      for (final row in rows)
        Profile(
          id: row['id'] as int,
          name: row['name'] as String,
          settings: _decode(
            row['settings_json'] as String,
            links[row['id']] ?? const {},
          ),
          isActive: row['is_active'] == 1,
          createdAt: _time(row['created_at'] as int),
          updatedAt: _time(row['updated_at'] as int),
        ),
    ];
  }

  Map<int, Map<int, MacroButton>> _links(Iterable<int> profileIds) {
    final ids = profileIds.toList();
    final rows = _raw.select(
      'SELECT * FROM button_macro_links WHERE profile_id IN '
      '(${List.filled(ids.length, '?').join(', ')})',
      ids,
    );
    final result = <int, Map<int, MacroButton>>{};
    for (final row in rows) {
      final mode = MacroPlaybackMode.values.byName(
        row['playback_mode'] as String,
      );
      (result[row['profile_id'] as int] ??= {})[row['slot']
          as int] = MacroButton(
        macroId: row['macro_id'] as int,
        playback: MacroPlayback(
          mode: mode,
          loopCount: row['loop_count'] as int,
        ),
      );
    }
    return result;
  }

  static String _encode(DeviceSettings settings) => encodeDeviceSettingsJson(
    settings.copyWith(
      buttons: [
        for (final b in settings.buttons)
          b is MacroButton ? MacroButton(playback: b.playback) : b,
      ],
    ),
  );

  static DeviceSettings _decode(String json, Map<int, MacroButton> links) {
    DeviceSettings settings;
    try {
      settings = decodeDeviceSettingsJson(json);
    } on FormatException {
      settings = DeviceSettings.factoryDefaults;
    }
    if (links.isEmpty) return settings;
    return settings.copyWith(
      buttons: [
        for (var slot = 0; slot < settings.buttons.length; slot++)
          links[slot] ?? settings.buttons[slot],
      ],
    );
  }

  static String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'is empty');
    return trimmed;
  }

  static DateTime _time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
