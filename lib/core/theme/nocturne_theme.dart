import 'package:flutter/material.dart';

import 'nocturne_palette.dart';

const String fontFamily = 'Inter';
const List<String> fontFallback = ['Segoe UI', 'system-ui', 'sans-serif'];
const List<String> monoFamilyFallback = ['Consolas', 'Menlo', 'monospace'];

@immutable
class NocturneSpacing {
  const NocturneSpacing();

  double get s1 => 2.8;
  double get s2 => 5.6;
  double get s3 => 8.4;
  double get s4 => 11.2;
  double get s6 => 16.8;
  double get s8 => 22.4;
}

@immutable
class NocturneRadii {
  const NocturneRadii();

  double get sm => 4;
  double get md => 8;
  double get lg => 14;
  double get pill => 999;

  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get pillAll => BorderRadius.circular(pill);
}

@immutable
class NocturneMotion {
  const NocturneMotion();

  Duration get fast => const Duration(milliseconds: 150);
  Duration get medium => const Duration(milliseconds: 200);
  Duration get enter => const Duration(milliseconds: 300);
  Duration get toastLifetime => const Duration(milliseconds: 3600);

  Curve get enterCurve => const Cubic(0.2, 0.7, 0.3, 1);
  Curve get popCurve => const Cubic(0.2, 0.8, 0.3, 1);
  Curve get knobCurve => const Cubic(0.3, 0.7, 0.3, 1);
}

@immutable
class NocturneText {
  const NocturneText(this._text);

  final Color _text;

  static const _tabular = [FontFeature.tabularFigures()];

  TextStyle _base(double size, {FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: size,
        fontWeight: weight,
        height: 1.4,
        color: _text,
      );

  TextStyle _heading(double size) => _base(
    size,
    weight: FontWeight.w500,
  ).copyWith(height: 1.12, letterSpacing: -0.015 * size);

  TextStyle get display => _heading(28);
  TextStyle get title => _heading(24);
  TextStyle get dialogTitle => _heading(20);
  TextStyle get heading => _heading(16);
  TextStyle get subheading => _heading(15);

  TextStyle get body => _base(14);
  TextStyle get bodyStrong => _base(14, weight: FontWeight.w500);
  TextStyle get row => _base(13.5);
  TextStyle get small => _base(13);
  TextStyle get caption => _base(12);
  TextStyle get micro => _base(11);
  TextStyle get kicker => _base(10).copyWith(letterSpacing: 0.8);

  TextStyle get valueLarge => _base(
    26,
    weight: FontWeight.w500,
  ).copyWith(height: 1.1, fontFeatures: _tabular);
  TextStyle get valueMedium => _base(
    21,
    weight: FontWeight.w500,
  ).copyWith(height: 1.1, letterSpacing: -0.21, fontFeatures: _tabular);
  TextStyle get valueSmall =>
      _base(18, weight: FontWeight.w500).copyWith(fontFeatures: _tabular);

  TextStyle get mono => _base(14).copyWith(
    fontFamily: monoFamilyFallback.first,
    fontFamilyFallback: monoFamilyFallback,
    letterSpacing: 0.56,
  );

  TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: _tabular);
}

@immutable
class NocturneTheme extends ThemeExtension<NocturneTheme> {
  NocturneTheme(this.palette) : text = NocturneText(palette.text);

  final NocturnePalette palette;
  final NocturneText text;

  final NocturneSpacing space = const NocturneSpacing();
  final NocturneRadii radius = const NocturneRadii();
  final NocturneMotion motion = const NocturneMotion();

  Color get bg => palette.bg;
  Color get surface => palette.surface;
  Color get textColor => palette.text;
  Color get accent => palette.accent;
  Color get divider => palette.divider;

  Color get textMuted => palette.text.withValues(alpha: 0.55);
  Color get textSecondary => palette.text.withValues(alpha: 0.62);
  Color get textLabel => palette.text.withValues(alpha: 0.70);

  Color get hoverTint => palette.text.withValues(alpha: 0.07);
  Color get pressedTint => palette.text.withValues(alpha: 0.14);
  Color get accentHover => palette.accent.withValues(alpha: 0.12);
  Color get accentPressed => palette.accent.withValues(alpha: 0.22);
  Color get selection => palette.accent.withValues(alpha: 0.30);

  Color get chrome => mix(palette.bg, palette.surface, 0.70);
  Color get backdrop => palette.n(900).withValues(alpha: 0.5);

  double get disabledOpacity => 0.45;
  double get focusRingWidth => 2;
  double get focusRingOffset => 2;

  Gradient get groundGlow => RadialGradient(
    center: Alignment.topLeft,
    radius: 1.6,
    colors: [palette.accent.withValues(alpha: 0.06), palette.bg],
    stops: const [0, 0.6],
  );

  static NocturneTheme of(BuildContext context) =>
      Theme.of(context).extension<NocturneTheme>()!;

  @override
  NocturneTheme copyWith({NocturnePalette? palette}) =>
      NocturneTheme(palette ?? this.palette);

  @override
  NocturneTheme lerp(covariant NocturneTheme? other, double t) {
    if (other == null) return this;
    return NocturneTheme(NocturnePalette.lerp(palette, other.palette, t));
  }
}

extension NocturneContext on BuildContext {
  NocturneTheme get nocturne => NocturneTheme.of(this);
}

ThemeData buildNocturneTheme(NocturnePalette p) {
  final n = NocturneTheme(p);
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.bg,
    primaryContainer: p.a(800),
    onPrimaryContainer: p.a(100),
    secondary: p.a(400),
    onSecondary: p.bg,
    surface: p.surface,
    onSurface: p.text,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.bg,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surface,
    surfaceContainerHighest: p.n(800),
    onSurfaceVariant: n.textSecondary,
    outline: p.divider,
    outlineVariant: p.divider,
    error: p.danger,
    onError: p.bg,
    shadow: p.n(900),
    scrim: n.backdrop,
    inverseSurface: p.text,
    onInverseSurface: p.bg,
  );

  final inputBorder = WidgetStateInputBorder.resolveWith((states) {
    final color = states.contains(WidgetState.focused)
        ? p.accent
        : states.contains(WidgetState.error)
        ? p.danger
        : states.contains(WidgetState.hovered)
        ? p.text.withValues(alpha: 0.45)
        : p.divider;
    return OutlineInputBorder(
      borderRadius: n.radius.mdAll,
      borderSide: BorderSide(color: color),
    );
  });

  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.divider,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: NoSplash.splashFactory,
    hoverColor: n.hoverTint,
    focusColor: n.selection,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textTheme: TextTheme(
      displaySmall: n.text.display,
      headlineMedium: n.text.title,
      headlineSmall: n.text.dialogTitle,
      titleMedium: n.text.heading,
      titleSmall: n.text.subheading,
      bodyLarge: n.text.body,
      bodyMedium: n.text.small,
      bodySmall: n.text.caption,
      labelLarge: n.text.body,
      labelMedium: n.text.caption,
      labelSmall: n.text.micro,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: n.selection,
      selectionHandleColor: p.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.surface,
      hoverColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      hintStyle: n.text.body.copyWith(color: n.textMuted),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder,
      errorBorder: inputBorder,
      focusedErrorBorder: inputBorder,
      disabledBorder: inputBorder,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: Radius.circular(n.radius.sm),
      thumbColor: WidgetStatePropertyAll(p.n(700)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: n.radius.mdAll,
        boxShadow: p.shadowMd,
      ),
      textStyle: n.text.caption,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 500),
    ),
    extensions: [n],
  );
}
