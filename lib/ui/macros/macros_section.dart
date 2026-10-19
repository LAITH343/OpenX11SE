import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../data/protocol/macro_report.dart';
import '../../domain/keyboard_keys.dart';
import '../../domain/macro.dart';
import '../shell/app_section.dart';
import '../widgets/app_button.dart';
import '../widgets/motion.dart';
import '../widgets/number_field.dart';
import '../widgets/pressable.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_control.dart';
import '../widgets/tag.dart';
import '../widgets/text_input.dart';
import 'macro_editor_view_model.dart';
import 'macro_library_view_model.dart';

class MacrosSection extends StatelessWidget {
  const MacrosSection({super.key});

  static const _singleColumnWidth = 640.0;
  static const _gap = 14.0;

  @override
  Widget build(BuildContext context) {
    const section = AppSection.macros;
    final editor = context.select<MacroLibraryViewModel, MacroEditorViewModel?>(
      (vm) => vm.editor,
    );
    final body = editor == null
        ? const _NoSelection()
        : ChangeNotifierProvider.value(
            key: ObjectKey(editor),
            value: editor,
            child: const _EditorCard(),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        SectionHeader(title: section.label),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < _singleColumnWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _gap,
                children: [const _MacroList(), body],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: _gap,
              children: [
                SizedBox(
                  width: (c.maxWidth * 0.24).clamp(200, 240),
                  child: const _MacroList(),
                ),
                Expanded(child: body),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final style = n.text.body.copyWith(color: n.textSecondary);
    return _Panel(
      padding: const EdgeInsets.all(32),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: tr('No macro selected. Create one with ')),
            TextSpan(
              text: tr('+'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(text: tr('.')),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: n.surface,
        borderRadius: n.radius.lgAll,
        boxShadow: n.palette.shadowSm,
      ),
      child: child,
    );
  }
}

class _MacroList extends StatefulWidget {
  const _MacroList();

  @override
  State<_MacroList> createState() => _MacroListState();
}

class _MacroListState extends State<_MacroList> {
  late final _search = TextEditingController(
    text: context.read<MacroLibraryViewModel>().search,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<MacroLibraryViewModel>();
    if (vm.search != _search.text) _search.text = vm.search;
    final items = vm.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 6,
          children: [
            Expanded(
              child: TextInput(
                controller: _search,
                hint: 'Search macros',
                prefixIcon: AppIcons.magnifyingGlass,
                semanticLabel: 'Search macros',
                onChanged: vm.setSearch,
              ),
            ),
            AppIconButton(
              icon: AppIcons.plus,
              tooltip: 'New macro',
              variant: AppButtonVariant.primary,
              onPressed: vm.create,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            for (final item in items)
              _MacroListTile(
                key: ValueKey(item.id),
                item: item,
                onPressed: () => vm.select(item.id),
              ),
            if (vm.noResults)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  tr('No macros match.'),
                  style: n.text.caption.copyWith(
                    fontSize: 12.5,
                    color: n.textColor.withValues(alpha: 0.58),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MacroListTile extends StatelessWidget {
  const _MacroListTile({
    super.key,
    required this.item,
    required this.onPressed,
  });

  final MacroListItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final on = item.selected;
    return Pressable(
      onPressed: onPressed,
      selected: on,
      focusRadius: n.radius.mdAll,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: n.motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: on
                ? p.a(900)
                : hovered
                ? n.textColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: n.radius.mdAll,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -12,
                top: 1,
                bottom: 1,
                child: AnimatedContainer(
                  duration: n.motion.fast,
                  width: 2,
                  decoration: BoxDecoration(
                    color: on ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    tr(item.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: n.text.row.copyWith(
                      color: n.textColor.withValues(alpha: on ? 1 : 0.82),
                    ),
                  ),
                  Text(
                    tr(item.meta),
                    style: n.text.tabular(
                      n.text.micro.copyWith(color: n.textMuted),
                    ),
                  ),
                  if (item.assignedTo.isNotEmpty)
                    Row(
                      spacing: 4,
                      children: [
                        Icon(AppIcons.linkSimple, size: 11, color: p.a(300)),
                        Flexible(
                          child: Text(
                            tr(item.assignedTo.join(', ')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: n.text.micro.copyWith(color: p.a(300)),
                          ),
                        ),
                      ],
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

class _EditorCard extends StatelessWidget {
  const _EditorCard();

  @override
  Widget build(BuildContext context) {
    final listening = context.select<MacroEditorViewModel, bool>(
      (e) => e.listeningForKeys,
    );
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          const _EditorHeader(),
          const _RecordBar(),
          const _EventTable(),
          const _InsertBar(),
          const _EditorFooter(),
          if (listening) const _KeyListener(),
        ],
      ),
    );
  }
}

class _EditorHeader extends StatefulWidget {
  const _EditorHeader();

  @override
  State<_EditorHeader> createState() => _EditorHeaderState();
}

class _EditorHeaderState extends State<_EditorHeader> {
  late final _name = TextEditingController(
    text: context.read<MacroEditorViewModel>().name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final editor = context.watch<MacroEditorViewModel>();
    final library = context.watch<MacroLibraryViewModel>();
    if (editor.name != _name.text) _name.text = editor.name;
    final id = editor.id;
    final assigned = id == null ? const <String>[] : library.assignedTo(id);
    return Row(
      spacing: 8,
      children: [
        Flexible(
          flex: 3,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: TextInput(
              controller: _name,
              semanticLabel: 'Macro name',
              maxLength: 64,
              style: n.text.heading,
              onChanged: editor.setName,
            ),
          ),
        ),
        if (editor.dirty)
          const EntranceTransition(
            kind: Entrance.fade,
            child: Tag(label: 'Unsaved'),
          ),
        if (assigned.isNotEmpty)
          Flexible(
            flex: 2,
            child: Tooltip(
              message: tr('Assigned to ${assigned.join(', ')}'),
              child: Tag(
                label: assigned.join(', '),
                variant: TagVariant.neutral,
                icon: AppIcons.linkSimple,
              ),
            ),
          ),
        const Spacer(),
        AppButton(
          label: 'Assign to button',
          icon: AppIcons.mouseSimple,
          onPressed: library.canAssign ? library.openAssign : null,
        ),
        AppIconButton(
          icon: AppIcons.copy,
          tooltip: 'Duplicate macro',
          onPressed: library.duplicate,
        ),
        AppIconButton(
          icon: AppIcons.trash,
          tooltip: 'Delete macro',
          onPressed: library.delete,
        ),
      ],
    );
  }
}

class _RecordBar extends StatelessWidget {
  const _RecordBar();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final editor = context.watch<MacroEditorViewModel>();
    final recording = editor.recording;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: n.bg.withValues(alpha: 0.55),
        borderRadius: n.radius.mdAll,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              if (recording)
                AppButton(
                  label: 'Stop',
                  icon: AppIconsFill.stop,
                  variant: AppButtonVariant.danger,
                  onPressed: () => _toggle(context, editor),
                )
              else
                AppButton(
                  label: 'Record',
                  icon: AppIconsFill.record,
                  onPressed: () => _toggle(context, editor),
                ),
              if (recording)
                EntranceTransition(
                  kind: Entrance.fade,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Blink(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: p.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Text(
                        tr(
                          'Recording — press keys · '
                          '${editor.rows.length} events',
                        ),
                        style: n.text.small,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                tr('Delays while recording'),
                style: n.text.caption.copyWith(color: n.textSecondary),
              ),
              SegmentedControl<RecordDelayMode>(
                dense: true,
                options: [
                  for (final m in RecordDelayMode.values)
                    SegmentOption(value: m, label: m.label),
                ],
                selected: editor.delayMode,
                onChanged: editor.setDelayMode,
              ),
              if (editor.delayMode == RecordDelayMode.fixed)
                EntranceTransition(
                  kind: Entrance.fade,
                  child: NumberField(
                    value: editor.fixedDelayMs,
                    width: 96,
                    max: macroMaxDelayMs,
                    suffix: 'ms',
                    semanticLabel: 'Fixed delay',
                    onChanged: editor.setFixedDelay,
                    onCommit: editor.roundFixedDelay,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggle(BuildContext context, MacroEditorViewModel editor) {
    FocusManager.instance.primaryFocus?.unfocus();
    final was = editor.recording;
    editor.toggleRecording();
    if (was) {
      context.read<MacroLibraryViewModel>().recordingStopped();
    }
  }
}

class _KeyListener extends StatefulWidget {
  const _KeyListener();

  @override
  State<_KeyListener> createState() => _KeyListenerState();
}

class _KeyListenerState extends State<_KeyListener> {
  final _focus = FocusNode(debugLabel: 'macro keys');
  late final MacroEditorViewModel _editor = context
      .read<MacroEditorViewModel>();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _focus.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyRepeatEvent) return true;
    final usage = event.physicalKey.usbHidUsage;
    if (usage >> 16 != HidUsage.page) return true;
    final down = event is KeyDownEvent;
    if (_editor.recording) {
      _editor.recordKey(usage & 0xFFFF, down: down, timestamp: event.timeStamp);
    } else if (down) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _editor.cancelCapture();
      } else {
        _editor.captureKey(usage & 0xFFFF);
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    onKeyEvent: (_, _) => KeyEventResult.handled,
    child: const SizedBox.shrink(),
  );
}

class _EventTable extends StatelessWidget {
  const _EventTable();

  static const _maxHeight = 300.0;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final editor = context.watch<MacroEditorViewModel>();
    final rows = editor.rows;
    final head = n.text.kicker.copyWith(
      fontSize: 10.5,
      color: n.textMuted,
      letterSpacing: 0.84,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: _RowLayout(
            number: Text(tr('#'), style: head),
            key_: Text(tr('KEY'), style: head),
            action: Text(tr('ACTION'), style: head),
            delay: Text(tr('DELAY AFTER'), style: head),
            tools: const SizedBox.shrink(),
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
            child: Text(
              tr(
                'No events yet. Press Record and type, or insert actions below.',
              ),
              style: n.text.small.copyWith(
                color: n.textColor.withValues(alpha: 0.6),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxHeight),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              itemCount: rows.length,
              onReorderItem: editor.move,
              proxyDecorator: (child, _, _) => DecoratedBox(
                decoration: BoxDecoration(
                  color: n.surface,
                  borderRadius: n.radius.mdAll,
                  boxShadow: n.palette.shadowMd,
                ),
                child: Material(type: MaterialType.transparency, child: child),
              ),
              itemBuilder: (context, i) => _EventRow(
                key: ValueKey(rows[i].key),
                index: i,
                row: rows[i],
                last: i == rows.length - 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _RowLayout extends StatelessWidget {
  const _RowLayout({
    required this.number,
    required this.key_,
    required this.action,
    required this.delay,
    required this.tools,
  });

  final Widget number;
  final Widget key_;
  final Widget action;
  final Widget delay;
  final Widget tools;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      SizedBox(width: 40, child: number),
      Expanded(child: key_),
      SizedBox(width: 92, child: action),
      SizedBox(width: 140, child: delay),
      SizedBox(width: 88, child: tools),
    ],
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    super.key,
    required this.index,
    required this.row,
    required this.last,
  });

  final int index;
  final MacroRow row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final editor = context.read<MacroEditorViewModel>();
    final e = row.event;
    final capturing = context.select<MacroEditorViewModel, bool>(
      (vm) => vm.capturingRow == row.key,
    );
    final extended = context.select<MacroEditorViewModel, bool>(
      (vm) => index < vm.rows.length && vm.isExtended(index),
    );
    final muted = n.textMuted;
    return _HoverRow(
      child: _RowLayout(
        number: ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Tooltip(
              message: tr('Drag to reorder'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Icon(AppIcons.dotsSixVertical, size: 13, color: muted),
                  Text(
                    tr('${index + 1}'),
                    style: n.text.tabular(
                      n.text.caption.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        key_: e.isDelay
            ? SizedBox(
                height: 30,
                child: Row(
                  spacing: 8,
                  children: [
                    const SizedBox(width: 2),
                    Icon(
                      AppIcons.timer,
                      size: 15,
                      color: n.textColor.withValues(alpha: 0.7),
                    ),
                    Text(
                      tr('Wait'),
                      style: n.text.small.copyWith(
                        color: n.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            : _KeyCell(
                event: e,
                capturing: capturing,
                onPressed: e.kind == MacroEventKind.key
                    ? () => editor.startCapture(row.key)
                    : null,
              ),
        action: e.isDelay
            ? Text(
                tr('—'),
                style: n.text.caption.copyWith(
                  color: n.textColor.withValues(alpha: 0.5),
                ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: _ActionChip(
                  press: e.action == MacroAction.press,
                  onPressed: () => editor.toggleAction(row.key),
                ),
              ),
        delay: Row(
          spacing: 6,
          children: [
            NumberField(
              value: e.delayMs,
              width: 96,
              max: macroMaxDelayMs,
              suffix: 'ms',
              semanticLabel: 'Delay in ms',
              onChanged: (v) => editor.setDelay(row.key, v),
              onCommit: () => editor.roundDelay(row.key),
            ),
            if (extended)
              Tooltip(
                message: tr('Long delays use an extra step'),
                child: Text(
                  tr('+1 step'),
                  style: n.text.micro.copyWith(
                    fontSize: 10.5,
                    color: p.warning,
                  ),
                ),
              ),
          ],
        ),
        tools: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 2,
          children: [
            _RowTool(
              icon: AppIcons.arrowUp,
              tooltip: 'Move up',
              onPressed: index == 0
                  ? null
                  : () => editor.move(index, index - 1),
            ),
            _RowTool(
              icon: AppIcons.arrowDown,
              tooltip: 'Move down',
              onPressed: last ? null : () => editor.move(index, index + 1),
            ),
            _RowTool(
              icon: AppIcons.x,
              tooltip: 'Delete event',
              onPressed: () => editor.remove(row.key),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child});

  final Widget child;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: n.motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _hover
              ? n.textColor.withValues(alpha: 0.04)
              : Colors.transparent,
          borderRadius: n.radius.mdAll,
        ),
        child: widget.child,
      ),
    );
  }
}

class _KeyCell extends StatelessWidget {
  const _KeyCell({
    required this.event,
    required this.capturing,
    required this.onPressed,
  });

  final MacroEvent event;
  final bool capturing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final mouse = event.kind == MacroEventKind.mouse;
    final label = Text(
      tr(capturing ? 'Press a key…' : macroEventLabel(event)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: n.text.small,
    );
    return Pressable(
      onPressed: onPressed,
      dimWhenDisabled: false,
      tooltip: mouse ? 'Left mouse button' : 'Click, then press a key',
      focusRadius: BorderRadius.circular(6),
      builder: (context, states) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: p.n(900),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: capturing
                ? p.accent
                : states.contains(WidgetState.hovered) && onPressed != null
                ? n.divider
                : Colors.transparent,
          ),
        ),
        child: Row(
          spacing: 8,
          children: [
            Icon(
              mouse ? AppIcons.mouseSimple : AppIcons.keyboard,
              size: 15,
              color: n.textColor.withValues(alpha: 0.6),
            ),
            Flexible(child: capturing ? Blink(child: label) : label),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.press, required this.onPressed});

  final bool press;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final fg = press ? p.a(100) : p.n(200);
    return Pressable(
      onPressed: onPressed,
      tooltip: 'Toggle press / release',
      focusRadius: BorderRadius.circular(6),
      builder: (context, states) => AnimatedContainer(
        duration: n.motion.fast,
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: press ? p.a(800) : p.n(800),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            Icon(
              press ? AppIcons.arrowDown : AppIcons.arrowUp,
              size: 12,
              color: fg,
            ),
            Text(
              tr(press ? 'Press' : 'Release'),
              style: n.text.caption.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowTool extends StatelessWidget {
  const _RowTool({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AppIconButton(
    icon: icon,
    tooltip: tooltip,
    variant: AppButtonVariant.ghost,
    neutralForeground: true,
    size: 28,
    iconSize: 14,
    onPressed: onPressed,
  );
}

class _InsertBar extends StatelessWidget {
  const _InsertBar();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final editor = context.watch<MacroEditorViewModel>();
    return Row(
      spacing: 6,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  tr('Insert'),
                  style: n.text.caption.copyWith(
                    color: n.textColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
              AppButton(
                label: 'Key event',
                icon: AppIcons.keyboard,
                size: AppButtonSize.small,
                onPressed: editor.addKey,
              ),
              AppButton(
                label: 'Mouse button',
                icon: AppIcons.mouseSimple,
                size: AppButtonSize.small,
                tooltip: 'Inserts a left button press',
                onPressed: editor.addMouse,
              ),
              AppButton(
                label: 'Delay',
                icon: AppIcons.timer,
                size: AppButtonSize.small,
                onPressed: editor.addDelay,
              ),
            ],
          ),
        ),
        AppButton.ghost(
          label: 'Clear all',
          icon: AppIcons.trash,
          size: AppButtonSize.small,
          neutralForeground: true,
          onPressed: editor.isEmpty ? null : editor.clear,
        ),
      ],
    );
  }
}

class _EditorFooter extends StatelessWidget {
  const _EditorFooter();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final editor = context.watch<MacroEditorViewModel>();
    final library = context.read<MacroLibraryViewModel>();
    final pairs = editor.pairs;
    final over = editor.overCapacity;
    final color = over
        ? p.danger
        : pairs > macroPairLimit - 10
        ? p.warning
        : p.accent;
    final text = over
        ? '$pairs / $macroPairLimit steps — remove '
              '${pairs - macroPairLimit} to save'
        : '$pairs / $macroPairLimit steps · ${editor.pairsLeft} left';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                n.divider.withValues(alpha: 0),
                n.divider,
                n.divider,
                n.divider.withValues(alpha: 0),
              ],
              stops: const [0, 0.06, 0.94, 1],
            ),
          ),
        ),
        Row(
          spacing: 14,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 6,
                      color: p.n(800),
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          end: (pairs / macroPairLimit).clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, v, _) => FractionallySizedBox(
                          widthFactor: v,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    tr(text),
                    style: n.text.tabular(
                      n.text.caption.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
            AppButton(
              label: 'Cancel',
              onPressed: editor.dirty ? library.cancelEdits : null,
            ),
            AppButton.primary(
              label: 'Save macro',
              icon: AppIcons.floppyDisk,
              onPressed: editor.canSave ? library.save : null,
            ),
          ],
        ),
      ],
    );
  }
}
