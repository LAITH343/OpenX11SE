import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting/number_format.dart';
import '../../core/theme/nocturne_theme.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/tag.dart';
import 'app_section.dart';
import 'edit_session_view_model.dart';
import 'shell_view_model.dart';

class NavRail extends StatelessWidget {
  const NavRail({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellViewModel>();
    final dirty = context.watch<EditSessionViewModel>().dirtySections;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.ease,
      width: compact ? 60 : 212,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          for (final section in AppSection.values)
            _NavItem(
              section: section,
              active: shell.section == section,
              changed:
                  section.settingsSection != null &&
                  dirty.contains(section.settingsSection),
              compact: compact,
              onPressed: () => shell.selectSection(section),
            ),
          const Spacer(),
          if (!compact && shell.isOnline)
            _MouseWidget(
              onPressed: () => shell.selectSection(AppSection.performance),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.active,
    required this.changed,
    required this.compact,
    required this.onPressed,
  });

  final AppSection section;
  final bool active;
  final bool changed;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Pressable(
      onPressed: onPressed,
      tooltip: compact ? section.label : null,
      semanticLabel: section.label,
      selected: active,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final fg = active || hovered ? n.textColor : n.textSecondary;
        return AnimatedContainer(
          duration: n.motion.fast,
          height: 38,
          decoration: BoxDecoration(
            color: active ? n.palette.a(900) : Colors.transparent,
            borderRadius: n.radius.mdAll,
          ),
          child: Stack(
            children: [
              if (active)
                Positioned(
                  left: 0,
                  top: 10,
                  bottom: 10,
                  child: EntranceTransition(
                    kind: Entrance.fade,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: n.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
                child: Row(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(section.icon, size: 18, color: active ? n.accent : fg),
                    if (!compact) ...[
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          section.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: n.text.row.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (changed)
                const Positioned(
                  right: 10,
                  top: 16,
                  child: Tooltip(
                    message: 'Unsaved changes in this section',
                    child: ChangedDot(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MouseWidget extends StatelessWidget {
  const _MouseWidget({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final shell = context.watch<ShellViewModel>();
    final stage = shell.activeStage;
    if (stage == null) return const SizedBox.shrink();
    final color = Color(0xFF000000 | stage.color.rgb);
    return Pressable(
      onPressed: onPressed,
      tooltip: 'Current stage on the mouse',
      builder: (context, states) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.surface,
          borderRadius: n.radius.mdAll,
          boxShadow: n.palette.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              'ON THE MOUSE',
              style: n.text.kicker.copyWith(color: n.textMuted),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [BoxShadow(color: color, blurRadius: 10)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatThousands(stage.dpi), style: n.text.valueSmall),
                const SizedBox(width: 8),
                Text(
                  'DPI',
                  style: n.text.micro.copyWith(
                    color: n.textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            Text(
              'Stage ${shell.activeStageNumber} · ${shell.polling?.hz ?? '—'} Hz',
              style: n.text.tabular(
                n.text.micro.copyWith(color: n.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
