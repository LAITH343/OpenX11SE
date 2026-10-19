import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/l10n/strings.dart';
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
import 'data/update/update_repository.dart';
import 'domain/app_settings.dart';
import 'domain/app_version.dart';
import 'domain/keyboard_keys.dart';
import 'ui/buttons/buttons_view_model.dart';
import 'ui/lighting/lighting_view_model.dart';
import 'ui/macros/macro_library_view_model.dart';
import 'ui/performance/performance_view_model.dart';
import 'ui/power/power_view_model.dart';
import 'ui/settings/settings_view_model.dart';
import 'ui/settings/update_view_model.dart';
import 'ui/shell/appearance_view_model.dart';
import 'ui/shell/edit_session_view_model.dart';
import 'ui/shell/profiles_view_model.dart';
import 'ui/shell/shell_view_model.dart';
import 'ui/shell/startup_failure.dart';
import 'ui/shell/window/window_controls.dart';
import 'ui/widgets/toast_host.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  KeyLabels.apple = defaultTargetPlatform == TargetPlatform.macOS;
  _reportUncaughtErrors();
  final AppDatabase database;
  try {
    database = await openAppDatabase();
  } on Object catch (error) {
    runApp(StartupFailureApp(error: error));
    return;
  }
  final profiles = ProfileRepository(database);
  await profiles.ensureDefault();
  final settings = SettingsRepository(database);
  final appSettings = await settings.settings();
  AppStrings.language = AppLanguage.fromCode(appSettings.language);
  final system = createSystemIntegration();
  final toTray = appSettings.minimiseToTray && system.supportsTray;
  final startMinimised = args.contains(startMinimisedArgument);
  final version = await _appVersion();
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
          create: (_) => DeviceRepository(createHidTransport()),
          dispose: (_, repository) => repository.dispose(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppearanceViewModel(switch (appSettings.theme) {
            AppTheme.dark => ThemeMode.dark,
            AppTheme.light => ThemeMode.light,
            AppTheme.system => ThemeMode.system,
          }),
        ),
        ChangeNotifierProvider(
          create: (_) {
            return ToastController();
          },
        ),
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
            profiles: context.read(),
            initial: appSettings,
            system: system,
            appVersion: version?.toString() ?? '—',
          ),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) {
            final updates = UpdateViewModel(
              repository: version == null
                  ? const NoUpdateRepository()
                  : createUpdateRepository(),
              settings: context.read(),
              edit: context.read(),
              toasts: context.read(),
              currentVersion: version ?? const AppVersion(0, 0, 0),
              quit: system.quit,
              initial: appSettings,
            );
            unawaited(updates.checkOnStartup());
            return updates;
          },
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

Future<AppVersion?> _appVersion() async {
  try {
    return AppVersion.tryParse((await PackageInfo.fromPlatform()).version);
  } on Object {
    return null;
  }
}

void _reportUncaughtErrors() {
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };
}
