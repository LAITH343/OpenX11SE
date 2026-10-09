import '../../domain/device_settings.dart';
import 'button_report.dart';
import 'dpi_report.dart';
import 'lighting_report.dart';
import 'polling_report.dart';
import 'report_format.dart';

const _pollingOffset = 3;
const _dpiOffset = 5;
const _dpiChecksumOffset = 53;
const _lightingOffset = 55;
const _lightingChecksumOffset = 63;
const _buttonOffset = 65;
const _buttonChecksumOffset = 119;

DeviceSettings decodeSnapshot(List<int> bytes) {
  expectHeader(bytes, const [
    ReportId.snapshot,
    ReportLength.snapshot,
    0x01,
  ], ReportLength.snapshot);
  expectChecksum(
    sumBytes(bytes, _dpiOffset, _dpiChecksumOffset - 1),
    readUint16Le(bytes, _dpiChecksumOffset),
    'snapshot DPI block',
  );
  expectChecksum(
    sumBytes(bytes, _lightingOffset, _lightingChecksumOffset - 1),
    readUint16Le(bytes, _lightingChecksumOffset),
    'snapshot lighting block',
  );
  expectChecksum(
    sumBytes(bytes, _buttonOffset, _buttonChecksumOffset - 1),
    readUint16Le(bytes, _buttonChecksumOffset),
    'snapshot button block',
  );
  final dpi = readDpiBody(bytes, _dpiOffset);
  final lighting = readLightingBody(bytes, _lightingOffset);
  return DeviceSettings(
    dpi: dpi.dpi,
    sensor: dpi.sensor,
    lighting: lighting.lighting,
    power: lighting.power,
    polling: readPollingBody(bytes, _pollingOffset),
    buttons: readButtonBody(bytes, _buttonOffset),
  );
}
