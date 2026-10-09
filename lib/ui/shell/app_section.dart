import 'package:flutter/widgets.dart';

import '../../core/theme/app_icons.dart';
import '../../domain/settings_changes.dart';

enum AppSection {
  performance(
    'Performance',
    AppIcons.gauge,
    'DPI stages, polling rate and sensor behaviour. The DPI button cycles '
        'through enabled stages.',
    SettingsSection.performance,
  ),
  buttons(
    'Buttons',
    AppIcons.mouse,
    'Click a button on the mouse or in the list to remap it.',
    SettingsSection.buttons,
  ),
  lighting(
    'Lighting',
    AppIcons.lightbulbFilament,
    'The X11SE has a single RGB status LED. Choose how it behaves — the '
        'preview matches the mouse.',
    SettingsSection.lighting,
  ),
  power(
    'Power & Response',
    AppIcons.lightning,
    'How quickly the mouse sleeps, and how it filters switch bounce.',
    SettingsSection.power,
  ),
  macros(
    'Macros',
    AppIcons.record,
    'Record key sequences, fine-tune delays, then assign them to a button.',
    null,
  ),
  settings(
    'Settings',
    AppIcons.gearSix,
    'App preferences and device information.',
    null,
  );

  const AppSection(
    this.label,
    this.icon,
    this.description,
    this.settingsSection,
  );

  final String label;
  final IconData icon;
  final String description;
  final SettingsSection? settingsSection;

  static AppSection byName(String? name) =>
      values.asNameMap()[name] ?? AppSection.performance;
}
