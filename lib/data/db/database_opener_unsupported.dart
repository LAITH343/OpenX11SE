import 'platform_database.dart';

Future<PlatformDatabase> openPlatformDatabase(String name) =>
    throw UnsupportedError('No database is available on this platform');
