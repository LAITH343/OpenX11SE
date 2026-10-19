import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/nocturne_theme.dart';

enum TagVariant { accent, neutral, outline }

class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    this.variant = TagVariant.accent,
    this.icon,
    this.compact = false,
  });

  final String label;
  final TagVariant variant;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final (bg, fg, border) = switch (variant) {
      TagVariant.accent => (p.a(800), p.a(100), null),
      TagVariant.neutral => (p.n(800), p.n(100), null),
      TagVariant.outline => (Colors.transparent, p.accent, p.accent),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(n.radius.md * 0.75),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            tr(label),
            style: (compact ? n.text.kicker : n.text.micro).copyWith(
              color: fg,
              letterSpacing: 0.22,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class ChangedDot extends StatelessWidget {
  const ChangedDot({super.key, this.size = 6, this.glow = false, this.color});

  final double size;
  final bool glow;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.nocturne.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: glow ? [BoxShadow(color: c, blurRadius: 8)] : null,
      ),
    );
  }
}
