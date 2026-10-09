import 'app_database.dart';
import 'database_opener_unsupported.dart'
    if (dart.library.js_interop) 'database_opener_web.dart'
    if (dart.library.ffi) 'database_opener_native.dart'
    as platform;

const databaseName = 'openx11se';

Future<AppDatabase> openAppDatabase() async {
  final opened = await platform.openPlatformDatabase(databaseName);
  return AppDatabase(opened.database, persistent: opened.persistent);
}
