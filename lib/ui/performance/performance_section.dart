import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
import 'package:provider/provider.dart';

import '../../core/formatting/number_format.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/dpi_settings.dart';
import '../../domain/polling_rate.dart';
import '../../domain/rgb_color.dart';
import '../shell/app_section.dart';
import '../shell/shell_view_model.dart';
import '../widgets/app_button.dart';
import '../widgets/app_slider.dart';
import '../widgets/auto_grid.dart';
import '../widgets/colour_picker.dart';
import '../widgets/pressable.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_control.dart';
import '../widgets/surface_card.dart';
import '../widgets/tag.dart';
import '../widgets/text_input.dart';
import '../widgets/toggle.dart';
import 'performance_view_model.dart';

Color _color(RgbColor c) => Color(0xFF000000 | c.rgb);

RgbColor _rgb(Color c) => RgbColor.hex(c.toARGB32() & 0xFFFFFF);

String _tickLabel(int dpi) {
  if (dpi < 1000) return '$dpi';
  final k = dpi / 1000;
  return '${k == k.roundToDouble() ? k.toInt() : k}k';
}

class PerformanceSection extends StatelessWidget {
  const PerformanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<PerformanceViewModel>();
    const section = AppSection.performance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        SectionHeader(
          title: section.label,
          description: section.description,
          trailing: Text(
            '${vm.enabledCount} of ${DpiSettings.stageCount} stages enabled',
            style: n.text.tabular(
              n.text.caption.copyWith(color: n.textSecondary),
            ),
          ),
        ),
        if (vm.hasSettings) ...[
          const _StageGrid(),
          const _StageEditor(),
          const AutoGrid(
            minItemWidth: 380,
            spacing: 12,
            stretch: true,
            children: [_PollingCard(), _SensorCard()],
          ),
        ],
      ],
    );
  }
}

class _StageGrid extends StatelessWidget {
  const _StageGrid();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PerformanceViewModel>();
    return Semantics(
      label: 'DPI stages',
      child: AutoGrid(
        minItemWidth: 124,
        spacing: 8,
        fill: true,
        children: [
          for (var i = 0; i < vm.stages.length; i++)
            _StageCard(
              index: i,
              stage: vm.stages[i],
              active: vm.activeIndex == i,
              selected: vm.selectedIndex == i,
              changed: vm.stageChanged(i),
              flashSerial: vm.flashStage == i ? vm.flashSerial : null,
            ),
        ],
      ),
    );
  }
}

class _StageCard extends StatefulWidget {
  const _StageCard({
    required this.index,
    required this.stage,
    required this.active,
    required this.selected,
    required this.changed,
    required this.flashSerial,
  });

