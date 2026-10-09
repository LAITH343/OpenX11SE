import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _GetHidGuidN = Void Function(Pointer<Uint8>);
typedef _GetHidGuidD = void Function(Pointer<Uint8>);
typedef _GetClassDevsN =
    IntPtr Function(Pointer<Uint8>, Pointer<Utf16>, IntPtr, Uint32);
typedef _GetClassDevsD = int Function(Pointer<Uint8>, Pointer<Utf16>, int, int);
typedef _EnumInterfacesN =
    Int32 Function(
      IntPtr,
      Pointer<Void>,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint8>,
    );
typedef _EnumInterfacesD =
    int Function(int, Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>);
typedef _InterfaceDetailN =
    Int32 Function(
      IntPtr,
      Pointer<Uint8>,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint32>,
      Pointer<Void>,
    );
typedef _InterfaceDetailD =
    int Function(
      int,
      Pointer<Uint8>,
      Pointer<Uint8>,
      int,
      Pointer<Uint32>,
      Pointer<Void>,
    );
typedef _HandleBoolN = Int32 Function(IntPtr);
typedef _HandleBoolD = int Function(int);
typedef _HidBoolPtrN = Uint8 Function(IntPtr, Pointer<Uint8>);
typedef _HidBoolPtrD = int Function(int, Pointer<Uint8>);
typedef _HidBufferN = Uint8 Function(IntPtr, Pointer<Uint8>, Uint32);
typedef _HidBufferD = int Function(int, Pointer<Uint8>, int);
typedef _GetPreparsedN = Uint8 Function(IntPtr, Pointer<IntPtr>);
typedef _GetPreparsedD = int Function(int, Pointer<IntPtr>);
typedef _FreePreparsedN = Uint8 Function(IntPtr);
typedef _FreePreparsedD = int Function(int);
typedef _GetCapsN = Int32 Function(IntPtr, Pointer<Uint8>);
typedef _GetCapsD = int Function(int, Pointer<Uint8>);
typedef _CreateFileN =
    IntPtr Function(
      Pointer<Utf16>,
      Uint32,
      Uint32,
      Pointer<Void>,
      Uint32,
      Uint32,
      IntPtr,
    );
typedef _CreateFileD =
    int Function(Pointer<Utf16>, int, int, Pointer<Void>, int, int, int);
typedef _ReadFileN =
    Int32 Function(
      IntPtr,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint32>,
      Pointer<Uint8>,
    );
typedef _ReadFileD =
    int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Uint8>);
typedef _OverlappedResultN =
    Int32 Function(IntPtr, Pointer<Uint8>, Pointer<Uint32>, Int32);
typedef _OverlappedResultD =
    int Function(int, Pointer<Uint8>, Pointer<Uint32>, int);
typedef _CreateEventN =
    IntPtr Function(Pointer<Void>, Int32, Int32, Pointer<Utf16>);
typedef _CreateEventD = int Function(Pointer<Void>, int, int, Pointer<Utf16>);
typedef _WaitN = Uint32 Function(IntPtr, Uint32);
typedef _WaitD = int Function(int, int);
typedef _CancelIoN = Int32 Function(IntPtr, Pointer<Uint8>);
typedef _CancelIoD = int Function(int, Pointer<Uint8>);
typedef _LastErrorN = Uint32 Function();
typedef _LastErrorD = int Function();

const _invalidHandle = -1;
const _digcfPresent = 0x02;
const _digcfDeviceInterface = 0x10;
const _genericRead = 0x80000000;
const _genericWrite = 0x40000000;
const _fileShareReadWrite = 0x03;
const _openExisting = 3;
const _fileFlagOverlapped = 0x40000000;
const _hidpStatusSuccess = 0x00110000;
const _waitObject0 = 0;
const _waitTimeout = 0x102;
const _errorIoPending = 997;
const _errorOperationAborted = 995;
const _errorFileNotFound = 2;
const _errorInvalidHandle = 6;
const _errorGenFailure = 31;
const _errorDeviceNotConnected = 1167;
const _guidSize = 16;
const _interfaceDataSize = 32;
const _detailCbSize = 8;
const _capsSize = 64;
const _attributesSize = 12;
const _overlappedSize = 32;
const _overlappedEventOffset = 24;

