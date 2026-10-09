import 'list_equality.dart';

enum MacroEventKind { key, mouse, delay }

enum MacroAction { press, release }

abstract final class MacroMouseCode {
  static const left = 0xF1;
}

class MacroEvent {
  const MacroEvent({
    required this.kind,
    required this.code,
    required this.action,
    required this.delayMs,
  });

  const MacroEvent.delay(this.delayMs)
    : kind = MacroEventKind.delay,
      code = 0,
      action = MacroAction.press;

  final MacroEventKind kind;
  final int code;
  final MacroAction action;
  final int delayMs;

  bool get isDelay => kind == MacroEventKind.delay;

  MacroEvent copyWith({
    MacroEventKind? kind,
    int? code,
    MacroAction? action,
    int? delayMs,
  }) => MacroEvent(
    kind: kind ?? this.kind,
    code: code ?? this.code,
    action: action ?? this.action,
    delayMs: delayMs ?? this.delayMs,
  );

  @override
  bool operator ==(Object other) =>
      other is MacroEvent &&
      other.kind == kind &&
      other.code == code &&
      other.action == action &&
      other.delayMs == delayMs;

  @override
  int get hashCode => Object.hash(kind, code, action, delayMs);

  @override
  String toString() =>
      'MacroEvent($kind 0x${code.toRadixString(16)} $action ${delayMs}ms)';
}

class Macro {
  Macro({this.id, required this.name, required List<MacroEvent> events})
    : events = List.unmodifiable(events);

  final int? id;
  final String name;
  final List<MacroEvent> events;

  Macro copyWith({int? id, String? name, List<MacroEvent>? events}) => Macro(
    id: id ?? this.id,
    name: name ?? this.name,
    events: events ?? this.events,
  );

  @override
  bool operator ==(Object other) =>
      other is Macro &&
      other.id == id &&
      other.name == name &&
      elementsEqual(other.events, events);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(events));

  @override
  String toString() => 'Macro($id, $name, ${events.length} events)';
}

enum MacroPlaybackMode { once, untilKey, whileHeld }

class MacroPlayback {
  const MacroPlayback({required this.mode, this.loopCount = 1});

  static const minLoopCount = 1;
  static const maxLoopCount = 255;

  static const defaults = MacroPlayback(mode: MacroPlaybackMode.once);

  final MacroPlaybackMode mode;
  final int loopCount;

  MacroPlayback copyWith({MacroPlaybackMode? mode, int? loopCount}) =>
      MacroPlayback(
        mode: mode ?? this.mode,
        loopCount: loopCount ?? this.loopCount,
      );

  @override
  bool operator ==(Object other) =>
      other is MacroPlayback &&
      other.mode == mode &&
      other.loopCount == loopCount;

  @override
  int get hashCode => Object.hash(mode, loopCount);

  @override
  String toString() => 'MacroPlayback($mode, x$loopCount)';
}
