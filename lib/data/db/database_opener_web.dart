import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

import 'platform_database.dart';

Future<PlatformDatabase> openPlatformDatabase(String name) async {
  final sqlite = await WasmSqlite3.load(await _fetchModule());
  try {
    final fileSystem = await IndexedDbFileSystem.open(dbName: name);
    sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
    return (database: sqlite.open('/$name.db'), persistent: true);
  } on Object {
    return (database: sqlite.openInMemory(), persistent: false);
  }
}

Future<Uint8List> _fetchModule() async {
  final url = Uri.parse(web.document.baseURI).resolve('sqlite3.wasm');
  final response = await web.window.fetch(url.toString().toJS).toDart;
  if (!response.ok) {
    throw StateError('sqlite3.wasm could not be loaded (${response.status})');
  }
  return (await response.arrayBuffer().toDart).toDart.asUint8List();
}
