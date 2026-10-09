import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/lighting_settings.dart';
import '../../domain/rgb_color.dart';
import '../shell/app_section.dart';
import '../shell/shell_view_model.dart';
import '../widgets/auto_grid.dart';
import '../widgets/colour_picker.dart';
import '../widgets/motion.dart';
import '../widgets/mouse_body_painter.dart';
import '../widgets/pressable.dart';
import '../widgets/section_header.dart';
import '../widgets/surface_card.dart';
import 'led_glow.dart';
import 'lighting_view_model.dart';

Color _color(RgbColor c) => Color(0xFF000000 | c.rgb);

RgbColor _rgb(Color c) => RgbColor.hex(c.toARGB32() & 0xFFFFFF);

class LightingSection extends StatelessWidget {
  const LightingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LightingViewModel>();
    const section = AppSection.lighting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        SectionHeader(title: section.label, description: section.description),
        if (vm.hasSettings)
          const AutoGrid(
            minItemWidth: 300,
            spacing: 14,
            children: [_PreviewCard(), _Controls()],
          ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.mode, required this.builder});

  final LightingMode mode;
  final Widget Function(BuildContext context, LedFrame frame) builder;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LightingViewModel>();
    final l = vm.lighting;
    return LedGlow(
      mode: mode,
      color: _color(l.color),
      stageColor: _color(vm.activeStageColor),
      brightness: l.brightness,
      speed: l.speed,
      builder: builder,
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final mode = context.select<LightingViewModel, LightingMode>((v) => v.mode);
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            spacing: 10,
            children: [
              _MousePreview(mode: mode),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Blink(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: n.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Text('Live preview · ${mode.label}', style: n.text.small),
                ],
              ),
              Text(
                'One RGB status LED on the top shell',
                style: n.text.caption.copyWith(color: n.textMuted),
              ),
            ],
          ),
          Positioned(top: -6, right: -6, child: _CloseUp(mode: mode)),
        ],
      ),
    );
  }
}

class _MousePreview extends StatelessWidget {
  const _MousePreview({required this.mode});

  final LightingMode mode;

