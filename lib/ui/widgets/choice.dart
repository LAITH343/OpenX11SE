import 'package:flutter/material.dart';

import '../../core/theme/nocturne_theme.dart';
import 'pressable.dart';

class AppRadio<T> extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.label,
    this.trailing,
    this.filled = false,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final Widget label;
  final Widget? trailing;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final checked = value == groupValue;
    return Pressable(
      onPressed: onChanged == null ? null : () => onChanged!(value),
      selected: checked,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final dot = AnimatedContainer(
          duration: n.motion.fast,
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? n.accent : Colors.transparent,
            border: Border.all(
              color: checked || hovered ? n.accent : n.divider,
              width: 1.5,
            ),
          ),
          child: checked
              ? Container(
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: n.bg, width: 1.5),
                    color: n.accent,
                  ),
                )
              : null,
        );
        final row = Row(
          mainAxisSize: filled ? MainAxisSize.max : MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 8),
            if (filled)
              Expanded(
                child: DefaultTextStyle(style: n.text.body, child: label),
              )
            else
              DefaultTextStyle(style: n.text.body, child: label),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        );
        if (!filled) return row;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: n.bg, borderRadius: n.radius.mdAll),
          child: row,
        );
      },
    );
  }
}

class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    return Pressable(
      onPressed: onPressed,
      selected: selected,
      focusRadius: n.radius.pillAll,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: n.motion.fast,
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 16,
            vertical: dense ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: selected
                ? p.a(800)
                : hovered
                ? n.hoverTint
                : Colors.transparent,
            borderRadius: n.radius.pillAll,
            border: Border.all(color: selected ? p.accent : n.divider),
          ),
          child: Text(
            label,
            style: n.text.tabular(
              (dense ? n.text.micro.copyWith(fontSize: 11.5) : n.text.small)
                  .copyWith(color: selected ? p.a(100) : n.textColor),
            ),
          ),
        );
      },
    );
  }
}

class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    super.key,
    required this.color,
    required this.selected,
    required this.onPressed,
    this.size = 26,
    this.tooltip,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final radius = BorderRadius.circular(7);
    return Pressable(
      onPressed: onPressed,
      selected: selected,
      tooltip: tooltip,
      focusRadius: radius,
      builder: (context, states) => AnimatedScale(
        duration: n.motion.fast,
        scale: states.contains(WidgetState.hovered) ? 1.08 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            boxShadow: selected
                ? [
                    BoxShadow(color: color, spreadRadius: 4),
                    BoxShadow(color: n.surface, spreadRadius: 2),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
