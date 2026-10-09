import 'package:flutter/foundation.dart';

import '../../data/protocol/macro_report.dart';
import '../../domain/keyboard_keys.dart';
import '../../domain/list_equality.dart';
import '../../domain/macro.dart';

enum RecordDelayMode {
  actual('Actual delays'),
  fixed('Fixed'),
  none('No delay');

  const RecordDelayMode(this.label);

  final String label;
}

class MacroRow {
  const MacroRow(this.key, this.event);

  final int key;
  final MacroEvent event;

  MacroRow withEvent(MacroEvent event) => MacroRow(key, event);
}

class MacroEditorViewModel extends ChangeNotifier {
  MacroEditorViewModel(
    Macro macro, {
    this._delayMode = RecordDelayMode.actual,
    this._fixedDelayMs = defaultFixedDelayMs,
  }) : _original = macro {
    _load(macro);
  }

  static const defaultFixedDelayMs = 60;
  static const recordedDelayMs = 20;
  static const insertedDelayMs = 500;
  static const untitledName = 'Untitled macro';

  Macro _original;
  late String _name;
  late List<MacroRow> _rows;
  int _nextKey = 0;
  bool _recording = false;
  Duration? _lastStamp;
  RecordDelayMode _delayMode;
  int _fixedDelayMs;
  int? _capturing;

  Macro get original => _original;

  int? get id => _original.id;

  String get name => _name;

  List<MacroRow> get rows => List.unmodifiable(_rows);

  List<MacroEvent> get events => [for (final r in _rows) r.event];

  bool get isEmpty => _rows.isEmpty;

  bool get recording => _recording;

  RecordDelayMode get delayMode => _delayMode;

  int get fixedDelayMs => _fixedDelayMs;

  int? get capturingRow => _capturing;

  bool get listeningForKeys => _recording || _capturing != null;

  bool get dirty =>
      _name != _original.name || !elementsEqual(events, _original.events);

  int get pairs => macroPairCount(events);

  int get pairsLeft => macroPairLimit - pairs;

  bool get overCapacity => pairs > macroPairLimit;

  bool get canSave => dirty && !overCapacity;

  Macro get draft {
    final trimmed = _name.trim();
    return _original.copyWith(
      name: trimmed.isEmpty ? untitledName : trimmed,
      events: events,
    );
  }

  bool isExtended(int index) {
    if (_rows[index].event.isDelay) return false;
    var delay = _rows[index].event.delayMs;
    for (var i = index + 1; i < _rows.length && _rows[i].event.isDelay; i++) {
      delay += _rows[i].event.delayMs;
    }
    return isExtendedMacroDelay(delay.clamp(0, macroMaxDelayMs));
  }

  void _load(Macro macro) {
    _name = macro.name;
    _rows = [for (final e in macro.events) MacroRow(_nextKey++, e)];
    _recording = false;
    _capturing = null;
    _lastStamp = null;
  }

  void markSaved(Macro saved) {
    _original = saved;
    _load(saved);
    notifyListeners();
  }

  void cancel() {
    _load(_original);
    notifyListeners();
  }

  void setName(String value) {
    if (value == _name) return;
    _name = value;
    notifyListeners();
  }

  void setDelayMode(RecordDelayMode mode) {
    if (mode == _delayMode) return;
    _delayMode = mode;
    notifyListeners();
  }

  void setFixedDelay(int ms) {
    final next = ms.clamp(0, macroMaxDelayMs);
    if (next == _fixedDelayMs) return;
    _fixedDelayMs = next;
    notifyListeners();
  }

  void roundFixedDelay() => setFixedDelay(roundMacroDelay(_fixedDelayMs));

  void toggleRecording() {
    _recording = !_recording;
    _capturing = null;
    _lastStamp = null;
    notifyListeners();
  }

  void stopRecording() {
    if (!_recording) return;
    _recording = false;
    _lastStamp = null;
    notifyListeners();
  }

