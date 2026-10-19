import 'dart:async';

import 'package:flutter/foundation.dart';

import 'hid_transport.dart';

mixin DevicePolling {
  Duration get pollInterval;

  bool get pollingDisposed;

  Future<List<HidDeviceInfo>> enumerate();

  late final StreamController<List<HidDeviceInfo>> deviceList =
      StreamController.broadcast(
        onListen: _startPolling,
        onCancel: stopPolling,
      );
  Timer? _poll;
  List<HidDeviceInfo> _last = const [];
  bool _emitted = false;
  bool _enumerating = false;

  void _startPolling() {
    _poll ??= Timer.periodic(pollInterval, (_) => _refresh());
    _refresh();
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
    _emitted = false;
  }

  Future<void> _refresh() async {
    if (_enumerating || pollingDisposed) return;
    _enumerating = true;
    try {
      final list = await enumerate();
      if (!_emitted || !listEquals(list, _last)) {
        _emitted = true;
        _last = list;
        if (!deviceList.isClosed) deviceList.add(list);
      }
    } on Object catch (e, s) {
      if (!deviceList.isClosed) deviceList.addError(e, s);
    } finally {
      _enumerating = false;
    }
  }
}
