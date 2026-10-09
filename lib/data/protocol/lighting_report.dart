import 'dart:typed_data';

import '../../domain/lighting_settings.dart';
import '../../domain/power_settings.dart';
import '../../domain/rgb_color.dart';
import 'report_format.dart';

const lightingBodyLength = 8;

typedef LightingReportValues = ({
  LightingSettings lighting,
  PowerSettings power,
});

Uint8List encodeLightingReport(LightingSettings lighting, PowerSettings power) {
  final buffer = Uint8List(ReportLength.lighting);
  buffer[0] = ReportId.lighting;
  buffer[1] = ReportLength.lighting;
  buffer[2] = 0x01;
  writeLightingBody(buffer, 3, lighting, power);
  writeUint16Be(buffer, 11, sumBytes(buffer, 3, 10));
  return buffer;
}

LightingReportValues decodeLightingReport(List<int> bytes) {
  expectHeader(bytes, const [
    ReportId.lighting,
    ReportLength.lighting,
    0x01,
  ], 13);
  expectChecksum(sumBytes(bytes, 3, 10), readUint16Be(bytes, 11), '0x05');
  return readLightingBody(bytes, 3);
}

void writeLightingBody(
  Uint8List buffer,
  int offset,
  LightingSettings lighting,
  PowerSettings power,
) {
  _checkLevel(lighting.brightness, 'brightness');
  _checkLevel(lighting.speed, 'speed');
  RangeError.checkValueInInterval(
    power.sleepMinutes,
    PowerSettings.minMinutes,
    PowerSettings.maxMinutes,
    'sleepMinutes',
  );
  RangeError.checkValueInInterval(
    power.deepSleepMinutes,
    PowerSettings.minMinutes,
    PowerSettings.maxMinutes,
    'deepSleepMinutes',
  );
  RangeError.checkValueInInterval(
    power.debounceMs,
    PowerSettings.minDebounceMs,
    PowerSettings.maxDebounceMs,
    'debounceMs',
  );
  final deepSleep = power.deepSleepMinutes;
  final brightness = lighting.mode.usesBrightness ? lighting.brightness : 8;
  buffer[offset] = lighting.mode.index << 4;
  buffer[offset + 1] = (deepSleep & 0xF0) | (9 - lighting.speed);
  buffer[offset + 2] = ((deepSleep & 0x0F) << 4) | brightness;
  buffer[offset + 3] = lighting.color.r;
  buffer[offset + 4] = lighting.color.g;
  buffer[offset + 5] = lighting.color.b;
  buffer[offset + 6] = power.sleepMinutes;
  buffer[offset + 7] = power.debounceMs ~/ 2;
}

LightingReportValues readLightingBody(List<int> bytes, int offset) {
  final modeIndex = bytes[offset] >> 4;
  if (modeIndex >= LightingMode.values.length) {
    throw ProtocolException('Unknown lighting mode $modeIndex');
  }
  final b1 = bytes[offset + 1];
  final b2 = bytes[offset + 2];
  const min = LightingSettings.minLevel;
  const max = LightingSettings.maxLevel;
  return (
    lighting: LightingSettings(
      mode: LightingMode.values[modeIndex],
      color: RgbColor(bytes[offset + 3], bytes[offset + 4], bytes[offset + 5]),
      brightness: clampInt(b2 & 0x0F, min, max),
      speed: clampInt(9 - (b1 & 0x0F), min, max),
    ),
    power: PowerSettings(
      sleepMinutes: clampInt(
        bytes[offset + 6],
        PowerSettings.minMinutes,
        PowerSettings.maxMinutes,
      ),
      deepSleepMinutes: clampInt(
        (b1 & 0xF0) | (b2 >> 4),
        PowerSettings.minMinutes,
        PowerSettings.maxMinutes,
      ),
      debounceMs: clampInt(
        bytes[offset + 7] * 2,
        PowerSettings.minDebounceMs,
        PowerSettings.maxDebounceMs,
      ),
    ),
  );
}

void _checkLevel(int value, String name) => RangeError.checkValueInInterval(
  value,
  LightingSettings.minLevel,
  LightingSettings.maxLevel,
  name,
);
