import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/files/profile_files.dart';
import 'package:openx11se/data/json/profile_file_json.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/profile_transfer_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/data/system/system_integration.dart';
import 'package:openx11se/data/vendor/vendor_profile.dart';
import 'package:openx11se/domain/app_settings.dart';
import 'package:openx11se/domain/button_assignment.dart';
import 'package:openx11se/domain/device_settings.dart';
import 'package:openx11se/domain/lighting_settings.dart';
import 'package:openx11se/domain/macro.dart';
import 'package:openx11se/domain/polling_rate.dart';
import 'package:openx11se/domain/rgb_color.dart';
import 'package:openx11se/domain/settings_changes.dart';
import 'package:openx11se/ui/settings/settings_view_model.dart';
import 'package:openx11se/ui/shell/appearance_view_model.dart';
import 'package:openx11se/ui/shell/edit_session_view_model.dart';
import 'package:openx11se/ui/shell/profiles_view_model.dart';
import 'package:openx11se/ui/shell/shell_view_model.dart';
import 'package:openx11se/ui/widgets/toast_host.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_hid.dart';

const instant = DeviceTiming(
  reportGap: Duration.zero,
  readDelay: Duration.zero,
  ackTimeout: Duration(milliseconds: 20),
);

final defaults = DeviceSettings.factoryDefaults;

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

class FakeProfileFiles implements ProfileFiles {
  Uint8List? picked;
  Uint8List? vendor;
  final saved = <String, Uint8List>{};

  @override
  bool get supportsVendorImport => true;

  @override
  Future<Uint8List?> pickProfile() async => picked;

  @override
  Future<bool> saveProfile(String fileName, Uint8List bytes) async {
    saved[fileName] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> readVendorProfile() async => vendor;
}

class FakeSystem implements SystemIntegration {
  final calls = <String>[];

  @override
  bool get supportsStartup => true;

  @override
  bool get supportsTray => true;

  @override
  Future<void> setLaunchAtStartup(bool enabled) async =>
      calls.add('startup $enabled');

  @override
  Future<void> setMinimiseToTray(bool enabled) async =>
      calls.add('tray $enabled');

