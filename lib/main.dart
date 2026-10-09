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
import 'data/repositories/settings_repository.dart';
import 'ui/buttons/buttons_view_model.dart';
import 'ui/lighting/lighting_view_model.dart';
import 'ui/performance/performance_view_model.dart';
import 'ui/power/power_view_model.dart';
import 'ui/shell/appearance_view_model.dart';
import 'ui/shell/edit_session_view_model.dart';
import 'ui/shell/shell_view_model.dart';
import 'ui/shell/window/window_controls.dart';
import 'ui/widgets/toast_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initWindow();
  final database = await openAppDatabase();
  final profiles = ProfileRepository(database);
  await profiles.ensureDefault();
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<ProfileRepository>.value(value: profiles),
        Provider(create: (_) => MacroRepository(database)),
        Provider(create: (_) => SettingsRepository(database)),
        Provider(create: (_) => DeviceCacheRepository(database)),
        Provider<DeviceRepository>(
          create: (_) => DeviceRepository(createHidTransport()),
          dispose: (_, repository) => repository.dispose(),
        ),
        ChangeNotifierProvider(create: (_) => AppearanceViewModel()),
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
      ],
      child: const OpenX11SeApp(),
    ),
  );
}
