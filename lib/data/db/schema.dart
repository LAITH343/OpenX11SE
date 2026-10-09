import 'package:sqlite3/common.dart';

abstract final class Tables {
  static const profiles = 'profiles';
  static const macros = 'macros';
  static const macroEvents = 'macro_events';
  static const buttonMacroLinks = 'button_macro_links';
  static const appSettings = 'app_settings';
  static const deviceCache = 'device_cache';
}

typedef Migration = void Function(CommonDatabase db);

const List<Migration> migrations = [_createInitialSchema];

int get schemaVersion => migrations.length;

void migrateSchema(CommonDatabase db) {
  final current = db.userVersion;
  if (current > schemaVersion) {
    throw StateError(
      'Database schema $current is newer than supported $schemaVersion',
    );
  }
  for (var version = current; version < schemaVersion; version++) {
    db.execute('BEGIN IMMEDIATE');
    try {
      migrations[version](db);
      db.userVersion = version + 1;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

void _createInitialSchema(CommonDatabase db) {
  db.execute('''
    CREATE TABLE profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      settings_json TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    ) STRICT;

    CREATE UNIQUE INDEX profiles_single_active
      ON profiles (is_active) WHERE is_active = 1;

    CREATE TABLE macros (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    ) STRICT;

    CREATE TABLE macro_events (
      macro_id INTEGER NOT NULL REFERENCES macros (id) ON DELETE CASCADE,
      position INTEGER NOT NULL,
      kind TEXT NOT NULL CHECK (kind IN ('key', 'mouse')),
      code INTEGER NOT NULL,
      action TEXT NOT NULL CHECK (action IN ('press', 'release')),
      delay_ms INTEGER NOT NULL CHECK (delay_ms >= 0),
      PRIMARY KEY (macro_id, position)
    ) STRICT;

    CREATE TABLE button_macro_links (
      profile_id INTEGER NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
      slot INTEGER NOT NULL,
      macro_id INTEGER NOT NULL REFERENCES macros (id) ON DELETE CASCADE,
      playback_mode TEXT NOT NULL,
      loop_count INTEGER NOT NULL,
      PRIMARY KEY (profile_id, slot)
    ) STRICT;

    CREATE INDEX button_macro_links_macro ON button_macro_links (macro_id);

    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) STRICT;

    CREATE TABLE device_cache (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      connection TEXT NOT NULL,
      firmware_version INTEGER,
      battery_percent INTEGER,
      settings_json TEXT NOT NULL,
      includes_buttons INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    ) STRICT;
  ''');
}
