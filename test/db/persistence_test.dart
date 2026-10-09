import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/db/schema.dart';
import 'package:openx11se/data/json/device_settings_json.dart';
import 'package:openx11se/data/repositories/device_cache_repository.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/domain/app_settings.dart';
import 'package:openx11se/domain/button_assignment.dart';
import 'package:openx11se/domain/device_info.dart';
import 'package:openx11se/domain/device_settings.dart';
import 'package:openx11se/domain/lighting_settings.dart';
import 'package:openx11se/domain/macro.dart';
import 'package:openx11se/domain/polling_rate.dart';
import 'package:openx11se/domain/rgb_color.dart';
import 'package:sqlite3/sqlite3.dart';

final defaults = DeviceSettings.factoryDefaults;

final clickMacro = Macro(
  name: 'Click',
  events: const [
    MacroEvent(
      kind: MacroEventKind.key,
      code: 0x04,
      action: MacroAction.press,
      delayMs: 20,
    ),
    MacroEvent(
      kind: MacroEventKind.key,
      code: 0x04,
      action: MacroAction.release,
      delayMs: 20,
    ),
    MacroEvent(
      kind: MacroEventKind.mouse,
      code: MacroMouseCode.left,
      action: MacroAction.press,
      delayMs: 2000,
    ),
    MacroEvent(
      kind: MacroEventKind.mouse,
      code: MacroMouseCode.left,
      action: MacroAction.release,
      delayMs: 0,
    ),
  ],
);

DeviceSettings customSettings() => defaults
    .copyWith(
      dpi: defaults.dpi
          .withStage(
            6,
            defaults.dpi.stages[6].copyWith(
              enabled: true,
              dpi: 12000,
              color: const RgbColor.hex(0x123456),
            ),
          )
          .copyWith(activeStageIndex: 6),
      sensor: defaults.sensor.copyWith(angleSnap: true, ripple: false),
      lighting: defaults.lighting.copyWith(
        mode: LightingMode.breathingDpi,
        speed: 3,
      ),
      power: defaults.power.copyWith(
        sleepMinutes: 5,
        deepSleepMinutes: 30,
        debounceMs: 12,
      ),
      polling: PollingRate.hz500,
    )
    .withButton(
      ButtonSlot.back,
      const KeyButton(0x06, modifiers: KeyModifiers(ctrl: true, shift: true)),
    )
    .withButton(ButtonSlot.wheelUp, const DisabledButton())
    .withButton(3, const UnmappedButton(0x55, 0x01, 0x02));

