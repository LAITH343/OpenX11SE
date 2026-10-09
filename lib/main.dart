import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/hid/hid_transport_factory.dart';
import 'data/repositories/device_repository.dart';
import 'ui/shell/appearance_view_model.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
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
