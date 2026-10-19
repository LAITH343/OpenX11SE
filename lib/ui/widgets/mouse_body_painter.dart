import 'package:flutter/material.dart';

import '../../core/theme/nocturne_palette.dart';
import '../../domain/button_assignment.dart';

class MouseBodyPainter extends CustomPainter {
  MouseBodyPainter({
    required this.palette,
    this.highlights = const {},
    super.repaint,
  });

  final NocturnePalette palette;
  final Map<int, Animation<double>> highlights;

  static const bodySize = Size(200, 382);
  static const bleed = 8.0;

  static const _viewBox = Rect.fromLTWH(-8, -6, 216, 412);

  static const regions = [
    ButtonSlot.left,
    ButtonSlot.right,
    ButtonSlot.middle,
    ButtonSlot.forward,
    ButtonSlot.back,
  ];

  static final Path _body = Path()
    ..moveTo(9, 25)
    ..cubicTo(30, 14, 60, 4, 84, 0)
    ..lineTo(86, 14)
    ..lineTo(114, 14)
    ..lineTo(116, 0)
    ..cubicTo(140, 4, 170, 14, 191, 25)
    ..cubicTo(197, 32, 198, 45, 198, 70)
    ..lineTo(199, 262)
    ..cubicTo(199, 346, 160, 400, 100, 400)
    ..cubicTo(40, 400, 1, 346, 1, 262)
    ..lineTo(2, 70)
    ..cubicTo(2, 45, 3, 32, 9, 25)
    ..close();

  static final Path _left = Path()
    ..moveTo(9, 25)
    ..cubicTo(30, 14, 60, 4, 84, 0)
    ..lineTo(85, 116)
    ..lineTo(99, 118)
    ..lineTo(99, 187)
    ..lineTo(14, 187)
    ..cubicTo(6, 187, 3, 181, 3, 170)
    ..lineTo(2, 70)
    ..cubicTo(2, 45, 3, 32, 9, 25)
    ..close();

  static final Path _right = Path()
    ..moveTo(191, 25)
    ..cubicTo(170, 14, 140, 4, 116, 0)
    ..lineTo(115, 116)
    ..lineTo(101, 118)
    ..lineTo(101, 187)
    ..lineTo(186, 187)
    ..cubicTo(194, 187, 197, 181, 197, 170)
    ..lineTo(198, 70)
    ..cubicTo(198, 45, 197, 32, 191, 25)
    ..close();

  static final Path _seams = Path()
    ..moveTo(3, 170)
    ..cubicTo(3, 182, 6, 188, 14, 188)
    ..lineTo(186, 188)
    ..cubicTo(194, 188, 197, 182, 197, 170)
    ..moveTo(100, 118)
    ..lineTo(100, 188)
    ..moveTo(85, 2)
    ..lineTo(85, 116)
    ..lineTo(100, 118)
    ..lineTo(115, 116)
    ..lineTo(115, 2);

  static final RRect _wheelWell = RRect.fromLTRBR(
    86,
    14,
    114,
    116,
    const Radius.circular(4),
  );
  static final RRect _wheel = RRect.fromLTRBR(
    89,
    50,
    111,
    114,
    const Radius.circular(10),
  );
  static final RRect _forward = RRect.fromLTRBR(
    -4,
    128,
    3,
    186,
    const Radius.circular(3),
  );
  static final RRect _back = RRect.fromLTRBR(
    -4,
    192,
    3,
    250,
    const Radius.circular(3),
  );
  static final RRect _sensorMark = RRect.fromLTRBR(
    94,
    201,
    106,
    204.6,
    const Radius.circular(1.8),
  );

  static Offset _toViewBox(Offset local, Size size) => Offset(
    local.dx * _viewBox.width / size.width + _viewBox.left,
    local.dy * _viewBox.height / size.height + _viewBox.top,
  );

  static int? regionAt(Offset local, Size size) {
    final p = _toViewBox(local, size);
    if (_wheel.contains(p)) return ButtonSlot.middle;
    if (_forward.inflate(3).contains(p)) return ButtonSlot.forward;
    if (_back.inflate(3).contains(p)) return ButtonSlot.back;
    if (_left.contains(p)) return ButtonSlot.left;
    if (_right.contains(p)) return ButtonSlot.right;
    return null;
  }

  double _t(int slot) =>
      Curves.ease.transform(highlights[slot]?.value.clamp(0.0, 1.0) ?? 0);

  @override
  void paint(Canvas canvas, Size size) {
    const body = bodySize;
    canvas
      ..save()
      ..translate(bleed, bleed)
      ..scale(body.width / _viewBox.width, body.height / _viewBox.height)
      ..translate(-_viewBox.left, -_viewBox.top);

    final bounds = _body.getBounds();
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke;

    for (final shadow in palette.mouseShadow) {
      canvas.drawPath(
        _body.shift(shadow.offset),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
      );
    }
    canvas
      ..drawPath(
        _body,
        fill
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.mouseBody,
            stops: const [0, .55, 1],
          ).createShader(bounds),
      )
      ..drawPath(
        _body,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.3, -.4),
            radius: .6,
            colors: [
              palette.mouseSheen,
              palette.mouseSheen.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      )
      ..drawPath(
        _body,
        stroke
          ..color = palette.mouseEdge
          ..strokeWidth = 1.2,
      );

    final glow = palette.accent.withValues(alpha: .24);
    final clear = glow.withValues(alpha: 0);
    canvas
      ..drawPath(
        _left,
        Paint()..color = Color.lerp(clear, glow, _t(ButtonSlot.left))!,
      )
      ..drawPath(
        _right,
        Paint()..color = Color.lerp(clear, glow, _t(ButtonSlot.right))!,
      )
      ..drawPath(
        _seams,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = palette.mouseSeam
          ..strokeWidth = 1.4,
      )
      ..drawRRect(_wheelWell, Paint()..color = palette.mouseWell);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.n(600)
      ..strokeWidth = 1;
    void key(RRect r, int slot) {
      final color = Color.lerp(palette.n(800), palette.a(600), _t(slot))!;
      canvas
        ..drawRRect(r, Paint()..color = color)
        ..drawRRect(r, edge);
    }

    key(_wheel, ButtonSlot.middle);
    for (var y = 60.0; y <= 100; y += 8) {
      canvas.drawLine(Offset(92, y), Offset(108, y), edge);
    }
    key(_forward, ButtonSlot.forward);
    key(_back, ButtonSlot.back);
    canvas
      ..drawRRect(_sensorMark, Paint()..color = palette.n(600))
      ..restore();
  }

  @override
  bool shouldRepaint(MouseBodyPainter old) => old.palette != palette;
}
