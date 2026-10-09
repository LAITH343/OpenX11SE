import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/theme/app_icons.dart';
import '../../data/protocol/macro_report.dart';
import '../../data/repositories/macro_repository.dart';
import '../../domain/button_assignment.dart';
import '../../domain/macro.dart';
import '../buttons/buttons_view_model.dart';
import '../buttons/function_catalog.dart';
import '../shell/dialog_request.dart';
import '../shell/edit_session_view_model.dart';
import '../widgets/toast_host.dart';
import 'macro_editor_view_model.dart';

typedef ConfirmDialog = Future<bool> Function(DialogRequest request);

class MacroListItem {
  const MacroListItem({
    required this.id,
    required this.name,
    required this.pairs,
    required this.events,
    required this.assignedTo,
    required this.selected,
  });

  final int id;
  final String name;
  final int pairs;
  final int events;
  final List<String> assignedTo;
  final bool selected;

  String get meta => '$pairs steps · $events events';
}

class MacroAssignDraft {
  const MacroAssignDraft({required this.slot, required this.playback});

  final int slot;
  final MacroPlayback playback;

  MacroAssignDraft copyWith({int? slot, MacroPlayback? playback}) =>
      MacroAssignDraft(
        slot: slot ?? this.slot,
        playback: playback ?? this.playback,
      );
}

class MacroLibraryViewModel extends ChangeNotifier {
  MacroLibraryViewModel({
    required this._repository,
    required this._edit,
    required this._toasts,
    required this._confirm,
  }) {
    _edit.addListener(_onEdit);
    _subscription = _repository.watchMacros().listen(
      _onMacros,
      onError: (_) {},
    );
  }

  static List<ButtonInfo> get assignableButtons => ButtonsViewModel.mainButtons;

  final MacroRepository _repository;
  final EditSessionViewModel _edit;
  final ToastController _toasts;
  final ConfirmDialog _confirm;
  late final StreamSubscription<List<Macro>> _subscription;

  List<Macro> _macros = const [];
  bool _loaded = false;
  String _search = '';
  MacroEditorViewModel? _editor;
  MacroAssignDraft? _assign;
  bool _busy = false;
  bool _disposed = false;

  bool get loaded => _loaded;

  String get search => _search;

  MacroEditorViewModel? get editor => _editor;

  MacroAssignDraft? get assign => _assign;

  bool get hasMacros => _macros.isNotEmpty;

  List<MacroListItem> get items {
    final query = _search.trim().toLowerCase();
    return [
      for (final m in _macros)
        if (query.isEmpty || m.name.toLowerCase().contains(query))
          MacroListItem(
            id: m.id!,
            name: m.name,
            pairs: macroPairCount(m.events),
            events: m.events.length,
            assignedTo: assignedTo(m.id!),
            selected: m.id == _editor?.id,
          ),
    ];
  }

  bool get noResults => items.isEmpty && _search.trim().isNotEmpty;

  List<String> assignedTo(int id) {
    final buttons = _edit.staged?.buttons;
    if (buttons == null) return const [];
    return [
      for (final b in assignableButtons)
        if (buttons[b.slot] case MacroButton(:final macroId) when macroId == id)
          b.name,
    ];
  }

  bool get canAssign {
    final editor = _editor;
    return editor != null &&
        !editor.overCapacity &&
        _edit.staged != null &&
        !_edit.writing;
  }

  void setSearch(String value) {
    if (value == _search) return;
    _search = value;
    notifyListeners();
  }

  Future<void> select(int id) async {
    if (id == _editor?.id) return;
    if (!await _confirmDiscard()) return;
    final macro = _byId(id);
    if (macro != null) _open(macro);
  }

  Future<void> create() async {
    if (_busy || !await _confirmDiscard()) return;
    await _run(() async {
      final macro = await _repository.create(
        Macro(name: 'New macro ${_macros.length + 1}', events: const []),
      );
      _search = '';
      _open(macro);
    });
  }

  Future<void> duplicate() async {
    final editor = _editor;
    if (editor == null || _busy) return;
    final source = editor.draft;
    await _run(() async {
      final copy = await _repository.create(
        Macro(name: '${source.name} copy', events: source.events),
      );
      _open(copy);
      _toasts.show(
        'Duplicated as “${copy.name}”',
        kind: ToastKind.success,
        icon: AppIconsFill.copy,
      );
    });
  }

  Future<void> delete() async {
    final editor = _editor;
    final id = editor?.id;
    if (editor == null || id == null || _busy) return;
    final at = assignedTo(id);
    final ok = await _confirm(
      DialogRequest(
        title: 'Delete “${editor.original.name}”?',
        body: at.isEmpty
            ? 'This removes the macro from this computer.'
            : "It's assigned to ${at.join(', ')} — "
                  '${at.length > 1 ? 'those buttons' : 'that button'} will go '
                  'back to default.',
        confirmLabel: 'Delete macro',
        icon: AppIcons.trash,
        danger: true,
      ),
    );
    if (!ok) return;
    await _run(() async {
      _resetButtonsUsing(id);
      await _repository.delete(id);
      _editor = null;
      final rest = _macros.where((m) => m.id != id).toList();
      if (rest.isNotEmpty) _open(rest.first);
    });
  }

  Future<bool> save() async {
    final editor = _editor;
    if (editor == null || !editor.canSave || _busy) return false;
    var saved = false;
    await _run(() async {
      final macro = await _repository.save(editor.draft);
      editor.markSaved(macro);
      final id = macro.id;
      if (id != null) _edit.markMacroChanged(id);
      _toasts.show(
        'Macro “${macro.name}” saved',
        kind: ToastKind.success,
        icon: AppIconsFill.checkCircle,
      );
      saved = true;
    });
    return saved;
  }

