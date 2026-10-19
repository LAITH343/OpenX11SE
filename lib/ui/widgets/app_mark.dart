import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/nocturne_theme.dart';

class AppMark extends StatelessWidget {
  const AppMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = context.nocturne.accent;
    return Tooltip(
      message: tr('OpenX11SE'),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(size * 0.27),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: CustomPaint(
          size: Size.square(size * 0.86),
          painter: AppGlyphPainter(color: accent),
        ),
      ),
    );
  }
}

class AppGlyphPainter extends CustomPainter {
  const AppGlyphPainter({required this.color});

  final Color color;

  static final Path brackets = Path()
    ..moveTo(6, 7.5)
    ..lineTo(2.5, 12)
    ..lineTo(6, 16.5)
    ..moveTo(18, 7.5)
    ..lineTo(21.5, 12)
    ..lineTo(18, 16.5);

  static final Path fin = Path()
    ..moveTo(8, 16.5)
    ..cubicTo(10.4, 15.4, 12, 11.8, 12.4, 6)
    ..cubicTo(14, 9.8, 15.4, 13.6, 16, 16.5)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24, size.height / 24)
      ..drawPath(
        brackets,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      )
      ..drawPath(fin, Paint()..color = color)
      ..drawPath(
        fin,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(AppGlyphPainter old) => old.color != color;
}
