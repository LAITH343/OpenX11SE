import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/protocol/lighting_report.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/domain/power_settings.dart';
import 'package:openx11se/domain/settings_changes.dart';
import 'package:openx11se/ui/power/power_view_model.dart';
import 'package:openx11se/ui/shell/edit_session_view_model.dart';
import 'package:openx11se/ui/widgets/toast_host.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_hid.dart';

const instant = DeviceTiming(
  reportGap: Duration.zero,
  readDelay: Duration.zero,
  ackTimeout: Duration(milliseconds: 20),
);

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  late FakeHidTransport transport;
  late DeviceRepository device;
  late ToastController toasts;
  late EditSessionViewModel edit;
  late PowerViewModel vm;

  setUp(() async {
    final db = AppDatabase(sqlite3.openInMemory());
    final profiles = ProfileRepository(db);
    await profiles.ensureDefault();
    transport = FakeHidTransport();
    device = DeviceRepository(transport, timing: (_) => instant);
    toasts = ToastController();
    edit = EditSessionViewModel(
      device: device,
      profiles: profiles,
      macros: MacroRepository(db),
      settings: SettingsRepository(db),
      toasts: toasts,
    );
    vm = PowerViewModel(edit: edit);
    device.start();
    transport.setPresent([wiredDevice]);
    await until(() => edit.staged != null);
  });

  tearDown(() async {
    vm.dispose();
    edit.dispose();
    toasts.dispose();
    await device.dispose();
  });

  test('values are clamped and debounce snaps to 2 ms steps', () {
    vm
      ..setSleepMinutes(0)
      ..setDeepSleepMinutes(90)
      ..setDebounceMs(9);
    expect(vm.power.sleepMinutes, PowerSettings.minMinutes);
    expect(vm.power.deepSleepMinutes, PowerSettings.maxMinutes);
    expect(vm.power.debounceMs, 10);
    vm.setDebounceMs(51);
    expect(vm.power.debounceMs, PowerSettings.maxDebounceMs);
    vm.setDebounceMs(1);
    expect(vm.power.debounceMs, PowerSettings.minDebounceMs);
  });

  test('changes mark the power section and only the changed fields', () {
    final saved = edit.saved!.power;
    expect(vm.dirty, isFalse);
    vm.setDeepSleepMinutes(saved.deepSleepMinutes == 30 ? 31 : 30);
    expect(vm.dirty, isTrue);
    expect(edit.isDirty(SettingsSection.power), isTrue);
    expect(edit.isDirty(SettingsSection.lighting), isFalse);
    expect(vm.deepSleepChanged, isTrue);
    expect(vm.sleepChanged, isFalse);
    expect(vm.debounceChanged, isFalse);
    vm.setDeepSleepMinutes(saved.deepSleepMinutes);
    expect(vm.dirty, isFalse);
  });

  test(
    'applying sends report 0x05 with the staged power and lighting',
    () async {
      final lighting = edit.staged!.lighting;
      vm
        ..setSleepMinutes(30)
        ..setDeepSleepMinutes(45)
        ..setDebounceMs(20);
      await edit.apply();
      final sent = transport.opened.single.sent
          .where((r) => r[0] == ReportId.lighting)
          .last;
      expect(sent[4] & 0xF0, 0x20);
      expect(sent[5] >> 4, 0x0D);
      expect(sent[9], 30);
      expect(sent[10], 10);
      final decoded = decodeLightingReport(sent);
      expect(
        decoded.power,
        const PowerSettings(
          sleepMinutes: 30,
          deepSleepMinutes: 45,
          debounceMs: 20,
        ),
      );
      expect(decoded.lighting, lighting);
      expect(vm.dirty, isFalse);
      expect(edit.saved!.power, decoded.power);
    },
  );
}
