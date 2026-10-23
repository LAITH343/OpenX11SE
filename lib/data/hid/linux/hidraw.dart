import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../hid_transport.dart';

typedef _OpenN = Int Function(Pointer<Utf8>, Int, VarArgs<(Int,)>);
typedef _OpenD = int Function(Pointer<Utf8>, int, int);
typedef _CloseN = Int Function(Int);
typedef _CloseD = int Function(int);
typedef _IoctlN = Int Function(Int, UnsignedLong, VarArgs<(Pointer<Uint8>,)>);
typedef _IoctlD = int Function(int, int, Pointer<Uint8>);
typedef _ReadN = IntPtr Function(Int, Pointer<Uint8>, Size);
typedef _ReadD = int Function(int, Pointer<Uint8>, int);
typedef _PollN = Int Function(Pointer<_PollFd>, UnsignedLong, Int);
typedef _PollD = int Function(Pointer<_PollFd>, int, int);
typedef _ErrnoN = Pointer<Int> Function();
typedef _ErrnoD = Pointer<Int> Function();

final class _PollFd extends Struct {
  @Int()
  external int fd;

  @Short()
  external int events;

  @Short()
  external int revents;
}

abstract final class _Errno {
  static const perm = 1;
  static const noent = 2;
  static const nxio = 6;
  static const acces = 13;
  static const nodev = 19;
  static const shutdown = 108;
}

class HidrawException implements Exception {
  HidrawException(this.operation, this.errno, {this.nodeGone = false});

  final String operation;
  final int errno;

  /// The device node vanished, so the device was unplugged.
  final bool nodeGone;

  bool get disconnected =>
      nodeGone ||
      switch (errno) {
        _Errno.noent || _Errno.nodev || _Errno.nxio || _Errno.shutdown => true,
        _ => false,
      };

  bool get permissionDenied => errno == _Errno.acces || errno == _Errno.perm;

  @override
  String toString() => permissionDenied
      ? '$operation failed: permission denied'
      : '$operation failed (errno $errno)';
}

/// Thin libc bindings for `/dev/hidraw*`.
///
/// The VM can overwrite errno on the way back from a regular FFI call, so
/// only the leaf `open` reports an exact errno. Calls that may block stay
/// regular and treat a vanished device node as a disconnect.
class Hidraw {
  Hidraw() {
    final libc = DynamicLibrary.process();
    _open = libc.lookupFunction<_OpenN, _OpenD>('open', isLeaf: true);
    _close = libc.lookupFunction<_CloseN, _CloseD>('close');
    _ioctl = libc.lookupFunction<_IoctlN, _IoctlD>('ioctl');
    _read = libc.lookupFunction<_ReadN, _ReadD>('read');
    _poll = libc.lookupFunction<_PollN, _PollD>('poll');
    _errno = libc.lookupFunction<_ErrnoN, _ErrnoD>(
      '__errno_location',
      isLeaf: true,
    );
  }

  static const _readWrite = 0x02;
  static const _nonBlocking = 0x800;
  static const _closeOnExec = 0x80000;
  static const _pollIn = 0x01;
  static const _pollErr = 0x08;
  static const _pollHup = 0x10;
  static const _pollNval = 0x20;

  late final _OpenD _open;
  late final _CloseD _close;
  late final _IoctlD _ioctl;
  late final _ReadD _read;
  late final _PollD _poll;
  late final _ErrnoD _errno;
  final Map<int, String> _paths = {};

  int get _lastError => _errno().value;

  HidrawException _failure(String operation, int fd) {
    final error = _lastError;
    final path = _paths[fd];
    return HidrawException(
      operation,
      error,
      nodeGone:
          path != null &&
          FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound,
    );
  }

  /// `_IOC(_IOC_READ | _IOC_WRITE, 'H', nr, length)` from `linux/hidraw.h`.
  static int _hidIoctl(int nr, int length) =>
      (3 << 30) | (length << 16) | (0x48 << 8) | nr;

  static int setFeatureRequest(int length) => _hidIoctl(0x06, length);

  static int getFeatureRequest(int length) => _hidIoctl(0x07, length);

  int open(String path, {bool nonBlocking = false}) {
    final native = path.toNativeUtf8();
    try {
      final flags =
          _readWrite | _closeOnExec | (nonBlocking ? _nonBlocking : 0);
      final fd = _open(native, flags, 0);
      if (fd < 0) throw HidrawException('open $path', _lastError);
      _paths[fd] = path;
      return fd;
    } finally {
      calloc.free(native);
    }
  }

  void close(int fd) {
    _paths.remove(fd);
    _close(fd);
  }

