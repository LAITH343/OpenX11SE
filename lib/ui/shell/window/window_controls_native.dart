import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/nocturne_palette.dart';
import '../minimum_size_viewport.dart';

const bool hasWindowChrome = true;

bool _ready = false;

Future<void> initWindow({bool minimised = false, bool hidden = false}) async {
  await windowManager.ensureInitialized();
  _ready = true;
  final options = WindowOptions(
    size: const Size(1280, 800),
    minimumSize: minimumWindowSize,
    center: true,
    title: 'OpenX11SE',
    backgroundColor: nocturneDark.bg,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    if (hidden) return;
    await windowManager.show();
    if (minimised) {
      await windowManager.minimize();
    } else {
      await windowManager.focus();
    }
  });
}

Future<void> setWindowTitle(String title) async {
  if (_ready) await windowManager.setTitle(title);
}
