import 'dart:typed_data';

import 'report_format.dart';

const firmwareIndividualReadsFamily = 0x0700;

Uint8List encodeReadRequest(int reportId, int length, {int arg = 1}) =>
    Uint8List.fromList([
      ReportId.readRequest,
      reportId,
      length,
      0,
      arg,
      0,
      0,
      0,
    ]);

Uint8List versionReadRequest() =>
    encodeReadRequest(ReportId.version, ReportLength.version, arg: 0);

Uint8List snapshotReadRequest() =>
    encodeReadRequest(ReportId.snapshot, ReportLength.snapshot);

Uint8List dpiReadRequest() => encodeReadRequest(ReportId.dpi, ReportLength.dpi);

Uint8List lightingReadRequest() =>
    encodeReadRequest(ReportId.lighting, ReportLength.lighting);

Uint8List pollingReadRequest() =>
    encodeReadRequest(ReportId.polling, ReportLength.polling);

Uint8List encodeRestoreDefaultsReport() => Uint8List.fromList(const [
  ReportId.restoreDefaults,
  ReportLength.restoreDefaults,
  0x01,
  0xFE,
  0x01,
  0xFE,
  0,
  0,
  0,
  0,
]);

bool isBusyResponse(List<int> bytes) =>
    bytes.length >= 2 && bytes[0] == ReportId.readRequest && bytes[1] == 0x01;

bool isResponseFor(List<int> bytes, int reportId, int length) =>
    bytes.length >= 2 && bytes[0] == reportId && bytes[1] == length;

int decodeVersion(List<int> bytes) {
  expectHeader(bytes, const [ReportId.version, ReportLength.version], 4);
  return (bytes[2] << 8) | bytes[3];
}

bool usesIndividualReads(int version) =>
    (version & 0xFF00) == firmwareIndividualReadsFamily;