  void setFeature(int fd, Uint8List report) {
    final buffer = calloc<Uint8>(report.length);
    try {
      buffer.asTypedList(report.length).setAll(0, report);
      if (_ioctl(fd, setFeatureRequest(report.length), buffer) < 0) {
        throw _failure('HIDIOCSFEATURE', fd);
      }
    } finally {
      calloc.free(buffer);
    }
  }

  Uint8List getFeature(int fd, int reportId, int length) {
    final buffer = calloc<Uint8>(length);
    try {
      buffer[0] = reportId;
      if (_ioctl(fd, getFeatureRequest(length), buffer) < 0) {
        throw _failure('HIDIOCGFEATURE', fd);
      }
      return Uint8List.fromList(buffer.asTypedList(length));
    } finally {
      calloc.free(buffer);
    }
  }

  HidrawReader reader(int fd, int length) => HidrawReader._(this, fd, length);
}

/// Polls a non-blocking hidraw descriptor for input reports.
class HidrawReader {
  HidrawReader._(this._api, this._fd, this._length)
    : _buffer = calloc<Uint8>(_length),
      _pollFd = calloc<_PollFd>();

  final Hidraw _api;
  final int _fd;
  final int _length;
  final Pointer<Uint8> _buffer;
  final Pointer<_PollFd> _pollFd;

  /// Waits up to [timeoutMs] for a report; returns null on timeout.
  Uint8List? next(int timeoutMs) {
    _pollFd.ref
      ..fd = _fd
      ..events = Hidraw._pollIn
      ..revents = 0;
    final ready = _api._poll(_pollFd, 1, timeoutMs);
    if (ready < 0) throw _api._failure('poll', _fd);
    if (ready == 0) return null;
    final events = _pollFd.ref.revents;
    if (events & (Hidraw._pollErr | Hidraw._pollHup | Hidraw._pollNval) != 0) {
      throw HidrawException('poll', _Errno.nodev);
    }
    final count = _api._read(_fd, _buffer, _length);
    if (count < 0) {
      final failure = _api._failure('read', _fd);
      if (!failure.disconnected) return null;
      throw failure;
    }
    return Uint8List.fromList(_buffer.asTypedList(count));
  }

  void dispose() {
    calloc.free(_buffer);
    calloc.free(_pollFd);
  }
}

class ReportDescriptorInfo {
  const ReportDescriptorInfo({
    required this.usagePages,
    required this.featureLength,
    required this.inputLength,
  });

  /// Usage pages of the top-level collections.
  final Set<int> usagePages;

  /// Longest report in bytes, including the report ID byte.
  final int featureLength;
  final int inputLength;
}

/// Reads the parts of a HID report descriptor needed to pick interfaces.
ReportDescriptorInfo parseReportDescriptor(List<int> bytes) {
  final pages = <int>{};
  final inputBits = <int, int>{};
  final featureBits = <int, int>{};
  final stack = <(int, int, int, int)>[];
  var usagePage = 0;
  var reportSize = 0;
  var reportCount = 0;
  var reportId = 0;
  var depth = 0;
  int? usage;

  var i = 0;
  while (i < bytes.length) {
    final prefix = bytes[i];
    if (prefix == 0xFE) {
      if (i + 1 >= bytes.length) break;
      i += 3 + bytes[i + 1];
      continue;
    }
    final size = const [0, 1, 2, 4][prefix & 0x03];
    if (i + size >= bytes.length) break;
    var value = 0;
    for (var b = 0; b < size; b++) {
      value |= bytes[i + 1 + b] << (8 * b);
    }
    final type = (prefix >> 2) & 0x03;
    final tag = prefix >> 4;
    switch ((type, tag)) {
      case (0, 0x8):
        inputBits.update(
          reportId,
          (v) => v + reportSize * reportCount,
          ifAbsent: () => reportSize * reportCount,
        );
      case (0, 0xB):
        featureBits.update(
          reportId,
          (v) => v + reportSize * reportCount,
          ifAbsent: () => reportSize * reportCount,
        );
      case (0, 0xA):
        if (depth == 0) {
          final page = usage != null && usage > 0xFFFF
              ? usage >> 16
              : usagePage;
          pages.add(page);
        }
        depth++;
      case (0, 0xC):
        if (depth > 0) depth--;
      case (1, 0x0):
        usagePage = value;
      case (1, 0x7):
        reportSize = value;
      case (1, 0x8):
        reportId = value;
      case (1, 0x9):
        reportCount = value;
      case (1, 0xA):
        stack.add((usagePage, reportSize, reportCount, reportId));
      case (1, 0xB):
        if (stack.isNotEmpty) {
          (usagePage, reportSize, reportCount, reportId) = stack.removeLast();
        }
      case (2, 0x0):
        usage = size == 4 ? value : null;
    }
    if (type == 0) usage = null;
    i += 1 + size;
  }

  int longest(Map<int, int> bits) => bits.isEmpty
      ? 0
      : bits.values.map((b) => (b + 7) ~/ 8).reduce((a, b) => a > b ? a : b) +
            1;

  return ReportDescriptorInfo(
    usagePages: pages,
    featureLength: longest(featureBits),
    inputLength: longest(inputBits),
  );
}