class HidCaps {
  const HidCaps({
    required this.usagePage,
    required this.usage,
    required this.inputLength,
    required this.featureLength,
  });

  final int usagePage;
  final int usage;
  final int inputLength;
  final int featureLength;
}

class HidInterfaceProbe {
  const HidInterfaceProbe({
    required this.path,
    required this.vendorId,
    required this.productId,
    required this.caps,
  });

  final String path;
  final int vendorId;
  final int productId;
  final HidCaps caps;
}

class Win32HidException implements Exception {
  const Win32HidException(this.operation, this.errorCode);

  final String operation;
  final int errorCode;

  bool get disconnected => const {
    _errorFileNotFound,
    _errorInvalidHandle,
    _errorGenFailure,
    _errorOperationAborted,
    _errorDeviceNotConnected,
  }.contains(errorCode);

  @override
  String toString() => '$operation failed (Win32 error $errorCode)';
}

enum ReadWait { data, timeout }

class Win32Hid {
  Win32Hid()
    : _setupapi = DynamicLibrary.open('setupapi.dll'),
      _hid = DynamicLibrary.open('hid.dll'),
      _kernel32 = DynamicLibrary.open('kernel32.dll') {
    _getHidGuid = _hid.lookupFunction<_GetHidGuidN, _GetHidGuidD>(
      'HidD_GetHidGuid',
    );
    _getClassDevs = _setupapi.lookupFunction<_GetClassDevsN, _GetClassDevsD>(
      'SetupDiGetClassDevsW',
    );
    _enumInterfaces = _setupapi
        .lookupFunction<_EnumInterfacesN, _EnumInterfacesD>(
          'SetupDiEnumDeviceInterfaces',
        );
    _interfaceDetail = _setupapi
        .lookupFunction<_InterfaceDetailN, _InterfaceDetailD>(
          'SetupDiGetDeviceInterfaceDetailW',
        );
    _destroyInfoList = _setupapi.lookupFunction<_HandleBoolN, _HandleBoolD>(
      'SetupDiDestroyDeviceInfoList',
    );
    _getAttributes = _hid.lookupFunction<_HidBoolPtrN, _HidBoolPtrD>(
      'HidD_GetAttributes',
    );
    _getPreparsed = _hid.lookupFunction<_GetPreparsedN, _GetPreparsedD>(
      'HidD_GetPreparsedData',
    );
    _freePreparsed = _hid.lookupFunction<_FreePreparsedN, _FreePreparsedD>(
      'HidD_FreePreparsedData',
    );
    _getCaps = _hid.lookupFunction<_GetCapsN, _GetCapsD>('HidP_GetCaps');
    _setFeature = _hid.lookupFunction<_HidBufferN, _HidBufferD>(
      'HidD_SetFeature',
    );
    _getFeature = _hid.lookupFunction<_HidBufferN, _HidBufferD>(
      'HidD_GetFeature',
    );
    _getProductString = _hid.lookupFunction<_HidBufferN, _HidBufferD>(
      'HidD_GetProductString',
    );
    _createFile = _kernel32.lookupFunction<_CreateFileN, _CreateFileD>(
      'CreateFileW',
    );
    _closeHandle = _kernel32.lookupFunction<_HandleBoolN, _HandleBoolD>(
      'CloseHandle',
    );
    _readFile = _kernel32.lookupFunction<_ReadFileN, _ReadFileD>('ReadFile');
    _overlappedResult = _kernel32
        .lookupFunction<_OverlappedResultN, _OverlappedResultD>(
          'GetOverlappedResult',
        );
    _createEvent = _kernel32.lookupFunction<_CreateEventN, _CreateEventD>(
      'CreateEventW',
    );
    _wait = _kernel32.lookupFunction<_WaitN, _WaitD>('WaitForSingleObject');
    _cancelIo = _kernel32.lookupFunction<_CancelIoN, _CancelIoD>('CancelIoEx');
    _lastError = _kernel32.lookupFunction<_LastErrorN, _LastErrorD>(
      'GetLastError',
    );
  }