  void recordKey(int usage, {required bool down, required Duration timestamp}) {
    if (!_recording || !isMacroKey(usage)) return;
    final last = _lastStamp;
    if (_rows.isNotEmpty && last != null) {
      final gap = switch (_delayMode) {
        RecordDelayMode.actual => roundMacroDelay(
          (timestamp - last).inMilliseconds,
        ),
        RecordDelayMode.fixed => roundMacroDelay(_fixedDelayMs),
        RecordDelayMode.none => 0,
      };
      final i = _rows.length - 1;
      _rows[i] = _rows[i].withEvent(_rows[i].event.copyWith(delayMs: gap));
    }
    _rows.add(
      MacroRow(
        _nextKey++,
        MacroEvent(
          kind: MacroEventKind.key,
          code: usage,
          action: down ? MacroAction.press : MacroAction.release,
          delayMs: _delayMode == RecordDelayMode.none ? 0 : recordedDelayMs,
        ),
      ),
    );
    _lastStamp = timestamp;
    notifyListeners();
  }

  void startCapture(int rowKey) {
    if (_recording) return;
    final row = _find(rowKey);
    if (row == null || row.event.kind != MacroEventKind.key) return;
    _capturing = rowKey;
    notifyListeners();
  }

  void cancelCapture() {
    if (_capturing == null) return;
    _capturing = null;
    notifyListeners();
  }

  void captureKey(int usage) {
    final rowKey = _capturing;
    if (rowKey == null || !isMacroKey(usage)) return;
    _capturing = null;
    _update(rowKey, (e) => e.copyWith(code: usage));
  }

  void toggleAction(int rowKey) => _update(
    rowKey,
    (e) => e.isDelay
        ? e
        : e.copyWith(
            action: e.action == MacroAction.press
                ? MacroAction.release
                : MacroAction.press,
          ),
  );

  void setDelay(int rowKey, int ms) =>
      _update(rowKey, (e) => e.copyWith(delayMs: ms.clamp(0, macroMaxDelayMs)));

  void roundDelay(int rowKey) =>
      _update(rowKey, (e) => e.copyWith(delayMs: roundMacroDelay(e.delayMs)));

  void move(int from, int to) {
    if (from < 0 || from >= _rows.length) return;
    final target = to.clamp(0, _rows.length - 1);
    if (target == from) return;
    final row = _rows.removeAt(from);
    _rows.insert(target, row);
    notifyListeners();
  }

  void remove(int rowKey) {
    final before = _rows.length;
    _rows.removeWhere((r) => r.key == rowKey);
    if (_capturing == rowKey) _capturing = null;
    if (_rows.length != before) notifyListeners();
  }

  void clear() {
    if (_rows.isEmpty) return;
    _rows.clear();
    _capturing = null;
    notifyListeners();
  }

  void addKey() {
    final key = _append(
      const MacroEvent(
        kind: MacroEventKind.key,
        code: HidUsage.firstKey,
        action: MacroAction.press,
        delayMs: recordedDelayMs,
      ),
    );
    if (!_recording) _capturing = key;
    notifyListeners();
  }

  void addMouse() {
    _append(
      const MacroEvent(
        kind: MacroEventKind.mouse,
        code: MacroMouseCode.left,
        action: MacroAction.press,
        delayMs: recordedDelayMs,
      ),
    );
    notifyListeners();
  }

  void addDelay() {
    _append(const MacroEvent.delay(insertedDelayMs));
    notifyListeners();
  }

  int _append(MacroEvent event) {
    final key = _nextKey++;
    _rows.add(MacroRow(key, event));
    return key;
  }

  MacroRow? _find(int rowKey) {
    for (final r in _rows) {
      if (r.key == rowKey) return r;
    }
    return null;
  }

  void _update(int rowKey, MacroEvent Function(MacroEvent e) change) {
    final i = _rows.indexWhere((r) => r.key == rowKey);
    if (i < 0) {
      notifyListeners();
      return;
    }
    final next = change(_rows[i].event);
    _rows[i] = _rows[i].withEvent(next);
    notifyListeners();
  }
}

String macroEventLabel(MacroEvent event) => switch (event.kind) {
  MacroEventKind.key => hidKeyName(event.code),
  MacroEventKind.mouse =>
    event.code == MacroMouseCode.left
        ? 'Left button'
        : 'Mouse 0x${event.code.toRadixString(16).toUpperCase()}',
  MacroEventKind.delay => 'Wait',
};
