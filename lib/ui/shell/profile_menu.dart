import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/tag.dart';
import 'shell_view_model.dart';
import 'window/window_controls.dart';

class ProfileMenuAnchor extends InheritedWidget {
  const ProfileMenuAnchor({
    super.key,
    required this.link,
    required super.child,
  });

  final LayerLink link;

  static LayerLink of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileMenuAnchor>()!.link;

  @override
  bool updateShouldNotify(ProfileMenuAnchor oldWidget) =>
      link != oldWidget.link;
}

class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final shell = context.watch<ShellViewModel>();
    return CompositedTransformTarget(
      link: ProfileMenuAnchor.of(context),
      child: Pressable(
        onPressed: shell.toggleProfileMenu,
        tooltip: 'Profiles are stored on this computer',
        builder: (context, states) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          return AnimatedContainer(
            duration: n.motion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: pressed
                  ? n.pressedTint
                  : hovered || shell.profileMenuOpen
                  ? n.hoverTint
                  : Colors.transparent,
              borderRadius: n.radius.mdAll,
              border: Border.all(color: n.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.userCircle, size: 16, color: n.textColor),
                const SizedBox(width: 8),
                Text(
                  'Profile',
                  style: n.text.micro.copyWith(color: n.textMuted),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    shell.profileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: n.text.body.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  AppIcons.caretDown,
                  size: 12,
                  color: n.textColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProfileMenuLayer extends StatelessWidget {
  const ProfileMenuLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final open = context.select<ShellViewModel, bool>((s) => s.profileMenuOpen);
    if (!open) return const SizedBox.shrink();
    final shell = context.read<ShellViewModel>();
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: shell.closeProfileMenu,
            ),
          ),
          CompositedTransformFollower(
            link: ProfileMenuAnchor.of(context),
            targetAnchor: Alignment.bottomLeft,
            offset: const Offset(0, 6),
            child: const EntranceTransition(
              kind: Entrance.pop,
              duration: Duration(milliseconds: 180),
              child: _ProfileMenu(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final shell = context.watch<ShellViewModel>();
    final actions = [
      const _Action('New profile', AppIcons.plus),
      const _Action('Duplicate', AppIcons.copy),
      const _Action('Rename…', AppIcons.pencilSimple),
      const _Action('Delete…', AppIcons.trash),
      const _Action('Import file…', AppIcons.fileArrowUp),
      const _Action('Export…', AppIcons.downloadSimple),
      if (hasWindowChrome)
        const _Action(
          'Import from vendor software…',
          AppIcons.arrowSquareIn,
          wide: true,
        ),
      const _Action(
        'Restore defaults…',
        AppIcons.arrowCounterClockwise,
        wide: true,
        danger: true,
      ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      final a = actions[i];
      if (a.wide) {
        rows.add(_ActionItem(action: a));
      } else if (i + 1 < actions.length && !actions[i + 1].wide) {
        rows.add(
          Row(
            spacing: 2,
            children: [
              Expanded(child: _ActionItem(action: a)),
              Expanded(child: _ActionItem(action: actions[++i])),
            ],
          ),
        );
      } else {
        rows.add(
          Row(
            children: [Expanded(child: _ActionItem(action: a))],
          ),
        );
      }
    }
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: n.radius.lgAll,
          boxShadow: p.shadowLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                'PROFILES ON THIS COMPUTER',
                style: n.text.kicker.copyWith(color: n.textMuted),
              ),
            ),
            for (final profile in shell.profiles)
              _MenuRow(
                height: 34,
                onPressed: profile.isActive ? shell.closeProfileMenu : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      child: profile.isActive
                          ? Icon(AppIcons.check, size: 14, color: n.accent)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: n.text.small,
                      ),
                    ),
                    if (profile.isActive)
                      const Tag(label: 'In use', compact: true),
                  ],
                ),
              ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              color: n.divider,
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _Action {
  const _Action(
    this.label,
    this.icon, {
    this.wide = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool wide;
  final bool danger;
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.action});

  final _Action action;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final fg = action.danger ? n.palette.danger : n.textColor;
    return _MenuRow(
      height: 32,
      onPressed: null,
      dimWhenDisabled: true,
      child: Row(
        children: [
          Icon(action.icon, size: 14, color: fg.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: n.text.caption.copyWith(fontSize: 12.5, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.height,
    required this.onPressed,
    required this.child,
    this.dimWhenDisabled = false,
  });

  final double height;
  final VoidCallback? onPressed;
  final Widget child;
  final bool dimWhenDisabled;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Pressable(
      onPressed: onPressed,
      dimWhenDisabled: dimWhenDisabled,
      builder: (context, states) => AnimatedContainer(
        duration: n.motion.fast,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? n.hoverTint
              : Colors.transparent,
          borderRadius: n.radius.mdAll,
        ),
        child: child,
      ),
    );
  }
}
