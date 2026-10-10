enum AppTheme { dark, light, system }

class AppSettings {
  const AppSettings({
    this.theme = AppTheme.dark,
    this.accentFollowsStage = false,
    this.autoApply = false,
    this.language = 'en',
    this.lastSection,
    this.startWithSystem = false,
    this.minimiseToTray = true,
    this.autoCheckUpdates = true,
    this.lastUpdateCheck,
  });

  static const defaults = AppSettings();

  final AppTheme theme;
  final bool accentFollowsStage;
  final bool autoApply;
  final String language;
  final String? lastSection;
  final bool startWithSystem;
  final bool minimiseToTray;
  final bool autoCheckUpdates;
  final DateTime? lastUpdateCheck;

  AppSettings copyWith({
    AppTheme? theme,
    bool? accentFollowsStage,
    bool? autoApply,
    String? language,
    String? lastSection,
    bool? startWithSystem,
    bool? minimiseToTray,
    bool? autoCheckUpdates,
    DateTime? lastUpdateCheck,
  }) => AppSettings(
    theme: theme ?? this.theme,
    accentFollowsStage: accentFollowsStage ?? this.accentFollowsStage,
    autoApply: autoApply ?? this.autoApply,
    language: language ?? this.language,
    lastSection: lastSection ?? this.lastSection,
    startWithSystem: startWithSystem ?? this.startWithSystem,
    minimiseToTray: minimiseToTray ?? this.minimiseToTray,
    autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
    lastUpdateCheck: lastUpdateCheck ?? this.lastUpdateCheck,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.accentFollowsStage == accentFollowsStage &&
      other.autoApply == autoApply &&
      other.language == language &&
      other.lastSection == lastSection &&
      other.startWithSystem == startWithSystem &&
      other.minimiseToTray == minimiseToTray &&
      other.autoCheckUpdates == autoCheckUpdates &&
      other.lastUpdateCheck == lastUpdateCheck;

  @override
  int get hashCode => Object.hash(
    theme,
    accentFollowsStage,
    autoApply,
    language,
    lastSection,
    startWithSystem,
    minimiseToTray,
    autoCheckUpdates,
    lastUpdateCheck,
  );

  @override
  String toString() =>
      'AppSettings($theme, accentFollowsStage: $accentFollowsStage, '
      'autoApply: $autoApply, $language, lastSection: $lastSection)';
}
