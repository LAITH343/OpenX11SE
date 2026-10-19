import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/macro.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/choice.dart';
import '../widgets/motion.dart';
import '../widgets/number_field.dart';
import '../widgets/segmented_control.dart';
import 'macro_library_view_model.dart';

class MacroAssignLayer extends StatelessWidget {
  const MacroAssignLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final open = context.select<MacroLibraryViewModel, bool>(
      (vm) => vm.assign != null && vm.editor != null,
    );
    if (!open) return const SizedBox.shrink();
    final vm = context.read<MacroLibraryViewModel>();
    return Positioned.fill(
      child: EntranceTransition(
        kind: Entrance.fade,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: vm.closeAssign,
                child: ColoredBox(color: context.nocturne.backdrop),
              ),
            ),
            const EntranceTransition(
              kind: Entrance.pop,
              duration: Duration(milliseconds: 200),
              child: _AssignDialog(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignDialog extends StatelessWidget {
  const _AssignDialog();

  static String _modeLabel(MacroPlaybackMode mode) => switch (mode) {
    MacroPlaybackMode.once => 'Play a set number of times',
    MacroPlaybackMode.untilKey => 'Repeat until any key is pressed',
    MacroPlaybackMode.whileHeld => 'Repeat while held — stops on release',
  };

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<MacroLibraryViewModel>();
    final assign = vm.assign;
    final editor = vm.editor;
    if (assign == null || editor == null) return const SizedBox.shrink();
    final label = n.text.caption.copyWith(color: n.textLabel);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Assign macro',
      child: AppDialog(
        title: 'Assign “${editor.original.name}”',
        width: 480,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Text(tr('Button'), style: label),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedControl<int>(
                options: [
                  for (final b in MacroLibraryViewModel.assignableButtons)
                    SegmentOption(
                      value: b.slot,
                      label: b.name,
                      tooltip: 'Now: ${vm.currentLabel(b.slot)}',
                    ),
                ],
                selected: assign.slot,
                onChanged: vm.setAssignSlot,
              ),
            ),
            Text(
              tr('Replaces ${vm.currentLabel(assign.slot)}'),
              style: n.text.caption.copyWith(color: n.textSecondary),
            ),
            if (vm.assignLeftWarning)
              Row(
                spacing: 6,
                children: [
                  Icon(AppIcons.warning, size: 14, color: n.palette.warning),
                  Expanded(
                    child: Text(
                      tr(
                        "No other button is Left click — you'd lose the ability "
                        'to click.',
                      ),
                      style: n.text.caption.copyWith(color: n.palette.warning),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr('Playback'), style: label),
            ),
            for (final mode in MacroPlaybackMode.values)
              Row(
                spacing: 10,
                children: [
                  AppRadio<MacroPlaybackMode>(
                    value: mode,
                    groupValue: assign.playback.mode,
                    onChanged: vm.setAssignMode,
                    label: Text(tr(_modeLabel(mode))),
                  ),
                  if (mode == MacroPlaybackMode.once) ...[
                    NumberField(
                      value: assign.playback.loopCount,
                      width: 72,
                      min: MacroPlayback.minLoopCount,
                      max: MacroPlayback.maxLoopCount,
                      semanticLabel: 'Times',
                      onChanged: vm.setAssignLoopCount,
                    ),
                    Text(
                      tr('times'),
                      style: n.text.caption.copyWith(
                        color: n.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
        actions: [
          AppButton(label: 'Cancel', onPressed: vm.closeAssign),
          AppButton.primary(
            label: 'Assign',
            icon: AppIcons.check,
            onPressed: vm.confirmAssign,
          ),
        ],
      ),
    );
  }
}
