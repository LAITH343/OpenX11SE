import 'package:sqlite3/common.dart';

Future<CommonDatabase> openPlatformDatabase(String name) =>
    throw UnsupportedError('No database is available on this platform');
