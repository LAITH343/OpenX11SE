import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/system/system_integration.dart';
import 'package:openx11se/data/system/system_integration_native.dart';

void main() {
  test('writes and removes the macOS launch agent', () async {
    final home = await Directory.systemTemp.createTemp('launch_home');
    addTearDown(() => home.delete(recursive: true));
    final system = MacSystemIntegration(home: home.path);
    final agent = File(
      '${home.path}/Library/LaunchAgents/${MacSystemIntegration.label}.plist',
    );

    await system.setLaunchAtStartup(true);
    final plist = agent.readAsStringSync();
    expect(plist, contains('<string>/usr/bin/open</string>'));
    expect(plist, contains('<string>${MacSystemIntegration.label}</string>'));
    expect(plist, contains('<string>$startMinimisedArgument</string>'));
    expect(plist, contains('<key>RunAtLoad</key>'));

    await system.setLaunchAtStartup(false);
    expect(agent.existsSync(), isFalse);
    await system.setLaunchAtStartup(false);
  });

  test('writes and removes the Linux autostart entry', () async {
    final config = await Directory.systemTemp.createTemp('autostart_config');
    addTearDown(() => config.delete(recursive: true));
    final system = LinuxSystemIntegration(
      environment: {
        'XDG_CONFIG_HOME': config.path,
        'APPIMAGE': '/home/me/.local/bin/OpenX11SE.AppImage',
      },
      executable: '/tmp/.mount_OpenX1/usr/bin/openx11se',
    );
    final entry = File(
      '${config.path}/autostart/${LinuxSystemIntegration.appId}.desktop',
    );

    await system.setLaunchAtStartup(true);
    expect(
      entry.readAsStringSync(),
      contains(
        'Exec="/home/me/.local/bin/OpenX11SE.AppImage" '
        '$startMinimisedArgument',
      ),
    );

    await system.setLaunchAtStartup(false);
    expect(entry.existsSync(), isFalse);
    await system.setLaunchAtStartup(false);
  });

  test('Linux autostart falls back to the executable outside an AppImage', () {
    final system = LinuxSystemIntegration(
      environment: {'HOME': '/home/me'},
      executable: '/opt/openx11se/openx11se',
    );
    expect(system.launchPath, '/opt/openx11se/openx11se');
    expect(
      system.autostartEntry.path,
      '/home/me/.config/autostart/${LinuxSystemIntegration.appId}.desktop',
    );
  });

  test('autostart entry escapes the executable path', () {
    expect(
      autostartDesktopEntry(r'/opt/a "b" $c\d'),
      contains(r'Exec="/opt/a \\"b\\" \\$c\\\\d"'),
    );
  });
}
