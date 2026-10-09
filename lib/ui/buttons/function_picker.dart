import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_palette.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/button_assignment.dart';
import '../../domain/keyboard_keys.dart';
import '../../domain/macro.dart';
import '../shell/app_section.dart';
import '../shell/shell_view_model.dart';
import '../widgets/app_button.dart';
import '../widgets/choice.dart';
import '../widgets/dashed_border.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/text_input.dart';
import 'buttons_view_model.dart';
import 'function_catalog.dart';
import 'function_picker_view_model.dart';

class FunctionPickerLayer extends StatelessWidget {
  const FunctionPickerLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final picker = context.select<ButtonsViewModel, FunctionPickerViewModel?>(
      (b) => b.picker,
    );
    if (picker == null) return const SizedBox.shrink();
    final buttons = context.read<ButtonsViewModel>();
    final n = context.nocturne;
    return Positioned.fill(
      child: EntranceTransition(
        kind: Entrance.fade,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: buttons.closePicker,
                child: ColoredBox(color: n.backdrop),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: EntranceTransition(
                  kind: Entrance.pop,
                  duration: const Duration(milliseconds: 220),
                  child: ChangeNotifierProvider.value(
                    key: ObjectKey(picker),
                    value: picker,
                    child: const _PickerDialog(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerDialog extends StatelessWidget {
  const _PickerDialog();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    return LayoutBuilder(
      builder: (context, c) => Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Function picker',
        child: Container(
          width: math.min(800, c.maxWidth),
          height: math.min(580, c.maxHeight),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: n.radius.lgAll,
            boxShadow: p.shadowLg,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PickerHeader(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GroupList(),
                    Expanded(child: _PickerBody()),
                  ],
                ),
              ),
              _PickerFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatefulWidget {
  const _PickerHeader();

  @override
  State<_PickerHeader> createState() => _PickerHeaderState();
}

class _PickerHeaderState extends State<_PickerHeader> {
  late final _search = TextEditingController(
    text: context.read<FunctionPickerViewModel>().search,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.watch<FunctionPickerViewModel>();
    if (vm.search != _search.text) _search.text = vm.search;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${vm.number}',
              style: n.text.caption.copyWith(
                color: p.bg,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Assign a function to',
                  style: n.text.micro.copyWith(
                    fontSize: 11.5,
                    color: n.textColor.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  vm.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: n.text.heading.copyWith(height: 1.3),
                ),
              ],
            ),
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: TextInput(
                controller: _search,
                autofocus: true,
                hint: 'Search all functions',
                prefixIcon: AppIcons.magnifyingGlass,
                semanticLabel: 'Search functions',
                onChanged: vm.setSearch,
              ),
            ),
          ),
          AppIconButton(
            icon: AppIcons.x,
            tooltip: 'Close (Esc)',
            variant: AppButtonVariant.ghost,
            neutralForeground: true,
            onPressed: context.read<ButtonsViewModel>().closePicker,
          ),
        ],
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.watch<FunctionPickerViewModel>();
    return Container(
      width: 184,
      color: mix(p.bg, p.surface, 0.4),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (final group in ButtonFunctionGroup.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _GroupTile(
                group: group,
                active: !vm.searching && vm.group == group,
                onPressed: () => vm.selectGroup(group),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.active,
    required this.onPressed,
  });

  final ButtonFunctionGroup group;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    return Pressable(
      onPressed: onPressed,
      selected: active,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final fg = active || hovered
            ? p.text
            : n.textColor.withValues(alpha: 0.64);
        return AnimatedContainer(
          duration: n.motion.fast,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? p.a(900) : Colors.transparent,
            borderRadius: n.radius.mdAll,
          ),
          child: Row(
            spacing: 10,
            children: [
              Icon(group.icon, size: 16, color: active ? p.accent : fg),
              Expanded(
                child: Text(
                  group.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: n.text.small.copyWith(color: fg),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickerBody extends StatelessWidget {
  const _PickerBody();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<FunctionPickerViewModel>();
    final Widget content;
    if (vm.noResults) {
      content = Text(
        'No functions match. For any other key, use the Keyboard group.',
        style: n.text.small.copyWith(color: n.textColor.withValues(alpha: 0.6)),
      );
    } else if (vm.showKeyboard) {
      content = const _KeyboardPane();
    } else if (vm.showMacro) {
      content = const _MacroPane();
    } else {
      content = _FunctionGrid(items: vm.items);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: EntranceTransition(
        key: ValueKey((vm.searching, vm.group, vm.noResults)),
        kind: Entrance.fade,
        duration: const Duration(milliseconds: 150),
        child: content,
      ),
    );
  }
}

class _FunctionGrid extends StatelessWidget {
  const _FunctionGrid({required this.items});

  final List<FunctionItem> items;

  static const _minWidth = 160.0;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = math.max(
        1,
        ((c.maxWidth + _gap) / (_minWidth + _gap)).floor(),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _gap,
        children: [
          for (var i = 0; i < items.length; i += columns)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _gap,
                children: [
                  for (var k = i; k < i + columns; k++)
                    Expanded(
                      child: k < items.length
                          ? _FunctionTile(item: items[k])
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _FunctionTile extends StatefulWidget {
  const _FunctionTile({required this.item});

  final FunctionItem item;

  @override
  State<_FunctionTile> createState() => _FunctionTileState();
}

class _FunctionTileState extends State<_FunctionTile> {
  static const _doubleTap = Duration(milliseconds: 400);
  DateTime? _lastTap;

  void _onPressed() {
    final vm = context.read<FunctionPickerViewModel>();
    final now = DateTime.now();
    final last = _lastTap;
    _lastTap = now;
    vm.pick(widget.item);
    if (last != null && now.difference(last) < _doubleTap) vm.assign();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final selected = context.select<FunctionPickerViewModel, bool>(
      (vm) => vm.isSelected(widget.item),
    );
    final item = widget.item;
    return Pressable(
      onPressed: _onPressed,
      selected: selected,
      tooltip: 'Double-click to assign',
      semanticLabel: item.label,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? p.a(900) : Colors.transparent,
            borderRadius: n.radius.mdAll,
            border: Border.all(
              color: selected
                  ? p.accent
                  : hovered
                  ? n.textColor.withValues(alpha: 0.4)
                  : n.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(item.label, style: n.text.small),
              if (item.hint.isNotEmpty)
                Text(
                  item.hint,
                  style: n.text.micro.copyWith(
                    color: n.textColor.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _KeyboardPane extends StatelessWidget {
  const _KeyboardPane();

  static const _modifiers = [
    ('Ctrl', KeyModifiers(ctrl: true)),
    ('Shift', KeyModifiers(shift: true)),
    ('Alt', KeyModifiers(alt: true)),
    ('Win', KeyModifiers(win: true)),
  ];

  static bool _has(KeyModifiers set, KeyModifiers one) =>
      (one.ctrl && set.ctrl) ||
      (one.shift && set.shift) ||
      (one.alt && set.alt) ||
      (one.win && set.win);

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<FunctionPickerViewModel>();
    final label = n.text.caption.copyWith(color: n.textLabel);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text('Key', style: label),
          const _KeyCapture(),
          Text('Modifiers', style: label),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (name, mod) in _modifiers)
                PillChip(
                  label: name,
                  selected: _has(vm.modifiers, mod),
                  onPressed: () => vm.toggleModifier(mod),
                ),
              if (vm.capturedKey != null)
                AppButton.ghost(
                  label: 'Clear',
                  neutralForeground: true,
                  size: AppButtonSize.small,
                  onPressed: vm.clearKey,
                ),
            ],
          ),
          Text(
            'Tip: hold modifiers while pressing the key to capture the whole '
            'combo.',
            style: n.text.caption.copyWith(
              color: n.textColor.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyCapture extends StatefulWidget {
  const _KeyCapture();

  @override
  State<_KeyCapture> createState() => _KeyCaptureState();
}

class _KeyCaptureState extends State<_KeyCapture> {
  final _focus = FocusNode(debugLabel: 'key capture');
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.handled;
    final usage = event.physicalKey.usbHidUsage;
    if (usage >> 16 != HidUsage.page) return KeyEventResult.handled;
    final keyboard = HardwareKeyboard.instance;
    context.read<FunctionPickerViewModel>().captureKey(
      usage & 0xFFFF,
      held: KeyModifiers(
        ctrl: keyboard.isControlPressed,
        shift: keyboard.isShiftPressed,
        alt: keyboard.isAltPressed,
        win: keyboard.isMetaPressed,
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final key = context.select<FunctionPickerViewModel, String?>(
      (vm) => vm.capturedKeyLabel,
    );
    final prompt = Text(
      _focused ? 'Press any key…' : 'Click here, then press a key',
      style: n.text.body.copyWith(color: n.textColor.withValues(alpha: 0.6)),
    );
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      onFocusChange: (v) => setState(() => _focused = v),
      child: Semantics(
        textField: true,
        label: 'Press a key to capture',
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: GestureDetector(
            onTap: _focus.requestFocus,
            child: DashedBorder(
              color: _focused ? p.accent : p.n(600),
              radius: n.radius.mdAll,
              child: Container(
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: n.bg,
                  borderRadius: n.radius.mdAll,
                ),
                child: key != null
                    ? EntranceTransition(
                        key: ValueKey(key),
                        kind: Entrance.pop,
                        duration: const Duration(milliseconds: 150),
                        child: _KeyCap(label: key),
                      )
                    : _focused
                    ? Blink(child: prompt)
                    : prompt,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(minWidth: 44),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: n.radius.mdAll,
          boxShadow: [
            BoxShadow(color: p.n(800), offset: const Offset(0, 3)),
            BoxShadow(color: p.n(600), spreadRadius: 1),
          ],
        ),
        child: Text(label, style: n.text.heading.copyWith(height: 1)),
      ),
    );
  }
}

class _MacroPane extends StatelessWidget {
  const _MacroPane();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<FunctionPickerViewModel>();
    final label = n.text.caption.copyWith(color: n.textLabel);
    final muted = n.textColor.withValues(alpha: 0.7);
    if (!vm.macroAllowed) {
      return Row(
        spacing: 8,
        children: [
          Icon(AppIcons.info, size: 16, color: muted),
          Expanded(
            child: Text(
              'Macros can only be assigned to Left, Right, Middle, Forward and '
              'Back.',
              style: n.text.small.copyWith(color: muted),
            ),
          ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text('Macro', style: label),
          if (vm.macros.isEmpty)
            Text(
              'No macros yet. Record one in the Macros section, then assign it '
              'here.',
              style: n.text.small.copyWith(color: muted),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                for (final m in vm.macros)
                  AppRadio<int?>(
                    value: m.id,
                    groupValue: vm.macroId,
                    filled: true,
                    onChanged: (id) => vm.selectMacro(id!),
                    label: Text(m.name),
                    trailing: Text(
                      '${FunctionPickerViewModel.macroSteps(m)} steps',
                      style: n.text.micro.copyWith(
                        fontSize: 11.5,
                        color: n.textColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
              ],
            ),
          if (vm.macros.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Playback', style: label),
            ),
            for (final mode in MacroPlaybackMode.values)
              Row(
                spacing: 10,
                children: [
                  AppRadio<MacroPlaybackMode>(
                    value: mode,
                    groupValue: vm.mode,
                    onChanged: vm.setMode,
                    label: Text(_modeLabel(mode)),
                  ),
                  if (mode == MacroPlaybackMode.once) ...[
                    _LoopCountField(count: vm.loopCount),
                    Text(
                      'times',
                      style: n.text.caption.copyWith(
                        color: n.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onPressed: () {
                context.read<ButtonsViewModel>().closePicker();
                context.read<ShellViewModel>().selectSection(AppSection.macros);
              },
              builder: (context, states) => Text(
                'Create or edit macros',
                style: n.text.caption.copyWith(
                  fontSize: 12.5,
                  color: n.palette.a(300),
                  decoration: states.contains(WidgetState.hovered)
                      ? TextDecoration.underline
                      : null,
                  decorationColor: n.palette.a(300),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _modeLabel(MacroPlaybackMode mode) => switch (mode) {
    MacroPlaybackMode.once => 'Play a set number of times',
    MacroPlaybackMode.untilKey => 'Repeat until any key is pressed',
    MacroPlaybackMode.whileHeld => 'Repeat while held — stops on release',
  };
}

class _LoopCountField extends StatefulWidget {
  const _LoopCountField({required this.count});

  final int count;

  @override
  State<_LoopCountField> createState() => _LoopCountFieldState();
}

class _LoopCountFieldState extends State<_LoopCountField> {
  late final _text = TextEditingController(text: '${widget.count}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _text.text = '${widget.count}';
    });
  }

  @override
  void didUpdateWidget(covariant _LoopCountField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.count != widget.count) {
      _text.text = '${widget.count}';
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    context.read<FunctionPickerViewModel>().setLoopCount(parsed);
  }

  @override
  Widget build(BuildContext context) => TextInput(
    controller: _text,
    focusNode: _focus,
    width: 72,
    numeric: true,
    dense: true,
    maxLength: 3,
    semanticLabel: 'Times',
    onChanged: _onChanged,
  );
}

class _PickerFooter extends StatelessWidget {
  const _PickerFooter();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.watch<FunctionPickerViewModel>();
    final buttons = context.read<ButtonsViewModel>();
    return Container(
      color: mix(p.bg, p.surface, 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  vm.currentLabel,
                  style: n.text.caption.copyWith(
                    fontSize: 12.5,
                    color: n.textColor.withValues(alpha: 0.6),
                  ),
                ),
                Icon(
                  AppIcons.arrowRight,
                  size: 14,
                  color: n.textColor.withValues(alpha: 0.5),
                ),
                Text(vm.nextLabel, style: n.text.row.copyWith(color: p.a(300))),
                if (vm.leftClickWarning)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      Icon(AppIcons.warning, size: 13, color: p.warning),
                      Text(
                        'No button would be Left click',
                        style: n.text.caption.copyWith(color: p.warning),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              AppButton.ghost(
                label: 'Default',
                neutralForeground: true,
                size: AppButtonSize.small,
                onPressed: vm.resetToDefault,
              ),
              AppButton(label: 'Cancel', onPressed: buttons.closePicker),
              AppButton.primary(
                label: 'Assign',
                icon: AppIcons.check,
                onPressed: vm.canAssign ? vm.assign : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
