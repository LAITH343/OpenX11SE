import 'dart:async';

import 'package:sqlite3/common.dart';

import 'schema.dart';

class AppDatabase {
  AppDatabase(this.raw, {DateTime Function()? clock, this.persistent = true})
    : _clock = clock ?? DateTime.now {
    raw.execute('PRAGMA foreign_keys = ON');
    migrateSchema(raw);
  }

  final CommonDatabase raw;
  final bool persistent;
  final DateTime Function() _clock;
  final _changes = StreamController<Set<String>>.broadcast(sync: true);

  int get nowMs => _clock().toUtc().millisecondsSinceEpoch;

  T transaction<T>(T Function() body) {
    raw.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      raw.execute('COMMIT');
      return result;
    } catch (_) {
      raw.execute('ROLLBACK');
      rethrow;
    }
  }

  void notify(Set<String> tables) => _changes.add(tables);

  Stream<T> watch<T>(Set<String> tables, T Function() query) {
    late final StreamController<T> controller;
    StreamSubscription<Set<String>>? subscription;
    void emit() {
      try {
        controller.add(query());
      } catch (error, stack) {
        controller.addError(error, stack);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        subscription = _changes.stream
            .where((changed) => changed.any(tables.contains))
            .listen((_) => emit());
        emit();
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  Future<void> close() async {
    await _changes.close();
    raw.close();
  }
}
