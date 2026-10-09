import 'dart:typed_data';

abstract final class ReportId {
  static const dpi = 0x04;
  static const lighting = 0x05;
  static const polling = 0x06;
  static const buttons = 0x08;
  static const macro = 0x09;
  static const snapshot = 0x0A;
  static const version = 0x0B;
  static const restoreDefaults = 0x0C;
  static const readRequest = 0xA0;
}

abstract final class ReportLength {
  static const dpi = 56;
  static const lighting = 15;
  static const polling = 9;
  static const buttons = 59;
  static const macroBody = 131;
  static const macroChunk = 64;
  static const snapshot = 128;
  static const version = 8;
  static const restoreDefaults = 10;
  static const readRequest = 8;
}

class ProtocolException implements Exception {
  const ProtocolException(this.message);

  final String message;

  @override
  String toString() => 'ProtocolException: $message';
}

int sumBytes(List<int> bytes, int start, int endInclusive) {
  var sum = 0;
  for (var i = start; i <= endInclusive; i++) {
    sum += bytes[i];
  }
  return sum & 0xFFFF;
}

void writeUint16Be(Uint8List buffer, int offset, int value) {
  buffer[offset] = (value >> 8) & 0xFF;
  buffer[offset + 1] = value & 0xFF;
}

int readUint16Be(List<int> bytes, int offset) =>
    (bytes[offset] << 8) | bytes[offset + 1];

int readUint16Le(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

void expectHeader(List<int> bytes, List<int> header, int minLength) {
  if (bytes.length < minLength) {
    throw ProtocolException(
      'Report 0x${header[0].toRadixString(16)} too short: ${bytes.length}',
    );
  }
  for (var i = 0; i < header.length; i++) {
    if (bytes[i] != header[i]) {
      throw ProtocolException(
        'Unexpected header byte $i for report 0x${header[0].toRadixString(16)}',
      );
    }
  }
}

void expectChecksum(int expected, int actual, String report) {
  if ((expected & 0xFFFF) != actual) {
    throw ProtocolException('Checksum mismatch in $report');
  }
}

int clampInt(int value, int min, int max) =>
    value < min ? min : (value > max ? max : value);
