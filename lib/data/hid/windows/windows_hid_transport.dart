import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../domain/device_info.dart';
import '../hid_transport.dart';
import 'hid_isolates.dart';

class WindowsHidTransport implements HidTransport {
  WindowsHidTransport({this.pollInterval = const Duration(milliseconds: 1500)});

  final Duration pollInterval;

  _HidWorker? _worker;
  Future<_HidWorker>? _starting;
  final Map<String, EnumeratedDevice> _entries = {};
  late final StreamController<List<HidDeviceInfo>> _devices =
      StreamController.broadcast(
        onListen: _startPolling,
        onCancel: _stopPolling,
      );
  Timer? _poll;
  List<HidDeviceInfo> _last = const [];
  bool _emitted = false;
  bool _enumerating = false;
  bool _disposed = false;

  @override
  bool get isSupported => true;

  @override
  bool get requiresUserGrant => false;

  @override
  Stream<List<HidDeviceInfo>> get devices => _devices.stream;

  Future<_HidWorker> _ensureWorker() {
    if (_disposed) {
      return Future.error(const HidException('Transport disposed'));
    }
    final worker = _worker;
    if (worker != null) return Future.value(worker);
    return _starting ??= _HidWorker.spawn().then((w) {
      _worker = w;
      _starting = null;
      return w;
    });
  }

  @override
  Future<List<HidDeviceInfo>> enumerate() async {
    final worker = await _ensureWorker();
    final found =
        (await worker.request([WorkerOp.enumerate]))! as List<EnumeratedDevice>;
    _entries
      ..clear()
      ..addEntries(found.map((d) => MapEntry(d.info.id, d)));
    return [for (final d in found) d.info];
  }

  @override
  Future<List<HidDeviceInfo>> requestDevice() => enumerate();

  void _startPolling() {
    _poll ??= Timer.periodic(pollInterval, (_) => _refresh());
    _refresh();
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
    _emitted = false;
  }

  Future<void> _refresh() async {
    if (_enumerating || _disposed) return;
    _enumerating = true;
    try {
      final list = await enumerate();
      if (!_emitted || !_sameDevices(list, _last)) {
        _emitted = true;
        _last = list;
        if (!_devices.isClosed) _devices.add(list);
      }
    } on Object catch (e, s) {
      if (!_devices.isClosed) _devices.addError(e, s);
    } finally {
      _enumerating = false;
    }
  }

  @override
  Future<HidConnection> open(HidDeviceInfo device) async {
    final worker = await _ensureWorker();
    var entry = _entries[device.id];
    if (entry == null) {
      await enumerate();
      entry = _entries[device.id];
    }
    if (entry == null) {
      throw const HidException('Device not found', disconnected: true);
    }
    final handle =
        (await worker.request([WorkerOp.open, entry.featurePath]))! as int;
    final connection = WindowsHidConnection._(worker, entry, handle);
    await connection._startReader();
    return connection;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _stopPolling();
    await _devices.close();
    _worker?.kill();
    _worker = null;
  }
}

bool _sameDevices(List<HidDeviceInfo> a, List<HidDeviceInfo> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class WindowsHidConnection implements HidConnection {
  WindowsHidConnection._(this._worker, this._entry, this._handle);

  final _HidWorker _worker;
  final EnumeratedDevice _entry;
  final int _handle;
  final _notifications = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();
  ReceivePort? _readerEvents;
  SendPort? _readerControl;
  Completer<void>? _readerDone;
  bool _closing = false;

  @override
  HidDeviceInfo get device => _entry.info;

  @override
  ConnectionType get connectionType => _entry.info.connection;

  @override
  bool get supportsNotifications => _readerControl != null;

  @override
  Stream<Uint8List> get notifications => _notifications.stream;

  @override
  Future<void> get closed => _closed.future;

  Future<void> _startReader() async {
    final path = _entry.notificationPath;
    if (path == null || _entry.notificationLength <= 0) return;
    final events = ReceivePort();
    final ready = Completer<void>();
    final done = Completer<void>();
    _readerEvents = events;
    _readerDone = done;
    events.listen((message) {
      final m = message as List<Object?>;
      switch (m[0]) {
        case ReaderEvent.ready:
          _readerControl = m[1]! as SendPort;
          if (!ready.isCompleted) ready.complete();
        case ReaderEvent.data:
          if (!_notifications.isClosed) _notifications.add(m[1]! as Uint8List);
        case ReaderEvent.error:
          if (!ready.isCompleted) ready.complete();
          if (m[2]! as bool) _markClosed();
        case ReaderEvent.done:
          if (!ready.isCompleted) ready.complete();
          if (!done.isCompleted) done.complete();
          events.close();
      }
    });
    await Isolate.spawn(notificationReaderMain, [
      events.sendPort,
      path,
      _entry.notificationLength,
    ]);
    await ready.future;
  }

  @override
  Future<void> setFeature(Uint8List report) =>
      _call([WorkerOp.setFeature, _handle, report]);

  @override
  Future<Uint8List> getFeature(int reportId, int length) async =>
      (await _call([WorkerOp.getFeature, _handle, reportId, length]))!
          as Uint8List;

  Future<Object?> _call(List<Object?> message) async {
    if (_closing) {
      throw const HidException('Device closed', disconnected: true);
    }
    try {
      return await _worker.request(message);
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
    _readerControl?.send(null);
    final done = _readerDone;
    if (done != null) {
      await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    }
    _readerEvents?.close();
    try {
      await _worker.request([WorkerOp.close, _handle]);
    } on HidException {
      // Handle already invalid after a disconnect.
    }
    await _notifications.close();
    if (!_closed.isCompleted) _closed.complete();
  }
}

class _HidWorker {
  _HidWorker._(this._isolate, this._requests, this._replies);

  final Isolate _isolate;
  final SendPort _requests;
  final ReceivePort _replies;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;

  static Future<_HidWorker> spawn() async {
    final replies = ReceivePort();
    final first = Completer<SendPort>();
    late final _HidWorker worker;
    replies.listen((message) {
      if (message is SendPort) {
        first.complete(message);
        return;
      }
      worker._onReply(message as List<Object?>);
    });
    final isolate = await Isolate.spawn(hidWorkerMain, replies.sendPort);
    worker = _HidWorker._(isolate, await first.future, replies);
    return worker;
  }

  Future<Object?> request(List<Object?> message) {
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _requests.send([id, ...message]);
    return completer.future;
  }

  void _onReply(List<Object?> m) {
    final completer = _pending.remove(m[0]! as int);
    if (completer == null) return;
    if (m[1]! as bool) {
      completer.complete(m[2]);
    } else {
      completer.completeError(
        HidException(m[2]! as String, disconnected: m[3]! as bool),
      );
    }
  }

  void kill() {
    for (final c in _pending.values) {
      c.completeError(const HidException('Transport disposed'));
    }
    _pending.clear();
    _replies.close();
    _isolate.kill();
  }
}
