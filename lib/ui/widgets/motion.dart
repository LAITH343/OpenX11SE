import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';

enum Entrance { enter, pop, fade, slideIn }

class EntranceTransition extends StatefulWidget {
  const EntranceTransition({
    super.key,
    required this.child,
    this.kind = Entrance.enter,
    this.duration,
  });

  final Widget child;
  final Entrance kind;
  final Duration? duration;

  @override
  State<EntranceTransition> createState() => _EntranceTransitionState();
}

class _EntranceTransitionState extends State<EntranceTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.duration != null) return;
    final m = context.nocturne.motion;
    _c.duration =
        widget.duration ??
        switch (widget.kind) {
          Entrance.enter => m.enter,
          Entrance.pop => const Duration(milliseconds: 220),
          Entrance.fade => m.medium,
          Entrance.slideIn => const Duration(milliseconds: 250),
        };
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.nocturne.motion;
    final curve = switch (widget.kind) {
      Entrance.enter => m.enterCurve,
      Entrance.pop => m.popCurve,
      Entrance.fade => Curves.ease,
      Entrance.slideIn => Curves.ease,
    };
    final t = CurvedAnimation(parent: _c, curve: curve);
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) {
        final v = t.value;
        final (dy, scale) = switch (widget.kind) {
          Entrance.enter => (6 * (1 - v), 1.0),
          Entrance.pop => (8 * (1 - v), 0.98 + 0.02 * v),
          Entrance.fade => (0.0, 1.0),
          Entrance.slideIn => (-6 * (1 - v), 1.0),
        };
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: scale == 1
                ? child
                : Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

class _Looping extends StatefulWidget {
  const _Looping({required this.period, required this.builder});

  final Duration period;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_Looping> createState() => _LoopingState();
}

class _LoopingState extends State<_Looping>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => widget.builder(context, _c.value),
  );
}

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 16, this.color, this.period});

  final double size;
  final Color? color;
  final Duration? period;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.nocturne.accent;
    final icon = Icon(AppIcons.circleNotch, size: size, color: c);
    return _Looping(
      period: period ?? const Duration(seconds: 1),
      builder: (context, t) =>
          Transform.rotate(angle: t * 2 * math.pi, child: icon),
    );
  }
}

class Blink extends StatelessWidget {
  const Blink({super.key, required this.child, this.period});

  final Widget child;
  final Duration? period;

  @override
  Widget build(BuildContext context) => _Looping(
    period: period ?? const Duration(milliseconds: 1600),
    builder: (context, t) {
      final d = (t - 0.5).abs() * 2;
      final eased = Curves.easeInOut.transform(d);
      return Opacity(opacity: 0.25 + 0.75 * eased, child: child);
    },
  );
}

class PulseRings extends StatelessWidget {
  const PulseRings({super.key, required this.child, this.size = 72});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = context.nocturne.accent;
    Widget ring(double t) {
      final e = Curves.easeOut.transform(t);
      return Transform.scale(
        scale: 0.7 + 1.4 * e,
        child: Opacity(
          opacity: 0.8 * (1 - e),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: _Looping(
        period: const Duration(milliseconds: 2400),
        builder: (context, t) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [ring(t), ring((t + 0.5) % 1), child],
        ),
      ),
    );
  }
}

class Shimmer extends StatelessWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.nocturne.palette;
    final hi = Color.lerp(p.surface, p.n(700), 0.45)!;
    return _Looping(
      period: const Duration(milliseconds: 1400),
      builder: (context, t) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          const band = 1200.0;
          final dx = -600 + 1200 * t;
          return LinearGradient(
            colors: [p.surface, hi, p.surface],
            stops: const [0, 0.5, 1],
            tileMode: TileMode.repeated,
          ).createShader(Rect.fromLTWH(dx - rect.left, 0, band, rect.height));
        },
        child: child,
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.large = false,
  });

  final double? width;
  final double height;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: n.surface,
          borderRadius: large ? n.radius.lgAll : n.radius.mdAll,
        ),
      ),
    );
  }
}

double _wave(double t) => Curves.easeInOut.transform(1 - (t * 2 - 1).abs());

class Breathe extends StatelessWidget {
  const Breathe({super.key, required this.child, this.period});

  final Widget child;
  final Duration? period;

  @override
  Widget build(BuildContext context) => _Looping(
    period: period ?? const Duration(milliseconds: 2400),
    builder: (context, t) =>
        Opacity(opacity: 0.1 + 0.9 * _wave(t), child: child),
  );
}

class Doze extends StatelessWidget {
  const Doze({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _Looping(
    period: const Duration(seconds: 4),
    builder: (context, t) {
      final w = _wave(t);
      return Opacity(
        opacity: 0.5 + 0.5 * w,
        child: Transform.scale(scale: 0.94 + 0.06 * w, child: child),
      );
    },
  );
}

class Halo extends StatelessWidget {
  const Halo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = context.nocturne.accent;
    return _Looping(
      period: const Duration(seconds: 4),
      builder: (context, t) {
        final w = _wave(t);
        return Opacity(
          opacity: 0.12 + 0.38 * w,
          child: Transform.scale(
            scale: 0.9 + 0.22 * w,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.4),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
