import 'package:flutter/widgets.dart';

import '../../core/theme/app_icons.dart';
import '../../domain/settings_changes.dart';

enum AppSection {
  performance('Performance', AppIcons.gauge, SettingsSection.performance),
  buttons('Buttons', AppIcons.mouse, SettingsSection.buttons),
  lighting('Lighting', AppIcons.lightbulbFilament, SettingsSection.lighting),
  power('Power & Response', AppIcons.lightning, SettingsSection.power),
  macros('Macros', AppIcons.record, null),
  settings('Settings', AppIcons.gearSix, null);

  const AppSection(this.label, this.icon, this.settingsSection);

  final String label;
  final IconData icon;
  final SettingsSection? settingsSection;

  static AppSection byName(String? name) =>
      values.asNameMap()[name] ?? AppSection.performance;
}
