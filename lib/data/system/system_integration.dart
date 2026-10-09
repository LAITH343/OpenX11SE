import 'system_integration_none.dart'
    if (dart.library.ffi) 'system_integration_native.dart'
    as platform;

abstract interface class SystemIntegration {
  bool get supportsStartup;

  bool get supportsTray;

  Future<void> setLaunchAtStartup(bool enabled);

  Future<void> setMinimiseToTray(bool enabled);
}

class NoSystemIntegration implements SystemIntegration {
  const NoSystemIntegration();

  @override
  bool get supportsStartup => false;

  @override
  bool get supportsTray => false;

  @override
  Future<void> setLaunchAtStartup(bool enabled) async {}

  @override
  Future<void> setMinimiseToTray(bool enabled) async {}
}

const startMinimisedArgument = '--minimized';

SystemIntegration createSystemIntegration() =>
    platform.createPlatformIntegration();
