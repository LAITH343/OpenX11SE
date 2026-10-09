import '../../domain/device_info.dart';
import '../../domain/device_settings.dart';
import '../db/app_database.dart';
import '../db/schema.dart';
import '../json/device_settings_json.dart';

class CachedDevice {
  const CachedDevice({
    required this.info,
    required this.settings,
    required this.includesButtons,
    required this.updatedAt,
  });

  final DeviceInfo info;
  final DeviceSettings settings;
  final bool includesButtons;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is CachedDevice &&
      other.info == info &&
      other.settings == settings &&
      other.includesButtons == includesButtons &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(info, settings, includesButtons, updatedAt);

  @override
  String toString() => 'CachedDevice($info, $updatedAt)';
}

class DeviceCacheRepository {
  DeviceCacheRepository(this._db);

  final AppDatabase _db;

  Future<CachedDevice?> read() async {
    final rows = _db.raw.select('SELECT * FROM device_cache WHERE id = 1');
    if (rows.isEmpty) return null;
    final row = rows.single;
    final connection = ConnectionType.values.asNameMap()[row['connection']];
    if (connection == null) return null;
    final DeviceSettings settings;
    try {
      settings = decodeDeviceSettingsJson(row['settings_json'] as String);
    } on FormatException {
      return null;
    }
    return CachedDevice(
      info: DeviceInfo(
        connection: connection,
        firmwareVersion: row['firmware_version'] as int?,
        batteryPercent: row['battery_percent'] as int?,
      ),
      settings: settings,
      includesButtons: row['includes_buttons'] == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int,
        isUtc: true,
      ),
    );
  }

  Future<void> save({
    required DeviceInfo info,
    required DeviceSettings settings,
    required bool includesButtons,
  }) async {
    _db.raw.execute(
      'INSERT OR REPLACE INTO device_cache '
      '(id, connection, firmware_version, battery_percent, settings_json, '
      'includes_buttons, updated_at) VALUES (1, ?, ?, ?, ?, ?, ?)',
      [
        info.connection.name,
        info.firmwareVersion,
        info.batteryPercent,
        encodeDeviceSettingsJson(settings),
        includesButtons ? 1 : 0,
        _db.nowMs,
      ],
    );
    _db.notify(const {Tables.deviceCache});
  }

  Future<void> clear() async {
    _db.raw.execute('DELETE FROM device_cache');
    _db.notify(const {Tables.deviceCache});
  }
}
