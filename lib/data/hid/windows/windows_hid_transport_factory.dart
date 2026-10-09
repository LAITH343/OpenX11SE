import 'dart:io';

import '../hid_transport.dart';
import '../unsupported_hid_transport.dart';
import 'windows_hid_transport.dart';

HidTransport createPlatformHidTransport() => Platform.isWindows
    ? WindowsHidTransport()
    : const UnsupportedHidTransport();
