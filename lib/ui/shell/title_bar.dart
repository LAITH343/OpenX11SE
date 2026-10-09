import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_palette.dart';
import '../../core/theme/nocturne_theme.dart';
import '../widgets/pressable.dart';
import 'window/window_controls.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key, required this.profileName});

  final String profileName;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final style = n.text.caption;
    return Container(
      height: 34,
      color: n.chrome,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => unawaited(startWindowDrag()),
              onDoubleTap: () => unawaited(toggleMaximizeWindow()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const AppMark(size: 15),
                    const SizedBox(width: 8),
                    Text('OpenX11SE', style: style),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '— $profileName',
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          color: n.textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _WindowButton(
            icon: AppIcons.minus,
            tooltip: 'Minimise',
            onPressed: () => unawaited(minimizeWindow()),
          ),
          _WindowButton(
            icon: AppIcons.square,
            iconSize: 12,
            tooltip: 'Maximise',
            onPressed: () => unawaited(toggleMaximizeWindow()),
          ),
          _WindowButton(
            icon: AppIcons.x,
            tooltip: 'Close',
            close: true,
            onPressed: () => unawaited(closeWindow()),
          ),
        ],
      ),
    );
  }
}

class AppMark extends StatelessWidget {
  const AppMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.27),
        border: Border.all(color: n.accent, width: 1.5),
      ),
      child: Text(
        'X',
        style: n.text.micro.copyWith(
          fontSize: size * 0.53,
          height: 1,
          fontWeight: FontWeight.w600,
          color: n.accent,
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 14,
    this.close = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Pressable(
      onPressed: onPressed,
      tooltip: tooltip,
      semanticLabel: tooltip,
      focusRadius: BorderRadius.zero,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final bg = !hovered
            ? Colors.transparent
            : close
            ? windowCloseHover
            : n.textColor.withValues(alpha: 0.08);
        final fg = hovered && close ? nocturneDark.n(100) : n.textColor;
        return AnimatedContainer(
          duration: n.motion.fast,
          width: 46,
          height: 34,
          color: bg,
          alignment: Alignment.center,
          child: Icon(icon, size: iconSize, color: fg),
        );
      },
    );
  }
}
