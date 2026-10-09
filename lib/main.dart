import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'ui/shell/appearance_view_model.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppearanceViewModel(),
      child: const OpenX11SeApp(),
    ),
  );
}
