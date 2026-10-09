import 'list_equality.dart';
import 'rgb_color.dart';

class DpiStage {
  const DpiStage({
    required this.enabled,
    required this.dpi,
    required this.color,
  });

  final bool enabled;
  final int dpi;
  final RgbColor color;

  DpiStage copyWith({bool? enabled, int? dpi, RgbColor? color}) => DpiStage(
    enabled: enabled ?? this.enabled,
    dpi: dpi ?? this.dpi,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is DpiStage &&
      other.enabled == enabled &&
      other.dpi == dpi &&
      other.color == color;

  @override
  int get hashCode => Object.hash(enabled, dpi, color);

  @override
  String toString() => 'DpiStage(enabled: $enabled, dpi: $dpi, $color)';
}

class DpiSettings {
  DpiSettings({required List<DpiStage> stages, required this.activeStageIndex})
    : assert(stages.length == stageCount),
      assert(activeStageIndex >= 0 && activeStageIndex < stageCount),
      stages = List.unmodifiable(stages);

  static const stageCount = 8;

  static final factoryDefaults = DpiSettings(
    stages: const [
      DpiStage(enabled: true, dpi: 800, color: RgbColor.hex(0xFF0000)),
      DpiStage(enabled: true, dpi: 1600, color: RgbColor.hex(0x00FF00)),
      DpiStage(enabled: true, dpi: 2400, color: RgbColor.hex(0x0000FF)),
      DpiStage(enabled: true, dpi: 3200, color: RgbColor.hex(0xFFFF00)),
      DpiStage(enabled: true, dpi: 5000, color: RgbColor.hex(0x00FFFF)),
      DpiStage(enabled: true, dpi: 22000, color: RgbColor.hex(0xFF00FF)),
      DpiStage(enabled: false, dpi: 50, color: RgbColor.hex(0xFF4000)),
      DpiStage(enabled: false, dpi: 50, color: RgbColor.hex(0xFFFFFF)),
    ],
    activeStageIndex: 2,
  );

  final List<DpiStage> stages;
  final int activeStageIndex;

  DpiStage get activeStage => stages[activeStageIndex];

  DpiSettings copyWith({List<DpiStage>? stages, int? activeStageIndex}) =>
      DpiSettings(
        stages: stages ?? this.stages,
        activeStageIndex: activeStageIndex ?? this.activeStageIndex,
      );

  DpiSettings withStage(int index, DpiStage stage) =>
      copyWith(stages: [...stages]..[index] = stage);

  @override
  bool operator ==(Object other) =>
      other is DpiSettings &&
      other.activeStageIndex == activeStageIndex &&
      elementsEqual(other.stages, stages);

  @override
  int get hashCode => Object.hash(activeStageIndex, Object.hashAll(stages));

  @override
  String toString() =>
      'DpiSettings(active: $activeStageIndex, stages: $stages)';
}

class SensorOptions {
  const SensorOptions({required this.angleSnap, required this.ripple});

  static const factoryDefaults = SensorOptions(angleSnap: false, ripple: true);

  final bool angleSnap;
  final bool ripple;

  SensorOptions copyWith({bool? angleSnap, bool? ripple}) => SensorOptions(
    angleSnap: angleSnap ?? this.angleSnap,
    ripple: ripple ?? this.ripple,
  );

  @override
  bool operator ==(Object other) =>
      other is SensorOptions &&
      other.angleSnap == angleSnap &&
      other.ripple == ripple;

  @override
  int get hashCode => Object.hash(angleSnap, ripple);

  @override
  String toString() => 'SensorOptions(angleSnap: $angleSnap, ripple: $ripple)';
}
