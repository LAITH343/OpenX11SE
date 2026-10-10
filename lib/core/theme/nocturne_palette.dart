import 'package:flutter/widgets.dart';

typedef ColorRamp = Map<int, Color>;

const List<int> rampSteps = [100, 200, 300, 400, 500, 600, 700, 800, 900];

@immutable
class NocturnePalette {
  const NocturnePalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.text,
    required this.accent,
    required this.neutral,
    required this.accentRamp,
    required this.success,
    required this.danger,
    required this.warning,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color text;
  final Color accent;
  final ColorRamp neutral;
  final ColorRamp accentRamp;
  final Color success;
  final Color danger;
  final Color warning;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;

  bool get isDark => brightness == Brightness.dark;

  Color get divider => text.withValues(alpha: isDark ? 0.16 : 0.22);

  Color n(int step) => neutral[step]!;
  Color a(int step) => accentRamp[step]!;

  NocturnePalette withAccent(Color color) {
    final ramp = Map<int, Color>.of(accentRamp)
      ..[300] = mix(color, text, 0.55)
      ..[800] = mix(color, bg, 0.26)
      ..[900] = mix(color, bg, 0.14);
    return NocturnePalette(
      brightness: brightness,
      bg: bg,
      surface: surface,
      text: text,
      accent: color,
      neutral: neutral,
      accentRamp: ramp,
      success: success,
      danger: danger,
      warning: warning,
      shadowSm: shadowSm,
      shadowMd: shadowMd,
      shadowLg: shadowLg,
    );
  }

