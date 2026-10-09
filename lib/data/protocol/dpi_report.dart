import 'dart:typed_data';

import '../../domain/dpi_settings.dart';
import '../../domain/rgb_color.dart';
import 'dpi_codec.dart';
import 'report_format.dart';

const dpiBodyLength = 47;

typedef DpiReportValues = ({DpiSettings dpi, SensorOptions sensor});

Uint8List encodeDpiReport(DpiSettings dpi, SensorOptions sensor) {
  final buffer = Uint8List(ReportLength.dpi);
  buffer[0] = ReportId.dpi;
  buffer[1] = ReportLength.dpi;
  buffer[2] = 0x01;
  writeDpiBody(buffer, 3, dpi, sensor);
  writeUint16Be(buffer, 50, sumBytes(buffer, 3, 49));
  return buffer;
}

DpiReportValues decodeDpiReport(List<int> bytes) {
  expectHeader(bytes, const [ReportId.dpi, ReportLength.dpi, 0x01], 52);
  expectChecksum(sumBytes(bytes, 3, 49), readUint16Be(bytes, 50), '0x04');
  return readDpiBody(bytes, 3);
}

void writeDpiBody(
  Uint8List buffer,
  int offset,
  DpiSettings dpi,
  SensorOptions sensor,
) {
  buffer[offset] = sensor.angleSnap ? 1 : 0;
  buffer[offset + 1] = sensor.ripple ? 1 : 0;
  var enableMask = 0;
  var highRangeMask = 0;
  for (var i = 0; i < DpiSettings.stageCount; i++) {
    final stage = dpi.stages[i];
    if (stage.enabled) enableMask |= 1 << i;
    final code = encodeDpiRaw(dpiToRaw(stage.dpi));
    if (code.highRange) highRangeMask |= 1 << i;
    buffer[offset + 5 + i] = code.code;
    buffer[offset + 13 + i] = code.flag ? 1 : 0;
    final c = offset + 22 + i * 3;
    buffer[c] = stage.color.r;
    buffer[c + 1] = stage.color.g;
    buffer[c + 2] = stage.color.b;
  }
  buffer[offset + 2] = enableMask;
  buffer[offset + 3] = highRangeMask;
  buffer[offset + 4] = highRangeMask;
  buffer[offset + 21] = dpi.activeStageIndex + 1;
  buffer[offset + 46] = 0x02;
}

DpiReportValues readDpiBody(List<int> bytes, int offset) {
  final enableMask = bytes[offset + 2];
  final highRangeMask = bytes[offset + 3];
  final fallback = DpiSettings.factoryDefaults.stages;
  final stages = List.generate(DpiSettings.stageCount, (i) {
    final code = bytes[offset + 5 + i];
    final c = offset + 22 + i * 3;
    return DpiStage(
      enabled: enableMask & (1 << i) != 0,
      dpi: code == 0
          ? fallback[i].dpi
          : rawToDpi(
              decodeDpiRaw((
                code: code,
                flag: bytes[offset + 13 + i] != 0,
                highRange: highRangeMask & (1 << i) != 0,
              )),
            ),
      color: RgbColor(bytes[c], bytes[c + 1], bytes[c + 2]),
    );
  });
  final active = bytes[offset + 21];
  final activeIndex = active >= 1 && active <= DpiSettings.stageCount
      ? active - 1
      : stages.indexWhere((s) => s.enabled).clamp(0, 7);
  return (
    dpi: DpiSettings(stages: stages, activeStageIndex: activeIndex),
    sensor: SensorOptions(
      angleSnap: bytes[offset] != 0,
      ripple: bytes[offset + 1] != 0,
    ),
  );
}
