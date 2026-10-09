import 'dart:typed_data';

import '../../domain/button_assignment.dart';
import '../../domain/device_info.dart';
import '../../domain/device_settings.dart';
import '../../domain/macro.dart';
import '../protocol/button_report.dart';
import '../protocol/device_reads.dart';
import '../protocol/dpi_report.dart';
import '../protocol/lighting_report.dart';
import '../protocol/macro_report.dart';
import '../protocol/polling_report.dart';
import '../protocol/report_format.dart';

class OutgoingReport {
  OutgoingReport(this.reportId, List<Uint8List> chunks, {this.expectAck = true})
    : chunks = List.unmodifiable(chunks);

  final int reportId;
  final List<Uint8List> chunks;
  final bool expectAck;

  @override
  String toString() =>
      'OutgoingReport(0x${reportId.toRadixString(16)}, ${chunks.length})';
}

List<OutgoingReport> planApply({
  required DeviceSettings? previous,
  required DeviceSettings next,
  required ConnectionType connection,
  Map<int, Macro> macros = const {},
  Set<int> changedMacroIds = const {},
  bool restoreDefaults = false,
  bool forceButtons = false,
}) {
  final base = restoreDefaults ? null : previous;
  return [
    if (restoreDefaults)
      OutgoingReport(ReportId.restoreDefaults, [
        encodeRestoreDefaultsReport(),
      ], expectAck: false),
    if (base == null || base.dpi != next.dpi || base.sensor != next.sensor)
      OutgoingReport(ReportId.dpi, [encodeDpiReport(next.dpi, next.sensor)]),
    if (base == null ||
        base.lighting != next.lighting ||
        base.power != next.power)
      OutgoingReport(ReportId.lighting, [
        encodeLightingReport(next.lighting, next.power),
      ]),
    if (base == null || base.polling != next.polling)
      OutgoingReport(ReportId.polling, [encodePollingReport(next.polling)]),
    if (base == null ||
        forceButtons ||
        !_sameButtons(base.buttons, next.buttons))
      OutgoingReport(ReportId.buttons, [encodeButtonReport(next.buttons)]),
    for (var slot = 0; slot < next.buttons.length; slot++)
      if (_macroUpload(slot, base, next, macros, changedMacroIds)
          case final upload?)
        OutgoingReport(
          ReportId.macro,
          encodeMacroReports(
            macroSlotId(slot),
            upload.$1.events,
            upload.$2,
            connection: connection,
          ),
        ),
  ];
}

(Macro, MacroPlayback)? _macroUpload(
  int slot,
  DeviceSettings? base,
  DeviceSettings next,
  Map<int, Macro> macros,
  Set<int> changedMacroIds,
) {
  final assignment = next.buttons[slot];
  if (assignment is! MacroButton || !supportsMacro(slot)) return null;
  final macro = macros[assignment.macroId];
  if (macro == null) return null;
  final changed =
      base == null ||
      base.buttons[slot] != assignment ||
      changedMacroIds.contains(assignment.macroId);
  return changed ? (macro, assignment.playback) : null;
}

bool _sameButtons(List<ButtonAssignment> a, List<ButtonAssignment> b) {
  for (var slot = 0; slot < a.length; slot++) {
    if (encodeButtonEntry(slot, a[slot]) != encodeButtonEntry(slot, b[slot])) {
      return false;
    }
  }
  return true;
}
