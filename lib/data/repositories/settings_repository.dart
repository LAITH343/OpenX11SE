import '../../domain/app_settings.dart';
import '../db/app_database.dart';
import '../db/schema.dart';

abstract final class _Keys {
  static const theme = 'theme';
  static const accentFollowsStage = 'accent_follows_stage';
  static const autoApply = 'auto_apply';
  static const language = 'language';
  static const lastSection = 'last_section';
  static const startWithSystem = 'start_with_system';
  static const minimiseToTray = 'minimise_to_tray';
  static const autoCheckUpdates = 'auto_check_updates';
  static const lastUpdateCheck = 'last_update_check';
  static const notificationStyle = 'notification_style';
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _tables = {Tables.appSettings};

  Stream<AppSettings> watchSettings() => _db.watch(_tables, _read);

  Future<AppSettings> settings() async => _read();

  Future<void> save(AppSettings settings) async {
    final values = _toMap(settings);
    _db.transaction(() {
      for (final MapEntry(:key, :value) in values.entries) {
        if (value == null) {
          _db.raw.execute('DELETE FROM app_settings WHERE key = ?', [key]);
        } else {
          _db.raw.execute(
            'INSERT INTO app_settings (key, value) VALUES (?, ?) '
            'ON CONFLICT (key) DO UPDATE SET value = excluded.value',
            [key, value],
          );
        }
      }
    });
    _db.notify(_tables);
  }

  Future<AppSettings> update(AppSettings Function(AppSettings) change) async {
    final next = change(_read());
    await save(next);
    return next;
  }

  AppSettings _read() {
    final stored = {
      for (final row in _db.raw.select('SELECT key, value FROM app_settings'))
        row['key'] as String: row['value'] as String,
    };
    const d = AppSettings.defaults;
    bool flag(String key, bool fallback) => switch (stored[key]) {
      '1' => true,
      '0' => false,
      _ => fallback,
    };
    return AppSettings(
      theme: AppTheme.values.asNameMap()[stored[_Keys.theme]] ?? d.theme,
      accentFollowsStage: flag(_Keys.accentFollowsStage, d.accentFollowsStage),
      autoApply: flag(_Keys.autoApply, d.autoApply),
      language: stored[_Keys.language] ?? d.language,
      lastSection: stored[_Keys.lastSection],
      startWithSystem: flag(_Keys.startWithSystem, d.startWithSystem),
      minimiseToTray: flag(_Keys.minimiseToTray, d.minimiseToTray),
      autoCheckUpdates: flag(_Keys.autoCheckUpdates, d.autoCheckUpdates),
      lastUpdateCheck: switch (int.tryParse(
        stored[_Keys.lastUpdateCheck] ?? '',
      )) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        null => null,
      },
      notificationStyle:
          NotificationStyle.values.asNameMap()[stored[_Keys
              .notificationStyle]] ??
          d.notificationStyle,
    );
  }

  static Map<String, String?> _toMap(AppSettings s) {
    String flag(bool v) => v ? '1' : '0';
    return {
      _Keys.theme: s.theme.name,
      _Keys.accentFollowsStage: flag(s.accentFollowsStage),
      _Keys.autoApply: flag(s.autoApply),
      _Keys.language: s.language,
      _Keys.lastSection: s.lastSection,
      _Keys.startWithSystem: flag(s.startWithSystem),
      _Keys.minimiseToTray: flag(s.minimiseToTray),
      _Keys.autoCheckUpdates: flag(s.autoCheckUpdates),
      _Keys.lastUpdateCheck: s.lastUpdateCheck?.millisecondsSinceEpoch
          .toString(),
      _Keys.notificationStyle: s.notificationStyle.name,
    };
  }
}
