import 'package:flutter/widgets.dart';

import '../../core/theme/app_icons.dart';
import '../../domain/button_assignment.dart';
import '../../domain/keyboard_keys.dart';
import '../../domain/macro.dart';

extension ButtonFunctionGroupInfo on ButtonFunctionGroup {
  String get label => switch (this) {
    ButtonFunctionGroup.mouse => 'Mouse',
    ButtonFunctionGroup.dpi => 'DPI',
    ButtonFunctionGroup.profile => 'Profile',
    ButtonFunctionGroup.lighting => 'Lighting',
    ButtonFunctionGroup.media => 'Media',
    ButtonFunctionGroup.browser => 'Browser & apps',
    ButtonFunctionGroup.shortcuts => 'Shortcuts',
    ButtonFunctionGroup.keyboard => 'Keyboard',
    ButtonFunctionGroup.macro => 'Macro',
  };

  IconData get icon => switch (this) {
    ButtonFunctionGroup.mouse => AppIcons.mouseSimple,
    ButtonFunctionGroup.dpi => AppIcons.gauge,
    ButtonFunctionGroup.profile => AppIcons.userSwitch,
    ButtonFunctionGroup.lighting => AppIcons.lightbulb,
    ButtonFunctionGroup.media => AppIcons.musicNotes,
    ButtonFunctionGroup.browser => AppIcons.globe,
    ButtonFunctionGroup.shortcuts => AppIcons.command,
    ButtonFunctionGroup.keyboard => AppIcons.keyboard,
    ButtonFunctionGroup.macro => AppIcons.record,
  };

  bool get isListed =>
      this != ButtonFunctionGroup.keyboard && this != ButtonFunctionGroup.macro;
}

class FunctionItem {
  const FunctionItem({
    required this.label,
    required this.group,
    required this.assignment,
    this.hint = '',
  });

  final String label;
  final String hint;
  final ButtonFunctionGroup group;
  final ButtonAssignment assignment;
}

const disabledLabel = 'Disabled';

const _functionHints = {
  ButtonFunction.fireButton: 'Rapid fire',
  ButtonFunction.easyAim: 'Low DPI while held',
};

FunctionItem _functionItem(ButtonFunction f) => FunctionItem(
  label: f.label,
  group: f.group,
  assignment: FunctionButton(f),
  hint: _functionHints[f] ?? '',
);

FunctionItem _shortcutItem(ButtonShortcut s) => FunctionItem(
  label: s.label,
  group: s.group,
  assignment: s.key,
  hint: keyComboLabel(s.key),
);

final Map<ButtonFunctionGroup, List<FunctionItem>> functionItems = {
  for (final group in ButtonFunctionGroup.values) group: _itemsFor(group),
};

List<FunctionItem> _itemsFor(ButtonFunctionGroup group) {
  final items = <FunctionItem>[
    for (final f in ButtonFunction.values)
      if (f.group == group) _functionItem(f),
  ];
  final shortcuts = [
    for (final s in buttonShortcuts)
      if (s.group == group) _shortcutItem(s),
  ];
  if (group == ButtonFunctionGroup.browser) {
    final at =
        items.indexWhere(
          (i) =>
              i.assignment ==
              const FunctionButton(ButtonFunction.browserSearch),
        ) +
        1;
    items.insertAll(at, shortcuts);
  } else {
    items.addAll(shortcuts);
  }
  if (group == ButtonFunctionGroup.mouse) {
    items.add(
      const FunctionItem(
        label: 'Disable button',
        group: ButtonFunctionGroup.mouse,
        assignment: DisabledButton(),
        hint: 'Does nothing',
      ),
    );
  }
  return List.unmodifiable(items);
}

List<FunctionItem> searchFunctions(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return [
    for (final group in ButtonFunctionGroup.values)
      for (final item in functionItems[group]!)
        if ('${item.label} ${item.hint} ${group.label}'.toLowerCase().contains(
          q,
        ))
          FunctionItem(
            label: item.label,
            group: item.group,
            assignment: item.assignment,
            hint: item.hint.isEmpty
                ? group.label
                : '${group.label} · ${item.hint}',
          ),
  ];
}

ButtonShortcut? shortcutFor(KeyButton key) {
  for (final s in buttonShortcuts) {
    if (s.key == key) return s;
  }
  return null;
}

ButtonFunctionGroup groupOf(ButtonAssignment assignment) =>
    switch (assignment) {
      DisabledButton() || UnmappedButton() => ButtonFunctionGroup.mouse,
      FunctionButton(:final function) => function.group,
      KeyButton() =>
        shortcutFor(assignment)?.group ?? ButtonFunctionGroup.keyboard,
      MacroButton() => ButtonFunctionGroup.macro,
    };

IconData assignmentIcon(ButtonAssignment assignment) => switch (assignment) {
  UnmappedButton() => AppIcons.mouseSimple,
  _ => groupOf(assignment).icon,
};

String playbackLabel(MacroPlayback playback) => switch (playback.mode) {
  MacroPlaybackMode.untilKey => 'until key',
  MacroPlaybackMode.whileHeld => 'while held',
  MacroPlaybackMode.once =>
    playback.loopCount > 1 ? '×${playback.loopCount}' : 'once',
};

String describeAssignment(
  ButtonAssignment assignment, {
  String? Function(int id)? macroName,
}) => switch (assignment) {
  DisabledButton() => disabledLabel,
  FunctionButton(:final function) => function.label,
  KeyButton() => shortcutFor(assignment)?.label ?? keyComboLabel(assignment),
  MacroButton(:final macroId, :final playback) => switch (macroId == null
      ? null
      : macroName?.call(macroId)) {
    final String name => 'Macro: $name · ${playbackLabel(playback)}',
    null => 'Macro stored on the mouse',
  },
  UnmappedButton(:final b0, :final b1, :final b2) =>
    'Vendor code ${[b0, b1, b2].map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}',
};
