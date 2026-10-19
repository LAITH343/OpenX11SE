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
import '../widgets/pressable.dart';
import '../widgets/section_header.dart';
import '../widgets/surface_card.dart';
import 'lighting_view_model.dart';
import 'mouse_led.dart';

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
        SectionHeader(title: section.label),
        if (vm.hasSettings) const _Controls(),
      ],
    );
  }
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
              ? n.selectedSurface
              : states.contains(WidgetState.hovered)
              ? Color.lerp(p.surface, p.text, .05)
              : p.surface,
          borderRadius: n.radius.mdAll,
          border: Border.all(
            color: selected ? n.selectedBorder : Colors.transparent,
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
              child: StagedLedGlow(
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
