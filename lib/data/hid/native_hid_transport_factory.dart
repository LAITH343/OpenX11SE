import 'dart:io';

import 'hid_transport.dart';
import 'linux/linux_hid_transport.dart';
import 'macos/macos_hid_transport.dart';
import 'unsupported_hid_transport.dart';
import 'windows/windows_hid_transport.dart';

HidTransport createPlatformHidTransport() {
  if (Platform.isWindows) return WindowsHidTransport();
  if (Platform.isMacOS) return MacHidTransport();
  if (Platform.isLinux) return LinuxHidTransport();
  return const UnsupportedHidTransport();
}
