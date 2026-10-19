import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/system/system_integration.dart';
import '../../data/system/system_notifications.dart';
import '../../domain/app_settings.dart';
import '../../domain/device_info.dart';
import '../shell/appearance_view_model.dart';
import '../shell/dialog_request.dart';
import '../shell/edit_session_view_model.dart';
import '../shell/profiles_view_model.dart';
import '../shell/shell_view_model.dart';

class InfoRow {
  const InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required this._repository,
    required this._appearance,
    required this._edit,
    required this._shell,
    required this._profiles,
    AppSettings initial = AppSettings.defaults,
    this._system = const NoSystemIntegration(),
    this._notifications = const NoSystemNotifications(),
    this.appVersion = '1.0.0',
  }) : _settings = initial {
    _edit.addListener(_syncAccent);
    _shell.addListener(notifyListeners);
    _subscription = _repository.watchSettings().listen(
      _onSettings,
      onError: (_) {},
    );
    _applyAppearance();
    unawaited(_syncSystem(null));
  }

  static const sourceUrl = 'https://github.com/LAITH343/OpenX11SE';

  final SettingsRepository _repository;
  final AppearanceViewModel _appearance;
  final EditSessionViewModel _edit;
  final ShellViewModel _shell;
  final ProfilesViewModel _profiles;
  final SystemIntegration _system;
  final SystemNotifications _notifications;
  final String appVersion;
  late final StreamSubscription<AppSettings> _subscription;

  AppSettings _settings;

  AppSettings get settings => _settings;

  AppTheme get theme => _settings.theme;

  bool get accentFollowsStage => _settings.accentFollowsStage;

  bool get autoApply => _settings.autoApply;

  bool get startWithSystem => _settings.startWithSystem;

  bool get minimiseToTray => _settings.minimiseToTray;

  bool get supportsStartup => _system.supportsStartup;

  bool get supportsTray => _system.supportsTray;

  bool get supportsSystemNotifications => _notifications.isSupported;

  NotificationStyle get notificationStyle => _settings.notificationStyle;

  String get buildText => 'Desktop · ${_platformName()} · Flutter';

  String get platformNote => 'Talks to the mouse directly over USB HID.';

  List<InfoRow> get deviceInfo {
    final online = _shell.isOnline;
    final battery = _shell.batteryPercent;
    final full = _shell.chargeState == ChargeState.charged;
    final charging = _shell.chargeState == ChargeState.charging;
    return [
      const InfoRow('Model', 'Attack Shark X11SE'),
      InfoRow('Connection', switch (_shell.connection) {
        _ when !online => 'Not connected',
        ConnectionType.wired => 'USB cable',
        ConnectionType.dongle => '2.4 GHz dongle',
        null => 'Not connected',
      }),
      InfoRow('Firmware', online ? _shell.firmwareLabel ?? '—' : '—'),
      InfoRow('Battery', switch (battery) {
        _ when !online => '—',
        _ when full => 'Fully charged · on cable',
        _ when charging => 'Charging',
        null => '—',
        final percent => '$percent%',
      }),
    ];
  }

  Future<void> setTheme(AppTheme theme) =>
      _update((s) => s.copyWith(theme: theme));

  AppLanguage get language => AppLanguage.fromCode(_settings.language);

  Future<void> setLanguage(AppLanguage language) =>
      _update((s) => s.copyWith(language: language.code));

  Future<void> setAccentFollowsStage(bool value) =>
      _update((s) => s.copyWith(accentFollowsStage: value));

  Future<void> setAutoApply(bool value) =>
      _update((s) => s.copyWith(autoApply: value));

  Future<void> setStartWithSystem(bool value) =>
      _update((s) => s.copyWith(startWithSystem: value));

  Future<void> setMinimiseToTray(bool value) =>
      _update((s) => s.copyWith(minimiseToTray: value));

  Future<void> setNotificationStyle(NotificationStyle style) async {
    await _update((s) => s.copyWith(notificationStyle: style));
    if (style == NotificationStyle.system) {
      await _notifications.requestPermission();
    }
  }

  Future<void> restoreFactoryDefaults() async {
    final confirmed = await _shell.confirm(
      DialogRequest(
        title: 'Restore mouse to factory defaults?',
        body:
            'Every setting on the mouse — DPI stages, buttons, lighting and '
            'timers — goes back to factory values. Profiles and macros on '
            'this computer are kept.',
        confirmLabel: 'Restore factory defaults',
        icon: AppIcons.warning,
        danger: true,
      ),
    );
    if (confirmed) await _profiles.stageDefaults();
  }

  Future<void> _update(AppSettings Function(AppSettings) change) async {
    final next = change(_settings);
    if (next == _settings) return;
    _onSettings(next);
    try {
      await _repository.update(change);
    } on Object {
      return;
    }
  }

  void _onSettings(AppSettings next) {
    final previous = _settings;
    if (next == previous) return;
    _settings = next;
    _applyAppearance();
    unawaited(_syncSystem(previous));
    notifyListeners();
  }

  void _applyAppearance() {
    _appearance.themeMode = switch (_settings.theme) {
      AppTheme.dark => ThemeMode.dark,
      AppTheme.light => ThemeMode.light,
      AppTheme.system => ThemeMode.system,
    };
    _appearance.language = AppLanguage.fromCode(_settings.language);
    _syncAccent();
  }

  void _syncAccent() {
    final stage = _edit.staged?.dpi.activeStage;
    _appearance.accentOverride = _settings.accentFollowsStage && stage != null
        ? Color(0xFF000000 | stage.color.rgb)
        : null;
  }

  Future<void> _syncSystem(AppSettings? previous) async {
    final s = _settings;
    try {
      if (_system.supportsStartup &&
          previous?.startWithSystem != s.startWithSystem) {
        await _system.setLaunchAtStartup(s.startWithSystem);
      }
      if (_system.supportsTray &&
          previous?.minimiseToTray != s.minimiseToTray) {
        await _system.setMinimiseToTray(s.minimiseToTray);
      }
    } on Object {
      return;
    }
  }

  static String _platformName() => switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.macOS => 'macOS',
    _ => 'Native',
  };

  @override
  void dispose() {
    _edit.removeListener(_syncAccent);
    _shell.removeListener(notifyListeners);
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
