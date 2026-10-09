import 'dart:async';
import 'dart:typed_data';

import '../../domain/button_assignment.dart';
import '../../domain/device_info.dart';
import '../../domain/device_settings.dart';
import '../hid/hid_transport.dart';
import '../protocol/device_reads.dart';
import '../protocol/dpi_report.dart';
import '../protocol/lighting_report.dart';
import '../protocol/notifications.dart';
import '../protocol/polling_report.dart';
import '../protocol/report_format.dart';
import '../protocol/snapshot.dart';
import 'apply_plan.dart';
import 'device_timing.dart';

class DeviceReadResult {
  const DeviceReadResult({
    required this.settings,
    required this.includesButtons,
  });

  final DeviceSettings settings;
  final bool includesButtons;
}

class DeviceReadException implements Exception {
  const DeviceReadException(this.reportId, this.message, {this.cause});

  final int reportId;
  final String message;
  final Object? cause;

  bool get disconnected =>
      cause is HidException && (cause! as HidException).disconnected;

  @override
  String toString() =>
      'DeviceReadException(0x${reportId.toRadixString(16)}): $message';
}

enum DeviceWriteFailure { disconnected, rejected, noAcknowledgement }

class DeviceWriteException implements Exception {
  const DeviceWriteException(this.reportId, this.failure, {this.cause});

  final int reportId;
  final DeviceWriteFailure failure;
  final Object? cause;

  @override
  String toString() =>
      'DeviceWriteException(0x${reportId.toRadixString(16)}): ${failure.name}'
      '${cause == null ? '' : ' ($cause)'}';
}

typedef ApplyProgress = void Function(int done, int total);

class DeviceSession {
  DeviceSession(this._connection, this._timing) {
    _subscription = _connection.notifications.listen(_onRaw);
  }

  final HidConnection _connection;
  final DeviceTiming _timing;
  late final StreamSubscription<Uint8List> _subscription;
  final _events = StreamController<DeviceNotification>.broadcast();
  Future<void> _tail = Future.value();

  HidDeviceInfo get device => _connection.device;

  ConnectionType get connection => _connection.connectionType;

  Stream<DeviceNotification> get notifications => _events.stream;

  Future<void> get closed => _connection.closed;

  void _onRaw(Uint8List bytes) {
    final event = decodeNotification(bytes);
    if (event != null && !_events.isClosed) _events.add(event);
  }

  Future<T> _exclusive<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<int> readVersion() => _exclusive(() async {
    final bytes = await _read(
      versionReadRequest(),
      ReportId.version,
      ReportLength.version,
    );
    return _decode(ReportId.version, () => decodeVersion(bytes));
  });

  Future<DeviceReadResult> readSettings(int version) => _exclusive(() async {
    if (!usesIndividualReads(version)) {
      final bytes = await _read(
        snapshotReadRequest(),
        ReportId.snapshot,
        ReportLength.snapshot,
      );
      return DeviceReadResult(
        settings: _decode(ReportId.snapshot, () => decodeSnapshot(bytes)),
        includesButtons: true,
      );
    }
    final polling = await _read(
      pollingReadRequest(),
      ReportId.polling,
      ReportLength.polling,
    );
    final lighting = await _read(
      lightingReadRequest(),
      ReportId.lighting,
      ReportLength.lighting,
    );
    final dpi = await _read(dpiReadRequest(), ReportId.dpi, ReportLength.dpi);
    final dpiValues = _decode(ReportId.dpi, () => decodeDpiReport(dpi));
    final lightingValues = _decode(
      ReportId.lighting,
      () => decodeLightingReport(lighting),
    );
    return DeviceReadResult(
      settings: DeviceSettings(
        dpi: dpiValues.dpi,
        sensor: dpiValues.sensor,
        lighting: lightingValues.lighting,
        power: lightingValues.power,
        polling: _decode(ReportId.polling, () => decodePollingReport(polling)),
        buttons: factoryButtonAssignments,
      ),
      includesButtons: false,
    );
  });

  T _decode<T>(int reportId, T Function() decode) {
    try {
      return decode();
    } on ProtocolException catch (e) {
      throw DeviceReadException(reportId, e.message, cause: e);
    }
  }

  Future<Uint8List> _read(Uint8List request, int reportId, int length) async {
    try {
      for (var attempt = 0; attempt < _timing.readAttempts; attempt++) {
        await _connection.setFeature(request);
        for (var poll = 0; poll < _timing.busyPolls; poll++) {
          await _delay(_timing.readDelay);
          final bytes = await _connection.getFeature(reportId, length);
          if (isResponseFor(bytes, reportId, length)) return bytes;
        }
      }
    } on HidException catch (e) {
      throw DeviceReadException(reportId, e.message, cause: e);
    }
    throw DeviceReadException(reportId, 'No valid response');
  }

  Future<void> apply(
    List<OutgoingReport> reports, {
    ApplyProgress? onProgress,
  }) => _exclusive(() async {
    onProgress?.call(0, reports.length);
    for (var i = 0; i < reports.length; i++) {
      await _send(reports[i]);
      onProgress?.call(i + 1, reports.length);
    }
  });

  Future<void> _send(OutgoingReport report) async {
    final useAck = report.expectAck && _connection.supportsNotifications;
    Object? lastError;
    for (var attempt = 0; attempt < _timing.writeAttempts; attempt++) {
      final ack = useAck ? _AckWaiter(notifications, report.reportId) : null;
      try {
        for (var i = 0; i < report.chunks.length; i++) {
          if (i > 0) await _delay(_timing.reportGap);
          await _connection.setFeature(report.chunks[i]);
        }
      } on HidException catch (e) {
        ack?.cancel();
        if (e.disconnected) {
          throw DeviceWriteException(
            report.reportId,
            DeviceWriteFailure.disconnected,
            cause: e,
          );
        }
        lastError = e;
        await _delay(_timing.reportGap);
        continue;
      }
      final sent = Stopwatch()..start();
      if (ack == null || await ack.wait(_timing.ackTimeout)) {
        final remaining = _timing.reportGap - sent.elapsed;
        if (remaining > Duration.zero) await _delay(remaining);
        return;
      }
      lastError = null;
    }
    throw DeviceWriteException(
      report.reportId,
      lastError == null
          ? DeviceWriteFailure.noAcknowledgement
          : DeviceWriteFailure.rejected,
      cause: lastError,
    );
  }

  Future<void> _delay(Duration d) =>
      d > Duration.zero ? Future<void>.delayed(d) : Future<void>.value();

  Future<void> close() async {
    await _subscription.cancel();
    await _connection.close();
    await _events.close();
  }
}

class _AckWaiter {
  _AckWaiter(Stream<DeviceNotification> events, int reportId) {
    _subscription = events.listen((e) {
      if (e is WriteAckNotification && e.reportId == reportId) _finish(true);
    });
  }

  final _result = Completer<bool>();
  late final StreamSubscription<DeviceNotification> _subscription;
  Timer? _timer;

  Future<bool> wait(Duration timeout) {
    if (!_result.isCompleted) _timer = Timer(timeout, () => _finish(false));
    return _result.future;
  }

  void cancel() => _finish(false);

  void _finish(bool acked) {
    if (_result.isCompleted) return;
    _timer?.cancel();
    unawaited(_subscription.cancel());
    _result.complete(acked);
  }
}
