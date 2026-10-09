import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/hid/hid_transport.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/domain/device_settings.dart';
import 'package:openx11se/domain/polling_rate.dart';
import 'package:openx11se/domain/power_settings.dart';
import 'package:openx11se/domain/settings_changes.dart';
import 'package:openx11se/ui/shell/dialog_request.dart';
import 'package:openx11se/ui/shell/edit_session_view_model.dart';
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

void main() {
  late FakeHidTransport transport;
  late DeviceRepository device;
  late ProfileRepository profiles;
  late ToastController toasts;
  late ShellViewModel shell;
  late EditSessionViewModel edit;

  setUp(() async {
    final db = AppDatabase(sqlite3.openInMemory());
    profiles = ProfileRepository(db);
    await profiles.ensureDefault();
    final settings = SettingsRepository(db);
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
      macros: MacroRepository(db),
      settings: settings,
      toasts: toasts,
    );
    shell = ShellViewModel(
      device: device,
      profiles: profiles,
      settings: settings,
      toasts: toasts,
    );
  });

  tearDown(() async {
    shell.dispose();
    edit.dispose();
    toasts.dispose();
    await device.dispose();
  });

  List<String> toastTexts() => [for (final t in toasts.toasts) t.text];

  Future<void> connect([HidDeviceInfo deviceInfo = wiredDevice]) async {
    transport.setPresent([deviceInfo]);
    await until(() => shell.status == ConnectionStatus.connected);
  }

  test('starts without a device', () {
    expect(shell.status, ConnectionStatus.none);
    expect(edit.staged, isNull);
    expect(edit.canApply, isFalse);
  });

  test('reads the device and stages its settings', () async {
    await connect();
    expect(edit.saved, defaults);
    expect(edit.staged, defaults);
    expect(edit.pendingCount, 0);
    expect(shell.firmwareLabel, '1.05');
    expect(shell.activeStageNumber, 3);
    expect(toastTexts(), contains('X11SE connected · settings read'));
  });

  test('counts staged changes per section and discards them', () async {
    await connect();
    edit.stage(
      (s) => s.copyWith(
        polling: PollingRate.hz500,
        power: s.power.copyWith(sleepMinutes: 5, debounceMs: 12),
      ),
    );
    expect(edit.pendingCount, 3);
    expect(edit.dirtySections, {
      SettingsSection.performance,
      SettingsSection.power,
    });
    expect(edit.canApply, isTrue);
    edit.discard();
    expect(edit.staged, defaults);
    expect(edit.hasPending, isFalse);
  });

  test('apply writes changed reports and saves the profile', () async {
    await connect();
    edit.stage((s) => s.copyWith(polling: PollingRate.hz500));
    await edit.apply();
    expect(transport.opened.single.writtenReportIds, [ReportId.polling]);
    expect(edit.hasPending, isFalse);
    expect(edit.saved!.polling, PollingRate.hz500);
    expect(edit.writing, isFalse);
    expect(toastTexts(), contains('Settings saved to mouse'));
    await until(
      () => shell.activeProfile?.settings.polling == PollingRate.hz500,
    );
  });

  test('unplugging keeps staged edits and reconnecting allows apply', () async {
    await connect();
    edit.stage((s) => s.copyWith(polling: PollingRate.hz250));
    transport.setPresent(const []);
    await until(() => shell.status == ConnectionStatus.disconnected);
    expect(edit.canApply, isFalse);
    expect(edit.staged!.polling, PollingRate.hz250);
    expect(toastTexts(), contains('Mouse disconnected — edits kept'));

    transport.setPresent([wiredDevice]);
    await until(() => shell.status == ConnectionStatus.connected);
    expect(edit.pendingCount, 1);
    expect(edit.canApply, isTrue);
    await edit.apply();
    expect(transport.opened.last.writtenReportIds, [ReportId.polling]);
    expect(edit.hasPending, isFalse);
  });

  test('the DPI button updates the active stage and shows a toast', () async {
    await connect(dongleDevice);
    transport.opened.single.notify('03 07 10 02 00');
    await until(() => shell.activeStageNumber == 2);
    expect(edit.staged!.dpi.activeStageIndex, 1);
    expect(edit.hasPending, isFalse);
    expect(toastTexts(), contains('DPI button · stage 2 · 1,600 DPI'));
  });

  test('a sleeping mouse behind the dongle loads once it wakes', () async {
    final connection = FakeHidConnection(dongleDevice)..asleep = true;
    transport.factories['dongle'] = () => connection;
    transport.setPresent([dongleDevice]);
    await until(() => shell.status == ConnectionStatus.asleep);
    connection.asleep = false;
    await until(() => shell.status == ConnectionStatus.connected);
    expect(edit.saved, defaults);
  });

  test(
    'an unacknowledged write over the dongle reports a sleeping mouse',
    () async {
      await connect(dongleDevice);
      transport.opened.single.autoAck = false;
      edit.stage(
        (s) => s.copyWith(
          power: const PowerSettings(
            sleepMinutes: 3,
            deepSleepMinutes: 10,
            debounceMs: 8,
          ),
        ),
      );
      await edit.apply();
      expect(edit.writeError?.asleep, isTrue);
      expect(edit.writeError?.label, 'Power & response');
      expect(edit.writeError?.message, 'Mouse is asleep. Move it, then Retry.');
      expect(edit.hasPending, isTrue);
      expect(edit.writing, isFalse);
    },
  );

  test('confirm dialogs resolve through the shell', () async {
    final result = shell.prompt(
      DialogRequest(
        title: 'Rename profile',
        body: 'Profiles are stored on this computer.',
        confirmLabel: 'Rename',
        initialText: 'Default',
      ),
    );
    expect(shell.dialog?.initialText, 'Default');
    shell.closeDialog('Work');
    expect(await result, 'Work');
    expect(shell.dialog, isNull);
  });
}
