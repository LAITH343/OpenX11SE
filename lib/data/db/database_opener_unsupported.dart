import 'platform_database.dart';

Future<PlatformDatabase> openPlatformDatabase(String name) =>
    throw UnsupportedError(
      'OpenX11SE currently supports Windows and macOS desktop.',
    );
