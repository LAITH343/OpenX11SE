import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/domain/device_settings.dart';
import 'package:openx11se/domain/polling_rate.dart';
import 'package:openx11se/domain/rgb_color.dart';
import 'package:openx11se/domain/settings_changes.dart';
import 'package:openx11se/ui/performance/performance_view_model.dart';
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
  late PerformanceViewModel vm;

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
    vm = PerformanceViewModel(
      edit: edit,
      device: device,
      toasts: toasts,
      snapNoteDuration: const Duration(milliseconds: 20),
      flashDuration: const Duration(milliseconds: 20),
    );
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

  test('exposes the device stages and selects the active one', () {
    expect(vm.stages, hasLength(8));
    expect(vm.enabledCount, 6);
    expect(vm.activeIndex, 2);
    expect(vm.selectedIndex, 2);
    expect(vm.polling, PollingRate.hz1000);
    expect(vm.dirty, isFalse);
  });

  test('typed values snap and show a note', () async {
    vm
      ..selectStage(0)
      ..commitDpiText('1,234');
    expect(vm.stages[0].dpi, 1250);
    expect(vm.snapNote, 'Snapped to 1,250');
    expect(vm.stageChanged(0), isTrue);
    expect(vm.dirty, isTrue);
    expect(edit.isDirty(SettingsSection.performance), isTrue);
    await until(() => vm.snapNote == null);

    vm.commitDpiText('12345');
    expect(vm.stages[0].dpi, 12300);
    vm.commitDpiText('99999');
    expect(vm.stages[0].dpi, 24000);
    vm.commitDpiText('1600');
    expect(vm.stages[0].dpi, 1600);
    expect(vm.snapNote, isNull);
  });

  test('steps move one valid value across the 10,000 seam', () {
    vm
      ..setDpi(0, 10000)
      ..stepDpi(0, 1);
    expect(vm.stages[0].dpi, 10100);
    vm
      ..stepDpi(0, -1)
      ..stepDpi(0, -1);
    expect(vm.stages[0].dpi, 9950);
    vm
      ..setDpi(0, 50)
      ..stepDpi(0, -1);
    expect(vm.stages[0].dpi, 50);
    vm
      ..setDpi(0, 24000)
      ..stepDpi(0, 1);
    expect(vm.stages[0].dpi, 24000);
  });

  test('keeps at least one stage enabled and moves the active stage', () {
    vm.toggleStage(2);
    expect(vm.stages[2].enabled, isFalse);
    expect(vm.activeIndex, 0);
    for (final i in [0, 1, 3, 4]) {
      vm.toggleStage(i);
    }
    expect(vm.enabledCount, 1);
    vm.toggleStage(5);
    expect(vm.stages[5].enabled, isTrue);
    expect(vm.activeIndex, 5);
    expect([
      for (final t in toasts.toasts) t.text,
    ], contains('At least one DPI stage must stay enabled'));
  });

  test('disabled stages cannot become active', () {
    vm.setActive(6);
    expect(vm.activeIndex, 2);
    vm.setActive(4);
    expect(vm.activeIndex, 4);
    expect(vm.stageChanged(4), isTrue);
    expect(vm.stageChanged(2), isTrue);
  });

  test('polling and sensor changes are tracked', () {
    vm
      ..setPolling(PollingRate.hz250)
      ..setAngleSnap(true)
      ..setRipple(false)
      ..setColor(1, const RgbColor.hex(0x123456));
    expect(vm.pollingChanged, isTrue);
    expect(vm.angleSnapChanged, isTrue);
    expect(vm.rippleChanged, isTrue);
    expect(vm.stages[1].color, const RgbColor.hex(0x123456));
    expect(edit.pendingCount, 4);
  });

  test('the DPI button flashes the stage', () async {
    transport.opened.single.notify('03 07 10 02 00');
    await until(() => vm.flashStage == 1);
    expect(vm.flashSerial, 1);
    await until(() => vm.flashStage == null);
  });

  test('applying factory defaults writes the documented DPI report', () async {
    vm
      ..setDpi(0, 1000)
      ..toggleStage(6);
    await edit.apply();
    edit.stage((_) => DeviceSettings.factoryDefaults);
    await edit.apply();
    final sent = transport.opened.single.sent
        .where((r) => r[0] == ReportId.dpi)
        .last;
    expect(sent, defaultDpiReport);
    expect(edit.saved, DeviceSettings.factoryDefaults);
  });
}