void main() {
  late AppDatabase db;
  var now = DateTime.utc(2026, 1, 1);

  setUp(() {
    now = DateTime.utc(2026, 1, 1);
    db = AppDatabase(sqlite3.openInMemory(), clock: () => now);
  });

  tearDown(() => db.close());

  group('schema', () {
    test('sets user_version and creates every table', () {
      expect(db.raw.userVersion, schemaVersion);
      final tables = db.raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'])
          .toSet();
      expect(
        tables,
        containsAll([
          Tables.profiles,
          Tables.macros,
          Tables.macroEvents,
          Tables.buttonMacroLinks,
          Tables.appSettings,
          Tables.deviceCache,
        ]),
      );
    });

    test('migrating an up-to-date database is a no-op', () {
      migrateSchema(db.raw);
      expect(db.raw.userVersion, schemaVersion);
    });

    test('rejects a database from a newer schema', () {
      final raw = sqlite3.openInMemory()..userVersion = schemaVersion + 1;
      expect(() => AppDatabase(raw), throwsStateError);
      raw.close();
    });
  });

  group('settings json', () {
    test('round-trips custom settings', () {
      final settings = customSettings().withButton(
        ButtonSlot.forward,
        const MacroButton(
          macroId: 4,
          playback: MacroPlayback(mode: MacroPlaybackMode.once, loopCount: 3),
        ),
      );
      expect(
        decodeDeviceSettingsJson(encodeDeviceSettingsJson(settings)),
        settings,
      );
    });

    test('missing sections fall back to factory defaults', () {
      expect(
        decodeDeviceSettingsJson('{"version":1,"pollingHz":250}'),
        defaults.copyWith(polling: PollingRate.hz250),
      );
    });

    test('rejects malformed values', () {
      expect(
        () => decodeDeviceSettingsJson('{"pollingHz":333}'),
        throwsFormatException,
      );
      expect(
        () => decodeDeviceSettingsJson('{"buttons":[]}'),
        throwsFormatException,
      );
      expect(
        () => decodeDeviceSettingsJson('{"version":99}'),
        throwsFormatException,
      );
    });
  });

  group('ProfileRepository', () {
    late ProfileRepository profiles;
    late MacroRepository macros;

    setUp(() {
      profiles = ProfileRepository(db);
      macros = MacroRepository(db);
    });

    test('creates one active default profile on first launch', () async {
      final active = await profiles.ensureDefault();
      expect(active.name, defaultProfileName);
      expect(active.isActive, isTrue);
      expect(active.settings, defaults);
      await profiles.ensureDefault();
      expect(await profiles.profiles(), hasLength(1));
    });

    test('reactivates a profile when none is active', () async {
      await profiles.ensureDefault();
      db.raw.execute('UPDATE profiles SET is_active = 0');
      expect((await profiles.ensureDefault()).isActive, isTrue);
    });

    test('saves settings and timestamps', () async {
      final p = await profiles.ensureDefault();
      now = DateTime.utc(2026, 2, 1);
      await profiles.saveSettings(p.id, customSettings());
      final saved = (await profiles.profile(p.id))!;
      expect(saved.settings, customSettings());
      expect(saved.createdAt, DateTime.utc(2026, 1, 1));
      expect(saved.updatedAt, DateTime.utc(2026, 2, 1));
    });

    test('create, duplicate, rename, activate and delete', () async {
      final first = await profiles.ensureDefault();
      final second = await profiles.create(
        '  FPS  ',
        settings: customSettings(),
      );
      expect(second.name, 'FPS');
      expect(second.isActive, isFalse);

      final copy = await profiles.duplicate(second.id);
      expect(copy.name, 'FPS copy');
      expect(copy.settings, customSettings());

      await profiles.rename(copy.id, 'Desktop work');
      await profiles.activate(copy.id);
      expect((await profiles.activeProfile()).name, 'Desktop work');
      expect(
        (await profiles.profiles()).where((p) => p.isActive),
        hasLength(1),
      );

      await profiles.delete(copy.id);
      final active = await profiles.activeProfile();
      expect(active.id, first.id);
      expect(() => profiles.rename(first.id, '   '), throwsArgumentError);
    });

    test('refuses to delete the last profile', () async {
      final only = await profiles.ensureDefault();
      await expectLater(profiles.delete(only.id), throwsStateError);
      expect(await profiles.profiles(), hasLength(1));
    });

    test('stores macro assignments as links', () async {
      final macro = await macros.create(clickMacro);
      final p = await profiles.ensureDefault();
      const playback = MacroPlayback(
        mode: MacroPlaybackMode.once,
        loopCount: 3,
      );
      final settings = defaults.withButton(
        ButtonSlot.forward,
        MacroButton(macroId: macro.id, playback: playback),
      );
      await profiles.saveSettings(p.id, settings);

      final links = db.raw.select('SELECT * FROM button_macro_links');
      expect(links, hasLength(1));
      expect(links.first['slot'], ButtonSlot.forward);
      expect(links.first['macro_id'], macro.id);
      expect(links.first['loop_count'], 3);
      expect((await profiles.profile(p.id))!.settings, settings);

      await macros.delete(macro.id!);
      final after = (await profiles.profile(p.id))!.settings;
      expect(
        after.buttons[ButtonSlot.forward],
        const MacroButton(playback: playback),
      );
    });

    test('rejects links to missing macros', () async {
      final p = await profiles.ensureDefault();
      await expectLater(
        profiles.saveSettings(
          p.id,
          defaults.withButton(ButtonSlot.left, const MacroButton(macroId: 99)),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect((await profiles.profile(p.id))!.settings, defaults);
    });

    test('watch emits the current list and every change', () async {
      await profiles.ensureDefault();
      final names = <List<String>>[];
      final sub = profiles.watchProfiles().listen(
        (list) => names.add([for (final p in list) p.name]),
      );
      await pumpEventQueue();
      await profiles.create('Second');
      await pumpEventQueue();
      await sub.cancel();
      expect(names, [
        [defaultProfileName],
        [defaultProfileName, 'Second'],
      ]);
    });
  });

  group('MacroRepository', () {
    late MacroRepository macros;

    setUp(() => macros = MacroRepository(db));

    test('round-trips events in order', () async {
      final created = await macros.create(clickMacro);
      expect(created.id, isNotNull);
      expect(created.copyWith(id: 0), clickMacro.copyWith(id: 0));
      expect(await macros.macros(), [created]);
    });

    test('save replaces name and events', () async {
      final created = await macros.create(clickMacro);
      final edited = created.copyWith(
        name: 'Reload',
        events: clickMacro.events.reversed.toList(),
      );
      expect(await macros.save(edited), edited);
      expect(await macros.macro(created.id!), edited);
    });

    test('duplicate and delete cascade events', () async {
      final created = await macros.create(clickMacro);
      final copy = await macros.duplicate(created.id!);
      expect(copy.name, 'Click copy');
      expect(copy.events, clickMacro.events);
      await macros.delete(created.id!);
      expect(await macros.macros(), [copy]);
      final orphans = db.raw.select(
        'SELECT * FROM macro_events WHERE macro_id = ?',
        [created.id],
      );
      expect(orphans, isEmpty);
    });

    test('watch emits on changes', () async {
      final counts = <int>[];
      final sub = macros.watchMacros().listen((m) => counts.add(m.length));
      await pumpEventQueue();
      await macros.create(clickMacro);
      await pumpEventQueue();
      await sub.cancel();
      expect(counts, [0, 1]);
    });
  });

  group('SettingsRepository', () {
    late SettingsRepository repo;

    setUp(() => repo = SettingsRepository(db));

    test('returns defaults when empty', () async {
      expect(await repo.settings(), AppSettings.defaults);
    });

    test('persists every field', () async {
      const changed = AppSettings(
        theme: AppTheme.system,
        accentFollowsStage: true,
        autoApply: true,
        language: 'de',
        lastSection: 'macros',
        startWithSystem: false,
        minimiseToTray: false,
        autoReconnect: false,
      );
      await repo.save(changed);
      expect(await repo.settings(), changed);
      expect(await SettingsRepository(db).settings(), changed);
    });

    test('update applies a change and notifies watchers', () async {
      final themes = <AppTheme>[];
      final sub = repo.watchSettings().listen((s) => themes.add(s.theme));
      await pumpEventQueue();
      await repo.update((s) => s.copyWith(theme: AppTheme.light));
      await pumpEventQueue();
      await sub.cancel();
      expect(themes, [AppTheme.dark, AppTheme.light]);
    });

    test('ignores unknown stored values', () async {
      db.raw.execute(
        "INSERT INTO app_settings VALUES ('theme', 'neon'), ('auto_apply', 'x')",
      );
      expect(await repo.settings(), AppSettings.defaults);
    });
  });

  group('DeviceCacheRepository', () {
    test('stores the last snapshot', () async {
      final cache = DeviceCacheRepository(db);
      expect(await cache.read(), isNull);
      const info = DeviceInfo(
        connection: ConnectionType.dongle,
        firmwareVersion: 0x0812,
        batteryPercent: 76,
      );
      await cache.save(
        info: info,
        settings: customSettings(),
        includesButtons: true,
      );
      final cached = (await cache.read())!;
      expect(cached.info, info);
      expect(cached.settings, customSettings());
      expect(cached.includesButtons, isTrue);
      expect(cached.updatedAt, now);

      await cache.save(info: info, settings: defaults, includesButtons: false);
      expect((await cache.read())!.settings, defaults);
      await cache.clear();
      expect(await cache.read(), isNull);
    });
  });

  test('data survives reopening a database file', () async {
    final dir = await Directory.systemTemp.createTemp('openx11se_db');
    final path = '${dir.path}${Platform.pathSeparator}app.db';
    try {
      var fileDb = AppDatabase(sqlite3.open(path));
      final p = await ProfileRepository(fileDb).ensureDefault();
      await ProfileRepository(fileDb).saveSettings(p.id, customSettings());
      await SettingsRepository(
        fileDb,
      ).save(const AppSettings(theme: AppTheme.light));
      await fileDb.close();

      fileDb = AppDatabase(sqlite3.open(path));
      final reopened = await ProfileRepository(fileDb).activeProfile();
      expect(reopened.settings, customSettings());
      expect(
        (await SettingsRepository(fileDb).settings()).theme,
        AppTheme.light,
      );
      await fileDb.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
