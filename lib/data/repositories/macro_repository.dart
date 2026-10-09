import 'package:sqlite3/common.dart';

import '../../domain/macro.dart';
import '../db/app_database.dart';
import '../db/schema.dart';

class MacroRepository {
  MacroRepository(this._db);

  final AppDatabase _db;

  static const _tables = {Tables.macros, Tables.macroEvents};

  CommonDatabase get _raw => _db.raw;

  Stream<List<Macro>> watchMacros() => _db.watch(_tables, _all);

  Future<List<Macro>> macros() async => _all();

  Future<Macro?> macro(int id) async => _byId(id);

  Future<Macro> create(Macro macro) async {
    final id = _db.transaction(() {
      final now = _db.nowMs;
      _raw.execute(
        'INSERT INTO macros (name, created_at, updated_at) VALUES (?, ?, ?)',
        [_validName(macro.name), now, now],
      );
      final id = _raw.lastInsertRowId;
      _writeEvents(id, macro.events);
      return id;
    });
    _db.notify(_tables);
    return _byId(id)!;
  }

  Future<Macro> save(Macro macro) async {
    final id = macro.id;
    if (id == null) return create(macro);
    _require(id);
    _db.transaction(() {
      _raw.execute('UPDATE macros SET name = ?, updated_at = ? WHERE id = ?', [
        _validName(macro.name),
        _db.nowMs,
        id,
      ]);
      _raw.execute('DELETE FROM macro_events WHERE macro_id = ?', [id]);
      _writeEvents(id, macro.events);
    });
    _db.notify(_tables);
    return _byId(id)!;
  }

  Future<Macro> duplicate(int id, {String? name}) async {
    final source = _require(id);
    return create(
      Macro(name: name ?? '${source.name} copy', events: source.events),
    );
  }

  Future<void> delete(int id) async {
    _require(id);
    _raw.execute('DELETE FROM macros WHERE id = ?', [id]);
    _db.notify({..._tables, Tables.buttonMacroLinks});
  }

  void _writeEvents(int macroId, List<MacroEvent> events) {
    final insert = _raw.prepare(
      'INSERT INTO macro_events '
      '(macro_id, position, kind, code, action, delay_ms) '
      'VALUES (?, ?, ?, ?, ?, ?)',
    );
    try {
      for (var i = 0; i < events.length; i++) {
        final e = events[i];
        insert.execute([
          macroId,
          i,
          e.kind.name,
          e.code,
          e.action.name,
          e.delayMs,
        ]);
      }
    } finally {
      insert.close();
    }
  }

  List<Macro> _all() => _query('SELECT * FROM macros ORDER BY id');

  Macro? _byId(int id) {
    final found = _query('SELECT * FROM macros WHERE id = ?', [id]);
    return found.isEmpty ? null : found.single;
  }

  Macro _require(int id) =>
      _byId(id) ?? (throw StateError('Macro $id does not exist'));

  List<Macro> _query(String sql, [List<Object?> args = const []]) {
    final rows = _raw.select(sql, args);
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r['id'] as int];
    final events = <int, List<MacroEvent>>{};
    for (final row in _raw.select(
      'SELECT * FROM macro_events WHERE macro_id IN '
      '(${List.filled(ids.length, '?').join(', ')}) '
      'ORDER BY macro_id, position',
      ids,
    )) {
      (events[row['macro_id'] as int] ??= []).add(
        MacroEvent(
          kind: MacroEventKind.values.byName(row['kind'] as String),
          code: row['code'] as int,
          action: MacroAction.values.byName(row['action'] as String),
          delayMs: row['delay_ms'] as int,
        ),
      );
    }
    return [
      for (final row in rows)
        Macro(
          id: row['id'] as int,
          name: row['name'] as String,
          events: events[row['id']] ?? const [],
        ),
    ];
  }

  static String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'is empty');
    return trimmed;
  }
}
