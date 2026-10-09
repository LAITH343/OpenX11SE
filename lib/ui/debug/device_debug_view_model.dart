import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/device_repository.dart';
import '../../data/repositories/device_state.dart';
import '../../domain/button_assignment.dart';

class DeviceDebugViewModel extends ChangeNotifier {
  DeviceDebugViewModel(this._repository) {
    _subscriptions = [
      _repository.states.listen(_onState),
      _repository.stageChanges.listen(
        (stage) => _log('DPI stage changed on the mouse: ${stage + 1}'),
      ),
    ];
    _repository.start();
    _onState(_repository.state);
  }

  static const _maxLog = 200;

  final DeviceRepository _repository;
  late final List<StreamSubscription<Object>> _subscriptions;
  final List<String> _entries = [];
  DeviceState _state = const DeviceAbsent();

  DeviceState get state => _state;

  List<String> get log => List.unmodifiable(_entries);

  bool get isSupported => _repository.isSupported;

  bool get requiresUserGrant => _repository.requiresUserGrant;

  List<String> get settingsLines {
    final state = _state;
    if (state is! DeviceReady) return const [];
    final s = state.settings;
    return [
      for (var i = 0; i < s.dpi.stages.length; i++)
        'Stage ${i + 1}: ${s.dpi.stages[i].enabled ? 'on ' : 'off'} '
            '${s.dpi.stages[i].dpi} DPI ${s.dpi.stages[i].color}'
            '${i == s.dpi.activeStageIndex ? '  (active)' : ''}',
      'Sensor: ${s.sensor}',
      'Polling: ${s.polling}',
      'Lighting: ${s.lighting}',
      'Power: ${s.power}',
      if (state.includesButtons)
        for (final slot in ButtonSlot.main) 'Slot $slot: ${s.buttons[slot]}',
    ];
  }

  void _onState(DeviceState state) {
    final previous = _state;
    _state = state;
    if (state is! DeviceReady || previous is! DeviceReady) {
      _log('State: $state');
    } else if (state.info != previous.info) {
      _log('Info: ${state.info}');
    }
    notifyListeners();
  }

  void _log(String line) {
    _entries.insert(
      0,
      '${DateTime.now().toIso8601String().substring(11, 23)}  $line',
    );
    if (_entries.length > _maxLog) _entries.removeLast();
    notifyListeners();
  }

  Future<void> rescan() => _guard(_repository.rescan);

  Future<void> requestDevice() => _guard(_repository.requestDevice);

  Future<void> refresh() => _guard(_repository.refresh);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      _log('Error: $e');
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
