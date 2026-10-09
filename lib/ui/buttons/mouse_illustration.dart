import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nocturne_palette.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/button_assignment.dart';
import '../widgets/dashed_border.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import 'buttons_view_model.dart';

class MouseIllustration extends StatelessWidget {
  const MouseIllustration({super.key});

  static const bodySize = Size(200, 382);
  static const gutter = 30.0;
  static const bleed = 8.0;

  static const _callouts = {
    ButtonSlot.left: Offset(.25, .27),
    ButtonSlot.right: Offset(.75, .27),
    ButtonSlot.middle: Offset(.5, .215),
    ButtonSlot.forward: Offset(-.08, .395),
    ButtonSlot.back: Offset(-.08, .55),
    ButtonSlot.dpi: Offset(.5, .91),
    ButtonSlot.wheelUp: Offset(.5, .11),
    ButtonSlot.wheelDown: Offset(.5, .32),
  };

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<ButtonsViewModel>();
    final hovered = vm.hoveredSlot;

    Widget callout(ButtonRow row, {required bool advanced}) {
      final at = _callouts[row.info.slot]!;
      final size = advanced ? 20.0 : 22.0;
      final button = _Callout(
        row: row,
        size: size,
        advanced: advanced,
        hovered: hovered == row.info.slot,
      );
      return Positioned(
        left: gutter + at.dx * bodySize.width - size / 2,
        top: at.dy * bodySize.height - size / 2,
        child: advanced
            ? EntranceTransition(kind: Entrance.fade, child: button)
            : button,
      );
    }

    return MouseRegion(
      onExit: (_) => vm.setHovered(null),
      child: SizedBox(
        width: bodySize.width + gutter * 2,
        height: bodySize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: gutter - bleed,
              top: -bleed,
              width: bodySize.width + bleed * 2,
              height: bodySize.height + bleed * 2,
              child: _MouseBody(hovered: hovered),
            ),
            for (final row in vm.mainRows) callout(row, advanced: false),
            if (vm.showAdvanced) ...[
              for (final row in vm.advancedRows) callout(row, advanced: true),
              Positioned(
                left: 0,
                right: 0,
                top: bodySize.height * .97,
                child: EntranceTransition(
                  kind: Entrance.fade,
                  child: Text(
                    '6 · DPI button is on the underside',
                    textAlign: TextAlign.center,
                    style: n.text.micro.copyWith(
                      fontSize: 10.5,
                      color: n.textColor.withValues(alpha: 0.58),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.row,
    required this.size,
    required this.advanced,
    required this.hovered,
  });

  final ButtonRow row;
  final double size;
  final bool advanced;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.read<ButtonsViewModel>();
    final slot = row.info.slot;
    final border = hovered ? p.accent : p.n(600);
    return Pressable(
      onPressed: () => vm.openPicker(slot),
      onHover: (v) => v ? vm.setHovered(slot) : vm.endHover(slot),
      tooltip: '${row.info.title} — ${row.label}',
      semanticLabel: row.info.title,
      focusRadius: n.radius.pillAll,
      builder: (context, states) {
        final face = AnimatedContainer(
          duration: n.motion.fast,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hovered ? p.accent : p.bg,
            border: advanced ? null : Border.all(color: border),
          ),
          child: Text(
            '${row.info.number}',
            style: n.text.micro.copyWith(
              fontSize: advanced ? 10 : 11,
              fontWeight: advanced ? FontWeight.w400 : FontWeight.w500,
              height: 1,
              color: hovered ? p.bg : p.text,
            ),
          ),
        );
        return AnimatedScale(
          duration: n.motion.fast,
          scale: states.contains(WidgetState.hovered) ? 1.12 : 1,
          child: advanced
              ? DashedBorder(
                  color: border,
                  radius: BorderRadius.circular(size / 2),
                  dash: 2.5,
                  gap: 2,
                  child: face,
                )
              : face,
        );
      },
    );
  }
}

class _MouseBody extends StatefulWidget {
  const _MouseBody({required this.hovered});

  final int? hovered;

  @override
  State<_MouseBody> createState() => _MouseBodyState();
}

class _MouseBodyState extends State<_MouseBody> with TickerProviderStateMixin {
  late final Map<int, AnimationController> _fades = {
    for (final slot in _MousePainter.regions)
      slot: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 150),
      ),
  };
  int? _pointer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _MouseBody old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    _fades.forEach((slot, c) {
      if (slot == widget.hovered) {
        c.forward();
      } else {
        c.reverse();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _fades.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? _hit(Offset local) => _MousePainter.regionAt(
    local - const Offset(MouseIllustration.bleed, MouseIllustration.bleed),
    MouseIllustration.bodySize,
  );

  void _onHover(PointerHoverEvent e) {
    final slot = _hit(e.localPosition);
    if (slot == _pointer) return;
    setState(() => _pointer = slot);
    context.read<ButtonsViewModel>().setHovered(slot);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nocturne.palette;
    return MouseRegion(
      cursor: _pointer == null ? MouseCursor.defer : SystemMouseCursors.click,
      onHover: _onHover,
      onExit: (_) => setState(() => _pointer = null),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) {
          final slot = _hit(d.localPosition);
          if (slot != null) context.read<ButtonsViewModel>().openPicker(slot);
        },
        child: CustomPaint(
          painter: _MousePainter(
            palette: palette,
            fades: _fades,
            repaint: Listenable.merge(_fades.values.toList()),
          ),
        ),
      ),
    );
  }
}

class _MousePainter extends CustomPainter {
  _MousePainter({
    required this.palette,
    required this.fades,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final NocturnePalette palette;
  final Map<int, AnimationController> fades;

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
      Curves.ease.transform(fades[slot]?.value.clamp(0.0, 1.0) ?? 0);

  @override
  void paint(Canvas canvas, Size size) {
    const body = MouseIllustration.bodySize;
    canvas
      ..save()
      ..translate(MouseIllustration.bleed, MouseIllustration.bleed)
      ..scale(body.width / _viewBox.width, body.height / _viewBox.height)
      ..translate(-_viewBox.left, -_viewBox.top);

    final bounds = _body.getBounds();
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke;

    canvas
      ..drawPath(
        _body,
        fill
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: deviceBodyGradient,
            stops: [0, .55, 1],
          ).createShader(bounds),
      )
      ..drawPath(
        _body,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.3, -.4),
            radius: .6,
            colors: [
              deviceBodySheen.withValues(alpha: .07),
              deviceBodySheen.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      )
      ..drawPath(
        _body,
        stroke
          ..color = palette.n(700)
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
          ..color = palette.bg
          ..strokeWidth = 1.4,
      )
      ..drawRRect(_wheelWell, Paint()..color = palette.bg);

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
  bool shouldRepaint(_MousePainter old) => old.palette != palette;
}
