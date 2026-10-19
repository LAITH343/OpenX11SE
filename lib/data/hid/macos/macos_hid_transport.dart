import 'dart:async';

import 'package:flutter/services.dart';

import '../../../domain/device_info.dart';
import '../device_polling.dart';
import '../hid_transport.dart';

class MacHidInterface {
  const MacHidInterface({
    required this.id,
    required this.vendorId,
    required this.productId,
    required this.locationId,
    required this.usagePages,
    required this.featureLength,
    required this.inputLength,
    this.productName,
  });

  factory MacHidInterface.fromMap(Map<Object?, Object?> map) {
    final usages = map['usages'];
    return MacHidInterface(
      id: map['id']! as String,
      vendorId: map['vendorId']! as int,
      productId: map['productId']! as int,
      locationId: map['locationId']! as int,
      productName: map['product'] as String?,
      usagePages: {
        if (usages is List<Object?>)
          for (final pair in usages)
            if (pair is List<Object?> && pair.isNotEmpty) pair.first! as int,
      },
      featureLength: map['featureLength']! as int,
      inputLength: map['inputLength']! as int,
    );
  }

  final String id;
  final int vendorId;
  final int productId;
  final int locationId;
  final String? productName;
  final Set<int> usagePages;
  final int featureLength;
  final int inputLength;
}

class MacHidDevice {
  const MacHidDevice({
    required this.info,
    required this.feature,
    this.notification,
  });

  final HidDeviceInfo info;
  final MacHidInterface feature;
  final MacHidInterface? notification;
}

List<MacHidDevice> groupMacInterfaces(Iterable<MacHidInterface> interfaces) {
  final groups = <String, List<MacHidInterface>>{};
  for (final i in interfaces) {
    if (i.vendorId != X11seUsb.vendorId ||
        !X11seUsb.productIds.contains(i.productId)) {
      continue;
    }
    final key =
        '${i.vendorId.toRadixString(16)}:${i.productId.toRadixString(16)}:'
        '${i.locationId.toRadixString(16)}';
    groups.putIfAbsent(key, () => []).add(i);
  }
  final devices = <MacHidDevice>[];
  for (final MapEntry(key: id, value: members) in groups.entries) {
    members.sort((a, b) => a.id.compareTo(b.id));
    final feature =
        members
            .where(
              (i) =>
                  i.usagePages.contains(X11seUsb.featureUsagePage) &&
                  i.featureLength > 0,
            )
            .firstOrNull ??
        members.where((i) => i.featureLength > 0).firstOrNull;
    if (feature == null) continue;
    final notification = members
        .where(
          (i) =>
              i.usagePages.contains(X11seUsb.notificationUsagePage) &&
              i.inputLength > 0,
        )
        .firstOrNull;
    devices.add(
      MacHidDevice(
        info: HidDeviceInfo(
          id: id,
          vendorId: feature.vendorId,
          productId: feature.productId,
          productName: feature.productName,
        ),
        feature: feature,
        notification: notification,
      ),
    );
  }
  devices.sort((a, b) => a.info.id.compareTo(b.info.id));
  return devices;
}

HidException _hidError(PlatformException e) =>
    HidException(e.message ?? e.code, disconnected: e.code == 'disconnected');

class MacHidTransport with DevicePolling implements HidTransport {
  MacHidTransport({
    this.pollInterval = const Duration(milliseconds: 1500),
    this._methods = const MethodChannel('openx11se/hid'),
    this._events = const EventChannel('openx11se/hid/events'),
  });

  @override
  final Duration pollInterval;
  final MethodChannel _methods;
  final EventChannel _events;

  final Map<String, MacHidDevice> _entries = {};
  final Map<int, MacHidConnection> _byHandle = {};
  StreamSubscription<Object?>? _eventSubscription;
  bool _disposed = false;

  @override
  bool get pollingDisposed => _disposed;

  @override
  HidAvailability get availability => HidAvailability.available;

