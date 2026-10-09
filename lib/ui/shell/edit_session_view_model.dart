import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/theme/app_icons.dart';
import '../../data/protocol/report_format.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/device_session.dart';
import '../../data/repositories/device_state.dart';
import '../../data/repositories/macro_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/app_settings.dart';
import '../../domain/button_assignment.dart';
import '../../domain/device_info.dart';
import '../../domain/device_settings.dart';
import '../../domain/macro.dart';
import '../../domain/profile.dart';
import '../../domain/settings_changes.dart';
import '../widgets/toast_host.dart';

class WriteError {
  const WriteError({
    required this.label,
    required this.asleep,
    this.off = false,
  });

  final String label;
  final bool asleep;
  final bool off;

  String get message => off
      ? 'Mouse is off. Turn it on, then Retry.'
      : asleep
      ? 'Mouse is asleep. Move it, then Retry.'
      : "Couldn't write $label to the mouse. Your changes are still staged.";
}

class EditSessionViewModel extends ChangeNotifier {
  EditSessionViewModel({
    required this._device,
    required this._profiles,
    required this._macros,
    required SettingsRepository settings,
    required this._toasts,
    this.autoApplyDelay = const Duration(milliseconds: 700),
  }) {
    _subscriptions = [
      _device.states.listen(_onState),
      _profiles.watchActive().listen(_onProfile, onError: (_) {}),
      settings.watchSettings().listen(_onSettings, onError: (_) {}),
    ];
    _onState(_device.state);
  }

  final DeviceRepository _device;
  final ProfileRepository _profiles;
  final MacroRepository _macros;
  final ToastController _toasts;
  final Duration autoApplyDelay;
  late final List<StreamSubscription<Object>> _subscriptions;

  DeviceSettings? _saved;
  DeviceSettings? _staged;
  List<SettingsSection> _changes = const [];
  final Set<int> _changedMacroIds = {};
  bool _sendAll = false;
  bool _restorePending = false;
  DeviceSettings? _profileSettings;
  bool _online = false;
  bool _mouseOff = false;
  ConnectionType? _connection;
  int? _profileId;
  bool _autoApply = false;
  bool _writing = false;
  double _progress = 0;
  String _writeLabel = '';
  WriteError? _writeError;
  Timer? _autoApplyTimer;
  bool _disposed = false;

  DeviceSettings? get saved => _saved;

  DeviceSettings? get staged => _staged;

  int get pendingCount =>
      (_sendAll
          ? max(_changes.length, SettingsSection.values.length)
          : _changes.length) +
      _changedMacroIds.length;

  bool get hasPending => _sendAll || _changes.isNotEmpty || _macrosPending;

  Set<SettingsSection> get dirtySections => {
    if (_sendAll) ...SettingsSection.values,
    ..._changes,
    if (_macrosPending) SettingsSection.buttons,
  };

  bool isDirty(SettingsSection section) => dirtySections.contains(section);

  bool get _macrosPending => _changedMacroIds.isNotEmpty;

  bool get autoApply => _autoApply;

  bool get isOnline => _online;

  bool get mouseOff => _mouseOff;

  bool get writing => _writing;

  double get writeProgress => _progress;

  String get writeLabel => _writeLabel;

  WriteError? get writeError => _writeError;

  bool get canApply => hasPending && !_writing && _online && !_mouseOff;

  bool get canDiscard => (_sendAll || _changes.isNotEmpty) && !_writing;

  bool get restorePending => _restorePending;

  void stage(DeviceSettings Function(DeviceSettings current) change) {
    final current = _staged;
    if (current == null || _writing) return;
    final next = change(current);
    if (next == current) return;
    _staged = next;
    _recompute();
    notifyListeners();
    _scheduleAutoApply();
  }

  void markMacroChanged(int macroId) {
    final staged = _staged;
    if (staged == null) return;
    final assigned = staged.buttons.any(
      (b) => b is MacroButton && b.macroId == macroId,
    );
    if (!assigned || !_changedMacroIds.add(macroId)) return;
    notifyListeners();
    _scheduleAutoApply();
  }

