import 'dart:typed_data';

import 'package:openx11se/data/protocol/report_format.dart';

Uint8List hex(String s, [int? length]) {
  final bytes = s
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => int.parse(t, radix: 16))
      .toList();
  return Uint8List.fromList([
    ...bytes,
    if (length != null) ...List.filled(length - bytes.length, 0),
  ]);
}

final defaultDpiReport = hex(
  '04 38 01 00 01 3F 20 20 12 25 38 4B 75 81 01 01 00 00 00 00 00 01 00 00 03 '
  'FF 00 00 00 FF 00 00 00 FF FF FF 00 00 FF FF FF 00 FF FF 40 00 FF FF FF 02 0F 6B',
  ReportLength.dpi,
);

final defaultSnapshot = hex(
  '0A 80 01 01 FE 00 01 3F 20 20 12 25 38 4B 75 81 00 00 00 00 00 00 00 01 00 00 03 '
  'FF 00 00 00 FF 00 00 00 FF FF FF 00 00 FF FF FF 00 FF FF 40 00 FF FF FF 02 00 69 0F '
  '00 03 A8 00 FF 00 01 04 AF 01 '
  '02 00 00 03 00 00 04 00 00 00 00 00 00 00 00 0D 00 00 06 00 00 05 00 00 '
  '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
  '09 00 00 0A 00 00 34 00',
  ReportLength.snapshot,
);
