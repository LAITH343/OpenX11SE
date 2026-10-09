import 'package:flutter/foundation.dart';

import '../../domain/power_settings.dart';
import '../../domain/settings_changes.dart';
import '../shell/edit_session_view_model.dart';

class DebouncePreset {
  const DebouncePreset(this.ms, this.name);

  final int ms;
  final String name;

  String get label => '$ms ms · $name';
}

class PowerViewModel extends ChangeNotifier {
  PowerViewModel({required this._edit}) {
    _edit.addListener(_onEdit);
  }

  static const debouncePresets = [
    DebouncePreset(4, 'Fastest'),
    DebouncePreset(8, 'Default'),
    DebouncePreset(16, 'Worn switches'),
  ];

  final EditSessionViewModel _edit;

  bool get hasSettings => _edit.staged != null;

  bool get canEdit => _edit.staged != null && !_edit.writing;

  bool get dirty => _edit.isDirty(SettingsSection.power);

  PowerSettings get power =>
      _edit.staged?.power ?? PowerSettings.factoryDefaults;

  PowerSettings? get _saved => _edit.saved?.power;

  bool get sleepChanged =>
      _saved != null && _saved!.sleepMinutes != power.sleepMinutes;

  bool get deepSleepChanged =>
      _saved != null && _saved!.deepSleepMinutes != power.deepSleepMinutes;

  bool get debounceChanged =>
      _saved != null && _saved!.debounceMs != power.debounceMs;

  void setSleepMinutes(int minutes) =>
      _stage((p) => p.copyWith(sleepMinutes: _minutes(minutes)));

  void setDeepSleepMinutes(int minutes) =>
      _stage((p) => p.copyWith(deepSleepMinutes: _minutes(minutes)));

  void setDebounceMs(int ms) =>
      _stage((p) => p.copyWith(debounceMs: snapDebounce(ms)));

  static int snapDebounce(int ms) {
    const min = PowerSettings.minDebounceMs;
    const step = PowerSettings.debounceStepMs;
    final snapped = min + ((ms - min) / step).round() * step;
    return snapped.clamp(min, PowerSettings.maxDebounceMs);
  }

  static int _minutes(int minutes) =>
      minutes.clamp(PowerSettings.minMinutes, PowerSettings.maxMinutes);

  void _stage(PowerSettings Function(PowerSettings p) change) {
    if (!canEdit) return;
    final next = change(power);
    if (next == power) return;
    _edit.stage((s) => s.copyWith(power: next));
  }

  void _onEdit() => notifyListeners();

  @override
  void dispose() {
    _edit.removeListener(_onEdit);
    super.dispose();
  }
}
