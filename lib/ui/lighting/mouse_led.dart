import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/lighting_settings.dart';
import '../../domain/rgb_color.dart';
import 'led_glow.dart';
import 'lighting_view_model.dart';

Color _color(RgbColor c) => Color(0xFF000000 | c.rgb);

class StagedLedGlow extends StatelessWidget {
  const StagedLedGlow({super.key, this.mode, required this.builder});

  final LightingMode? mode;
  final Widget Function(BuildContext context, LedFrame frame) builder;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LightingViewModel>();
    final l = vm.lighting;
    return LedGlow(
      mode: mode ?? l.mode,
      color: _color(l.color),
      stageColor: _color(vm.activeStageColor),
      brightness: l.brightness,
      speed: l.speed,
      builder: builder,
    );
  }
}

class MouseLed extends StatelessWidget {
  const MouseLed({super.key});

  static const size = 160.0;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox.square(
      dimension: size,
      child: StagedLedGlow(
        builder: (context, f) => Opacity(
          opacity: f.opacity,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: .32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [f.color, f.color.withValues(alpha: 0)],
                        stops: const [0, .62],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 74,
                top: 78,
                child: Container(
                  width: 12,
                  height: 4,
                  decoration: BoxDecoration(
                    color: f.color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(color: f.color, spreadRadius: 1, blurRadius: 4),
                      BoxShadow(
                        color: f.color,
                        spreadRadius: 2,
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
