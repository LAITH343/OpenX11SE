import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../hid_transport.dart';
import 'win32_hid.dart';

abstract final class WorkerOp {
  static const enumerate = 'enumerate';
  static const open = 'open';
  static const setFeature = 'set';
  static const getFeature = 'get';
  static const close = 'close';
}

abstract final class ReaderEvent {
  static const ready = 'ready';
  static const data = 'data';
  static const error = 'error';
  static const done = 'done';
}

class EnumeratedDevice {
  const EnumeratedDevice({
    required this.info,
    required this.featurePath,
    required this.featureLength,
    this.notificationPath,
    this.notificationLength = 0,
  });

  final HidDeviceInfo info;
  final String featurePath;
  final int featureLength;
  final String? notificationPath;
  final int notificationLength;
}

void hidWorkerMain(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  final api = Win32Hid();
  final probes = <String, HidInterfaceProbe?>{};
  final names = <String, String?>{};
  final featureLengths = <int, int>{};

  Object? handle(List<Object?> m) {
    switch (m[1]) {
      case WorkerOp.enumerate:
        return _enumerate(api, probes, names);
      case WorkerOp.open:
        final h = api.openReadWrite(m[2]! as String);
        featureLengths[h] = m[3]! as int;
        return h;
      case WorkerOp.setFeature:
        _setFeature(api, m[2]! as int, m[3]! as Uint8List, featureLengths);
        return null;
      case WorkerOp.getFeature:
        return _getFeature(
          api,
          m[2]! as int,
          m[3]! as int,
          m[4]! as int,
          featureLengths,
        );
      case WorkerOp.close:
        final h = m[2]! as int;
        featureLengths.remove(h);
        api.close(h);
        return null;
    }
    throw ArgumentError.value(m[1], 'op');
  }

  requests.listen((message) {
    final m = message as List<Object?>;
    try {
      replies.send([m[0], true, handle(m)]);
    } on Win32HidException catch (e) {
      replies.send([m[0], false, e.toString(), e.disconnected]);
    } on Object catch (e) {
      replies.send([m[0], false, e.toString(), false]);
    }
  });
}

void _setFeature(
  Win32Hid api,
  int handle,
  Uint8List report,
  Map<int, int> featureLengths,
) {
  try {
    api.setFeature(handle, report);
  } on Win32HidException catch (e) {
    final max = featureLengths[handle] ?? 0;
    if (e.disconnected || max <= report.length) rethrow;
    api.setFeature(handle, Uint8List(max)..setAll(0, report));
  }
}

Uint8List _getFeature(
  Win32Hid api,
  int handle,
  int reportId,
  int length,
  Map<int, int> featureLengths,
) {
  try {
    return api.getFeature(handle, reportId, length);
  } on Win32HidException catch (e) {
    final max = featureLengths[handle] ?? 0;
    if (e.disconnected || max <= length) rethrow;
    return Uint8List.sublistView(
      api.getFeature(handle, reportId, max),
      0,
      length,
    );
  }
}

List<EnumeratedDevice> _enumerate(
  Win32Hid api,
  Map<String, HidInterfaceProbe?> probes,
  Map<String, String?> names,
) {
  final paths = api.interfacePaths().where(_isCandidatePath).toSet();
  probes.removeWhere((path, _) => !paths.contains(path));
  names.removeWhere((path, _) => !paths.contains(path));
  final groups = <String, List<HidInterfaceProbe>>{};
  for (final path in paths) {
    final probe = probes.putIfAbsent(path, () => api.probe(path));
    if (probe == null ||
        probe.vendorId != X11seUsb.vendorId ||
        !X11seUsb.productIds.contains(probe.productId)) {
      continue;
    }
    groups.putIfAbsent(_groupKey(probe), () => []).add(probe);
  }
  final devices = <EnumeratedDevice>[];
  for (final MapEntry(key: id, value: members) in groups.entries) {
    final feature =
        _firstWhere(
          members,
          (p) =>
              p.caps.usagePage == X11seUsb.featureUsagePage &&
              p.caps.featureLength > 0,
        ) ??
        _firstWhere(members, (p) => p.caps.featureLength > 0);
    if (feature == null) continue;
    final notification = _firstWhere(
      members,
      (p) =>
          p.caps.usagePage == X11seUsb.notificationUsagePage &&
          p.caps.inputLength > 0,
    );
    devices.add(
      EnumeratedDevice(
        info: HidDeviceInfo(
          id: id,
          vendorId: feature.vendorId,
          productId: feature.productId,
          productName: names.putIfAbsent(
            feature.path,
            () => api.productString(feature.path),
          ),
        ),
        featurePath: feature.path,
        featureLength: feature.caps.featureLength,
        notificationPath: notification?.path,
        notificationLength: notification?.caps.inputLength ?? 0,
      ),
    );
  }
  devices.sort((a, b) => a.info.id.compareTo(b.info.id));
  return devices;
}

bool _isCandidatePath(String path) {
  final p = path.toLowerCase();
  final vid = 'vid_${X11seUsb.vendorId.toRadixString(16).padLeft(4, '0')}';
  return p.contains(vid) &&
      X11seUsb.productIds.any(
        (pid) => p.contains('pid_${pid.toRadixString(16).padLeft(4, '0')}'),
      );
}

String _groupKey(HidInterfaceProbe probe) {
  final parts = probe.path.toLowerCase().split('#');
  final instance = parts.length > 2 ? parts[2] : probe.path.toLowerCase();
  final cut = instance.lastIndexOf('&');
  final parent = cut > 0 ? instance.substring(0, cut) : instance;
  return '${probe.vendorId.toRadixString(16)}:'
      '${probe.productId.toRadixString(16)}:$parent';
}

HidInterfaceProbe? _firstWhere(
  List<HidInterfaceProbe> items,
  bool Function(HidInterfaceProbe) test,
) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

Future<void> notificationReaderMain(List<Object?> args) async {
  final events = args[0]! as SendPort;
  final path = args[1]! as String;
  final length = args[2]! as int;
  final control = ReceivePort();
  var stopped = false;
  control.listen((_) => stopped = true);
  final api = Win32Hid();
  int? handle;
  OverlappedReader? reader;
  try {
    handle = api.openReadWrite(path, overlapped: true);
    reader = api.overlappedReader(handle, length);
    events.send([ReaderEvent.ready, control.sendPort]);
    while (!stopped) {
      reader.start();
      if (reader.wait(100) == ReadWait.data) {
        events.send([ReaderEvent.data, reader.complete()]);
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    }
  } on Win32HidException catch (e) {
    if (!stopped) {
      events.send([ReaderEvent.error, e.toString(), e.disconnected]);
    }
  } on Object catch (e) {
    if (!stopped) events.send([ReaderEvent.error, e.toString(), false]);
  } finally {
    reader?.dispose();
    if (handle != null) api.close(handle);
    control.close();
    events.send([ReaderEvent.done]);
  }
}
