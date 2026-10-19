import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/tag.dart';
import 'profiles_view_model.dart';
import 'shell_view_model.dart';

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

class ProfileMenuLayer extends StatelessWidget {
  const ProfileMenuLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final open = context.select<ShellViewModel, bool>((s) => s.profileMenuOpen);
    if (!open) return const SizedBox.shrink();
    final shell = context.read<ShellViewModel>();
    final rtl = Directionality.of(context) == TextDirection.rtl;
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
            targetAnchor: rtl ? Alignment.topRight : Alignment.topLeft,
            followerAnchor: rtl ? Alignment.bottomRight : Alignment.bottomLeft,
            offset: Offset(rtl ? 6 : -6, -12),
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
    final vm = context.watch<ProfilesViewModel>();
    VoidCallback? run(Future<void> Function() action) => vm.busy
        ? null
        : () {
            shell.closeProfileMenu();
            unawaited(action());
          };
    final actions = [
      _Action('New profile', AppIcons.plus, run(vm.create)),
      _Action('Duplicate', AppIcons.copy, run(vm.duplicate)),
      _Action('Rename…', AppIcons.pencilSimple, run(vm.rename)),
      _Action('Delete…', AppIcons.trash, run(vm.delete)),
      _Action('Import file…', AppIcons.fileArrowUp, run(vm.importFile)),
      _Action('Export…', AppIcons.downloadSimple, run(vm.export)),
      if (vm.supportsVendorImport)
        _Action(
          'Import from vendor software…',
          AppIcons.arrowSquareIn,
          run(vm.importVendor),
          wide: true,
        ),
      _Action(
        'Restore defaults…',
        AppIcons.arrowCounterClockwise,
        run(vm.restoreDefaults),
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
                tr('PROFILES ON THIS COMPUTER'),
                style: n.text.kicker.copyWith(color: n.textMuted),
              ),
            ),
            for (final profile in shell.profiles)
              _MenuRow(
                height: 34,
                onPressed: profile.isActive
                    ? shell.closeProfileMenu
                    : run(() => vm.select(profile)),
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
                        tr(profile.name),
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
    this.icon,
    this.onPressed, {
    this.wide = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
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
      onPressed: action.onPressed,
      dimWhenDisabled: true,
      child: Row(
        children: [
          Icon(action.icon, size: 14, color: fg.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tr(action.label),
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
