import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'platform_database.dart';

Future<PlatformDatabase> openPlatformDatabase(String name) async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final db = sqlite3.open('${directory.path}${Platform.pathSeparator}$name.db');
  db.execute('PRAGMA journal_mode = WAL');
  return (database: db, persistent: true);
}
