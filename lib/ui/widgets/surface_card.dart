import 'package:flutter/material.dart';

import '../../core/theme/nocturne_theme.dart';

enum CardElevation { none, sm, md, lg }

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.elevation = CardElevation.sm,
    this.large = true,
    this.color,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final CardElevation elevation;
  final bool large;
  final Color? color;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: large ? n.radius.lgAll : n.radius.mdAll,
        boxShadow: switch (elevation) {
          CardElevation.none => null,
          CardElevation.sm => p.shadowSm,
          CardElevation.md => p.shadowMd,
          CardElevation.lg => p.shadowLg,
        },
      ),
      child: child,
    );
  }
}

class CardHeading extends StatelessWidget {
  const CardHeading({
    super.key,
    required this.title,
    this.icon,
    this.changed = false,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final bool changed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: n.accent),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(title, style: n.text.subheading)),
        if (changed) ...[const SizedBox(width: 8), _dot(n)],
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }

  Widget _dot(NocturneTheme n) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: n.accent, shape: BoxShape.circle),
  );
}

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Text(
      text.toUpperCase(),
      style: n.text.kicker.copyWith(
        color: accent ? n.accent : n.textMuted,
        letterSpacing: accent ? 1.0 : 0.8,
      ),
    );
  }
}
