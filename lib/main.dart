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
import 'ui/shell/appearance_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      ],
      child: const OpenX11SeApp(),
    ),
  );
}
