class RgbColor {
  const RgbColor(this.r, this.g, this.b);

  const RgbColor.hex(int rgb)
    : r = (rgb >> 16) & 0xFF,
      g = (rgb >> 8) & 0xFF,
      b = rgb & 0xFF;

  final int r;
  final int g;
  final int b;

  int get rgb => (r << 16) | (g << 8) | b;

  @override
  bool operator ==(Object other) =>
      other is RgbColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => rgb;

  @override
  String toString() =>
      'RgbColor(#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()})';
}