  @override
  Future<void> quit() async => calls.add('quit');
}

Uint8List vendorFile({required void Function(ByteData profile) fill}) {
  final bytes = Uint8List(vendorProfileOffset + vendorProfileLength);
  fill(ByteData.sublistView(bytes, vendorProfileOffset));
  return bytes;
}

void writeVendorDefaults(ByteData p) {
  void i32(int offset, int value) => p.setInt32(offset, value, Endian.little);
  const name = 'Gaming';
  for (var i = 0; i < name.length; i++) {
    p.setUint16(2 * i, name.codeUnitAt(i), Endian.little);
  }
  const raws = [16, 32, 48, 64, 100, 320, 1, 1];
  for (var s = 0; s < 8; s++) {
    i32(0x8C4 + 4 * s, raws[s]);
    i32(0x904 + 4 * s, s < 6 ? 1 : 0);
  }
  i32(0x924, 3);
  i32(0x928, 5);
  i32(0x92C, 12);
  i32(0x930, 2);
  i32(0x934, 1);
  i32(0x938, 2);
  i32(0x944, 0);
  i32(0x948, 1);
  i32(0x950, 1);
  i32(0x95C, 6);
  p
    ..setUint8(0x960, 0x12)
    ..setUint8(0x961, 0x34)
    ..setUint8(0x962, 0x56);
  for (var s = 0; s < 8; s++) {
    p.setUint8(0x964 + 4 * s, s * 10);
  }
  const functions = {0: 1, 1: 2, 2: 3, 5: 6, 6: 4, 7: 5, 16: 0x0B, 17: 0x0C};
  for (var slot = 0; slot < 18; slot++) {
    p.setUint8(0x9A4 + slot * 0x1020, slot);
    p.setUint8(0x9A4 + slot * 0x1020 + 1, functions[slot] ?? 0);
  }
}

void main() {
  group('profile file', () {
    test('round-trips settings and referenced macros', () {
      final settings = defaults.withButton(
        ButtonSlot.forward,
        const MacroButton(
          macroId: 7,
          playback: MacroPlayback(mode: MacroPlaybackMode.once, loopCount: 3),
        ),
      );
      final macro = Macro(
        name: 'Reload',
        events: const [
          MacroEvent(
            kind: MacroEventKind.key,
            code: 0x15,
            action: MacroAction.press,
            delayMs: 20,
          ),
          MacroEvent.delay(500),
          MacroEvent(
            kind: MacroEventKind.mouse,
            code: MacroMouseCode.left,
            action: MacroAction.release,
            delayMs: 10,
          ),
        ],
      );
      final json = encodeProfileFile(
        ProfileFile(
          name: 'Tournament',
          settings: settings,
          macros: {
            7: macro,
            9: Macro(name: 'Unused', events: const []),
          },
        ),
      );
      final decoded = decodeProfileFile(json);
      expect(decoded.name, 'Tournament');
      expect(decoded.settings, settings);
      expect(decoded.macros.keys, [7]);
      expect(decoded.macros[7]!.events, macro.events);
    });

    test('rejects other files', () {
      expect(() => decodeProfileFile('{"a": 1}'), throwsFormatException);
      expect(() => decodeProfileFile('not json'), throwsFormatException);
    });
  });

  group('vendor profile', () {
    test('decodes settings from pro.data', () {
      final v = decodeVendorProfile(vendorFile(fill: writeVendorDefaults));
      final s = v.settings;
      expect(v.name, 'Gaming');
      expect(
        [for (final st in s.dpi.stages) st.dpi],
        [800, 1600, 2400, 3200, 5000, 22000, 50, 50],
      );
      expect(
        [for (final st in s.dpi.stages) st.enabled],
        [true, true, true, true, true, true, false, false],
      );
      expect(s.dpi.activeStageIndex, 1);
      expect(s.dpi.stages[3].color, const RgbColor(30, 0, 0));
      expect(s.sensor.angleSnap, isTrue);
      expect(s.sensor.ripple, isFalse);
      expect(s.lighting.mode, LightingMode.staticColor);
      expect(s.lighting.color, const RgbColor.hex(0x123456));
      expect(s.lighting.brightness, 3);
      expect(s.lighting.speed, 5);
      expect(s.power.sleepMinutes, 2);
      expect(s.power.deepSleepMinutes, 12);
      expect(s.power.debounceMs, 12);
      expect(s.polling, PollingRate.hz500);
      expect(s.buttons, defaults.buttons);
      expect(v.macros, isEmpty);
      expect(v.unmappedSlots, isEmpty);
    });

    test('decodes keyboard keys, macros and keeps unknown codes', () {
      final bytes = vendorFile(
        fill: (p) {
          writeVendorDefaults(p);
          const right = 0x9A4 + 1 * 0x1020;
          p
            ..setUint8(right + 1, 0x10)
            ..setUint8(right + 3, 0x06)
            ..setUint8(right + 7, 0x01);
          const middle = 0x9A4 + 2 * 0x1020;
          p.setUint8(middle + 1, 0x44);
          const forward = 0x9A4 + 6 * 0x1020;
          p
            ..setUint8(forward + 1, 0x11)
            ..setInt32(forward + 0x0C, 0, Endian.little)
            ..setInt32(forward + 0x40, 3, Endian.little)
            ..setUint16(forward + 0x44, 2, Endian.little);
          const label = 'Spray';
          for (var i = 0; i < label.length; i++) {
            p.setUint16(
              forward + 0x10 + 2 * i,
              label.codeUnitAt(i),
              Endian.little,
            );
          }
          p
            ..setUint8(forward + 0x440 + 1, 0x04)
            ..setUint8(forward + 0x440 + 2, 1)
            ..setUint16(forward + 0x440 + 4, 10, Endian.little)
            ..setUint8(forward + 0x450 + 1, 0xF1)
            ..setUint8(forward + 0x450 + 2, 0)
            ..setUint16(forward + 0x450 + 4, 2000, Endian.little);
        },
      );
      final v = decodeVendorProfile(bytes);
      expect(
        v.settings.buttons[ButtonSlot.right],
        const KeyButton(0x06, modifiers: KeyModifiers(ctrl: true)),
      );
      expect(v.settings.buttons[ButtonSlot.middle], defaults.buttons[2]);
      expect(v.unmappedSlots, [ButtonSlot.middle]);
      final macro = v.macros[ButtonSlot.forward]!;
      expect(macro.macro.name, 'Spray');
      expect(macro.playback.loopCount, 3);
      expect(macro.macro.events, const [
        MacroEvent(
          kind: MacroEventKind.key,
          code: 0x04,
          action: MacroAction.press,
          delayMs: 10,
        ),
        MacroEvent(
          kind: MacroEventKind.mouse,
          code: 0xF1,
          action: MacroAction.release,
          delayMs: 2000,
        ),
      ]);
    });

    test('rejects short files', () {
      expect(() => decodeVendorProfile(Uint8List(1024)), throwsFormatException);
    });
  });

  group('profiles and settings', () {
    late FakeHidTransport transport;
    late DeviceRepository device;
    late ProfileRepository profiles;
    late MacroRepository macros;
    late SettingsRepository settings;
    late ToastController toasts;
    late ShellViewModel shell;
    late EditSessionViewModel edit;
    late FakeProfileFiles files;
    late ProfilesViewModel vm;
    late AppearanceViewModel appearance;
    late FakeSystem system;
    late SettingsViewModel settingsVm;

    setUp(() async {
      final db = AppDatabase(sqlite3.openInMemory());
      profiles = ProfileRepository(db);
      macros = MacroRepository(db);
      await profiles.ensureDefault();
      settings = SettingsRepository(db);
      transport = FakeHidTransport();
      device = DeviceRepository(
        transport,
        timing: (_) => instant,
        wakeRetryInterval: const Duration(milliseconds: 10),
      );
      toasts = ToastController();
      edit = EditSessionViewModel(
        device: device,
        profiles: profiles,
        macros: macros,
        settings: settings,
        toasts: toasts,
      );
      shell = ShellViewModel(
        device: device,
        profiles: profiles,
        settings: settings,
        toasts: toasts,
      );
      files = FakeProfileFiles();
      vm = ProfilesViewModel(
        profiles: profiles,
        transfer: ProfileTransferRepository(profiles, macros),
        edit: edit,
        toasts: toasts,
        confirm: shell.confirm,
        prompt: shell.prompt,
        files: files,
      );
      appearance = AppearanceViewModel();
      system = FakeSystem();
      settingsVm = SettingsViewModel(
        repository: settings,
        appearance: appearance,
        edit: edit,
        shell: shell,
        device: device,
        profiles: vm,
        system: system,
        isWeb: false,
      );
    });

    tearDown(() async {
      settingsVm.dispose();
      vm.dispose();
      shell.dispose();
      edit.dispose();
      appearance.dispose();
      toasts.dispose();
      await device.dispose();
    });

    List<String> toastTexts() => [for (final t in toasts.toasts) t.text];

    Future<void> connect() async {
      transport.setPresent([wiredDevice]);
      await until(() => shell.status == ConnectionStatus.connected);
    }

    Future<void> answer(String? value) async {
      await until(() => shell.dialog != null);
      shell.closeDialog(value);
    }

    test('switching profile stages it and sends every report', () async {
      await connect();
      final other = await profiles.create(
        'Other',
        settings: defaults.copyWith(polling: PollingRate.hz250),
      );
      await vm.select(other);
      expect((await profiles.activeProfile()).id, other.id);
      expect(edit.staged!.polling, PollingRate.hz250);
      expect(edit.dirtySections, SettingsSection.values.toSet());
      expect(edit.canDiscard, isTrue);
      await edit.apply();
      expect(transport.opened.single.writtenReportIds, [
        ReportId.dpi,
        ReportId.lighting,
        ReportId.polling,
        ReportId.buttons,
      ]);
      expect(edit.hasPending, isFalse);
    });

    test('switching to an identical profile still marks it pending', () async {
      await connect();
      final other = await profiles.create('Same');
      await vm.select(other);
      expect(edit.hasPending, isTrue);
      expect(edit.pendingCount, SettingsSection.values.length);
    });

    test('creates, duplicates, renames and deletes profiles', () async {
      await connect();
      await vm.create();
      expect((await profiles.activeProfile()).name, 'Profile 2');
      edit.stage((s) => s.copyWith(polling: PollingRate.hz125));
      await vm.duplicate();
      final copy = await profiles.activeProfile();
      expect(copy.name, 'Profile 2 copy');
      expect(copy.settings.polling, PollingRate.hz125);

      final renaming = vm.rename();
      await answer('  Aim  ');
      await renaming;
      expect((await profiles.activeProfile()).name, 'Aim');

      final deleting = vm.delete();
      await answer('');
      await deleting;
      expect((await profiles.profiles()).map((p) => p.name), [
        defaultProfileName,
        'Profile 2',
      ]);
      expect((await profiles.activeProfile()).name, defaultProfileName);
    });

    test('keeps the last profile', () async {
      await vm.delete();
      expect(shell.dialog, isNull);
      expect(toastTexts(), contains('Keep at least one profile'));
      expect(await profiles.profiles(), hasLength(1));
    });

    test('exports and imports a profile with its macro', () async {
      await connect();
      final macro = await macros.create(
        Macro(
          name: 'Reload',
          events: const [
            MacroEvent(
              kind: MacroEventKind.key,
              code: 0x15,
              action: MacroAction.press,
              delayMs: 20,
            ),
          ],
        ),
      );
      edit.stage(
        (s) => s.withButton(ButtonSlot.back, MacroButton(macroId: macro.id)),
      );
      await vm.export();
      final bytes = files.saved['$defaultProfileName.x11profile']!;
      expect(utf8.decode(bytes), contains('Reload'));

      files.picked = bytes;
      await vm.importFile();
      final imported = (await profiles.profiles()).last;
      expect(imported.name, defaultProfileName);
      expect(imported.isActive, isFalse);
      final button = imported.settings.buttons[ButtonSlot.back] as MacroButton;
      expect(button.macroId, isNot(macro.id));
      expect((await macros.macro(button.macroId!))!.name, 'Reload');
      expect(toastTexts(), contains('Imported “$defaultProfileName”'));
    });

    test('reports files that are not profiles', () async {
      files.picked = Uint8List.fromList(utf8.encode('hello'));
      await vm.importFile();
      expect(toastTexts(), contains("That file isn't an OpenX11SE profile"));
      expect(await profiles.profiles(), hasLength(1));
    });

    test('imports the vendor profile', () async {
      files.vendor = vendorFile(fill: writeVendorDefaults);
      await vm.importVendor();
      final imported = (await profiles.profiles()).last;
      expect(imported.name, 'Vendor · Gaming');
      expect(imported.settings.polling, PollingRate.hz500);
    });

    test('restore defaults sends 0x0C, then every report', () async {
      await connect();
      edit.stage((s) => s.copyWith(polling: PollingRate.hz125));
      await edit.apply();
      transport.opened.single.sent.clear();

      final restoring = vm.restoreDefaults();
      await answer('');
      await restoring;
      expect(transport.opened.single.writtenReportIds, [
        ReportId.restoreDefaults,
        ReportId.dpi,
        ReportId.lighting,
        ReportId.polling,
        ReportId.buttons,
      ]);
      expect(edit.saved, defaults);
      expect(edit.hasPending, isFalse);
      await until(
        () => shell.activeProfile?.settings.polling == defaults.polling,
      );
    });

    test('restore defaults while disconnected stays staged', () async {
      await connect();
      transport.setPresent(const []);
      await until(() => shell.status == ConnectionStatus.disconnected);
      await vm.stageDefaults();
      expect(edit.restorePending, isTrue);
      expect(
        toastTexts(),
        contains('Defaults staged — apply when the mouse reconnects'),
      );
    });

    test('settings drive appearance and system integration', () async {
      await until(() => system.calls.isNotEmpty);
      expect(system.calls, ['startup false', 'tray true']);
      await settingsVm.setTheme(AppTheme.light);
      expect(appearance.themeMode, ThemeMode.light);
      expect((await settings.settings()).theme, AppTheme.light);

      await connect();
      await settingsVm.setAccentFollowsStage(true);
      expect(appearance.accentOverride, const Color(0xFF0000FF));
      edit.stage((s) => s.copyWith(dpi: s.dpi.copyWith(activeStageIndex: 0)));
      expect(appearance.accentOverride, const Color(0xFFFF0000));
      await settingsVm.setAccentFollowsStage(false);
      expect(appearance.accentOverride, isNull);

      await settingsVm.setStartWithSystem(true);
      expect(system.calls.last, 'startup true');
      await settingsVm.setAutoReconnect(false);
      expect(device.autoConnect, isFalse);
    });

    test('device info rows follow the connection', () async {
      expect(settingsVm.deviceInfo[1].value, 'Not connected');
      await connect();
      expect(settingsVm.deviceInfo[1].value, 'USB cable');
      expect(settingsVm.deviceInfo[2].value, '1.05');
    });

    test('factory restore asks first', () async {
      await connect();
      final restoring = settingsVm.restoreFactoryDefaults();
      await until(() => shell.dialog != null);
      expect(shell.dialog!.title, 'Restore mouse to factory defaults?');
      shell.closeDialog();
      await restoring;
      expect(transport.opened.single.writtenReportIds, isEmpty);
    });
  });
}
