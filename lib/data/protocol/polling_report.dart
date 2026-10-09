import 'dart:typed_data';

import '../../domain/polling_rate.dart';
import 'report_format.dart';

int pollingCode(PollingRate rate) => switch (rate) {
  PollingRate.hz125 => 0x08,
  PollingRate.hz250 => 0x04,
  PollingRate.hz500 => 0x02,
  PollingRate.hz1000 => 0x01,
};

PollingRate pollingFromCode(int code) => switch (code) {
  0x08 => PollingRate.hz125,
  0x04 => PollingRate.hz250,
  0x02 => PollingRate.hz500,
  0x01 => PollingRate.hz1000,
  _ => throw ProtocolException(
    'Unknown polling code 0x${code.toRadixString(16)}',
  ),
};

Uint8List encodePollingReport(PollingRate rate) {
  final code = pollingCode(rate);
  return Uint8List.fromList([
    ReportId.polling,
    ReportLength.polling,
    0x01,
    code,
    0xFF - code,
    0,
    0,
    0,
    0,
  ]);
}

PollingRate decodePollingReport(List<int> bytes) {
  expectHeader(bytes, const [ReportId.polling, ReportLength.polling, 0x01], 5);
  return readPollingBody(bytes, 3);
}

PollingRate readPollingBody(List<int> bytes, int offset) {
  final code = bytes[offset];
  if (bytes[offset + 1] != 0xFF - code) {
    throw const ProtocolException('Polling code complement mismatch');
  }
  return pollingFromCode(code);
}
