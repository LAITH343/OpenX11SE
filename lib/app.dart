import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/strings.dart';
import 'ui/debug/device_debug_screen.dart';
import 'ui/gallery/widget_gallery.dart';
import 'ui/shell/app_shell.dart';
import 'ui/shell/appearance_view_model.dart';
import 'ui/shell/minimum_size_viewport.dart';

const bool showWidgetGallery = bool.fromEnvironment('WIDGET_GALLERY');

const bool showDeviceDiagnostics = bool.fromEnvironment('DEVICE_DIAGNOSTICS');

class OpenX11SeApp extends StatelessWidget {
  const OpenX11SeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceViewModel>();
    return MaterialApp(
      title: 'OpenX11SE',
      debugShowCheckedModeBanner: false,
      theme: appearance.lightTheme,
      darkTheme: appearance.darkTheme,
      themeMode: appearance.themeMode,
      locale: appearance.language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          MinimumSizeViewport(child: child ?? const SizedBox.shrink()),
      home: KeyedSubtree(
        key: ValueKey(appearance.language),
        child: showDeviceDiagnostics
            ? const DeviceDebugScreen()
            : showWidgetGallery
            ? const WidgetGallery()
            : const AppShell(),
      ),
    );
  }
}
