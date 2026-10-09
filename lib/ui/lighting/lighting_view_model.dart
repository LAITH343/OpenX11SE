import 'package:flutter/foundation.dart';

import '../../domain/device_settings.dart';
import '../../domain/lighting_settings.dart';
import '../../domain/rgb_color.dart';
import '../../domain/settings_changes.dart';
import '../shell/edit_session_view_model.dart';

class StageSwatch {
  const StageSwatch(this.color, {required this.active});

  final RgbColor color;
  final bool active;
}

extension LightingModeLabels on LightingMode {
  String get label => switch (this) {
    LightingMode.off => 'Off',
    LightingMode.staticColor => 'Static',
    LightingMode.breathing => 'Breathing',
    LightingMode.neon => 'Neon',
    LightingMode.colorBreathing => 'Colour breathing',
    LightingMode.staticDpi => 'Static DPI',
    LightingMode.breathingDpi => 'Breathing DPI',
  };

  String get description => switch (this) {
    LightingMode.off => 'All LEDs dark',
    LightingMode.staticColor => 'Solid colour',
    LightingMode.breathing => 'Fades in and out',
    LightingMode.neon => 'Rainbow cycle',
    LightingMode.colorBreathing => 'Breathes through colours',
    LightingMode.staticDpi => 'Active stage colour',
    LightingMode.breathingDpi => 'Breathes in stage colour',
  };
}

class LightingViewModel extends ChangeNotifier {
  LightingViewModel({required this._edit}) {
    _edit.addListener(_onEdit);
  }

  final EditSessionViewModel _edit;

  DeviceSettings? get _staged => _edit.staged;

  bool get hasSettings => _staged != null;

  bool get canEdit => _staged != null && !_edit.writing;

  bool get dirty => _edit.isDirty(SettingsSection.lighting);

  LightingSettings get lighting =>
      _staged?.lighting ?? LightingSettings.factoryDefaults;

  LightingMode get mode => lighting.mode;

  RgbColor get activeStageColor {
    final dpi = _staged?.dpi;
    if (dpi == null) return lighting.color;
    return dpi.stages[dpi.activeStageIndex].color;
  }

  List<StageSwatch> get stageSwatches {
    final dpi = _staged?.dpi;
    if (dpi == null) return const [];
    return [
      for (var i = 0; i < dpi.stages.length; i++)
        if (dpi.stages[i].enabled)
          StageSwatch(dpi.stages[i].color, active: i == dpi.activeStageIndex),
    ];
  }

  String? get colorNote {
    if (mode.usesColor) return null;
    if (mode == LightingMode.off) return 'Lighting is off.';
    if (mode.usesStageColors) {
      return '${mode.label} uses the active DPI stage colour.';
    }
    return '${mode.label} cycles through its own colours.';
  }

  String? get brightnessNote => mode.usesBrightness
      ? null
      : "${mode.label} doesn't use brightness — only Static and Static DPI "
            'do.';

  String? get speedNote {
    if (mode.usesSpeed) return null;
    if (mode == LightingMode.off) return 'Lighting is off.';
    return "${mode.label} isn't animated.";
  }

  void setMode(LightingMode mode) => _stage((l) => l.copyWith(mode: mode));

  void setColor(RgbColor color) => _stage((l) => l.copyWith(color: color));

  void setBrightness(int level) {
    if (!mode.usesBrightness) return;
    _stage((l) => l.copyWith(brightness: _level(level)));
  }

  void setSpeed(int level) {
    if (!mode.usesSpeed) return;
    _stage((l) => l.copyWith(speed: _level(level)));
  }

  static int _level(int level) =>
      level.clamp(LightingSettings.minLevel, LightingSettings.maxLevel);

  void _stage(LightingSettings Function(LightingSettings l) change) =>
      _edit.stage((s) => s.copyWith(lighting: change(s.lighting)));

  void _onEdit() => notifyListeners();

  @override
  void dispose() {
    _edit.removeListener(_onEdit);
    super.dispose();
  }
}
