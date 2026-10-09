import '../hid_transport.dart';
import 'web_hid_transport.dart';

HidTransport createPlatformHidTransport() => WebHidTransport();
