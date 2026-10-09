import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/formatting/number_format.dart';
import '../../core/theme/app_icons.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/device_state.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/device_info.dart';
import '../../domain/dpi_settings.dart';
import '../../domain/polling_rate.dart';
import '../../domain/profile.dart';
import '../widgets/toast_host.dart';
import 'app_section.dart';
import 'dialog_request.dart';

enum ConnectionStatus { none, loading, asleep, off, connected, disconnected }

class ShellViewModel extends ChangeNotifier {
  ShellViewModel({
    required this._device,
    required ProfileRepository profiles,
    required this._settings,
    required this._toasts,
  }) {
    _subscriptions = [
      _device.states.listen(_onState),
      _device.stageChanges.listen(_onStageChange),
      profiles.watchProfiles().listen(_onProfiles, onError: (_) {}),
    ];
    unawaited(_restoreSection());
    _onState(_device.state);
    _device.start();
  }

  static const lowBatteryPercent = 15;

  final DeviceRepository _device;
  final SettingsRepository _settings;
  final ToastController _toasts;
  late final List<StreamSubscription<Object>> _subscriptions;

  DeviceState _state = const DeviceAbsent();
  bool _hadSettings = false;
  DeviceInfo? _info;
  ConnectionType? _connection;
  DpiSettings? _dpi;
  PollingRate? _polling;
  AppSection _section = AppSection.performance;
  bool _sectionChosen = false;
  List<Profile> _profiles = const [];
  bool _profileMenuOpen = false;
  DialogRequest? _dialog;
  bool _sleepChecking = false;
  bool _checkingOff = false;
  bool _disposed = false;

  ConnectionStatus get status => switch (_state) {
    DeviceReady() => ConnectionStatus.connected,
    _ when _hadSettings => ConnectionStatus.disconnected,
    DeviceConnecting() when _sleepChecking =>
      _checkingOff ? ConnectionStatus.off : ConnectionStatus.asleep,
    DeviceConnecting() => ConnectionStatus.loading,
    DeviceAsleep() => ConnectionStatus.asleep,
    DeviceOff() => ConnectionStatus.off,
    DeviceAbsent() || DeviceFailed() => ConnectionStatus.none,
  };

  bool get isOnline => status == ConnectionStatus.connected;

  bool get showsContent =>
      status == ConnectionStatus.connected ||
      status == ConnectionStatus.disconnected;

  bool get isReconnecting =>
      status == ConnectionStatus.disconnected && _state is! DeviceAbsent;

  bool get deviceAsleep => switch (_state) {
    DeviceAsleep() => true,
    DeviceReady(:final asleep) => asleep,
    _ => false,
  };

  bool get deviceOff => switch (_state) {
    DeviceOff() => true,
    DeviceReady(:final off) => off,
    _ => false,
  };

  bool get needsUserGrant => _device.requiresUserGrant;

  String? get failureText => _state is DeviceFailed
      ? 'The mouse was found but its settings could not be read.'
      : null;

  ConnectionType? get connection => _connection;

  DeviceInfo? get info => _info;

  String? get firmwareLabel => _info?.firmwareLabel;

  int? get batteryPercent => _info?.batteryPercent;

  ChargeState get chargeState => _info?.chargeState ?? ChargeState.unknown;

  bool get sleepChecking => _sleepChecking;

  int? get activeStageNumber =>
      _dpi == null ? null : _dpi!.activeStageIndex + 1;

  DpiStage? get activeStage => _dpi?.activeStage;

  PollingRate? get polling => _polling;

  AppSection get section => _section;

  List<Profile> get profiles => _profiles;

  Profile? get activeProfile {
    for (final p in _profiles) {
      if (p.isActive) return p;
    }
    return null;
  }

  String get profileName => activeProfile?.name ?? '—';

  bool get profileMenuOpen => _profileMenuOpen;

  DialogRequest? get dialog => _dialog;

  void selectSection(AppSection section) {
    _profileMenuOpen = false;
    _sectionChosen = true;
    if (section == _section) {
      notifyListeners();
      return;
    }
    _section = section;
    notifyListeners();
    unawaited(_saveSection(section));
  }

  Future<void> _saveSection(AppSection section) async {
    try {
      await _settings.update((s) => s.copyWith(lastSection: section.name));
    } on Object {
      return;
    }
  }

  void toggleProfileMenu() {
    _profileMenuOpen = !_profileMenuOpen;
    notifyListeners();
  }

  void closeProfileMenu() {
    if (!_profileMenuOpen) return;
    _profileMenuOpen = false;
    notifyListeners();
  }

  Future<bool> confirm(DialogRequest request) async =>
      await _open(request) != null;

  Future<String?> prompt(DialogRequest request) => _open(request);

