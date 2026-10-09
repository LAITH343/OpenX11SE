import 'package:flutter/foundation.dart';

import '../../data/protocol/button_report.dart';
import '../../data/protocol/macro_report.dart';
import '../../domain/button_assignment.dart';
import '../../domain/keyboard_keys.dart';
import '../../domain/macro.dart';
import 'function_catalog.dart';

class FunctionPickerViewModel extends ChangeNotifier {
  FunctionPickerViewModel({
    required this.slot,
    required this.number,
    required this.name,
    required this.current,
    required this.defaultAssignment,
    required this._buttons,
    required List<Macro> macros,
    required this.onAssign,
  }) : _macros = macros,
       _selection = current,
       _group = groupOf(current) {
    final c = current;
    if (c is KeyButton && shortcutFor(c) == null) {
      _key = c.usage;
      _modifiers = c.modifiers;
    }
    if (c is MacroButton) {
      _macroId = c.macroId;
      _mode = c.playback.mode;
      _loopCount = c.playback.loopCount;
    }
    _macroId ??= macros.isEmpty ? null : macros.first.id;
  }

  final int slot;
  final int number;
  final String name;
  final ButtonAssignment current;
  final ButtonAssignment defaultAssignment;
  final ValueChanged<ButtonAssignment> onAssign;

  List<ButtonAssignment> _buttons;
  List<Macro> _macros;
  ButtonAssignment? _selection;
  ButtonFunctionGroup _group;
  String _search = '';
  int? _key;
  KeyModifiers _modifiers = KeyModifiers.none;
  int? _macroId;
  MacroPlaybackMode _mode = MacroPlaybackMode.once;
  int _loopCount = 1;

  ButtonAssignment? get selection => _selection;

  ButtonFunctionGroup get group => _group;

  String get search => _search;

  bool get searching => _search.trim().isNotEmpty;

  List<FunctionItem> get items =>
      searching ? searchFunctions(_search) : functionItems[_group]!;

  bool get showList => !showKeyboard && !showMacro && items.isNotEmpty;

  bool get showKeyboard => !searching && _group == ButtonFunctionGroup.keyboard;

  bool get showMacro => !searching && _group == ButtonFunctionGroup.macro;

  bool get noResults => searching && items.isEmpty;

  int? get capturedKey => _key;

  String? get capturedKeyLabel => _key == null ? null : hidKeyName(_key!);

  KeyModifiers get modifiers => _modifiers;

  bool get macroAllowed => supportsMacro(slot);

  List<Macro> get macros => _macros;

  int? get macroId => _macroId;

  MacroPlaybackMode get mode => _mode;

  int get loopCount => _loopCount;

  bool get canAssign => _selection != null;

  String? _knownMacroName(int id) {
    for (final m in _macros) {
      if (m.id == id) return m.name;
    }
    return null;
  }

  String get currentLabel =>
      describeAssignment(current, macroName: _knownMacroName);

  String get nextLabel => _selection == null
      ? 'Choose a function'
      : describeAssignment(_selection!, macroName: _knownMacroName);

  bool get leftClickWarning {
    final after = [..._buttons];
    final s = _selection;
    if (s != null) after[slot] = s;
    return !after.contains(const FunctionButton(ButtonFunction.leftClick));
  }

  static int macroSteps(Macro macro) => macroPairCount(macro.events);

  bool isSelected(FunctionItem item) => _selection == item.assignment;

  set buttons(List<ButtonAssignment> value) {
    _buttons = value;
    notifyListeners();
  }

  set macros(List<Macro> value) {
    _macros = value;
    if (!value.any((m) => m.id == _macroId)) {
      _macroId = value.isEmpty ? null : value.first.id;
    }
    notifyListeners();
  }

  void selectGroup(ButtonFunctionGroup group) {
    _group = group;
    _search = '';
    notifyListeners();
  }

  void setSearch(String value) {
    if (value == _search) return;
    _search = value;
    notifyListeners();
  }

  void pick(FunctionItem item) {
    _selection = item.assignment;
    notifyListeners();
  }

  void captureKey(int usage, {KeyModifiers held = KeyModifiers.none}) {
    if (isModifierUsage(usage)) {
      _modifiers = combineModifiers(_modifiers, modifierForUsage(usage));
      if (_key != null) _selection = KeyButton(_key!, modifiers: _modifiers);
      notifyListeners();
      return;
    }
    if (!isAssignableKey(usage)) return;
    _key = usage;
    if (!held.isEmpty) _modifiers = held;
    _selection = KeyButton(usage, modifiers: _modifiers);
    notifyListeners();
  }

  void toggleModifier(KeyModifiers modifier) {
    _modifiers = KeyModifiers(
      ctrl: _modifiers.ctrl != modifier.ctrl,
      shift: _modifiers.shift != modifier.shift,
      alt: _modifiers.alt != modifier.alt,
      win: _modifiers.win != modifier.win,
    );
    if (_key != null) _selection = KeyButton(_key!, modifiers: _modifiers);
    notifyListeners();
  }

  void clearKey() {
    _key = null;
    _modifiers = KeyModifiers.none;
    _selection = null;
    notifyListeners();
  }

  void selectMacro(int id) {
    _macroId = id;
    _selectMacro();
  }

  void setMode(MacroPlaybackMode mode) {
    _mode = mode;
    _selectMacro();
  }

  void setLoopCount(int count) {
    _loopCount = count.clamp(
      MacroPlayback.minLoopCount,
      MacroPlayback.maxLoopCount,
    );
    _mode = MacroPlaybackMode.once;
    _selectMacro();
  }

  void _selectMacro() {
    final id = _macroId;
    if (id != null && macroAllowed) {
      _selection = MacroButton(
        macroId: id,
        playback: MacroPlayback(
          mode: _mode,
          loopCount: _mode == MacroPlaybackMode.once ? _loopCount : 1,
        ),
      );
    }
    notifyListeners();
  }

  void resetToDefault() {
    _selection = defaultAssignment;
    _group = groupOf(defaultAssignment);
    _search = '';
    notifyListeners();
  }

  void assign() {
    final s = _selection;
    if (s == null) return;
    onAssign(s);
  }
}
