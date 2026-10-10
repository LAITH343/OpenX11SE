import 'hid_transport.dart';
import 'unsupported_hid_transport.dart'
    if (dart.library.ffi) 'windows/windows_hid_transport_factory.dart'
    as platform;

HidTransport createHidTransport() => platform.createPlatformHidTransport();