  static const _halo = 160.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.nocturne.palette;
    const body = MouseBodyPainter.bodySize;
    const bleed = MouseBodyPainter.bleed;
    return SizedBox.fromSize(
      size: body,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -bleed,
            top: -bleed,
            width: body.width + bleed * 2,
            height: body.height + bleed * 2,
            child: CustomPaint(painter: MouseBodyPainter(palette: palette)),
          ),
          Positioned(
            left: body.width / 2 - _halo / 2,
            top: body.height * .507 - _halo / 2,
            width: _halo,
            height: _halo,
            child: IgnorePointer(
              child: _Glow(
                mode: mode,
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
                        child: _Led(
                          color: f.color,
                          width: 12,
                          height: 4,
                          glow: const [(1, 4), (2, 14)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseUp extends StatelessWidget {
  const _CloseUp({required this.mode});

  final LightingMode mode;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    return Column(
      spacing: 6,
      children: [
        Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.bg,
            shape: BoxShape.circle,
            boxShadow: p.shadowSm,
          ),
          child: _Glow(
            mode: mode,
            builder: (context, f) => Opacity(
              opacity: f.opacity,
              child: _Led(
                color: f.color,
                width: 28,
                height: 9,
                glow: const [(2, 8), (6, 26)],
              ),
            ),
          ),
        ),
        Text(
          'LED close-up',
          style: n.text.micro.copyWith(fontSize: 10.5, color: n.textMuted),
        ),
      ],
    );
  }
}

class _Led extends StatelessWidget {
  const _Led({
    required this.color,
    required this.width,
    required this.height,
    required this.glow,
  });

  final Color color;
  final double width;
  final double height;
  final List<(double spread, double blur)> glow;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(height / 2),
      boxShadow: [
        for (final (spread, blur) in glow)
          BoxShadow(color: color, spreadRadius: spread, blurRadius: blur),
      ],
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LightingViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          label: 'Lighting mode',
          container: true,
          child: AutoGrid(
            minItemWidth: 180,
            spacing: 8,
            fill: true,
            children: [
              for (final mode in LightingMode.values)
                _ModeTile(mode: mode, selected: vm.mode == mode),
            ],
          ),
        ),
        const SurfaceCard(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [_ColourControl(), _BrightnessControl(), _SpeedControl()],
          ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.selected});

  final LightingMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.read<LightingViewModel>();
    return Pressable(
      onPressed: () => vm.setMode(mode),
      selected: selected,
      semanticLabel: mode.label,
      focusRadius: n.radius.mdAll,
      builder: (context, states) => AnimatedContainer(
        duration: n.motion.medium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Color.lerp(p.surface, p.accent, .09)
              : states.contains(WidgetState.hovered)
              ? Color.lerp(p.surface, p.text, .05)
              : p.surface,
          borderRadius: n.radius.mdAll,
          border: Border.all(
            color: selected ? p.accent : p.accent.withValues(alpha: 0),
          ),
          boxShadow: p.shadowSm,
        ),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
              child: _Glow(
                mode: mode,
                builder: (context, f) => Opacity(
                  opacity: f.opacity,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: f.color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: f.color, blurRadius: 12)],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: n.text.row,
                  ),
                  Text(
                    mode.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: n.text.micro.copyWith(
                      fontSize: 11.5,
                      color: n.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.value});

  final String text;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Row(
      children: [
        Expanded(
          child: Text(text, style: n.text.caption.copyWith(color: n.textLabel)),
        ),
        if (value != null) Text(value!, style: n.text.tabular(n.text.small)),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final color = muted ? n.textMuted : n.textLabel;
    return Row(
      spacing: 6,
      children: [
        Icon(AppIcons.info, size: 13, color: color),
        Expanded(
          child: Text(text, style: n.text.caption.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _ColourControl extends StatelessWidget {
  const _ColourControl();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<LightingViewModel>();
    final note = vm.colorNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        const _Label('Colour'),
        AnimatedSwitcher(
          duration: n.motion.medium,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: vm.mode.usesColor
              ? Align(
                  key: const ValueKey('picker'),
                  alignment: Alignment.centerLeft,
                  child: ColourPicker(
                    value: _color(vm.lighting.color),
                    onChanged: (c) => vm.setColor(_rgb(c)),
                  ),
                )
              : vm.mode.usesStageColors
              ? _StageColours(key: const ValueKey('stages'), note: note!)
              : _Note(key: ValueKey(note), note!, muted: true),
        ),
      ],
    );
  }
}

class _StageColours extends StatelessWidget {
  const _StageColours({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.watch<LightingViewModel>();
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in vm.stageSwatches)
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _color(s.color),
              borderRadius: BorderRadius.circular(5),
              boxShadow: s.active
                  ? [
                      BoxShadow(color: _color(s.color), spreadRadius: 3.5),
                      BoxShadow(color: p.surface, spreadRadius: 2),
                    ]
                  : null,
            ),
          ),
        Text(
          note,
          style: n.text.caption.copyWith(
            fontSize: 12.5,
            color: n.textSecondary,
          ),
        ),
        Pressable(
          onPressed: () => context.read<ShellViewModel>().selectSection(
            AppSection.performance,
          ),
          builder: (context, states) => Text(
            'Edit stage colours',
            style: n.text.caption.copyWith(
              fontSize: 12.5,
              color: n.accent,
              decoration: states.contains(WidgetState.hovered)
                  ? TextDecoration.underline
                  : null,
              decorationColor: n.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelControl extends StatelessWidget {
  const _LevelControl({
    required this.label,
    required this.value,
    required this.note,
    required this.disabledTip,
    required this.onChanged,
    required this.pip,
    this.ends,
  });

  final String label;
  final int value;
  final String? note;
  final String disabledTip;
  final ValueChanged<int> onChanged;
  final Widget Function(BuildContext context, int index, bool filled) pip;
  final (String, String)? ends;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final enabled = note == null;
    const max = LightingSettings.maxLevel;
    Widget pips = SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 4,
        children: [
          for (var i = 0; i < max; i++)
            Expanded(
              child: Pressable(
                onPressed: enabled ? () => onChanged(i + 1) : null,
                dimWhenDisabled: false,
                tooltip: enabled ? '$label ${i + 1}' : null,
                semanticLabel: '$label ${i + 1}',
                selected: i + 1 == value,
                builder: (context, _) => pip(context, i, i < value),
              ),
            ),
        ],
      ),
    );
    final edges = ends;
    if (edges != null) {
      final style = n.text.micro.copyWith(
        color: n.textColor.withValues(alpha: .6),
      );
      pips = Row(
        spacing: 8,
        children: [
          Text(edges.$1, style: style),
          Expanded(child: pips),
          Text(edges.$2, style: style),
        ],
      );
    }
    final body = AnimatedOpacity(
      duration: n.motion.medium,
      opacity: enabled ? 1 : .38,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          _Label(label, value: '$value / $max'),
          pips,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (enabled) body else Tooltip(message: disabledTip, child: body),
        if (note != null) _Note(note!),
      ],
    );
  }
}

class _BrightnessControl extends StatelessWidget {
  const _BrightnessControl();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.watch<LightingViewModel>();
    return _LevelControl(
      label: 'Brightness',
      value: vm.lighting.brightness,
      note: vm.brightnessNote,
      disabledTip: "${vm.mode.label} doesn't use brightness",
      onChanged: vm.setBrightness,
      pip: (context, i, filled) => AnimatedContainer(
        duration: n.motion.fast,
        height: 22,
        decoration: BoxDecoration(
          color: filled
              ? p.accent.withValues(alpha: (40 + i * 8.5) / 100)
              : p.n(800),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _SpeedControl extends StatelessWidget {
  const _SpeedControl();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.watch<LightingViewModel>();
    return _LevelControl(
      label: 'Speed',
      value: vm.lighting.speed,
      note: vm.speedNote,
      disabledTip: "${vm.mode.label} isn't animated",
      onChanged: vm.setSpeed,
      ends: ('Slow', 'Fast'),
      pip: (context, i, filled) => AnimatedContainer(
        duration: n.motion.fast,
        height: 8 + i * 2,
        decoration: BoxDecoration(
          color: filled ? p.accent : p.n(800),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
