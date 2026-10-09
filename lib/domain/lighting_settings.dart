import 'rgb_color.dart';

enum LightingMode {
  off,
  staticColor,
  breathing,
  neon,
  colorBreathing,
  staticDpi,
  breathingDpi;

  bool get usesColor => this == staticColor || this == breathing;

  bool get usesBrightness => this == staticColor || this == staticDpi;

  bool get usesSpeed =>
      this == breathing ||
      this == neon ||
      this == colorBreathing ||
      this == breathingDpi;

  bool get usesStageColors => this == staticDpi || this == breathingDpi;
}

class LightingSettings {
  const LightingSettings({
    required this.mode,
    required this.color,
    required this.brightness,
    required this.speed,
  });

  static const minLevel = 1;
  static const maxLevel = 8;

  static const factoryDefaults = LightingSettings(
    mode: LightingMode.off,
    color: RgbColor.hex(0x00FF00),
    brightness: 8,
    speed: 6,
  );

  final LightingMode mode;
  final RgbColor color;
  final int brightness;
  final int speed;

  LightingSettings copyWith({
    LightingMode? mode,
    RgbColor? color,
    int? brightness,
    int? speed,
  }) => LightingSettings(
    mode: mode ?? this.mode,
    color: color ?? this.color,
    brightness: brightness ?? this.brightness,
    speed: speed ?? this.speed,
  );

  @override
  bool operator ==(Object other) =>
      other is LightingSettings &&
      other.mode == mode &&
      other.color == color &&
      other.brightness == brightness &&
      other.speed == speed;

  @override
  int get hashCode => Object.hash(mode, color, brightness, speed);

  @override
  String toString() =>
      'LightingSettings($mode, $color, brightness: $brightness, speed: $speed)';
}
