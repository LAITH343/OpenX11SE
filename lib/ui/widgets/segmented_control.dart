import 'package:flutter/material.dart';

import '../../core/theme/nocturne_theme.dart';
import 'pressable.dart';

@immutable
class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? tooltip;
}

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.dense = false,
    this.tabular = false,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final bool dense;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final inner = BorderRadius.circular(n.radius.md - 1);
    return Container(
      decoration: BoxDecoration(
        borderRadius: n.radius.mdAll,
        border: Border.all(color: n.divider),
      ),
      child: ClipRRect(
        borderRadius: inner,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) VerticalDivider(width: 1, color: n.divider),
                _Segment<T>(
                  option: options[i],
                  selected: options[i].value == selected,
                  dense: dense,
                  tabular: tabular,
                  onPressed: onChanged == null
                      ? null
                      : () => onChanged!(options[i].value),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.dense,
    required this.tabular,
    required this.onPressed,
  });

  final SegmentOption<T> option;
  final bool selected;
  final bool dense;
  final bool tabular;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Pressable(
      onPressed: onPressed,
      selected: selected,
      tooltip: option.tooltip,
      focusRadius: BorderRadius.zero,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final fg = n.textColor;
        var style = (dense ? n.text.caption : n.text.small).copyWith(
          color: fg,
          height: 1.3,
        );
        if (tabular) style = n.text.tabular(style);
        return AnimatedContainer(
          duration: n.motion.fast,
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: selected
                ? n.selectedSurface
                : hovered
                ? n.hoverTint
                : Colors.transparent,
            borderRadius: n.radius.smAll,
            border: selected ? Border.all(color: n.selectedBorder) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: dense ? 13 : 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(option.label, style: style),
            ],
          ),
        );
      },
    );
  }
}