  @override
  Stream<List<HidDeviceInfo>> get devices => deviceList.stream;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (_disposed) throw const HidException('Transport disposed');
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw _hidError(e);
    }
  }

  @override
  Future<List<HidDeviceInfo>> enumerate() async {
    final raw = await _invoke<List<Object?>>('enumerate') ?? const [];
    final found = groupMacInterfaces(
      raw.whereType<Map<Object?, Object?>>().map(MacHidInterface.fromMap),
    );
    _entries
      ..clear()
      ..addEntries(found.map((d) => MapEntry(d.info.id, d)));
    return [for (final d in found) d.info];
  }

  void _ensureEvents() {
    _eventSubscription ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object _) {},
    );
  }

  void _onEvent(Object? event) {
    if (event is! Map<Object?, Object?>) return;
    final connection = _byHandle[event['handle']];
    if (connection == null) return;
    switch (event['event']) {
      case 'report':
        final data = event['data'];
        if (data is Uint8List) connection._report(data);
      case 'removed':
        connection._markClosed();
    }
  }

  @override
  Future<HidConnection> open(HidDeviceInfo device) async {
    var entry = _entries[device.id];
    if (entry == null) {
      await enumerate();
      entry = _entries[device.id];
    }
    if (entry == null) {
      throw const HidException('Device not found', disconnected: true);
    }
    _ensureEvents();
    final feature = (await _invoke<int>('open', {'id': entry.feature.id}))!;
    final connection = MacHidConnection._(this, entry, feature);
    _byHandle[feature] = connection;
    final notification = entry.notification;
    if (notification != null) {
      try {
        final handle = notification.id == entry.feature.id
            ? feature
            : (await _invoke<int>('open', {'id': notification.id}))!;
        if (connection._closing) {
          if (handle != feature) await _release(handle);
          throw const HidException('Device closed', disconnected: true);
        }
        _byHandle[handle] = connection;
        connection._notificationHandle = handle;
        await _invoke<void>('listen', {
          'handle': handle,
          'length': notification.inputLength,
        });
        connection._listening = true;
      } on HidException catch (e) {
        if (e.disconnected) {
          await connection.close();
          rethrow;
        }
        connection._listening = false;
      }
    }
    if (connection._closing) {
      throw const HidException('Device closed', disconnected: true);
    }
    return connection;
  }

  Future<void> _release(int handle) async {
    _byHandle.remove(handle);
    if (_disposed) return;
    try {
      await _invoke<void>('close', {'handle': handle});
    } on HidException {
      return;
    }
  }

  @override
  Future<void> dispose() async {
    for (final connection in {..._byHandle.values}) {
      await connection.close();
    }
    _disposed = true;
    stopPolling();
    await deviceList.close();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}

class MacHidConnection implements HidConnection {
  MacHidConnection._(this._transport, this._entry, this._featureHandle);

  final MacHidTransport _transport;
  final MacHidDevice _entry;
  final int _featureHandle;
  int? _notificationHandle;
  bool _listening = false;
  final _notifications = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();
  bool _closing = false;

  @override
  HidDeviceInfo get device => _entry.info;

  @override
  ConnectionType get connectionType => _entry.info.connection;

  @override
  bool get supportsNotifications => _listening;

  @override
  Stream<Uint8List> get notifications => _notifications.stream;

  @override
  Future<void> get closed => _closed.future;

  void _report(Uint8List data) {
    if (!_notifications.isClosed) _notifications.add(data);
  }

  @override
  Future<void> setFeature(Uint8List report) =>
      _call('setFeature', {'handle': _featureHandle, 'data': report});

  @override
  Future<Uint8List> getFeature(int reportId, int length) async =>
      (await _call<Uint8List>('getFeature', {
        'handle': _featureHandle,
        'reportId': reportId,
        'length': length,
      }))!;

  Future<T?> _call<T>(String method, Map<String, Object?> args) async {
    if (_closing) {
      throw const HidException('Device closed', disconnected: true);
    }
    try {
      return await _transport._invoke<T>(method, args);
    } on HidException catch (e) {
      if (e.disconnected) _markClosed();
      rethrow;
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
    final notification = _notificationHandle;
    if (notification != null && notification != _featureHandle) {
      await _transport._release(notification);
    }
    await _transport._release(_featureHandle);
    await _notifications.close();
    if (!_closed.isCompleted) _closed.complete();
  }
}