  void loadProfile(int profileId, DeviceSettings settings) {
    _profileId = profileId;
    _profileSettings = settings;
    if (_staged == null || _writing) return;
    _staged = settings;
    _sendAll = true;
    _writeError = null;
    _recompute();
    notifyListeners();
    _scheduleAutoApply();
  }

  Future<bool> restoreDefaults() async {
    if (_staged == null || _writing) return false;
    _staged = DeviceSettings.factoryDefaults;
    _sendAll = true;
    _restorePending = true;
    _writeError = null;
    _recompute();
    notifyListeners();
    if (!canApply) return false;
    _autoApplyTimer?.cancel();
    await apply();
    return !hasPending;
  }

  void _scheduleAutoApply() {
    if (!_autoApply) return;
    _autoApplyTimer?.cancel();
    _autoApplyTimer = Timer(autoApplyDelay, () => unawaited(apply()));
  }

  void discard() {
    final saved = _saved;
    if (saved == null || _writing || !canDiscard) return;
    _staged = saved;
    _sendAll = false;
    _restorePending = false;
    _writeError = null;
    _recompute();
    notifyListeners();
    _toasts.show(
      'Staged changes discarded',
      icon: AppIconsFill.arrowCounterClockwise,
    );
  }

  void dismissError() {
    if (_writeError == null) return;
    _writeError = null;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_mouseOff) {
      _toasts.show('Turn the mouse on to apply', icon: AppIcons.power);
      return;
    }
    _writeError = null;
    notifyListeners();
    return apply();
  }

  Future<void> apply() async {
    _autoApplyTimer?.cancel();
    final previous = _saved;
    final next = _staged;
    if (!canApply || previous == null || next == null) return;
    final changed = dirtySections;
    final changedMacros = {..._changedMacroIds};
    final sendAll = _sendAll;
    final restore = _restorePending;
    _writing = true;
    _progress = 0.06;
    _writeError = null;
    _writeLabel = _labelFor(null, changed);
    notifyListeners();
    try {
      await _device.apply(
        next,
        previous: previous,
        macros: await _macrosFor(next),
        changedMacroIds: changedMacros,
        restoreDefaults: restore,
        sendAll: sendAll,
        onProgress: (done, total, nextReportId) {
          if (_disposed) return;
          _progress = total == 0 ? 1 : (done / total).clamp(0.06, 1.0);
          if (nextReportId != null) {
            _writeLabel = _labelFor(nextReportId, changed);
          }
          notifyListeners();
        },
      );
      if (_disposed) return;
      _saved = next;
      if (identical(_staged, next)) {
        _sendAll = false;
        _restorePending = false;
      }
      _changedMacroIds.removeAll(changedMacros);
      _recompute();
      _toasts.show(
        'Settings saved to mouse',
        kind: ToastKind.success,
        icon: AppIconsFill.checkCircle,
      );
      final profileId = _profileId;
      if (profileId != null) {
        unawaited(_saveProfile(profileId, next));
      }
    } on DeviceWriteException catch (e) {
      if (_disposed) return;
      final off = e.failure == DeviceWriteFailure.off || _mouseOff;
      final asleep =
          !off &&
          (e.failure == DeviceWriteFailure.asleep ||
              (e.failure == DeviceWriteFailure.noAcknowledgement &&
                  _connection == ConnectionType.dongle));
      _writeError = WriteError(
        label: _labelFor(e.reportId, changed),
        asleep: asleep,
        off: off,
      );
      if (!off) {
        _toasts.show(
          asleep
              ? 'No reply — mouse is asleep. Nothing was lost.'
              : "Couldn't write ${_writeError!.label} — nothing was lost",
          kind: asleep ? ToastKind.warning : ToastKind.error,
          icon: asleep ? AppIconsFill.moon : AppIconsFill.xCircle,
        );
      }
    } on Object {
      if (_disposed) return;
      _writeError = WriteError(label: _writeLabel, asleep: false);
      _toasts.show(
        "Couldn't write $_writeLabel — nothing was lost",
        kind: ToastKind.error,
        icon: AppIconsFill.xCircle,
      );
    } finally {
      if (!_disposed) {
        _writing = false;
        _progress = 0;
        notifyListeners();
      }
    }
  }

  Future<void> _saveProfile(int id, DeviceSettings settings) async {
    try {
      await _profiles.saveSettings(id, settings);
    } on Object {
      return;
    }
  }

  Future<Map<int, Macro>> _macrosFor(DeviceSettings settings) async {
    final result = <int, Macro>{};
    for (final button in settings.buttons) {
      if (button is! MacroButton) continue;
      final id = button.macroId;
      if (id == null || result.containsKey(id)) continue;
      final macro = await _macros.macro(id);
      if (macro != null) result[id] = macro;
    }
    return result;
  }

  static String _labelFor(int? reportId, Set<SettingsSection> changed) =>
      switch (reportId) {
        ReportId.lighting when !changed.contains(SettingsSection.lighting) =>
          'Power & response',
        ReportId.lighting => 'Lighting',
        ReportId.buttons || ReportId.macro => 'Button mapping',
        ReportId.dpi || ReportId.polling => 'DPI & sensor',
        _ => _sectionLabel(changed),
      };

  static String _sectionLabel(Set<SettingsSection> changed) {
    for (final section in SettingsSection.values) {
      if (!changed.contains(section)) continue;
      return switch (section) {
        SettingsSection.performance => 'DPI & sensor',
        SettingsSection.buttons => 'Button mapping',
        SettingsSection.lighting => 'Lighting',
        SettingsSection.power => 'Power & response',
      };
    }
    return 'settings';
  }

  void _onState(DeviceState state) {
    final wasOnline = _online;
    _online = state is DeviceReady;
    _mouseOff = state is DeviceOff || (state is DeviceReady && state.off);
    switch (state) {
      case DeviceReady(:final settings, :final info):
        _connection = info.connection;
        _rebase(_linkMacros(settings), reconnected: !wasOnline);
      case DeviceConnecting(:final device) ||
          DeviceAsleep(:final device) ||
          DeviceOff(:final device) ||
          DeviceFailed(:final device):
        _connection = device.connection;
      case DeviceAbsent():
        _autoApplyTimer?.cancel();
    }
    notifyListeners();
  }

  void _rebase(DeviceSettings fresh, {required bool reconnected}) {
    final saved = _saved;
    final staged = _staged;
    final hadPending = hasPending;
    _saved = fresh;
    if (saved == null || staged == null || staged == saved) {
      _staged = fresh;
    } else if (staged.dpi.activeStageIndex == saved.dpi.activeStageIndex) {
      _staged = staged.copyWith(
        dpi: staged.dpi.copyWith(activeStageIndex: fresh.dpi.activeStageIndex),
      );
    }
    _recompute();
    if (reconnected && saved != null && hadPending && hasPending) {
      _toasts.show(
        'Reconnected — your staged changes are ready to apply',
        kind: ToastKind.success,
        icon: AppIconsFill.plugsConnected,
      );
    }
  }

  void _onProfile(Profile profile) {
    _profileId = profile.id;
    _profileSettings = profile.settings;
    final saved = _saved;
    final staged = _staged;
    if (saved == null || staged == null) return;
    final linked = _linkMacros(saved);
    if (linked == saved) return;
    _saved = linked;
    _staged = staged == saved ? linked : _linkMacros(staged);
    _recompute();
    notifyListeners();
  }

  DeviceSettings _linkMacros(DeviceSettings settings) {
    final links = _profileSettings?.buttons;
    if (links == null) return settings;
    var linked = settings;
    for (var slot = 0; slot < settings.buttons.length; slot++) {
      final button = settings.buttons[slot];
      final link = links[slot];
      if (button is MacroButton &&
          button.macroId == null &&
          link is MacroButton &&
          link.macroId != null) {
        linked = linked.withButton(slot, link);
      }
    }
    return linked;
  }

  void _onSettings(AppSettings settings) {
    if (settings.autoApply == _autoApply) return;
    _autoApply = settings.autoApply;
    notifyListeners();
  }

  void _recompute() {
    final saved = _saved;
    final staged = _staged;
    _changes = saved == null || staged == null
        ? const []
        : changedFields(saved, staged);
  }

  @override
  void dispose() {
    _disposed = true;
    _autoApplyTimer?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
