import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/nocturne_theme.dart';
import 'pressable.dart';
import 'tag.dart';

class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.small = false,
    this.tooltip,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool small;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final width = small ? 30.0 : 36.0;
    final height = small ? 17.0 : 20.0;
    final knob = small ? 11.0 : 14.0;
    final onLeft = width - 2 - knob - 2;
    return Pressable(
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      toggled: value,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      focusRadius: n.radius.pillAll,
      builder: (context, states) => AnimatedContainer(
        duration: n.motion.medium,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? p.a(800) : Colors.transparent,
          borderRadius: n.radius.pillAll,
          border: Border.all(color: value ? p.accent : p.n(600)),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: n.motion.knobCurve,
              left: value ? onLeft : 2,
              top: 2,
              child: AnimatedContainer(
                duration: n.motion.medium,
                width: knob,
                height: knob,
                decoration: BoxDecoration(
                  color: value ? p.a(200) : p.n(500),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
    this.changed = false,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool changed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(tr(title), style: n.text.row)),
                    if (changed) ...[
                      const SizedBox(width: 6),
                      const ChangedDot(size: 5),
                    ],
                  ],
                ),
                if (description != null)
                  Text(
                    tr(description!),
                    style: n.text.caption.copyWith(color: n.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(value: value, onChanged: onChanged, semanticLabel: title),
        ],
      ),
    );
  }
}
