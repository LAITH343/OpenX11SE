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
    required this.mouseBody,
    required this.mouseEdge,
    required this.mouseSeam,
    required this.mouseWell,
    required this.mouseSheen,
    required this.mouseShadow,
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
  final List<Color> mouseBody;
  final Color mouseEdge;
  final Color mouseSeam;
  final Color mouseWell;
  final Color mouseSheen;
  final List<BoxShadow> mouseShadow;

  bool get isDark => brightness == Brightness.dark;

  Color get divider => text.withValues(alpha: isDark ? 0.13 : 0.22);

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
      mouseBody: mouseBody,
      mouseEdge: mouseEdge,
      mouseSeam: mouseSeam,
      mouseWell: mouseWell,
      mouseSheen: mouseSheen,
      mouseShadow: mouseShadow,
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
      mouseBody: [
        for (var i = 0; i < a.mouseBody.length; i++)
          Color.lerp(a.mouseBody[i], b.mouseBody[i], t)!,
      ],
      mouseEdge: Color.lerp(a.mouseEdge, b.mouseEdge, t)!,
      mouseSeam: Color.lerp(a.mouseSeam, b.mouseSeam, t)!,
      mouseWell: Color.lerp(a.mouseWell, b.mouseWell, t)!,
      mouseSheen: Color.lerp(a.mouseSheen, b.mouseSheen, t)!,
      mouseShadow: BoxShadow.lerpList(a.mouseShadow, b.mouseShadow, t)!,
    );
  }
}

Color mix(Color a, Color b, double amountOfA) => Color.lerp(b, a, amountOfA)!;

const _shade = Color(0xFF000000);

final NocturnePalette nocturneDark = NocturnePalette(
  brightness: Brightness.dark,
  bg: const Color(0xFF1A1A1D),
  surface: const Color(0xFF242428),
  text: const Color(0xFFEBEBEE),
  accent: const Color(0xFF5865F2),
  neutral: const {
    100: Color(0xFFEBEBEE),
    200: Color(0xFFD2D2D7),
    300: Color(0xFFAEAEB5),
    400: Color(0xFF8A8A92),
    500: Color(0xFF6B6B73),
    600: Color(0xFF505056),
    700: Color(0xFF3C3C41),
    800: Color(0xFF2F2F33),
    900: Color(0xFF1F1F22),
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
  shadowSm: const [BoxShadow(color: Color(0xFF2E2E32), spreadRadius: 1)],
  shadowMd: [
    BoxShadow(
      color: _shade.withValues(alpha: 0.35),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
    const BoxShadow(color: Color(0xFF333338), spreadRadius: 1),
  ],
  shadowLg: [
    BoxShadow(
      color: _shade.withValues(alpha: 0.5),
      offset: const Offset(0, 18),
      blurRadius: 44,
    ),
    const BoxShadow(color: Color(0xFF3A3A3F), spreadRadius: 1),
  ],
  mouseBody: const [Color(0xFF3A3A3F), Color(0xFF28282C), Color(0xFF1C1C1F)],
  mouseEdge: const Color(0xFF3C3C41),
  mouseSeam: const Color(0xFF1A1A1D),
  mouseWell: const Color(0xFF1A1A1D),
  mouseSheen: const Color(0x12EBEBEE),
  mouseShadow: const [],
);

const _lightInk = Color(0xFF14141E);

final NocturnePalette nocturneLight = NocturnePalette(
  brightness: Brightness.light,
  bg: const Color(0xFFEEEEF0),
  surface: const Color(0xFFF9F9FA),
  text: const Color(0xFF1C1C1F),
  accent: const Color(0xFF5865F2),
  neutral: const {
    100: Color(0xFF26262A),
    200: Color(0xFF3D3D42),
    300: Color(0xFF58585E),
    400: Color(0xFF75757C),
    500: Color(0xFF94949B),
    600: Color(0xFFB4B4BA),
    700: Color(0xFFD0D0D5),
    800: Color(0xFFE2E2E6),
    900: Color(0xFFEBEBEE),
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
  shadowSm: const [BoxShadow(color: Color(0xFFDCDCE0), spreadRadius: 1)],
  shadowMd: [
    BoxShadow(
      color: _lightInk.withValues(alpha: 0.08),
      offset: const Offset(0, 8),
      blurRadius: 22,
    ),
    const BoxShadow(color: Color(0xFFD4D4D9), spreadRadius: 1),
  ],
  shadowLg: [
    BoxShadow(
      color: _lightInk.withValues(alpha: 0.14),
      offset: const Offset(0, 18),
      blurRadius: 40,
    ),
    const BoxShadow(color: Color(0xFFC4C4CA), spreadRadius: 1),
  ],
  mouseBody: const [Color(0xFFFAFAFB), Color(0xFFEBEBEE), Color(0xFFD4D4D9)],
  mouseEdge: const Color(0xFFB4B4BA),
  mouseSeam: const Color(0xFF9A9AA1),
  mouseWell: const Color(0xFFCFCFD4),
  mouseSheen: const Color(0xE6FFFFFF),
  mouseShadow: [
    BoxShadow(
      color: _lightInk.withValues(alpha: 0.16),
      offset: const Offset(0, 10),
      blurRadius: 18,
    ),
    BoxShadow(
      color: _lightInk.withValues(alpha: 0.12),
      offset: const Offset(0, 2),
      blurRadius: 3,
    ),
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

const Color ledCycleBase = Color(0xFFFF4545);
