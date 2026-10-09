import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/domain/lighting_settings.dart';
import 'package:openx11se/domain/power_settings.dart';
import 'package:openx11se/domain/rgb_color.dart';
import 'package:openx11se/domain/settings_changes.dart';
import 'package:openx11se/ui/lighting/led_glow.dart';
import 'package:openx11se/ui/lighting/lighting_view_model.dart';
import 'package:openx11se/ui/shell/edit_session_view_model.dart';
import 'package:openx11se/ui/widgets/toast_host.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_hid.dart';
import '../support/golden_vectors.dart';

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
  late LightingViewModel vm;

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
    vm = LightingViewModel(edit: edit);
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

  test('levels only change for modes that use them', () {
    vm.setMode(LightingMode.neon);
    final speed = vm.lighting.speed;
    final brightness = vm.lighting.brightness;
    vm
      ..setBrightness(brightness == 1 ? 2 : 1)
      ..setSpeed(speed == 8 ? 7 : 8);
    expect(vm.lighting.brightness, brightness);
    expect(vm.lighting.speed, speed == 8 ? 7 : 8);
    expect(vm.brightnessNote, contains("Neon doesn't use brightness"));
    expect(vm.speedNote, isNull);

    vm
      ..setMode(LightingMode.staticColor)
      ..setBrightness(12);
    expect(vm.lighting.brightness, LightingSettings.maxLevel);
    expect(vm.speedNote, "Static isn't animated.");
    expect(vm.colorNote, isNull);
    expect(vm.dirty, isTrue);
    expect(edit.isDirty(SettingsSection.lighting), isTrue);
  });

  test('DPI modes follow the active stage colour', () {
    vm.setMode(LightingMode.staticDpi);
    final dpi = edit.staged!.dpi;
    expect(vm.activeStageColor, dpi.stages[dpi.activeStageIndex].color);
    expect(vm.stageSwatches.length, dpi.stages.where((s) => s.enabled).length);
    expect(vm.stageSwatches.where((s) => s.active), hasLength(1));
    expect(vm.colorNote, 'Static DPI uses the active DPI stage colour.');
  });

  test('applying writes report 0x05 merged with the staged power', () async {
    edit.stage(
      (s) => s.copyWith(
        power: const PowerSettings(
          sleepMinutes: 1,
          deepSleepMinutes: 10,
          debounceMs: 8,
        ),
        lighting: s.lighting.copyWith(speed: 6),
      ),
    );
    vm
      ..setMode(LightingMode.staticColor)
      ..setColor(const RgbColor.hex(0xFF0000))
      ..setBrightness(2);
    await edit.apply();
    final sent = transport.opened.single.sent
        .where((r) => r[0] == ReportId.lighting)
        .last;
    expect(sent, hex('05 0F 01 10 03 A2 FF 00 00 01 04 01 B9 00 00'));
    expect(vm.dirty, isFalse);
  });

  test('preview frames match each mode', () {
    const red = Color(0xFFFF0000);
    const blue = Color(0xFF0000FF);
    LedFrame frame(LightingMode mode, {int brightness = 8, Duration? at}) =>
        ledFrame(
          mode: mode,
          color: red,
          stageColor: blue,
          brightness: brightness,
          speed: 4,
          elapsed: at ?? Duration.zero,
        );

    expect(frame(LightingMode.off).opacity, 0);
    expect(frame(LightingMode.staticColor).color, red);
    expect(
      frame(LightingMode.staticColor, brightness: 2).opacity,
      lessThan(frame(LightingMode.staticColor).opacity),
    );
    expect(frame(LightingMode.staticDpi).color, blue);
    expect(frame(LightingMode.breathingDpi).color, blue);
    expect(frame(LightingMode.breathing).opacity, closeTo(.1, 1e-9));
    expect(
      frame(LightingMode.neon, at: const Duration(seconds: 2)).color,
      isNot(frame(LightingMode.neon).color),
    );
  });
}
