import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../../domain/device_info.dart';
import '../../protocol/device_reads.dart';
import '../hid_transport.dart';
import 'web_hid_bindings.dart';

const _connectEvent = 'connect';
const _disconnectEvent = 'disconnect';
const _inputReportEvent = 'inputreport';

class WebHidTransport implements HidTransport {
  WebHidTransport() : _hid = navigatorHid;

  final Hid? _hid;
  final Map<String, List<HidDevice>> _groups = {};
  late final StreamController<List<HidDeviceInfo>> _devices =
      StreamController.broadcast(onListen: _listen, onCancel: _unlisten);
  JSFunction? _onConnectionChange;

  @override
  HidAvailability get availability => _hid != null
      ? HidAvailability.available
      : web.window.isSecureContext
      ? HidAvailability.unsupported
      : HidAvailability.insecureContext;

  @override
  bool get requiresUserGrant => true;

  @override
  Stream<List<HidDeviceInfo>> get devices => _devices.stream;

  void _listen() {
    final hid = _hid;
    if (hid == null) return;
    final handler = ((web.Event _) => unawaited(_emit())).toJS;
    _onConnectionChange = handler;
    hid
      ..addEventListener(_connectEvent, handler)
      ..addEventListener(_disconnectEvent, handler);
    unawaited(_emit());
  }

  void _unlisten() {
    final hid = _hid;
    final handler = _onConnectionChange;
    if (hid == null || handler == null) return;
    hid
      ..removeEventListener(_connectEvent, handler)
      ..removeEventListener(_disconnectEvent, handler);
    _onConnectionChange = null;
  }

  Future<void> _emit() async {
    try {
      final list = await enumerate();
      if (!_devices.isClosed) _devices.add(list);
    } on Object catch (e, s) {
      if (!_devices.isClosed) _devices.addError(e, s);
    }
  }

  @override
  Future<List<HidDeviceInfo>> enumerate() async {
    final hid = _hid;
    if (hid == null) return const [];
    return _group((await hid.getDevices().toDart).toDart);
  }

  @override
  Future<List<HidDeviceInfo>> requestDevice() async {
    final hid = _hid;
    if (hid == null) return const [];
    final filters = [
      for (final pid in X11seUsb.productIds)
        HidDeviceFilter(vendorId: X11seUsb.vendorId, productId: pid),
    ];
    await hid
        .requestDevice(HidDeviceRequestOptions(filters: filters.toJS))
        .toDart;
    final list = await enumerate();
    if (!_devices.isClosed) _devices.add(list);
    return list;
  }

  List<HidDeviceInfo> _group(List<HidDevice> devices) {
    _groups.clear();
    for (final d in devices) {
      if (d.vendorId != X11seUsb.vendorId ||
          !X11seUsb.productIds.contains(d.productId)) {
        continue;
      }
      _groups.putIfAbsent(_groupId(d.productId), () => []).add(d);
    }
    return [
      for (final MapEntry(key: id, value: members) in _groups.entries)
        HidDeviceInfo(
          id: id,
          vendorId: members.first.vendorId,
          productId: members.first.productId,
          productName: members.first.productName,
        ),
    ];
  }

  static String _groupId(int productId) =>
      'webhid:${productId.toRadixString(16).padLeft(4, '0')}';

  @override
  Future<HidConnection> open(HidDeviceInfo device) async {
    final hid = _hid;
    if (hid == null) {
      throw const HidException('WebHID is not available in this browser');
    }
    var members = _groups[device.id];
    if (members == null) {
      await enumerate();
      members = _groups[device.id];
    }
    if (members == null || members.isEmpty) {
      throw const HidException('Device not found', disconnected: true);
    }
    final feature =
        _withCollection(members, X11seUsb.featureUsagePage, feature: true) ??
        members.first;
    final notification = _withCollection(
      members,
      X11seUsb.notificationUsagePage,
      feature: false,
    );
    final toOpen = [
      feature,
      if (notification != null && notification != feature) notification,
    ];
    try {
      for (final d in toOpen) {
        if (!d.opened) await d.open().toDart;
      }
    } on Object catch (e) {
      throw HidException('Could not open device: $e');
    }
    return WebHidConnection._(hid, device, feature, notification, toOpen);
  }