  final DynamicLibrary _setupapi;
  final DynamicLibrary _hid;
  final DynamicLibrary _kernel32;

  late final _GetHidGuidD _getHidGuid;
  late final _GetClassDevsD _getClassDevs;
  late final _EnumInterfacesD _enumInterfaces;
  late final _InterfaceDetailD _interfaceDetail;
  late final _HandleBoolD _destroyInfoList;
  late final _HidBoolPtrD _getAttributes;
  late final _GetPreparsedD _getPreparsed;
  late final _FreePreparsedD _freePreparsed;
  late final _GetCapsD _getCaps;
  late final _HidBufferD _setFeature;
  late final _HidBufferD _getFeature;
  late final _HidBufferD _getProductString;
  late final _CreateFileD _createFile;
  late final _HandleBoolD _closeHandle;
  late final _ReadFileD _readFile;
  late final _OverlappedResultD _overlappedResult;
  late final _CreateEventD _createEvent;
  late final _WaitD _wait;
  late final _CancelIoD _cancelIo;
  late final _LastErrorD _lastError;

  List<String> interfacePaths() {
    final guid = calloc<Uint8>(_guidSize);
    final data = calloc<Uint8>(_interfaceDataSize);
    final required = calloc<Uint32>();
    final paths = <String>[];
    try {
      _getHidGuid(guid);
      final infoSet = _getClassDevs(
        guid,
        nullptr,
        0,
        _digcfPresent | _digcfDeviceInterface,
      );
      if (infoSet == _invalidHandle) {
        throw Win32HidException('SetupDiGetClassDevs', _lastError());
      }
      try {
        for (var i = 0; ; i++) {
          data.cast<Uint32>().value = _interfaceDataSize;
          if (_enumInterfaces(infoSet, nullptr, guid, i, data) == 0) break;
          _interfaceDetail(infoSet, data, nullptr, 0, required, nullptr);
          final size = required.value;
          if (size < _detailCbSize) continue;
          final detail = calloc<Uint8>(size);
          try {
            detail.cast<Uint32>().value = _detailCbSize;
            if (_interfaceDetail(
                  infoSet,
                  data,
                  detail,
                  size,
                  nullptr,
                  nullptr,
                ) !=
                0) {
              paths.add((detail + 4).cast<Utf16>().toDartString());
            }
          } finally {
            calloc.free(detail);
          }
        }
      } finally {
        _destroyInfoList(infoSet);
      }
    } finally {
      calloc
        ..free(guid)
        ..free(data)
        ..free(required);
    }
    return paths;
  }

  HidInterfaceProbe? probe(String path) {
    final handle = _open(path, 0, 0);
    if (handle == _invalidHandle) return null;
    final attributes = calloc<Uint8>(_attributesSize);
    final preparsed = calloc<IntPtr>();
    final caps = calloc<Uint8>(_capsSize);
    try {
      attributes.cast<Uint32>().value = _attributesSize;
      if (_getAttributes(handle, attributes) == 0) return null;
      final ids = attributes.cast<Uint16>().asTypedList(4);
      final vendorId = ids[2];
      final productId = ids[3];
      if (_getPreparsed(handle, preparsed) == 0) return null;
      try {
        if (_getCaps(preparsed.value, caps) != _hidpStatusSuccess) return null;
      } finally {
        _freePreparsed(preparsed.value);
      }
      final c = caps.cast<Uint16>().asTypedList(5);
      return HidInterfaceProbe(
        path: path,
        vendorId: vendorId,
        productId: productId,
        caps: HidCaps(
          usage: c[0],
          usagePage: c[1],
          inputLength: c[2],
          featureLength: c[4],
        ),
      );
    } finally {
      calloc
        ..free(attributes)
        ..free(preparsed)
        ..free(caps);
      _closeHandle(handle);
    }
  }

