import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../domain/device_info.dart';
import '../device_polling.dart';
import '../hid_transport.dart';
import 'hidraw.dart';

abstract final class _Op {
  static const open = 'open';
  static const setFeature = 'set';
  static const getFeature = 'get';
  static const close = 'close';
}

abstract final class _ReaderEvent {
  static const ready = 'ready';
  static const data = 'data';
  static const error = 'error';
  static const done = 'done';
}

class LinuxHidTransport with DevicePolling implements HidTransport {
  LinuxHidTransport({
    this.pollInterval = const Duration(milliseconds: 1500),
    Future<List<HidrawNode>> Function()? nodes,
  }) : _nodes = nodes ?? readHidrawNodes;

  @override
  final Duration pollInterval;
  final Future<List<HidrawNode>> Function() _nodes;

  _HidrawWorker? _worker;
  Future<_HidrawWorker>? _starting;
  final Map<String, HidrawDevice> _entries = {};
  bool _disposed = false;

  @override
  bool get pollingDisposed => _disposed;

  @override
  HidAvailability get availability => HidAvailability.available;

  @override
  Stream<List<HidDeviceInfo>> get devices => deviceList.stream;

  Future<_HidrawWorker> _ensureWorker() {
    if (_disposed) {
      return Future.error(const HidException('Transport disposed'));
    }
    final worker = _worker;
    if (worker != null) return Future.value(worker);
    return _starting ??= _HidrawWorker.spawn().then((w) {
      _worker = w;
      _starting = null;
      return w;
    });
  }

  @override
  Future<List<HidDeviceInfo>> enumerate() async {
    if (_disposed) throw const HidException('Transport disposed');
    final found = groupHidrawNodes(await _nodes());
    _entries
      ..clear()
      ..addEntries(found.map((d) => MapEntry(d.info.id, d)));
    return [for (final d in found) d.info];
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
    final fd = (await worker.request([_Op.open, entry.featurePath]))! as int;
    final connection = LinuxHidConnection._(worker, entry, fd);
    await connection._startReader();
    return connection;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    stopPolling();
    await deviceList.close();
    _worker?.kill();
    _worker = null;
  }
}

class LinuxHidConnection implements HidConnection {
  LinuxHidConnection._(this._worker, this._entry, this._fd);

  final _HidrawWorker _worker;
  final HidrawDevice _entry;
  final int _fd;
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
        case _ReaderEvent.ready:
          _readerControl = m[1]! as SendPort;
          if (!ready.isCompleted) ready.complete();
        case _ReaderEvent.data:
          if (!_notifications.isClosed) _notifications.add(m[1]! as Uint8List);
        case _ReaderEvent.error:
          if (!ready.isCompleted) ready.complete();
          if (m[2]! as bool) _markClosed();
        case _ReaderEvent.done:
          if (!ready.isCompleted) ready.complete();
          if (!done.isCompleted) done.complete();
          events.close();
      }
    });
    await Isolate.spawn(_readerMain, [
      events.sendPort,
      path,
      _entry.notificationLength,
    ]);
    await ready.future;
  }

  @override
  Future<void> setFeature(Uint8List report) =>
      _call([_Op.setFeature, _fd, report]);

  @override
  Future<Uint8List> getFeature(int reportId, int length) async =>
      (await _call([_Op.getFeature, _fd, reportId, length]))! as Uint8List;

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
      await _worker.request([_Op.close, _fd]);
    } on HidException {
      // Descriptor already gone after a disconnect.
    }
    await _notifications.close();
    if (!_closed.isCompleted) _closed.complete();
  }
}

class _HidrawWorker {
  _HidrawWorker._(this._isolate, this._requests, this._replies);

  final Isolate _isolate;
  final SendPort _requests;
  final ReceivePort _replies;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;

  static Future<_HidrawWorker> spawn() async {
    final replies = ReceivePort();
    final first = Completer<SendPort>();
    late final _HidrawWorker worker;
    replies.listen((message) {
      if (message is SendPort) {
        first.complete(message);
        return;
      }
      worker._onReply(message as List<Object?>);
    });
    final isolate = await Isolate.spawn(_workerMain, replies.sendPort);
    worker = _HidrawWorker._(isolate, await first.future, replies);
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
        HidException(
          m[2]! as String,
          disconnected: m[3]! as bool,
          permissionDenied: m[4]! as bool,
        ),
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

void _workerMain(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  final api = Hidraw();

  Object? handle(List<Object?> m) {
    switch (m[1]) {
      case _Op.open:
        return api.open(m[2]! as String);
      case _Op.setFeature:
        api.setFeature(m[2]! as int, m[3]! as Uint8List);
        return null;
      case _Op.getFeature:
        return api.getFeature(m[2]! as int, m[3]! as int, m[4]! as int);
      case _Op.close:
        api.close(m[2]! as int);
        return null;
    }
    throw ArgumentError.value(m[1], 'op');
  }

  requests.listen((message) {
    final m = message as List<Object?>;
    try {
      replies.send([m[0], true, handle(m)]);
    } on HidrawException catch (e) {
      replies.send([
        m[0],
        false,
        e.toString(),
        e.disconnected,
        e.permissionDenied,
      ]);
    } on Object catch (e) {
      replies.send([m[0], false, e.toString(), false, false]);
    }
  });
}

Future<void> _readerMain(List<Object?> args) async {
  final events = args[0]! as SendPort;
  final path = args[1]! as String;
  final length = args[2]! as int;
  final control = ReceivePort();
  var stopped = false;
  control.listen((_) => stopped = true);
  final api = Hidraw();
  int? fd;
  HidrawReader? reader;
  try {
    fd = api.open(path, nonBlocking: true);
    reader = api.reader(fd, length);
    events.send([_ReaderEvent.ready, control.sendPort]);
    while (!stopped) {
      final report = reader.next(100);
      if (report != null && report.isNotEmpty) {
        events.send([_ReaderEvent.data, report]);
      }
      // Let the control port deliver a stop request.
      await Future<void>.delayed(Duration.zero);
    }
  } on HidrawException catch (e) {
    if (!stopped) {
      events.send([_ReaderEvent.error, e.toString(), e.disconnected]);
    }
  } on Object catch (e) {
    if (!stopped) events.send([_ReaderEvent.error, e.toString(), false]);
  } finally {
    reader?.dispose();
    if (fd != null) api.close(fd);
    control.close();
    events.send([_ReaderEvent.done]);
  }
}
