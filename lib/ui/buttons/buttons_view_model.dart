import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/repositories/macro_repository.dart';
import '../../domain/button_assignment.dart';
import '../../domain/device_settings.dart';
import '../../domain/macro.dart';
import '../../domain/settings_changes.dart';
import '../shell/edit_session_view_model.dart';
import 'function_catalog.dart';
import 'function_picker_view_model.dart';

class ButtonInfo {
  const ButtonInfo(this.slot, this.number, this.name, this.place);

  final int slot;
  final int number;
  final String name;
  final String? place;

  String get title => place == null ? name : '$name · $place';
}

class ButtonRow {
  const ButtonRow({
    required this.info,
    required this.label,
    required this.icon,
    required this.changed,
    required this.custom,
    required this.defaultLabel,
  });

  final ButtonInfo info;
  final String label;
  final IconData icon;
  final bool changed;
  final bool custom;
  final String defaultLabel;
}

class ButtonsViewModel extends ChangeNotifier {
  ButtonsViewModel({required this._edit, required MacroRepository macros}) {
    _edit.addListener(_onEdit);
    _macroSubscription = macros.watchMacros().listen(
      _onMacros,
      onError: (_) {},
    );
  }

  static const mainButtons = [
    ButtonInfo(ButtonSlot.left, 1, 'Left button', null),
    ButtonInfo(ButtonSlot.right, 2, 'Right button', null),
    ButtonInfo(ButtonSlot.middle, 3, 'Middle', 'wheel click'),
    ButtonInfo(ButtonSlot.forward, 4, 'Forward', 'side front'),
    ButtonInfo(ButtonSlot.back, 5, 'Back', 'side rear'),
  ];

  static const advancedButtons = [
    ButtonInfo(ButtonSlot.dpi, 6, 'DPI button', 'underside'),
    ButtonInfo(ButtonSlot.wheelUp, 7, 'Wheel up', null),
    ButtonInfo(ButtonSlot.wheelDown, 8, 'Wheel down', null),
  ];

  static const _leftClick = FunctionButton(ButtonFunction.leftClick);

  final EditSessionViewModel _edit;
  late final StreamSubscription<List<Macro>> _macroSubscription;

  List<Macro> _macros = const [];
  bool _showAdvanced = false;
  int? _hovered;
  FunctionPickerViewModel? _picker;

  DeviceSettings? get _staged => _edit.staged;

  bool get hasSettings => _staged != null;

  bool get canEdit => _staged != null && !_edit.writing;

  bool get dirty => _edit.isDirty(SettingsSection.buttons);

  bool get showAdvanced => _showAdvanced;

  int? get hoveredSlot => _picker?.slot ?? _hovered;

  FunctionPickerViewModel? get picker => _picker;

  List<ButtonRow> get mainRows => [for (final b in mainButtons) _row(b)];

  List<ButtonRow> get advancedRows => [
    for (final b in advancedButtons) _row(b),
  ];

  static Iterable<ButtonInfo> get _visible => [
    ...mainButtons,
    ...advancedButtons,
  ];

  bool get noLeftClick {
    final staged = _staged;
    return staged != null && !staged.buttons.contains(_leftClick);
  }

  bool get anyCustom {
    final staged = _staged;
    if (staged == null) return false;
    return _visible.any(
      (b) => staged.buttons[b.slot] != factoryButtonAssignments[b.slot],
    );
  }

  ButtonAssignment assignment(int slot) =>
      _staged?.buttons[slot] ?? factoryButtonAssignments[slot];

  String label(ButtonAssignment assignment) =>
      describeAssignment(assignment, macroName: _macroName);

  String? _macroName(int id) {
    for (final m in _macros) {
      if (m.id == id) return m.name;
    }
    return null;
  }

  ButtonRow _row(ButtonInfo info) {
    final current = assignment(info.slot);
    final saved = _edit.saved?.buttons[info.slot];
    final defaults = factoryButtonAssignments[info.slot];
    return ButtonRow(
      info: info,
      label: label(current),
      icon: assignmentIcon(current),
      changed: saved != null && saved != current,
      custom: current != defaults,
      defaultLabel: label(defaults),
    );
  }

  void toggleAdvanced() {
    _showAdvanced = !_showAdvanced;
    notifyListeners();
  }

  void setHovered(int? slot) {
    if (slot == _hovered) return;
    _hovered = slot;
    notifyListeners();
  }

  void endHover(int slot) {
    if (_hovered == slot) setHovered(null);
  }

  void resetButton(int slot) =>
      _setButton(slot, factoryButtonAssignments[slot]);

  void restoreLeftClick() => resetButton(ButtonSlot.left);

  void resetAll() {
    if (!canEdit) return;
    _edit.stage((s) {
      final buttons = [...s.buttons];
      for (final b in _visible) {
        buttons[b.slot] = factoryButtonAssignments[b.slot];
      }
      return s.copyWith(buttons: buttons);
    });
  }

  void _setButton(int slot, ButtonAssignment value) {
    if (!canEdit) return;
    _edit.stage((s) => s.withButton(slot, value));
  }

  void openPicker(int slot) {
    final staged = _staged;
    if (staged == null || !canEdit) return;
    final info = _visible.firstWhere((b) => b.slot == slot);
    _picker = FunctionPickerViewModel(
      slot: slot,
      number: info.number,
      name: info.title,
      current: staged.buttons[slot],
      defaultAssignment: factoryButtonAssignments[slot],
      buttons: staged.buttons,
      macros: _macros,
      onAssign: (value) {
        _setButton(slot, value);
        closePicker();
      },
    );
    notifyListeners();
  }

  bool closePicker() {
    if (_picker == null) return false;
    _picker = null;
    notifyListeners();
    return true;
  }

  void _onEdit() {
    final staged = _staged;
    if (staged != null) _picker?.buttons = staged.buttons;
    notifyListeners();
  }

  void _onMacros(List<Macro> macros) {
    _macros = macros;
    _picker?.macros = macros;
    notifyListeners();
  }

  @override
  void dispose() {
    _edit.removeListener(_onEdit);
    unawaited(_macroSubscription.cancel());
    super.dispose();
  }
}