  final int index;
  final DpiStage stage;
  final bool active;
  final bool selected;
  final bool changed;
  final int? flashSerial;

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _StageCard old) {
    super.didUpdateWidget(old);
    final serial = widget.flashSerial;
    if (serial != null && serial != old.flashSerial) {
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.read<PerformanceViewModel>();
    final stage = widget.stage;
    final on = stage.enabled;
    final color = on ? _color(stage.color) : p.n(700);
    return Pressable(
      onPressed: () => vm.selectStage(widget.index),
      selected: widget.selected,
      semanticLabel: 'Stage ${widget.index + 1}',
      focusRadius: n.radius.mdAll,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return Transform.translate(
          offset: Offset(0, hovered ? -1 : 0),
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, child) {
              final t = Curves.easeOut.transform(_flash.value);
              final flashing = _flash.isAnimating;
              return AnimatedContainer(
                duration: n.motion.medium,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? Color.lerp(p.surface, p.accent, 0.09)
                      : p.surface,
                  borderRadius: n.radius.mdAll,
                  boxShadow: flashing
                      ? [
                          BoxShadow(
                            color: p.accent.withValues(alpha: 0.7 * (1 - t)),
                            blurRadius: 28 * (1 - t),
                          ),
                          BoxShadow(color: p.accent, spreadRadius: 2 - t),
                        ]
                      : widget.selected
                      ? [BoxShadow(color: p.accent, spreadRadius: 1)]
                      : p.shadowSm,
                ),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: n.radius.mdAll,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(11, 11, 11, 14),
                    child: _cardBody(context, vm, color),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: on ? (widget.active ? 1 : 0.35) : 0,
                      child: Container(height: 2, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cardBody(BuildContext context, PerformanceViewModel vm, Color color) {
    final n = context.nocturne;
    final p = n.palette;
    final stage = widget.stage;
    final on = stage.enabled;
    final opacity = on ? 1.0 : 0.42;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          children: [
            Text(
              'STAGE ${widget.index + 1}',
              maxLines: 1,
              softWrap: false,
              style: n.text.kicker.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.735,
                color: n.textSecondary,
              ),
            ),
            if (widget.changed) ...[
              const SizedBox(width: 6),
              const Tooltip(
                message: 'Changed — not applied yet',
                child: ChangedDot(size: 5),
              ),
            ],
            const Spacer(),
            AppSwitch(
              value: on,
              small: true,
              tooltip: on ? 'Disable stage' : 'Enable stage',
              semanticLabel: 'Stage ${widget.index + 1} enabled',
              onChanged: (_) => vm.toggleStage(widget.index),
            ),
          ],
        ),
        AnimatedOpacity(
          duration: n.motion.medium,
          opacity: opacity,
          child: Text(formatThousands(stage.dpi), style: n.text.valueMedium),
        ),
        AnimatedOpacity(
          duration: n.motion.medium,
          opacity: opacity,
          child: Row(
            spacing: 7,
            children: [
              _StageRadio(
                active: widget.active,
                onPressed: on ? () => vm.setActive(widget.index) : null,
              ),
              Text(
                widget.active
                    ? 'Active'
                    : on
                    ? ''
                    : 'Off',
                style: n.text.micro.copyWith(
                  color: widget.active ? p.a(300) : n.textSecondary,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: n.motion.medium,
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: n.radius.smAll,
                  boxShadow: on
                      ? [BoxShadow(color: color, blurRadius: 10)]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StageRadio extends StatelessWidget {
  const _StageRadio({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    return Pressable(
      onPressed: onPressed,
      selected: active,
      tooltip: 'Make this the active stage',
      dimWhenDisabled: false,
      focusRadius: n.radius.pillAll,
      builder: (context, _) => AnimatedContainer(
        duration: n.motion.medium,
        width: 14,
        height: 14,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: active ? p.accent : p.n(600), width: 1.5),
        ),
        child: AnimatedContainer(
          duration: n.motion.medium,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? p.accent : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _StageEditor extends StatelessWidget {
  const _StageEditor();

  @override
  Widget build(BuildContext context) => const SurfaceCard(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    child: AutoGrid(
      minItemWidth: 300,
      spacing: 32,
      runSpacing: 20,
      children: [_DpiEditor(), _StageColour()],
    ),
  );
}

class _DpiEditor extends StatelessWidget {
  const _DpiEditor();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.watch<PerformanceViewModel>();
    final index = vm.selectedIndex;
    final stage = vm.selectedStage!;
    final color = _color(stage.color);
    final active = vm.activeIndex == index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AnimatedContainer(
              duration: n.motion.medium,
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: color, blurRadius: 10)],
              ),
            ),
            Text('Stage ${index + 1}', style: n.text.heading),
            if (active) const Tag(label: 'Active'),
            if (!stage.enabled)
              const Tag(label: 'Disabled', variant: TagVariant.neutral),
            if (stage.enabled && !active)
              AppButton.ghost(
                label: 'Set as active',
                icon: AppIcons.radioButton,
                size: AppButtonSize.small,
                onPressed: () => vm.setActive(index),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(
                  'Enabled',
                  style: n.text.caption.copyWith(color: n.textLabel),
                ),
                AppSwitch(
                  value: stage.enabled,
                  semanticLabel: 'Stage ${index + 1} enabled',
                  onChanged: (_) => vm.toggleStage(index),
                ),
              ],
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppIconButton(
              icon: AppIcons.minus,
              tooltip: 'Previous valid value',
              size: 44,
              onPressed: () => vm.stepDpi(index, -1),
            ),
            _DpiField(stageIndex: index, dpi: stage.dpi),
            AppIconButton(
              icon: AppIcons.plus,
              tooltip: 'Next valid value',
              size: 44,
              onPressed: () => vm.stepDpi(index, 1),
            ),
            if (vm.snapNote != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 5,
                children: [
                  Icon(AppIcons.magnet, size: 13, color: p.a(300)),
                  Text(
                    vm.snapNote!,
                    style: n.text.caption.copyWith(color: p.a(300)),
                  ),
                ],
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              AppSlider(
                value: PerformanceViewModel.dpiToSliderValue(
                  stage.dpi,
                ).toDouble(),
                min: 1,
                max: 340,
                large: true,
                gradient: true,
                semanticLabel: 'DPI',
                seams: [
                  PerformanceViewModel.sliderFraction(
                    PerformanceViewModel.highRangeStart,
                  ),
                ],
                onChanged: (v) => vm.setDpi(
                  index,
                  PerformanceViewModel.sliderValueToDpi(v.round()),
                ),
              ),
              const _DpiTicks(),
              Text(
                'Steps of 50 up to 10,000, then steps of 100. Arrow keys move '
                'one step; typed values snap.',
                style: n.text.caption.copyWith(color: n.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DpiTicks extends StatelessWidget {
  const _DpiTicks();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final style = n.text.tabular(
      n.text.micro.copyWith(fontSize: 10.5, color: n.textMuted),
    );
    const ticks = PerformanceViewModel.dpiTicks;
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (var k = 0; k < ticks.length; k++)
              Positioned(
                left:
                    PerformanceViewModel.sliderFraction(ticks[k]) * c.maxWidth,
                top: 0,
                child: FractionalTranslation(
                  translation: Offset(
                    k == 0
                        ? 0
                        : k == ticks.length - 1
                        ? -1
                        : -0.5,
                    0,
                  ),
                  child: Text(_tickLabel(ticks[k]), style: style),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DpiField extends StatefulWidget {
  const _DpiField({required this.stageIndex, required this.dpi});

  final int stageIndex;
  final int dpi;

  @override
  State<_DpiField> createState() => _DpiFieldState();
}

class _DpiFieldState extends State<_DpiField> {
  late final TextEditingController _text = TextEditingController(
    text: formatThousands(widget.dpi),
  );
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _DpiField old) {
    super.didUpdateWidget(old);
    if (old.stageIndex != widget.stageIndex ||
        (old.dpi != widget.dpi && !_focus.hasFocus)) {
      _reset();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reset() => _text.text = formatThousands(widget.dpi);

  void _commit() {
    context.read<PerformanceViewModel>().commitDpiText(_text.text);
    _reset();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => 1,
      LogicalKeyboardKey.arrowDown => -1,
      _ => 0,
    };
    if (direction == 0) return KeyEventResult.ignored;
    final vm = context.read<PerformanceViewModel>()
      ..commitDpiText(_text.text)
      ..stepDpi(widget.stageIndex, direction);
    _text.text = formatThousands(vm.stages[widget.stageIndex].dpi);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return SizedBox(
      width: 150,
      height: 44,
      child: TextInput(
        controller: _text,
        focusNode: _focus,
        semanticLabel: 'DPI value',
        textAlign: TextAlign.right,
        suffixText: 'DPI',
        style: n.text.tabular(
          const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9,]'))],
        maxLength: 6,
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}

class _StageColour extends StatelessWidget {
  const _StageColour();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<PerformanceViewModel>();
    final index = vm.selectedIndex;
    final stage = vm.selectedStage!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(
          'Stage colour',
          style: n.text.caption.copyWith(color: n.textLabel),
        ),
        ColourPicker(
          value: _color(stage.color),
          onChanged: (c) => vm.setColor(index, _rgb(c)),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Shown on the mouse in Static DPI and Breathing DPI lighting. ',
              style: n.text.caption.copyWith(color: n.textSecondary),
            ),
            Pressable(
              onPressed: () => context.read<ShellViewModel>().selectSection(
                AppSection.lighting,
              ),
              builder: (context, states) => Text(
                'Lighting',
                style: n.text.caption.copyWith(
                  color: n.accent,
                  decoration: states.contains(WidgetState.hovered)
                      ? TextDecoration.underline
                      : null,
                  decorationColor: n.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PollingCard extends StatelessWidget {
  const _PollingCard();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<PerformanceViewModel>();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          CardHeading(
            title: 'Polling rate',
            icon: AppIcons.pulse,
            changed: vm.pollingChanged,
          ),
          SegmentedControl<PollingRate>(
            tabular: true,
            selected: vm.polling,
            onChanged: vm.setPolling,
            options: [
              for (final rate in PollingRate.values)
                SegmentOption(value: rate, label: '${rate.hz} Hz'),
            ],
          ),
          Text(
            '${1000 ~/ vm.polling.hz} ms between reports. Higher is smoother '
            'but uses more battery.',
            style: n.text.caption.copyWith(color: n.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PerformanceViewModel>();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const CardHeading(title: 'Sensor', icon: AppIcons.crosshair),
          ToggleRow(
            title: 'Angle snap',
            description: 'Straightens slightly wobbly movement lines.',
            value: vm.angleSnap,
            changed: vm.angleSnapChanged,
            onChanged: vm.setAngleSnap,
          ),
          ToggleRow(
            title: 'Ripple control',
            description: 'Smooths sensor jitter at high DPI.',
            value: vm.ripple,
            changed: vm.rippleChanged,
            onChanged: vm.setRipple,
          ),
        ],
      ),
    );
  }
}
