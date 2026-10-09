import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/nocturne_theme.dart';
import 'surface_card.dart';

class AppSlider extends StatefulWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.onChangeEnd,
    this.large = false,
    this.gradient = false,
    this.seams = const [],
    this.semanticLabel,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool large;
  final bool gradient;
  final List<double> seams;
  final String? semanticLabel;

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  bool _focused = false;

  bool get _enabled => widget.onChanged != null;

  double get _fraction {
    final span = widget.max - widget.min;
    if (span <= 0) return 0;
    return ((widget.value - widget.min) / span).clamp(0.0, 1.0);
  }

  double _snap(double v) {
    final steps = ((v - widget.min) / widget.step).round();
    return (widget.min + steps * widget.step).clamp(widget.min, widget.max);
  }

  void _fromPosition(Offset local, double width, {bool end = false}) {
    final f = (local.dx / width).clamp(0.0, 1.0);
    final v = _snap(widget.min + f * (widget.max - widget.min));
    if (v != widget.value) widget.onChanged?.call(v);
    if (end) widget.onChangeEnd?.call(v);
  }

  void _nudge(double delta) {
    final v = _snap(widget.value + delta);
    if (v == widget.value) return;
    widget.onChanged?.call(v);
    widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final thumb = widget.large ? 18.0 : 16.0;
    final ring = widget.large ? 5.0 : 4.0;
    final height = widget.large ? 26.0 : 24.0;
    final page = (widget.max - widget.min) / 10;

    return FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _StepIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _StepIntent(1),
        SingleActivator(LogicalKeyboardKey.pageDown): _StepIntent(-10),
        SingleActivator(LogicalKeyboardKey.pageUp): _StepIntent(10),
        SingleActivator(LogicalKeyboardKey.home): _StepIntent.toMin(),
        SingleActivator(LogicalKeyboardKey.end): _StepIntent.toMax(),
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(
          onInvoke: (i) {
            if (i.toEdge != 0) {
              _nudge(i.toEdge < 0 ? -double.infinity : double.infinity);
            } else if (i.steps.abs() >= 10) {
              _nudge(i.steps.sign * (page < widget.step ? widget.step : page));
            } else {
              _nudge(i.steps * widget.step);
            }
            return null;
          },
        ),
      },
      child: Semantics(
        slider: true,
        label: widget.semanticLabel,
        value: widget.value.toStringAsFixed(0),
        child: Opacity(
          opacity: _enabled ? 1 : n.disabledOpacity,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final x = _fraction * w;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _enabled
                    ? (d) => _fromPosition(d.localPosition, w)
                    : null,
                onTapUp: _enabled
                    ? (d) => _fromPosition(d.localPosition, w, end: true)
                    : null,
                onHorizontalDragUpdate: _enabled
                    ? (d) => _fromPosition(d.localPosition, w)
                    : null,
                onHorizontalDragEnd: _enabled
                    ? (_) => widget.onChangeEnd?.call(widget.value)
                    : null,
                child: SizedBox(
                  height: height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.n(800),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      for (final s in widget.seams)
                        Positioned(
                          left: s.clamp(0.0, 1.0) * w,
                          top: 7,
                          bottom: 7,
                          child: Container(width: 1, color: p.n(600)),
                        ),
                      Container(
                        width: x,
                        height: 4,
                        decoration: BoxDecoration(
                          color: widget.gradient ? null : p.accent,
                          gradient: widget.gradient
                              ? LinearGradient(colors: [p.a(700), p.accent])
                              : null,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Positioned(
                        left: x - thumb / 2,
                        child: Container(
                          width: thumb,
                          height: thumb,
                          decoration: BoxDecoration(
                            color: p.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.accent, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: p.accent.withValues(
                                  alpha: _focused ? 0.4 : 0.16,
                                ),
                                spreadRadius: ring,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.steps) : toEdge = 0;
  const _StepIntent.toMin() : steps = 0, toEdge = -1;
  const _StepIntent.toMax() : steps = 0, toEdge = 1;

  final int steps;
  final int toEdge;
}

class ValueSlider extends StatelessWidget {
  const ValueSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.step = 1,
    this.onChangeEnd,
    this.rangeLabels,
    this.semanticLabel,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final List<String>? rangeLabels;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final labels = rangeLabels ?? ['${_fmt(min)} $unit', '${_fmt(max)} $unit'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(_fmt(value), style: n.text.valueLarge),
            const SizedBox(width: 5),
            Text(unit, style: n.text.caption.copyWith(color: n.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        AppSlider(
          value: value,
          min: min,
          max: max,
          step: step,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
          semanticLabel: semanticLabel,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final l in labels)
              Text(l, style: n.text.micro.copyWith(color: n.textMuted)),
          ],
        ),
      ],
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.title,
    required this.slider,
    this.icon,
    this.description,
    this.changed = false,
    this.extra,
  });

  final String title;
  final IconData? icon;
  final String? description;
  final bool changed;
  final Widget slider;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CardHeading(title: title, icon: icon, changed: changed),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: n.text.caption.copyWith(
              fontSize: 12.5,
              color: n.textSecondary,
            ),
          ),
        ],
        if (extra != null) ...[const SizedBox(height: 10), extra!],
      ],
    );
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 2 * 260 + 32) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 16), slider],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 32),
              Expanded(child: slider),
            ],
          );
        },
      ),
    );
  }
}
