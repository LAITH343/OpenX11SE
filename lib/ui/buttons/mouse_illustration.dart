import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nocturne_theme.dart';
import '../../domain/button_assignment.dart';
import '../lighting/mouse_led.dart';
import '../widgets/dashed_border.dart';
import '../widgets/mouse_body_painter.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import 'buttons_view_model.dart';

class MouseIllustration extends StatelessWidget {
  const MouseIllustration({super.key, this.interactive = true});

  final bool interactive;

  static const bodySize = MouseBodyPainter.bodySize;
  static const gutter = 30.0;
  static const bleed = MouseBodyPainter.bleed;

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
              child: interactive
                  ? _MouseBody(hovered: hovered)
                  : CustomPaint(painter: MouseBodyPainter(palette: n.palette)),
            ),
            Positioned(
              left: gutter + bodySize.width / 2 - MouseLed.size / 2,
              top: bodySize.height * .507 - MouseLed.size / 2,
              child: const MouseLed(),
            ),
            if (interactive)
              for (final row in vm.mainRows) callout(row, advanced: false),
            if (interactive && vm.showAdvanced) ...[
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
    for (final slot in MouseBodyPainter.regions)
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

  int? _hit(Offset local) => MouseBodyPainter.regionAt(
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
          painter: MouseBodyPainter(
            palette: palette,
            highlights: _fades,
            repaint: Listenable.merge(_fades.values.toList()),
          ),
        ),
      ),
    );
  }
}