  static NocturnePalette lerp(NocturnePalette a, NocturnePalette b, double t) {
    ColorRamp ramp(ColorRamp x, ColorRamp y) => {
      for (final s in rampSteps) s: Color.lerp(x[s], y[s], t)!,
    };
    return NocturnePalette(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      bg: Color.lerp(a.bg, b.bg, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      text: Color.lerp(a.text, b.text, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      neutral: ramp(a.neutral, b.neutral),
      accentRamp: ramp(a.accentRamp, b.accentRamp),
      success: Color.lerp(a.success, b.success, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      warning: Color.lerp(a.warning, b.warning, t)!,
      shadowSm: BoxShadow.lerpList(a.shadowSm, b.shadowSm, t)!,
      shadowMd: BoxShadow.lerpList(a.shadowMd, b.shadowMd, t)!,
      shadowLg: BoxShadow.lerpList(a.shadowLg, b.shadowLg, t)!,
    );
  }
}

Color mix(Color a, Color b, double amountOfA) => Color.lerp(b, a, amountOfA)!;

const _shade = Color(0xFF000000);

final NocturnePalette nocturneDark = NocturnePalette(
  brightness: Brightness.dark,
  bg: const Color(0xFF1E1F22),
  surface: const Color(0xFF2B2D31),
  text: const Color(0xFFF2F3F5),
  accent: const Color(0xFF5865F2),
  neutral: const {
    100: Color(0xFFF2F3F5),
    200: Color(0xFFDBDEE1),
    300: Color(0xFFB5BAC1),
    400: Color(0xFF949BA4),
    500: Color(0xFF80848E),
    600: Color(0xFF6D6F78),
    700: Color(0xFF4E5058),
    800: Color(0xFF383A40),
    900: Color(0xFF232428),
  },
  accentRamp: const {
    100: Color(0xFFF2F3FF),
    200: Color(0xFFE3E6FF),
    300: Color(0xFFC9CDFD),
    400: Color(0xFFA8B0FA),
    500: Color(0xFF7983F5),
    600: Color(0xFF5865F2),
    700: Color(0xFF4752C4),
    800: Color(0xFF313A8F),
    900: Color(0xFF23295B),
  },
  success: const Color(0xFF23A55A),
  danger: const Color(0xFFF23F43),
  warning: const Color(0xFFF0B232),
  shadowSm: const [BoxShadow(color: Color(0xFF404249), spreadRadius: 1)],
  shadowMd: [
    BoxShadow(
      color: _shade.withValues(alpha: 0.55),
      offset: const Offset(0, 6),
      blurRadius: 18,
    ),
    const BoxShadow(color: Color(0xFF383A40), spreadRadius: 1),
  ],
  shadowLg: [
    BoxShadow(
      color: _shade.withValues(alpha: 0.65),
      offset: const Offset(0, 16),
      blurRadius: 40,
    ),
    const BoxShadow(color: Color(0xFF4E5058), spreadRadius: 1),
  ],
);

const _lightInk = Color(0xFF141628);

final NocturnePalette nocturneLight = NocturnePalette(
  brightness: Brightness.light,
  bg: const Color(0xFFE9EBEF),
  surface: const Color(0xFFFFFFFF),
  text: const Color(0xFF232428),
  accent: const Color(0xFF5865F2),
  neutral: const {
    100: Color(0xFF232428),
    200: Color(0xFF383A40),
    300: Color(0xFF4E5058),
    400: Color(0xFF6D6F78),
    500: Color(0xFF80848E),
    600: Color(0xFF949BA4),
    700: Color(0xFFB5BAC1),
    800: Color(0xFFDBDEE1),
    900: Color(0xFFF2F3F5),
  },
  accentRamp: const {
    100: Color(0xFF1F245C),
    200: Color(0xFF303A91),
    300: Color(0xFF414FC7),
    400: Color(0xFF5865F2),
    500: Color(0xFF7983F5),
    600: Color(0xFFA1A8FA),
    700: Color(0xFFC9CDFD),
    800: Color(0xFFE3E5FF),
    900: Color(0xFFF2F3FF),
  },
  success: const Color(0xFF248046),
  danger: const Color(0xFFB3261E),
  warning: const Color(0xFF8A5A00),
  shadowSm: const [BoxShadow(color: Color(0xFFD8DADD), spreadRadius: 1)],
  shadowMd: [
    BoxShadow(
      color: _lightInk.withValues(alpha: 0.08),
      offset: const Offset(0, 6),
      blurRadius: 18,
    ),
    const BoxShadow(color: Color(0xFFD8DADD), spreadRadius: 1),
  ],
  shadowLg: [
    BoxShadow(
      color: _lightInk.withValues(alpha: 0.12),
      offset: const Offset(0, 16),
      blurRadius: 40,
    ),
    const BoxShadow(color: Color(0xFFB5BAC1), spreadRadius: 1),
  ],
);

const List<Color> swatchPresets = [
  Color(0xFFFF4545),
  Color(0xFFFF9A2E),
  Color(0xFFFFD84A),
  Color(0xFF3DDC84),
  Color(0xFF1FD1C1),
  Color(0xFF2EC5FF),
  Color(0xFF3B6CFF),
  Color(0xFF8B6CFF),
  Color(0xFFFF4FD8),
  Color(0xFFE6E6F0),
];

const List<Color> stageColorDefaults = [
  Color(0xFFFF4545),
  Color(0xFFFF9A2E),
  Color(0xFFFFD84A),
  Color(0xFF3DDC84),
  Color(0xFF2EC5FF),
  Color(0xFF8B6CFF),
  Color(0xFFFF4FD8),
  Color(0xFFE6E6F0),
];

const List<Color> spectrumStops = [
  Color(0xFFFF4545),
  Color(0xFFFFD84A),
  Color(0xFF3DDC84),
  Color(0xFF2EC5FF),
  Color(0xFF8B6CFF),
  Color(0xFFFF4FD8),
  Color(0xFFFF4545),
];

const Color windowCloseHover = Color(0xFFC4453A);

const List<Color> deviceBodyGradient = [
  Color(0xFF3F424D),
  Color(0xFF292B31),
  Color(0xFF1D1F2A),
];

const Color deviceBodySheen = Color(0xFFE9E9ED);

const Color ledCycleBase = Color(0xFFFF4545);
