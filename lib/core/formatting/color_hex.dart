import 'dart:ui' show Color;

final _hexPattern = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$');

Color? parseHexColor(String input) {
  final m = _hexPattern.firstMatch(input.trim());
  if (m == null) return null;
  var hex = m.group(1)!;
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

String formatHexColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