  static HidDevice? _withCollection(
    List<HidDevice> devices,
    int usagePage, {
    required bool feature,
  }) {
    for (final d in devices) {
      for (final c in d.collections.toDart) {
        if (c.usagePage != usagePage) continue;
        final reports = feature ? c.featureReports : c.inputReports;
        if (reports == null || reports.length > 0) return d;
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    _unlisten();
    await _devices.close();
  }
}

class WebHidConnection implements HidConnection {
  WebHidConnection._(
    this._hid,
    this.device,
    this._feature,
    this._notification,
    this._opened,
  ) {
    final input = ((web.Event e) => _onInput(e as HidInputReportEvent)).toJS;
    final disconnect = ((web.Event e) {
      final d = (e as HidConnectionEvent).device;
      if (_opened.contains(d)) _markClosed();
    }).toJS;
    _onInputReport = input;
    _onDisconnect = disconnect;
    _notification?.addEventListener(_inputReportEvent, input);
    _hid.addEventListener(_disconnectEvent, disconnect);
  }

  final Hid _hid;
  @override
  final HidDeviceInfo device;
  final HidDevice _feature;
  final HidDevice? _notification;
  final List<HidDevice> _opened;
  late final JSFunction _onInputReport;
  late final JSFunction _onDisconnect;
  final _notifications = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();
  bool _closing = false;

  @override
  ConnectionType get connectionType => device.connection;

  @override
  bool get supportsNotifications => _notification != null;

  @override
  Stream<Uint8List> get notifications => _notifications.stream;

  @override
  Future<void> get closed => _closed.future;

  void _onInput(HidInputReportEvent event) {
    if (_notifications.isClosed) return;
    final data = event.data.toDart;
    final bytes = Uint8List(data.lengthInBytes + 1)
      ..[0] = event.reportId
      ..setAll(
        1,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    _notifications.add(bytes);
  }

  @override
  Future<void> setFeature(Uint8List report) async {
    _ensureOpen();
    try {
      await _feature
          .sendFeatureReport(report[0], Uint8List.sublistView(report, 1).toJS)
          .toDart;
    } on Object catch (e) {
      throw HidException('sendFeatureReport failed: $e');
    }
  }

  @override
  Future<Uint8List> getFeature(int reportId, int length) async {
    _ensureOpen();
    final ByteData data;
    try {
      data = (await _feature.receiveFeatureReport(reportId).toDart).toDart;
    } on Object catch (e) {
      throw HidException('receiveFeatureReport failed: $e');
    }
    final raw = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final withId =
        raw.isNotEmpty && (raw[0] == reportId || isBusyResponse(raw));
    final out = Uint8List(length);
    if (withId) {
      out.setRange(0, raw.length < length ? raw.length : length, raw);
    } else {
      out[0] = reportId;
      final n = raw.length < length - 1 ? raw.length : length - 1;
      out.setRange(1, 1 + n, raw);
    }
    return out;
  }

  void _ensureOpen() {
    if (_closing) {
      throw const HidException('Device closed', disconnected: true);
    }
  }

  void _markClosed() {
    if (!_closed.isCompleted) _closed.complete();
    unawaited(close());
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    _notification?.removeEventListener(_inputReportEvent, _onInputReport);
    _hid.removeEventListener(_disconnectEvent, _onDisconnect);
    for (final d in _opened) {
      try {
        if (d.opened) await d.close().toDart;
      } on Object {
        // Device may already be gone.
      }
    }
    await _notifications.close();
    if (!_closed.isCompleted) _closed.complete();
  }
}
