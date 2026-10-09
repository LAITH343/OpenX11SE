import 'package:sqlite3/wasm.dart';

Future<CommonDatabase> openPlatformDatabase(String name) async {
  final sqlite = await WasmSqlite3.loadFromUrl(
    Uri.base.resolve('sqlite3.wasm'),
  );
  final fileSystem = await IndexedDbFileSystem.open(dbName: name);
  sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
  return sqlite.open('/$name.db');
}
