import 'dart:async';

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
  const WriteError({required this.label, required this.asleep});

  final String label;
  final bool asleep;

  String get message => asleep
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
  bool _online = false;
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

  int get pendingCount => _changes.length;

  bool get hasPending => _changes.isNotEmpty;

  Set<SettingsSection> get dirtySections => _changes.toSet();

  bool isDirty(SettingsSection section) => _changes.contains(section);

  bool get autoApply => _autoApply;

  bool get isOnline => _online;

  bool get writing => _writing;

  double get writeProgress => _progress;

  String get writeLabel => _writeLabel;

  WriteError? get writeError => _writeError;

  bool get canApply => hasPending && !_writing && _online;

  bool get canDiscard => hasPending && !_writing;

  void stage(DeviceSettings Function(DeviceSettings current) change) {
    final current = _staged;
    if (current == null || _writing) return;
    final next = change(current);
    if (next == current) return;
    _staged = next;
    _recompute();
    notifyListeners();
    if (_autoApply) {
      _autoApplyTimer?.cancel();
      _autoApplyTimer = Timer(autoApplyDelay, () => unawaited(apply()));
    }
  }

  void discard() {
    final saved = _saved;
    if (saved == null || _writing || !hasPending) return;
    _staged = saved;
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

  Future<void> retry() {
    _writeError = null;
    notifyListeners();
    return apply();
  }

  Future<void> apply() async {
    _autoApplyTimer?.cancel();
    final previous = _saved;
    final next = _staged;
    if (!canApply || previous == null || next == null) return;
    final changed = _changes.toSet();
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
      final asleep =
          e.failure == DeviceWriteFailure.noAcknowledgement &&
          _connection == ConnectionType.dongle;
      _writeError = WriteError(
        label: _labelFor(e.reportId, changed),
        asleep: asleep,
      );
      _toasts.show(
        asleep
            ? 'No reply — mouse is asleep. Nothing was lost.'
            : "Couldn't write ${_writeError!.label} — nothing was lost",
        kind: asleep ? ToastKind.warning : ToastKind.error,
        icon: asleep ? AppIconsFill.moon : AppIconsFill.xCircle,
      );
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
    switch (state) {
      case DeviceReady(:final settings, :final info):
        _connection = info.connection;
        _rebase(settings, reconnected: !wasOnline);
      case DeviceConnecting(:final device) ||
          DeviceAsleep(:final device) ||
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
