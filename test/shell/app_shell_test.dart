import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/core/theme/nocturne_palette.dart';
import 'package:openx11se/core/theme/nocturne_theme.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/domain/polling_rate.dart';
import 'package:openx11se/ui/shell/app_shell.dart';
import 'package:openx11se/ui/shell/edit_session_view_model.dart';
import 'package:openx11se/ui/shell/shell_view_model.dart';
import 'package:openx11se/ui/widgets/toast_host.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_hid.dart';

const instant = DeviceTiming(
  reportGap: Duration.zero,
  readDelay: Duration.zero,
  ackTimeout: Duration(milliseconds: 20),
);

void main() {
  testWidgets('shows the device states and staged changes', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late final FakeHidTransport transport;
    late final DeviceRepository device;
    late final ToastController toasts;
    late final EditSessionViewModel edit;
    late final ShellViewModel shell;
    await tester.runAsync(() async {
      final db = AppDatabase(sqlite3.openInMemory());
      final profiles = ProfileRepository(db);
      await profiles.ensureDefault();
      final settings = SettingsRepository(db);
      transport = FakeHidTransport();
      device = DeviceRepository(transport, timing: (_) => instant);
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: toasts),
          ChangeNotifierProvider.value(value: edit),
          ChangeNotifierProvider.value(value: shell),
        ],
        child: MaterialApp(
          theme: buildNocturneTheme(nocturneDark),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Connect your X11SE'), findsOneWidget);
    expect(find.text('No device'), findsOneWidget);

    await tester.runAsync(() async {
      transport.setPresent([wiredDevice]);
      for (
        var i = 0;
        i < 400 && shell.status != ConnectionStatus.connected;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Wired'), findsOneWidget);
    expect(find.text('FW 1.05'), findsOneWidget);
    expect(find.text('Performance'), findsWidgets);
    expect(find.text('ON THE MOUSE'), findsOneWidget);

    edit.stage((s) => s.copyWith(polling: PollingRate.hz500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 unsaved change'), findsOneWidget);

    await tester.runAsync(() async {
      transport.setPresent(const []);
      for (
        var i = 0;
        i < 400 && shell.status != ConnectionStatus.disconnected;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('1 unsaved change'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      shell.dispose();
      edit.dispose();
      await device.dispose();
      toasts.dispose();
    });
  });
}