  void cancelEdits() => _editor?.cancel();

  void recordingStopped() =>
      _toasts.show('Recording stopped', icon: AppIconsFill.stop);

  Future<void> openAssign() async {
    final editor = _editor;
    final id = editor?.id;
    if (editor == null || id == null || !canAssign) return;
    if (editor.dirty && !await save()) return;
    final buttons = _edit.staged!.buttons;
    MacroAssignDraft? current;
    for (final b in assignableButtons) {
      if (buttons[b.slot] case final MacroButton m when m.macroId == id) {
        current = MacroAssignDraft(slot: b.slot, playback: m.playback);
        break;
      }
    }
    _assign =
        current ??
        const MacroAssignDraft(
          slot: ButtonSlot.forward,
          playback: MacroPlayback.defaults,
        );
    notifyListeners();
  }

  bool closeAssign() {
    if (_assign == null) return false;
    _assign = null;
    notifyListeners();
    return true;
  }

  void setAssignSlot(int slot) => _updateAssign((a) => a.copyWith(slot: slot));

  void setAssignMode(MacroPlaybackMode mode) => _updateAssign(
    (a) => a.copyWith(
      playback: MacroPlayback(mode: mode, loopCount: a.playback.loopCount),
    ),
  );

  void setAssignLoopCount(int count) => _updateAssign(
    (a) => a.copyWith(
      playback: MacroPlayback(
        mode: MacroPlaybackMode.once,
        loopCount: count.clamp(
          MacroPlayback.minLoopCount,
          MacroPlayback.maxLoopCount,
        ),
      ),
    ),
  );

  String currentLabel(int slot) {
    final button = _edit.staged?.buttons[slot];
    return button == null
        ? '—'
        : describeAssignment(button, macroName: _macroName);
  }

  bool get assignLeftWarning {
    final a = _assign;
    final buttons = _edit.staged?.buttons;
    if (a == null || buttons == null || a.slot != ButtonSlot.left) {
      return false;
    }
    const left = FunctionButton(ButtonFunction.leftClick);
    for (var slot = 0; slot < buttons.length; slot++) {
      if (slot != ButtonSlot.left && buttons[slot] == left) return false;
    }
    return true;
  }

  void confirmAssign() {
    final a = _assign;
    final editor = _editor;
    final id = editor?.id;
    if (a == null || editor == null || id == null) return;
    final playback = a.playback.mode == MacroPlaybackMode.once
        ? a.playback
        : MacroPlayback(mode: a.playback.mode);
    _edit.stage(
      (s) => s.withButton(a.slot, MacroButton(macroId: id, playback: playback)),
    );
    _assign = null;
    notifyListeners();
    final button = assignableButtons.firstWhere((b) => b.slot == a.slot);
    _toasts.show(
      '“${editor.original.name}” → ${button.name} · apply to write',
      kind: ToastKind.success,
      icon: AppIconsFill.checkCircle,
    );
  }

  void _updateAssign(MacroAssignDraft Function(MacroAssignDraft a) change) {
    final a = _assign;
    if (a == null) return;
    _assign = change(a);
    notifyListeners();
  }

  void _resetButtonsUsing(int id) {
    final staged = _edit.staged;
    if (staged == null) return;
    if (!staged.buttons.any((b) => b is MacroButton && b.macroId == id)) {
      return;
    }
    _edit.stage(
      (s) => s.copyWith(
        buttons: [
          for (var slot = 0; slot < s.buttons.length; slot++)
            switch (s.buttons[slot]) {
              MacroButton(:final macroId) when macroId == id =>
                factoryButtonAssignments[slot],
              final other => other,
            },
        ],
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final editor = _editor;
    if (editor == null || !editor.dirty) return true;
    final ok = await _confirm(
      DialogRequest(
        title: 'Discard macro changes?',
        body:
            '“${editor.name.trim().isEmpty ? editor.original.name : editor.name.trim()}” '
            'has unsaved edits. Switching macros will discard them.',
        confirmLabel: 'Discard edits',
        icon: AppIcons.warning,
        danger: true,
      ),
    );
    return ok && !_disposed;
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    try {
      await action();
    } on Object {
      if (!_disposed) {
        _toasts.show(
          "Couldn't update the macro library",
          kind: ToastKind.error,
          icon: AppIconsFill.xCircle,
        );
      }
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _open(Macro macro) {
    final previous = _editor;
    _editor = MacroEditorViewModel(
      macro,
      delayMode: previous?.delayMode ?? RecordDelayMode.actual,
      fixedDelayMs:
          previous?.fixedDelayMs ?? MacroEditorViewModel.defaultFixedDelayMs,
    );
    _assign = null;
    notifyListeners();
  }

  Macro? _byId(int id) {
    for (final m in _macros) {
      if (m.id == id) return m;
    }
    return null;
  }

  String? _macroName(int id) => _byId(id)?.name;

  void _onMacros(List<Macro> macros) {
    _macros = macros;
    _loaded = true;
    final editor = _editor;
    final id = editor?.id;
    final current = id == null ? null : _byId(id);
    if (editor == null || current == null) {
      if (!_busy) {
        _editor = null;
        if (macros.isNotEmpty) {
          _open(macros.first);
          return;
        }
      }
    } else if (!editor.dirty && current != editor.original) {
      editor.markSaved(current);
    }
    notifyListeners();
  }

  void _onEdit() => notifyListeners();

  @override
  void dispose() {
    _disposed = true;
    _edit.removeListener(_onEdit);
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
