import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_palette.dart';
import '../../core/theme/nocturne_theme.dart';

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenX11SE',
      debugShowCheckedModeBanner: false,
      theme: buildNocturneTheme(nocturneDark),
      home: Builder(
        builder: (context) {
          final n = context.nocturne;
          return Material(
            color: n.bg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Icon(
                        AppIcons.warningCircle,
                        size: 32,
                        color: n.palette.warning,
                      ),
                      Text(
                        tr('OpenX11SE could not start'),
                        style: n.text.display,
                      ),
                      Text(
                        tr(
                          'Local storage could not be opened. Close other '
                          'OpenX11SE windows or tabs and start it again.',
                        ),
                        style: n.text.body.copyWith(color: n.textSecondary),
                      ),
                      SelectableText(
                        '$error',
                        style: n.text.caption.copyWith(color: n.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
