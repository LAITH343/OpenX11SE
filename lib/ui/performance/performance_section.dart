import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
import 'package:provider/provider.dart';

import '../../core/formatting/number_format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/dpi_settings.dart';
import '../../domain/polling_rate.dart';
import '../../domain/rgb_color.dart';
import '../shell/app_section.dart';
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
          trailing: Text(
            tr('${vm.enabledCount} of ${DpiSettings.stageCount} enabled'),
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
    final n = context.nocturne;
    final vm = context.watch<PerformanceViewModel>();
    return Semantics(
      label: 'DPI stages',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: n.surface,
          borderRadius: n.radius.lgAll,
          boxShadow: n.palette.shadowSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            for (var i = 0; i < vm.stages.length; i++)
              Expanded(
                child: _StageColumn(
                  index: i,
                  stage: vm.stages[i],
                  active: vm.activeIndex == i,
                  selected: vm.selectedIndex == i,
                  changed: vm.stageChanged(i),
                  flashSerial: vm.flashStage == i ? vm.flashSerial : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageColumn extends StatefulWidget {
  const _StageColumn({
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
  State<_StageColumn> createState() => _StageColumnState();
}

class _StageColumnState extends State<_StageColumn>
    with SingleTickerProviderStateMixin {
  static const _barHeight = 150.0;

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _StageColumn old) {
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

  static double _fill(int dpi) =>
      (12 + math.log(dpi / 50) / math.log(480) * 88).clamp(0, 100) / 100;

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
        return AnimatedBuilder(
          animation: _flash,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_flash.value);
            final flashing = _flash.isAnimating;
            return AnimatedContainer(
              duration: n.motion.medium,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: widget.selected
                    ? p.accent.withValues(alpha: 0.10)
                    : hovered
                    ? p.text.withValues(alpha: 0.04)
                    : p.text.withValues(alpha: 0),
                borderRadius: n.radius.mdAll,
                border: Border.all(
                  color: widget.selected
                      ? p.accent
                      : p.accent.withValues(alpha: 0),
                ),
                boxShadow: flashing
                    ? [
                        BoxShadow(
                          color: p.accent.withValues(alpha: 0.7 * (1 - t)),
                          blurRadius: 28 * (1 - t),
                        ),
                        BoxShadow(color: p.accent, spreadRadius: 2 - t),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                spacing: 5,
                children: [
                  Text(
                    tr('S${widget.index + 1}'),
                    maxLines: 1,
                    softWrap: false,
                    style: n.text.kicker.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 0.84,
                      color: n.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: widget.active
                        ? Text(
                            tr('ACTIVE'),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            textAlign: TextAlign.end,
                            style: n.text.kicker.copyWith(
                              fontSize: 9.5,
                              letterSpacing: 0.95,
                              color: p.a(300),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (widget.changed)
                    Tooltip(
                      message: tr('Changed — not applied yet'),
                      child: const ChangedDot(size: 5),
                    ),
                ],
              ),
              AnimatedOpacity(
                duration: n.motion.medium,
                opacity: on ? 1 : 0.42,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr(formatThousands(stage.dpi)),
                    maxLines: 1,
                    style: n.text.tabular(
                      n.text.subheading.copyWith(height: 1.2),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: n.motion.medium,
                opacity: on ? 1 : 0.42,
                child: Container(
                  height: _barHeight,
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    color: p.n(900),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: widget.active ? 1 : 0.55,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: n.motion.knobCurve,
                      height: _barHeight * _fill(stage.dpi),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color.alphaBlend(
                              color.withValues(alpha: 0.10),
                              p.n(900),
                            ),
                            Color.alphaBlend(
                              color.withValues(alpha: 0.42),
                              p.n(900),
                            ),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.active
                                ? color
                                : color.withValues(alpha: 0),
                            offset: const Offset(0, -6),
                            blurRadius: 22,
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.antiAlias,
                      child: Container(height: 2, color: color),
                    ),
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 6,
                children: [
                  _StageRadio(
                    active: widget.active,
                    onPressed: on ? () => vm.setActive(widget.index) : null,
                  ),
                  AppSwitch(
                    value: on,
                    small: true,
                    tooltip: on ? 'Disable stage' : 'Enable stage',
                    semanticLabel: 'Stage ${widget.index + 1} enabled',
                    onChanged: (_) => vm.toggleStage(widget.index),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
            Text(tr('Stage ${index + 1}'), style: n.text.heading),
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
                  tr('Enabled'),
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
                    tr(vm.snapNote!),
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
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
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
                  child: Text(tr(_tickLabel(ticks[k])), style: style),
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
          tr('Stage colour'),
          style: n.text.caption.copyWith(color: n.textLabel),
        ),
        ColourPicker(
          value: _color(stage.color),
          onChanged: (c) => vm.setColor(index, _rgb(c)),
        ),
      ],
    );
  }
}

class _PollingCard extends StatelessWidget {
  const _PollingCard();

  @override
  Widget build(BuildContext context) {
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
            value: vm.angleSnap,
            changed: vm.angleSnapChanged,
            onChanged: vm.setAngleSnap,
          ),
          ToggleRow(
            title: 'Ripple control',
            value: vm.ripple,
            changed: vm.rippleChanged,
            onChanged: vm.setRipple,
          ),
        ],
      ),
    );
  }
}
