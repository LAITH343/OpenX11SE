import 'package:flutter/material.dart';

import '../../core/theme/nocturne_palette.dart';
import '../../core/theme/nocturne_theme.dart';

class AppearanceViewModel extends ChangeNotifier {
  AppearanceViewModel([this._themeMode = ThemeMode.dark]) {
    _rebuild();
  }

  ThemeMode _themeMode;
  Color? _accentOverride;
  late ThemeData _light;
  late ThemeData _dark;

  ThemeMode get themeMode => _themeMode;
  Color? get accentOverride => _accentOverride;
  ThemeData get lightTheme => _light;
  ThemeData get darkTheme => _dark;

  set themeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }

  set accentOverride(Color? color) {
    if (color == _accentOverride) return;
    _accentOverride = color;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final accent = _accentOverride;
    _dark = buildNocturneTheme(
      accent == null ? nocturneDark : nocturneDark.withAccent(accent),
    );
    _light = buildNocturneTheme(
      accent == null ? nocturneLight : nocturneLight.withAccent(accent),
    );
  }
}
