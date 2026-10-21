import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class SystemNotifications {
  bool get isSupported;

  Future<void> requestPermission();

  Future<void> show(String text);
}

class NoSystemNotifications implements SystemNotifications {
  const NoSystemNotifications();

  @override
  bool get isSupported => false;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show(String text) async {}
}

class LocalSystemNotifications implements SystemNotifications {
  static const _appName = 'OpenX11SE';
  static const _id = 0;

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  @override
  bool get isSupported => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => !kIsWeb,
    _ => false,
  };

  Future<bool> _initialise() => _ready ??= _start();

  Future<bool> _start() async {
    try {
      final ready = await _plugin.initialize(
        settings: const InitializationSettings(
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
          windows: WindowsInitializationSettings(
            appName: _appName,
            appUserModelId: 'LAITH343.OpenX11SE',
            guid: '8f3c2a71-4d5e-4b9a-9c1f-2e7d6a0b5c34',
          ),
        ),
      );
      return defaultTargetPlatform == TargetPlatform.macOS || (ready ?? false);
    } on Object {
      return false;
    }
  }

  @override
  Future<void> requestPermission() async {
    if (!isSupported || !await _initialise()) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
    } on Object {
      return;
    }
  }

  @override
  Future<void> show(String text) async {
    if (!isSupported || !await _initialise()) return;
    try {
      await _plugin.show(
        id: _id,
        title: _appName,
        body: text,
        notificationDetails: const NotificationDetails(
          macOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
      );
    } on Object {
      return;
    }
  }
}
