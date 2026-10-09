import 'dart:async';

import '../../domain/device_info.dart';
import '../../domain/device_settings.dart';
import '../../domain/macro.dart';
import '../hid/hid_transport.dart';
import '../protocol/notifications.dart';
import 'apply_plan.dart';
import 'device_session.dart';
import 'device_state.dart';
import 'device_timing.dart';

class DeviceRepository {
  DeviceRepository(
    this._transport, {
    DeviceTiming Function(ConnectionType)? timing,
    this.wakeRetryInterval = const Duration(seconds: 10),
    this.silenceTimeout = const Duration(milliseconds: 3500),
    this.awakeReportGap = const Duration(seconds: 3),
    this.offTimeout = const Duration(seconds: 9),
  }) : _timing = timing ?? DeviceTiming.forConnection;

  final HidTransport _transport;
  final DeviceTiming Function(ConnectionType) _timing;
  final Duration wakeRetryInterval;
  final Duration silenceTimeout;
  final Duration awakeReportGap;
  final Duration offTimeout;
  final _clock = Stopwatch()..start();
  Duration? _lastBattery;
  Timer? _wakeRetry;
  Timer? _silence;
  Timer? _offTimer;
  bool _awaitingWake = false;
  final _states = StreamController<DeviceState>.broadcast();
  final _stageChanges = StreamController<int>.broadcast();
  DeviceState _state = const DeviceAbsent();
  DeviceSession? _session;
  HidDeviceInfo? _current;
  StreamSubscription<List<HidDeviceInfo>>? _devices;
  StreamSubscription<DeviceNotification>? _notifications;
  BatteryNotification? _battery;
  int _generation = 0;
  bool _disposed = false;

  bool get isSupported => _transport.isSupported;

  bool get requiresUserGrant => _transport.requiresUserGrant;

  DeviceState get state => _state;

  Stream<DeviceState> get states => _states.stream;

  Stream<int> get stageChanges => _stageChanges.stream;

  void start() {
    _devices ??= _transport.devices.listen(_onDevices, onError: (_) {});
  }

  Future<void> rescan() async => _onDevices(await _transport.enumerate());

  Future<void> requestDevice() async =>
      _onDevices(await _transport.requestDevice());

  void _onDevices(List<HidDeviceInfo> devices) {
    if (_disposed) return;
    final preferred = _preferred(devices);
    final current = _current;
    if (preferred == null) {
      if (current != null) unawaited(_drop());
      return;
    }
    if (current == preferred && _state is! DeviceFailed) return;
    if (current != null &&
        devices.contains(current) &&
        current.connection == preferred.connection &&
        _state is! DeviceFailed) {
      return;
    }
    unawaited(_connect(preferred));
  }

  static HidDeviceInfo? _preferred(List<HidDeviceInfo> devices) {
    HidDeviceInfo? best;
    for (final d in devices) {
      if (best == null ||
          (d.connection == ConnectionType.wired &&
              best.connection != ConnectionType.wired)) {
        best = d;
      }
    }
    return best;
  }

  Future<void> _connect(HidDeviceInfo device) async {
    final generation = ++_generation;
    await _closeSession();
    if (generation != _generation) return;
    _current = device;
    _battery = null;
    _setState(DeviceConnecting(device));
    try {
      final connection = await _transport.open(device);
      if (generation != _generation) {
        await connection.close();
        return;
      }
      final session = DeviceSession(connection, _timing(device.connection));
      _session = session;
      _notifications = session.notifications.listen(_onNotification);
      unawaited(session.closed.then((_) => _onSessionClosed(session)));
      await _loadOrWait(session, generation);
    } on Object catch (e) {
      if (generation == _generation) _setState(DeviceFailed(device, e));
    }
  }

  Future<void> _loadOrWait(
    DeviceSession session,
    int generation, {
    bool off = false,
  }) async {
    _wakeRetry?.cancel();
    _awaitingWake = false;
    try {
      await _load(session, generation);
    } on DeviceReadException catch (e) {
      if (!e.noResponse || session.connection != ConnectionType.dongle) {
        rethrow;
      }
      if (generation != _generation) return;
      _setState(off ? DeviceOff(session.device) : DeviceAsleep(session.device));
      if (session.supportsNotifications) {
        _awaitingWake = true;
        if (!off) _watchOff();
        return;
      }
      _wakeRetry = Timer(
        wakeRetryInterval,
        () => unawaited(_retryAsleep(session, generation)),
      );
    }
  }

  Future<void> _retryAsleep(DeviceSession session, int generation) async {
    _wakeRetry?.cancel();
    _awaitingWake = false;
    final state = _state;
    if (generation != _generation ||
        (state is! DeviceAsleep && state is! DeviceOff)) {
      return;
    }
    try {
      await _loadOrWait(session, generation, off: state is DeviceOff);
    } on Object catch (e) {
      if (generation == _generation) _setState(DeviceFailed(session.device, e));
    }
  }

