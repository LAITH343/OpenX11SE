import 'dart:typed_data';

import '../../domain/device_info.dart';
import '../../domain/macro.dart';
import 'report_format.dart';

const macroPairLimit = 50;
const macroMaxDelayMs = 50000;
const macroChunkCount = 3;

const _shortDelayMaxMs = 1270;
const _extendedDelayStepMs = 200;
const _extendedDelayMarker = 0x03;
const _pairOffset = 29;
const _chunkPayload = 60;
const _wirelessLastChunkLength = 0x0C;

int macroEventPairs(MacroEvent event) =>
    event.delayMs > _shortDelayMaxMs ? 2 : 1;

int macroPairCount(Iterable<MacroEvent> events) =>
    events.fold(0, (sum, e) => sum + macroEventPairs(e));

int macroPairsLeft(Iterable<MacroEvent> events) =>
    macroPairLimit - macroPairCount(events);

bool fitsMacroCapacity(Iterable<MacroEvent> events) =>
    macroPairCount(events) <= macroPairLimit;

List<int> encodeMacroEvent(MacroEvent event) {
  RangeError.checkValueInInterval(event.delayMs, 0, macroMaxDelayMs, 'delayMs');
  final flag = event.action == MacroAction.press ? 0x01 : 0x81;
  final code = event.code & 0xFF;
  final delay = event.delayMs;
  if (delay <= _shortDelayMaxMs) return [_tenths(delay) | flag, code];
  return [
    _tenths(delay % _extendedDelayStepMs) | flag,
    code,
    delay ~/ _extendedDelayStepMs,
    _extendedDelayMarker,
  ];
}

int _tenths(int delayMs) => ((delayMs < 1 ? 1 : delayMs) / 10 + 0.5).truncate();

int macroPlayModeCode(MacroPlaybackMode mode) => switch (mode) {
  MacroPlaybackMode.once => 0,
  MacroPlaybackMode.untilKey => 1,
  MacroPlaybackMode.whileHeld => 2,
};

Uint8List encodeMacroBody(
  int slotId,
  List<MacroEvent> events,
  MacroPlayback playback,
) {
  final pairs = macroPairCount(events);
  if (pairs > macroPairLimit) {
    throw ArgumentError.value(pairs, 'events', 'Exceeds $macroPairLimit pairs');
  }
  final body = Uint8List(ReportLength.macroBody);
  body[0] = ReportId.macro;
  body[1] = ReportLength.macroBody;
  body[2] = slotId;
  body[3] = macroPlayModeCode(playback.mode);
  body[7] = clampInt(
    playback.loopCount,
    MacroPlayback.minLoopCount,
    MacroPlayback.maxLoopCount,
  );
  body[28] = pairs;
  var o = _pairOffset;
  for (final event in events) {
    final encoded = encodeMacroEvent(event);
    body.setRange(o, o + encoded.length, encoded);
    o += encoded.length;
  }
  writeUint16Be(body, 129, sumBytes(body, 3, 128));
  return body;
}

List<Uint8List> encodeMacroReports(
  int slotId,
  List<MacroEvent> events,
  MacroPlayback playback, {
  required ConnectionType connection,
}) {
  final body = encodeMacroBody(slotId, events, playback);
  return List.generate(macroChunkCount, (index) {
    final chunk = Uint8List(ReportLength.macroChunk);
    final isLast = index == macroChunkCount - 1;
    chunk[0] = ReportId.macro;
    chunk[1] = isLast && connection == ConnectionType.dongle
        ? _wirelessLastChunkLength
        : ReportLength.macroChunk;
    chunk[2] = slotId;
    chunk[3] = index;
    final start = 3 + index * _chunkPayload;
    final end = (start + _chunkPayload).clamp(0, body.length);
    chunk.setRange(4, 4 + end - start, body, start);
    return chunk;
  });
}
