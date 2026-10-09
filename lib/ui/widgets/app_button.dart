import 'package:flutter/material.dart';

import '../../core/theme/nocturne_theme.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { regular, small }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailing,
    this.tooltip,
    this.minWidth,
    this.neutralForeground = false,
    this.expand = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailing,
    this.tooltip,
    this.minWidth,
    this.expand = false,
  }) : variant = AppButtonVariant.primary,
       neutralForeground = false;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailing,
    this.tooltip,
    this.neutralForeground = false,
  }) : variant = AppButtonVariant.ghost,
       minWidth = null,
       expand = false;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final Widget? trailing;
  final String? tooltip;
  final double? minWidth;
  final bool neutralForeground;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final small = size == AppButtonSize.small;
    final textStyle = (small ? n.text.caption : n.text.body).copyWith(
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final hPad = switch (variant) {
      AppButtonVariant.ghost => small ? n.space.s1 : n.space.s2,
      _ => small ? 10.0 : n.space.s3 * 1.2,
    };
    final vPad = small ? 5.0 : n.space.s2;

    return Pressable(
      onPressed: onPressed,
      tooltip: tooltip,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        final (fg, border, fill) = _colors(n, hovered, pressed);
        return AnimatedContainer(
          duration: n.motion.fast,
          constraints: BoxConstraints(minWidth: minWidth ?? 0),
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: n.radius.mdAll,
            border: Border.all(color: border),
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: fg, size: small ? 14 : 16),
            child: DefaultTextStyle(
              style: textStyle.copyWith(color: fg),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon), const SizedBox(width: 6)],
                  Text(label),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  (Color, Color, Color) _colors(NocturneTheme n, bool hovered, bool pressed) {
    const clear = Colors.transparent;
    switch (variant) {
      case AppButtonVariant.primary:
        return (
          n.accent,
          n.accent,
          pressed
              ? n.accentPressed
              : hovered
              ? n.accentHover
              : clear,
        );
      case AppButtonVariant.secondary:
        return (
          n.textColor,
          n.divider,
          pressed
              ? n.pressedTint
              : hovered
              ? n.hoverTint
              : clear,
        );
      case AppButtonVariant.ghost:
        final fg = neutralForeground ? n.textColor : n.accent;
        return (
          fg,
          clear,
          pressed
              ? n.accent.withValues(alpha: 0.18)
              : hovered
              ? n.accent.withValues(alpha: 0.10)
              : clear,
        );
      case AppButtonVariant.danger:
        final d = n.palette.danger;
        return (
          d,
          d.withValues(alpha: 0.6),
          pressed
              ? d.withValues(alpha: 0.22)
              : hovered
              ? d.withValues(alpha: 0.12)
              : clear,
        );
    }
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.variant = AppButtonVariant.secondary,
    this.size = 36,
    this.iconSize = 16,
    this.neutralForeground = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final AppButtonVariant variant;
  final double size;
  final double iconSize;
  final bool neutralForeground;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Pressable(
      onPressed: onPressed,
      tooltip: tooltip,
      semanticLabel: tooltip,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        final accentFg =
            variant == AppButtonVariant.primary ||
            (variant == AppButtonVariant.ghost && !neutralForeground);
        final fg = accentFg ? n.accent : n.textColor;
        final border = switch (variant) {
          AppButtonVariant.primary => n.accent,
          AppButtonVariant.secondary => n.divider,
          AppButtonVariant.danger => n.palette.danger.withValues(alpha: 0.6),
          AppButtonVariant.ghost => Colors.transparent,
        };
        final tintBase = variant == AppButtonVariant.secondary
            ? n.textColor
            : n.accent;
        final fill = pressed
            ? tintBase.withValues(alpha: 0.18)
            : hovered
            ? tintBase.withValues(alpha: 0.09)
            : Colors.transparent;
        return AnimatedContainer(
          duration: n.motion.fast,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: n.radius.mdAll,
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: iconSize, color: fg),
        );
      },
    );
  }
}
