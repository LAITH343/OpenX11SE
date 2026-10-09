import 'dart:async';
import 'dart:typed_data';

import 'package:openx11se/data/hid/hid_transport.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/domain/device_info.dart';

import 'golden_vectors.dart';

const wiredDevice = HidDeviceInfo(
  id: 'wired',
  vendorId: X11seUsb.vendorId,
  productId: X11seUsb.wiredProductId,
);

const dongleDevice = HidDeviceInfo(
  id: 'dongle',
  vendorId: X11seUsb.vendorId,
  productId: X11seUsb.dongleProductId,
);

class FakeHidConnection implements HidConnection {
  FakeHidConnection(
    this.device, {
    this.supportsNotifications = true,
    this.autoAck = true,
    this.busyResponses = 1,
    int version = 0x0105,
    Uint8List? snapshot,
  }) : responses = {
         ReportId.version: hex(
           '0B 08 ${(version >> 8).toRadixString(16)} '
           '${(version & 0xFF).toRadixString(16)} 00 00 00 00',
         ),
         ReportId.snapshot: snapshot ?? defaultSnapshot,
       };

  @override
  final HidDeviceInfo device;
  @override
  final bool supportsNotifications;
  bool autoAck;
  int busyResponses;
  bool asleep = false;
  final List<Uint8List> staleResponses = [];
  Uint8List? _lastRequest;
  final Map<int, Uint8List> responses;
  final List<Uint8List> sent = [];
  final _notifications = StreamController<Uint8List>.broadcast(sync: true);
  final _closed = Completer<void>();
  int _pendingBusy = 0;
  bool isClosed = false;

  @override
  ConnectionType get connectionType => device.connection;

  @override
  Stream<Uint8List> get notifications => _notifications.stream;

  @override
  Future<void> get closed => _closed.future;

  List<int> get writtenReportIds => [
    for (final r in sent)
      if (r[0] != ReportId.readRequest) r[0],
  ];

  void notify(String bytes) => _notifications.add(hex(bytes));

  void unplug() {
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  Future<void> setFeature(Uint8List report) async {
    if (isClosed || _closed.isCompleted) {
      throw const HidException('gone', disconnected: true);
    }
    sent.add(Uint8List.fromList(report));
    if (report[0] == ReportId.readRequest) {
      _lastRequest = Uint8List.fromList(report);
      _pendingBusy = busyResponses;
    } else if (autoAck && report[0] != ReportId.restoreDefaults) {
      scheduleMicrotask(
        () => notify('03 07 50 00 ${report[0].toRadixString(16)}'),
      );
    }
  }

  @override
  Future<Uint8List> getFeature(int reportId, int length) async {
    if (asleep) {
      final echo = Uint8List(length);
      echo.setAll(0, _lastRequest ?? const []);
      return echo;
    }
    if (staleResponses.isNotEmpty) return staleResponses.removeAt(0);
    if (_pendingBusy > 0) {
      _pendingBusy--;
      return hex('A0 01 00 00 00 00 00 00', length);
    }
    final response = responses[reportId];
    if (response == null) throw const HidException('stall');
    return response;
  }

  @override
  Future<void> close() async {
    isClosed = true;
    await _notifications.close();
    if (!_closed.isCompleted) _closed.complete();
  }
}

class FakeHidTransport implements HidTransport {
  final _devices = StreamController<List<HidDeviceInfo>>.broadcast(sync: true);
  final Map<String, FakeHidConnection Function()> factories = {};
  final List<FakeHidConnection> opened = [];
  List<HidDeviceInfo> present = const [];

  @override
  bool get isSupported => true;

  @override
  bool get requiresUserGrant => false;

  @override
  Stream<List<HidDeviceInfo>> get devices => _devices.stream;

  void setPresent(List<HidDeviceInfo> devices) {
    present = devices;
    _devices.add(devices);
  }

  @override
  Future<List<HidDeviceInfo>> enumerate() async => present;

  @override
  Future<List<HidDeviceInfo>> requestDevice() async => present;

  @override
  Future<HidConnection> open(HidDeviceInfo device) async {
    final connection =
        factories[device.id]?.call() ?? FakeHidConnection(device);
    opened.add(connection);
    return connection;
  }

  @override
  Future<void> dispose() => _devices.close();
}