  String? productString(String path) {
    final handle = _open(path, 0, 0);
    if (handle == _invalidHandle) return null;
    final buffer = calloc<Uint8>(256);
    try {
      if (_getProductString(handle, buffer, 256) == 0) return null;
      final text = buffer.cast<Utf16>().toDartString();
      return text.isEmpty ? null : text;
    } finally {
      calloc.free(buffer);
      _closeHandle(handle);
    }
  }

  int openReadWrite(String path, {bool overlapped = false}) {
    final handle = _open(
      path,
      _genericRead | _genericWrite,
      overlapped ? _fileFlagOverlapped : 0,
    );
    if (handle == _invalidHandle) {
      throw Win32HidException('CreateFile', _lastError());
    }
    return handle;
  }

  int _open(String path, int access, int flags) {
    final native = path.toNativeUtf16();
    try {
      return _createFile(
        native,
        access,
        _fileShareReadWrite,
        nullptr,
        _openExisting,
        flags,
        0,
      );
    } finally {
      calloc.free(native);
    }
  }

  void close(int handle) => _closeHandle(handle);

  void setFeature(int handle, Uint8List report) {
    final buffer = calloc<Uint8>(report.length);
    try {
      buffer.asTypedList(report.length).setAll(0, report);
      if (_setFeature(handle, buffer, report.length) == 0) {
        throw Win32HidException('HidD_SetFeature', _lastError());
      }
    } finally {
      calloc.free(buffer);
    }
  }

  Uint8List getFeature(int handle, int reportId, int length) {
    final buffer = calloc<Uint8>(length);
    try {
      buffer[0] = reportId;
      if (_getFeature(handle, buffer, length) == 0) {
        throw Win32HidException('HidD_GetFeature', _lastError());
      }
      return Uint8List.fromList(buffer.asTypedList(length));
    } finally {
      calloc.free(buffer);
    }
  }

  OverlappedReader overlappedReader(int handle, int length) =>
      OverlappedReader._(this, handle, length);
}

class OverlappedReader {
  OverlappedReader._(this._api, this._handle, this.length)
    : _buffer = calloc<Uint8>(length),
      _transferred = calloc<Uint32>(),
      _overlapped = calloc<Uint8>(_overlappedSize) {
    _event = _api._createEvent(nullptr, 1, 0, nullptr);
    if (_event == 0) {
      _free();
      throw Win32HidException('CreateEvent', _api._lastError());
    }
    (_overlapped + _overlappedEventOffset).cast<IntPtr>().value = _event;
  }

  final Win32Hid _api;
  final int _handle;
  final int length;
  final Pointer<Uint8> _buffer;
  final Pointer<Uint32> _transferred;
  final Pointer<Uint8> _overlapped;
  late final int _event;
  bool _pending = false;

  void start() {
    if (_pending) return;
    _overlapped
        .asTypedList(_overlappedEventOffset)
        .fillRange(0, _overlappedEventOffset, 0);
    if (_api._readFile(_handle, _buffer, length, nullptr, _overlapped) == 0) {
      final error = _api._lastError();
      if (error != _errorIoPending) throw Win32HidException('ReadFile', error);
    }
    _pending = true;
  }

  ReadWait wait(int timeoutMs) {
    final result = _api._wait(_event, timeoutMs);
    if (result == _waitTimeout) return ReadWait.timeout;
    if (result != _waitObject0) {
      throw Win32HidException('WaitForSingleObject', _api._lastError());
    }
    return ReadWait.data;
  }

  Uint8List complete() {
    _pending = false;
    if (_api._overlappedResult(_handle, _overlapped, _transferred, 0) == 0) {
      throw Win32HidException('GetOverlappedResult', _api._lastError());
    }
    return Uint8List.fromList(_buffer.asTypedList(_transferred.value));
  }

  void cancel() {
    if (!_pending) return;
    _api._cancelIo(_handle, _overlapped);
    _api._overlappedResult(_handle, _overlapped, _transferred, 1);
    _pending = false;
  }

  void dispose() {
    cancel();
    _api._closeHandle(_event);
    _free();
  }

  void _free() {
    calloc
      ..free(_buffer)
      ..free(_transferred)
      ..free(_overlapped);
  }
}