  Future<String?> _open(DialogRequest request) {
    _dialog?.complete(null);
    _dialog = request;
    _profileMenuOpen = false;
    notifyListeners();
    return request.result;
  }

  void closeDialog([String? value]) {
    final dialog = _dialog;
    if (dialog == null) return;
    _dialog = null;
    dialog.complete(value);
    notifyListeners();
  }

  bool dismissTopmost() {
    if (_dialog != null) {
      closeDialog();
      return true;
    }
    if (_profileMenuOpen) {
      closeProfileMenu();
      return true;
    }
    return false;
  }

  Future<void> checkAgain() => _guard(_device.rescan);

  Future<void> connect() => _guard(_device.requestDevice);

  Future<void> reconnect() => _guard(_device.refresh);

  Future<void> checkSleep() async {
    if (_sleepChecking) return;
    _sleepChecking = true;
    _checkingOff = status == ConnectionStatus.off;
    notifyListeners();
    await _guard(_device.refresh);
    if (_disposed) return;
    _sleepChecking = false;
    notifyListeners();
    switch (_device.state) {
      case DeviceAsleep():
        _toasts.show(
          'Still asleep — move or click the mouse',
          icon: AppIconsFill.moon,
        );
      case DeviceOff():
        _toasts.show('Still off — turn the mouse on', icon: AppIcons.power);
      default:
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _restoreSection() async {
    try {
      final stored = await _settings.settings();
      if (_disposed || _sectionChosen || stored.lastSection == null) return;
      _section = AppSection.byName(stored.lastSection);
      notifyListeners();
    } on Object {
      return;
    }
  }

  void _onProfiles(List<Profile> profiles) {
    _profiles = profiles;
    notifyListeners();
  }

  void _onState(DeviceState state) {
    final previous = _state;
    _state = state;
    switch (state) {
      case DeviceReady(:final info, :final settings):
        _announceReady(previous, state);
        _hadSettings = true;
        _info = info;
        _connection = info.connection;
        _dpi = settings.dpi;
        _polling = settings.polling;
      case DeviceConnecting(:final device) ||
          DeviceAsleep(:final device) ||
          DeviceOff(:final device) ||
          DeviceFailed(:final device):
        _connection = device.connection;
      case DeviceAbsent():
        if (previous is DeviceReady) {
          _toasts.show(
            'Mouse disconnected — edits kept',
            kind: ToastKind.warning,
            icon: AppIconsFill.plugs,
          );
        }
        if (!_hadSettings) _connection = null;
    }
    notifyListeners();
  }

  void _announceReady(DeviceState previous, DeviceReady ready) {
    final info = ready.info;
    if (previous is DeviceReady && previous.link != ready.link) {
      _announceLink(previous.link, ready.link);
    }
    if (previous is! DeviceReady) {
      if (!_hadSettings) {
        _toasts.show(
          'X11SE connected · settings read',
          kind: ToastKind.success,
          icon: AppIconsFill.plugsConnected,
        );
      }
      return;
    }
    final before = previous.info;
    final percent = info.batteryPercent;
    final charging =
        info.chargeState == ChargeState.charging ||
        info.chargeState == ChargeState.charged;
    if (percent != null &&
        percent < lowBatteryPercent &&
        !charging &&
        (before.batteryPercent == null ||
            before.batteryPercent! >= lowBatteryPercent)) {
      _toasts.show(
        'Battery low — $percent%. Connect the cable to charge.',
        kind: ToastKind.warning,
        icon: AppIconsFill.batteryWarning,
      );
    }
    if (info.chargeState == ChargeState.charged &&
        before.chargeState != ChargeState.charged &&
        before.chargeState != ChargeState.unknown) {
      _toasts.show(
        'X11SE fully charged',
        kind: ToastKind.success,
        icon: AppIconsFill.batteryFull,
      );
    }
  }

  void _announceLink(MouseLink from, MouseLink to) {
    if (to == MouseLink.off) {
      _toasts.show('X11SE turned off — edits kept', icon: AppIcons.power);
    } else if (from == MouseLink.off) {
      _toasts.show(
        'X11SE is back on',
        kind: ToastKind.success,
        icon: AppIconsFill.plugsConnected,
      );
    } else if (to == MouseLink.asleep) {
      _toasts.show(
        'X11SE went to sleep — move it to wake',
        icon: AppIconsFill.moon,
      );
    } else {
      _toasts.show(
        'X11SE is awake',
        kind: ToastKind.success,
        icon: AppIconsFill.sun,
      );
    }
  }

  void _onStageChange(int index) {
    final state = _state;
    if (state is! DeviceReady) return;
    final stage = state.settings.dpi.stages[index];
    _toasts.show(
      'DPI button · stage ${index + 1} · ${formatThousands(stage.dpi)} DPI',
      icon: AppIconsFill.gauge,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _dialog?.complete(null);
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
