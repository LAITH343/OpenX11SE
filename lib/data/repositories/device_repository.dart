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
  }) : _timing = timing ?? DeviceTiming.forConnection;

  final HidTransport _transport;
  final DeviceTiming Function(ConnectionType) _timing;
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
      await _load(session, generation);
    } on Object catch (e) {
      if (generation == _generation) _setState(DeviceFailed(device, e));
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
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null) return rescan();
    final generation = _generation;
    _setState(DeviceConnecting(session.device));
    try {
      await _load(session, generation);
    } on Object catch (e) {
      if (generation == _generation) {
        _setState(DeviceFailed(session.device, e));
      }
    }
  }

  void _onNotification(DeviceNotification event) {
    final state = _state;
    switch (event) {
      case BatteryNotification():
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
