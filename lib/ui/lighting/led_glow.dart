import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/nocturne_palette.dart';
import '../../domain/lighting_settings.dart';

typedef LedFrame = ({Color color, double opacity});

double _seconds(Duration d) =>
    d.inMicroseconds / Duration.microsecondsPerSecond;

double _cycle(Duration elapsed, double period) {
  final t = _seconds(elapsed) / period;
  return t - t.floorToDouble();
}

double _breathe(Duration elapsed, double period) {
  final x = _cycle(elapsed, period);
  return 0.1 + 0.9 * Curves.easeInOut.transform(1 - (x * 2 - 1).abs());
}

Color _rotateHue(Color color, double degrees) {
  final hsv = HSVColor.fromColor(color);
  return hsv.withHue((hsv.hue + degrees) % 360).toColor();
}

LedFrame ledFrame({
  required LightingMode mode,
  required Color color,
  required Color stageColor,
  required int brightness,
  required int speed,
  Duration elapsed = Duration.zero,
}) {
  final breathePeriod = (9 - speed) * 0.55 + 1.1;
  final huePeriod = (9 - speed) * 0.9 + 2.5;
  final level = 0.3 + brightness / LightingSettings.maxLevel * 0.7;
  return switch (mode) {
    LightingMode.off => (color: color.withValues(alpha: 0), opacity: 0),
    LightingMode.staticColor => (color: color, opacity: level),
    LightingMode.breathing => (
      color: color,
      opacity: _breathe(elapsed, breathePeriod),
    ),
    LightingMode.neon => (
      color: _rotateHue(ledCycleBase, 360 * _cycle(elapsed, huePeriod)),
      opacity: 1,
    ),
    LightingMode.colorBreathing => (
      color: _rotateHue(
        ledCycleBase,
        60 * (_cycle(elapsed, huePeriod * 2.4) * 6).floorToDouble(),
      ),
      opacity: _breathe(elapsed, breathePeriod),
    ),
    LightingMode.staticDpi => (color: stageColor, opacity: level),
    LightingMode.breathingDpi => (
      color: stageColor,
      opacity: _breathe(elapsed, breathePeriod),
    ),
  };
}

class LedGlow extends StatefulWidget {
  const LedGlow({
    super.key,
    required this.mode,
    required this.color,
    required this.stageColor,
    required this.brightness,
    required this.speed,
    required this.builder,
  });

  final LightingMode mode;
  final Color color;
  final Color stageColor;
  final int brightness;
  final int speed;
  final Widget Function(BuildContext context, LedFrame frame) builder;

  @override
  State<LedGlow> createState() => _LedGlowState();
}

class _LedGlowState extends State<LedGlow> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _elapsed = elapsed),
  );
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LedGlow old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) _sync();
  }

  void _sync() {
    if (widget.mode.usesSpeed) {
      if (!_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _ticker.stop();
      _elapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    ledFrame(
      mode: widget.mode,
      color: widget.color,
      stageColor: widget.stageColor,
      brightness: widget.brightness,
      speed: widget.speed,
      elapsed: _elapsed,
    ),
  );
}
