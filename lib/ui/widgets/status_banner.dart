import 'package:flutter/material.dart';

import '../../core/theme/nocturne_palette.dart';
import '../../core/theme/nocturne_theme.dart';
import 'motion.dart';

enum BannerKind { warning, error }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.kind,
    required this.icon,
    required this.message,
    this.actions = const [],
  });

  final BannerKind kind;
  final IconData icon;
  final Widget message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final (color, edge) = switch (kind) {
      BannerKind.warning => (p.warning, 0.40),
      BannerKind.error => (p.danger, 0.45),
    };
    return Semantics(
      liveRegion: true,
      child: EntranceTransition(
        kind: Entrance.slideIn,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mix(color, p.surface, 0.12),
            borderRadius: n.radius.mdAll,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: edge), spreadRadius: 1),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: DefaultTextStyle(style: n.text.small, child: message),
              ),
              for (final a in actions) ...[const SizedBox(width: 12), a],
            ],
          ),
        ),
      ),
    );
  }
}
