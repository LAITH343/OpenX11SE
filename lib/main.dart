import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/db/database_opener.dart';
import 'data/hid/hid_transport_factory.dart';
import 'data/repositories/device_cache_repository.dart';
import 'data/repositories/device_repository.dart';
import 'data/repositories/macro_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/profile_transfer_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/system/system_integration.dart';
import 'domain/app_settings.dart';
import 'ui/buttons/buttons_view_model.dart';
import 'ui/lighting/lighting_view_model.dart';
import 'ui/macros/macro_library_view_model.dart';
import 'ui/performance/performance_view_model.dart';
import 'ui/power/power_view_model.dart';
import 'ui/settings/settings_view_model.dart';
import 'ui/shell/appearance_view_model.dart';
import 'ui/shell/edit_session_view_model.dart';
import 'ui/shell/profiles_view_model.dart';
import 'ui/shell/shell_view_model.dart';
import 'ui/shell/window/window_controls.dart';
import 'ui/widgets/toast_host.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openAppDatabase();
  final profiles = ProfileRepository(database);
  await profiles.ensureDefault();
  final settings = SettingsRepository(database);
  final appSettings = await settings.settings();
  final system = createSystemIntegration();
  final toTray = appSettings.minimiseToTray && system.supportsTray;
  final startMinimised = args.contains(startMinimisedArgument);
  await initWindow(
    minimised: startMinimised && !toTray,
    hidden: startMinimised && toTray,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<ProfileRepository>.value(value: profiles),
        Provider(create: (_) => MacroRepository(database)),
        Provider<SettingsRepository>.value(value: settings),
        Provider(
          create: (context) =>
              ProfileTransferRepository(profiles, context.read()),
        ),
        Provider(create: (_) => DeviceCacheRepository(database)),
        Provider<DeviceRepository>(
          create: (_) => DeviceRepository(
            createHidTransport(),
            autoConnect: appSettings.autoReconnect,
          ),
          dispose: (_, repository) => repository.dispose(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppearanceViewModel(switch (appSettings.theme) {
            AppTheme.dark => ThemeMode.dark,
            AppTheme.light => ThemeMode.light,
            AppTheme.system => ThemeMode.system,
          }),
        ),
        ChangeNotifierProvider(create: (_) => ToastController()),
        ChangeNotifierProvider(
          create: (context) => EditSessionViewModel(
            device: context.read(),
            profiles: context.read(),
            macros: context.read(),
            settings: context.read(),
            toasts: context.read(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ShellViewModel(
            device: context.read(),
            profiles: context.read(),
            settings: context.read(),
            toasts: context.read(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final shell = context.read<ShellViewModel>();
            return ProfilesViewModel(
              profiles: context.read(),
              transfer: context.read(),
              edit: context.read(),
              toasts: context.read(),
              confirm: shell.confirm,
              prompt: shell.prompt,
            );
          },
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => SettingsViewModel(
            repository: context.read(),
            appearance: context.read(),
            edit: context.read(),
            shell: context.read(),
            device: context.read(),
            profiles: context.read(),
            initial: appSettings,
            system: system,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => PerformanceViewModel(
            edit: context.read(),
            device: context.read(),
            toasts: context.read(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ButtonsViewModel(edit: context.read(), macros: context.read()),
        ),
        ChangeNotifierProvider(
          create: (context) => LightingViewModel(edit: context.read()),
        ),
        ChangeNotifierProvider(
          create: (context) => PowerViewModel(edit: context.read()),
        ),
        ChangeNotifierProvider(
          create: (context) => MacroLibraryViewModel(
            repository: context.read(),
            edit: context.read(),
            toasts: context.read(),
            confirm: context.read<ShellViewModel>().confirm,
          ),
        ),
      ],
      child: const OpenX11SeApp(),
    ),
  );
}
