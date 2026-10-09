import 'hid_transport.dart';

HidTransport createPlatformHidTransport() => const UnsupportedHidTransport();

class UnsupportedHidTransport implements HidTransport {
  const UnsupportedHidTransport();

  @override
  bool get isSupported => false;

  @override
  bool get requiresUserGrant => false;

  @override
  Stream<List<HidDeviceInfo>> get devices => const Stream.empty();

  @override
  Future<List<HidDeviceInfo>> enumerate() async => const [];

  @override
  Future<List<HidDeviceInfo>> requestDevice() async => const [];

  @override
  Future<HidConnection> open(HidDeviceInfo device) =>
      Future.error(const HidException('HID is not supported on this platform'));

  @override
  Future<void> dispose() async {}
}
