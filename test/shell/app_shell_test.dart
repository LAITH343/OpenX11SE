import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/core/theme/nocturne_palette.dart';
import 'package:openx11se/core/theme/nocturne_theme.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/profile_transfer_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/data/update/update_repository.dart';
import 'package:openx11se/domain/app_version.dart';
import 'package:openx11se/domain/polling_rate.dart';
import 'package:openx11se/ui/buttons/buttons_view_model.dart';
import 'package:openx11se/ui/lighting/lighting_view_model.dart';
import 'package:openx11se/ui/macros/macro_library_view_model.dart';
import 'package:openx11se/ui/power/power_view_model.dart';
import 'package:openx11se/ui/performance/performance_view_model.dart';
import 'package:openx11se/ui/settings/settings_view_model.dart';
import 'package:openx11se/ui/settings/update_view_model.dart';
import 'package:openx11se/ui/shell/app_section.dart';
import 'package:openx11se/ui/shell/app_shell.dart';
import 'package:openx11se/ui/shell/appearance_view_model.dart';
import 'package:openx11se/ui/shell/edit_session_view_model.dart';
import 'package:openx11se/ui/shell/profiles_view_model.dart';
import 'package:openx11se/ui/shell/shell_view_model.dart';
import 'package:openx11se/ui/widgets/app_button.dart';
import 'package:openx11se/ui/widgets/colour_picker.dart';
import 'package:openx11se/ui/widgets/toast_host.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_hid.dart';

const instant = DeviceTiming(
  reportGap: Duration.zero,
  readDelay: Duration.zero,
  ackTimeout: Duration(milliseconds: 20),
);

Future<void> loadFonts() async {
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(Uint8List.fromList(await File(path).readAsBytes()));
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(read('assets/fonts/Inter-$w.ttf'));
  }
  await inter.load();
}

void expectApplyCount(WidgetTester tester, int count) {
  expect(
    find.ancestor(of: find.text('Apply'), matching: find.byType(AppButton)),
    findsOneWidget,
  );
  expect(
    find.text('$count unsaved change${count == 1 ? '' : 's'}'),
    findsOneWidget,
  );
}

void main() {
  setUpAll(loadFonts);

  testWidgets('shows the device states and staged changes', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late final FakeHidTransport transport;
    late final DeviceRepository device;
    late final ToastController toasts;
    late final EditSessionViewModel edit;
    late final ShellViewModel shell;
    late final PerformanceViewModel performance;
    late final ButtonsViewModel buttons;
    late final LightingViewModel lighting;
    late final PowerViewModel power;
    late final MacroLibraryViewModel macroLibrary;
    late final ProfilesViewModel profilesVm;
    late final AppearanceViewModel appearance;
    late final SettingsViewModel settingsVm;
    late final UpdateViewModel updates;
    await tester.runAsync(() async {
      final db = AppDatabase(sqlite3.openInMemory());
      final profiles = ProfileRepository(db);
      await profiles.ensureDefault();
      final settings = SettingsRepository(db);
      final macros = MacroRepository(db);
      transport = FakeHidTransport();
      device = DeviceRepository(transport, timing: (_) => instant);
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
      performance = PerformanceViewModel(
        edit: edit,
        device: device,
        toasts: toasts,
      );
      buttons = ButtonsViewModel(edit: edit, macros: macros);
      lighting = LightingViewModel(edit: edit);
      power = PowerViewModel(edit: edit);
      macroLibrary = MacroLibraryViewModel(
        repository: macros,
        edit: edit,
        toasts: toasts,
        confirm: shell.confirm,
      );
      profilesVm = ProfilesViewModel(
        profiles: profiles,
        transfer: ProfileTransferRepository(profiles, macros),
        edit: edit,
        toasts: toasts,
        confirm: shell.confirm,
        prompt: shell.prompt,
      );
      appearance = AppearanceViewModel();
      settingsVm = SettingsViewModel(
        repository: settings,
        appearance: appearance,
        edit: edit,
        shell: shell,
        profiles: profilesVm,
      );
      updates = UpdateViewModel(
        repository: const NoUpdateRepository(),
        settings: settings,
        edit: edit,
        toasts: toasts,
        currentVersion: const AppVersion(1, 0, 0),
        quit: () async {},
      );
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: toasts),
          ChangeNotifierProvider.value(value: edit),
          ChangeNotifierProvider.value(value: shell),
          ChangeNotifierProvider.value(value: performance),
          ChangeNotifierProvider.value(value: buttons),
          ChangeNotifierProvider.value(value: lighting),
          ChangeNotifierProvider.value(value: power),
          ChangeNotifierProvider.value(value: macroLibrary),
          ChangeNotifierProvider.value(value: profilesVm),
          ChangeNotifierProvider.value(value: settingsVm),
          ChangeNotifierProvider.value(value: updates),
        ],
        child: MaterialApp(
          theme: buildNocturneTheme(nocturneDark),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Connect your X11SE'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);

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
    expect(find.text('Report rate'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('6 of 8 enabled'), findsOneWidget);
    expect(find.text('22,000'), findsWidgets);
    expect(find.text('Polling rate'), findsOneWidget);

    tester.view.physicalSize = const Size(880, 600);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Polling rate'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump(const Duration(milliseconds: 400));

    edit.stage((s) => s.copyWith(polling: PollingRate.hz500));
    await tester.pump(const Duration(milliseconds: 400));
    expectApplyCount(tester, 1);

    shell.selectSection(AppSection.buttons);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Middle · wheel click'), findsOneWidget);
    expect(find.text('Forward · side front'), findsOneWidget);
    await tester.tap(find.text('Forward · side front'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Assign a function to'), findsOneWidget);
    await tester.tap(find.text('Shortcuts'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Copy'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Assign'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Assign a function to'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expectApplyCount(tester, 2);

    shell.selectSection(AppSection.lighting);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Breathing DPI'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Edit stage colours'), findsOneWidget);
    await tester.tap(find.text('Static'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ColourPicker), findsOneWidget);
    expectApplyCount(tester, 3);
    tester.view.physicalSize = const Size(880, 600);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ColourPicker), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump(const Duration(milliseconds: 400));

    shell.selectSection(AppSection.power);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sleep timer'), findsOneWidget);
    expect(find.text('LED off · deep sleep'), findsOneWidget);
    await tester.tap(find.text('16 ms · Worn switches'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(power.power.debounceMs, 16);
    expectApplyCount(tester, 4);

    shell.selectSection(AppSection.settings);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Accent colour'), findsOneWidget);
    expect(find.text('USB cable'), findsOneWidget);
    expect(find.text('Restore mouse to factory defaults'), findsOneWidget);
    tester.view.physicalSize = const Size(880, 600);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Auto-apply changes'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump(const Duration(milliseconds: 400));

    shell.toggleProfileMenu();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PROFILES ON THIS COMPUTER'), findsOneWidget);
    expect(find.text('Restore defaults…'), findsOneWidget);
    await tester.tap(find.text('Rename…'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rename profile'), findsOneWidget);
    shell.closeDialog();
    await tester.pump(const Duration(milliseconds: 400));
    shell.selectSection(AppSection.performance);
    await tester.pump(const Duration(milliseconds: 400));

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
    expectApplyCount(tester, 4);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      performance.dispose();
      buttons.dispose();
      lighting.dispose();
      power.dispose();
      macroLibrary.dispose();
      updates.dispose();
      settingsVm.dispose();
      profilesVm.dispose();
      appearance.dispose();
      shell.dispose();
      edit.dispose();
      await device.dispose();
      toasts.dispose();
    });
  });
}