class HidrawNode {
  const HidrawNode({
    required this.devicePath,
    required this.vendorId,
    required this.productId,
    required this.physical,
    required this.descriptor,
    this.productName,
  });

  final String devicePath;
  final int vendorId;
  final int productId;
  final String physical;
  final String? productName;
  final ReportDescriptorInfo descriptor;
}

class HidrawDevice {
  const HidrawDevice({
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

/// Parses `HID_ID=0003:00001D57:00002125` from a hidraw `device/uevent`.
(int, int)? parseHidId(String uevent) {
  final match = RegExp(
    r'^HID_ID=[0-9A-Fa-f]+:([0-9A-Fa-f]+):([0-9A-Fa-f]+)$',
    multiLine: true,
  ).firstMatch(uevent);
  if (match == null) return null;
  return (int.parse(match[1]!, radix: 16), int.parse(match[2]!, radix: 16));
}

String? _ueventValue(String uevent, String key) =>
    RegExp('^$key=(.*)\$', multiLine: true).firstMatch(uevent)?[1]?.trim();

/// Lists X11SE hidraw interfaces under [sysfs] (`/sys/class/hidraw`).
Future<List<HidrawNode>> readHidrawNodes({
  String sysfs = '/sys/class/hidraw',
  String dev = '/dev',
}) async {
  final root = Directory(sysfs);
  if (!await root.exists()) return const [];
  final nodes = <HidrawNode>[];
  await for (final entry in root.list(followLinks: false)) {
    final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (!name.startsWith('hidraw')) continue;
    try {
      final uevent = await File('${entry.path}/device/uevent').readAsString();
      final id = parseHidId(uevent);
      if (id == null) continue;
      final (vendorId, productId) = id;
      if (vendorId != X11seUsb.vendorId ||
          !X11seUsb.productIds.contains(productId)) {
        continue;
      }
      final descriptor = await File(
        '${entry.path}/device/report_descriptor',
      ).readAsBytes();
      nodes.add(
        HidrawNode(
          devicePath: '$dev/$name',
          vendorId: vendorId,
          productId: productId,
          physical: _ueventValue(uevent, 'HID_PHYS') ?? name,
          productName: _ueventValue(uevent, 'HID_NAME'),
          descriptor: parseReportDescriptor(descriptor),
        ),
      );
    } on FileSystemException {
      continue;
    }
  }
  return nodes;
}

/// Pairs the feature and notification interfaces of each physical device.
List<HidrawDevice> groupHidrawNodes(Iterable<HidrawNode> nodes) {
  final groups = <String, List<HidrawNode>>{};
  for (final node in nodes) {
    final cut = node.physical.lastIndexOf('/input');
    final parent = cut > 0 ? node.physical.substring(0, cut) : node.physical;
    final key =
        '${node.vendorId.toRadixString(16)}:'
        '${node.productId.toRadixString(16)}:$parent';
    groups.putIfAbsent(key, () => []).add(node);
  }
  final devices = <HidrawDevice>[];
  for (final MapEntry(key: id, value: members) in groups.entries) {
    members.sort((a, b) => a.devicePath.compareTo(b.devicePath));
    final feature =
        members
            .where(
              (n) =>
                  n.descriptor.usagePages.contains(X11seUsb.featureUsagePage) &&
                  n.descriptor.featureLength > 0,
            )
            .firstOrNull ??
        members.where((n) => n.descriptor.featureLength > 0).firstOrNull;
    if (feature == null) continue;
    final notification = members
        .where(
          (n) =>
              n.descriptor.usagePages.contains(
                X11seUsb.notificationUsagePage,
              ) &&
              n.descriptor.inputLength > 0,
        )
        .firstOrNull;
    devices.add(
      HidrawDevice(
        info: HidDeviceInfo(
          id: id,
          vendorId: feature.vendorId,
          productId: feature.productId,
          productName: feature.productName,
        ),
        featurePath: feature.devicePath,
        featureLength: feature.descriptor.featureLength,
        notificationPath: notification?.devicePath,
        notificationLength: notification?.descriptor.inputLength ?? 0,
      ),
    );
  }
  devices.sort((a, b) => a.info.id.compareTo(b.info.id));
  return devices;
}
