import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../domain/power_settings.dart';
import '../shell/app_section.dart';
import '../widgets/app_slider.dart';
import '../widgets/choice.dart';
import '../widgets/section_header.dart';
import 'power_view_model.dart';

class PowerSection extends StatelessWidget {
  const PowerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PowerViewModel>();
    final power = vm.power;
    final enabled = vm.canEdit;
    const section = AppSection.power;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        SectionHeader(title: section.label),
        if (vm.hasSettings) ...[
          SliderRow(
            title: 'Sleep timer',
            icon: AppIcons.moon,
            changed: vm.sleepChanged,
            slider: _MinutesSlider(
              value: power.sleepMinutes,
              semanticLabel: 'Sleep timer',
              onChanged: enabled ? vm.setSleepMinutes : null,
            ),
          ),
          SliderRow(
            title: 'LED off · deep sleep',
            icon: AppIcons.moonStars,
            changed: vm.deepSleepChanged,
            slider: _MinutesSlider(
              value: power.deepSleepMinutes,
              semanticLabel: 'LED off timer',
              onChanged: enabled ? vm.setDeepSleepMinutes : null,
            ),
          ),
          SliderRow(
            title: 'Button debounce',
            icon: AppIcons.timer,
            description:
                'Lower = faster response. Higher = fewer accidental '
                'double-clicks.',
            changed: vm.debounceChanged,
            extra: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in PowerViewModel.debouncePresets)
                  PillChip(
                    label: p.label,
                    dense: true,
                    selected: power.debounceMs == p.ms,
                    onPressed: enabled ? () => vm.setDebounceMs(p.ms) : null,
                  ),
              ],
            ),
            slider: ValueSlider(
              value: power.debounceMs.toDouble(),
              min: PowerSettings.minDebounceMs.toDouble(),
              max: PowerSettings.maxDebounceMs.toDouble(),
              step: PowerSettings.debounceStepMs.toDouble(),
              unit: 'ms',
              rangeLabels: const ['4 ms', '2 ms steps', '50 ms'],
              semanticLabel: 'Debounce',
              onChanged: enabled ? (v) => vm.setDebounceMs(v.round()) : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _MinutesSlider extends StatelessWidget {
  const _MinutesSlider({
    required this.value,
    required this.semanticLabel,
    required this.onChanged,
  });

  final int value;
  final String semanticLabel;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => ValueSlider(
    value: value.toDouble(),
    min: PowerSettings.minMinutes.toDouble(),
    max: PowerSettings.maxMinutes.toDouble(),
    unit: 'min',
    semanticLabel: semanticLabel,
    onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
  );
}