  Future<void> _load(DeviceSession session, int generation) async {
    final version = await session.readVersion();
    final result = await session.readSettings(version);
    if (generation != _generation) return;
    final battery = _battery;
    _setState(
      DeviceReady(
        device: session.device,
        info: DeviceInfo(
          connection: session.connection,
          firmwareVersion: version,
          batteryPercent: battery?.percent,
          chargeState: battery?.chargeState ?? ChargeState.unknown,
        ),
        settings: result.settings,
        includesButtons: result.includesButtons,
      ),
    );
    _watchSilence();
    _watchOff();
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null) return rescan();
    final generation = _generation;
    final previous = _state;
    final off =
        previous is DeviceOff || (previous is DeviceReady && previous.off);
    _setState(DeviceConnecting(session.device));
    try {
      await _loadOrWait(session, generation, off: off);
    } on Object catch (e) {
      if (generation == _generation) {
        _setState(DeviceFailed(session.device, e));
      }
    }
  }

  DeviceSession? get _watchedSession {
    final session = _session;
    if (session == null ||
        session.connection != ConnectionType.dongle ||
        !session.supportsNotifications) {
      return null;
    }
    return session;
  }

  void _watchSilence() {
    _silence?.cancel();
    final session = _watchedSession;
    if (session == null) return;
    _silence = Timer(silenceTimeout, () {
      final state = _state;
      if (state is DeviceReady &&
          state.link == MouseLink.awake &&
          _session == session) {
        _setState(state.copyWith(link: MouseLink.asleep));
      }
    });
  }

  void _watchOff() {
    _offTimer?.cancel();
    final session = _watchedSession;
    if (session == null) return;
    _offTimer = Timer(offTimeout, () {
      if (_session != session) return;
      final state = _state;
      if (state is DeviceReady && !state.off) {
        _setState(state.copyWith(link: MouseLink.off));
      } else if (state is DeviceAsleep) {
        _setState(DeviceOff(state.device));
      }
    });
  }

  MouseLink? _linkFrom(DeviceNotification event) {
    if (event is! BatteryNotification) return MouseLink.awake;
    final now = _clock.elapsed;
    final last = _lastBattery;
    _lastBattery = now;
    if (last == null || now - last >= offTimeout) return null;
    return now - last < awakeReportGap ? MouseLink.awake : MouseLink.asleep;
  }

  void _onNotification(DeviceNotification event) {
    var state = _state;
    final session = _session;
    final link = _linkFrom(event);
    _watchOff();
    if (link == MouseLink.awake) _watchSilence();
    if (state is DeviceReady && link != null && link != state.link) {
      state = state.copyWith(link: link);
      _setState(state);
    } else if (state is DeviceOff && link == MouseLink.asleep) {
      state = DeviceAsleep(state.device);
      _setState(state);
    }
    final awake = link == MouseLink.awake;
    if (awake &&
        (state is DeviceAsleep || state is DeviceOff) &&
        session != null &&
        (_awaitingWake || _wakeRetry?.isActive == true)) {
      unawaited(_retryAsleep(session, _generation));
    }
    switch (event) {
      case BatteryNotification():
        if (_battery == event) break;
        _battery = event;
        if (state is DeviceReady) {
          _setState(
            state.copyWith(
              info: state.info.copyWith(
                batteryPercent: event.percent,
                chargeState: event.chargeState,
              ),
            ),
          );
        }
      case DpiStageNotification(:final stageIndex):
        if (state is DeviceReady) {
          _setState(
            state.copyWith(
              settings: state.settings.copyWith(
                dpi: state.settings.dpi.copyWith(activeStageIndex: stageIndex),
              ),
            ),
          );
        }
        if (!_stageChanges.isClosed) _stageChanges.add(stageIndex);
      case WriteAckNotification():
        break;
    }
  }

  void _onSessionClosed(DeviceSession session) {
    if (_session != session || _disposed) return;
    final wasReady = _state is DeviceReady;
    unawaited(
      _drop().then((_) {
        if (wasReady) return rescan();
      }),
    );
  }

  Future<void> _drop() async {
    _generation++;
    await _closeSession();
    _current = null;
    _setState(const DeviceAbsent());
  }

  Future<void> _closeSession() async {
    _wakeRetry?.cancel();
    _silence?.cancel();
    _offTimer?.cancel();
    _lastBattery = null;
    _awaitingWake = false;
    final session = _session;
    _session = null;
    await _notifications?.cancel();
    _notifications = null;
    if (session != null) await session.close();
  }

  Future<void> apply(
    DeviceSettings next, {
    DeviceSettings? previous,
    Map<int, Macro> macros = const {},
    Set<int> changedMacroIds = const {},
    bool restoreDefaults = false,
    ApplyProgress? onProgress,
  }) async {
    final session = _session;
    final state = _state;
    if (session == null || state is! DeviceReady) {
      throw const DeviceWriteException(0, DeviceWriteFailure.disconnected);
    }
    if (state.link != MouseLink.awake) {
      throw DeviceWriteException(
        0,
        state.off ? DeviceWriteFailure.off : DeviceWriteFailure.asleep,
      );
    }
    final reports = planApply(
      previous: previous ?? state.settings,
      next: next,
      connection: session.connection,
      macros: macros,
      changedMacroIds: changedMacroIds,
      restoreDefaults: restoreDefaults,
      forceButtons: !state.includesButtons,
    );
    await session.apply(reports, onProgress: onProgress);
    final current = _state;
    if (_session == session && current is DeviceReady) {
      _setState(current.copyWith(settings: next, includesButtons: true));
    }
  }

  Future<void> restoreDefaults({ApplyProgress? onProgress}) => apply(
    DeviceSettings.factoryDefaults,
    restoreDefaults: true,
    onProgress: onProgress,
  );

  void _setState(DeviceState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    await _devices?.cancel();
    await _closeSession();
    await _transport.dispose();
    await _states.close();
    await _stageChanges.close();
  }
}
