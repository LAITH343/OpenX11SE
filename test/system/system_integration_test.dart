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
}
