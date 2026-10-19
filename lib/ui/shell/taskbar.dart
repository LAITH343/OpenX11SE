import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/app_settings.dart';
import '../settings/settings_view_model.dart';
import '../widgets/app_button.dart';
import '../widgets/app_mark.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/tag.dart';
import 'app_section.dart';
import 'edit_session_view_model.dart';
import 'profile_menu.dart';
import 'shell_view_model.dart';

class Taskbar extends StatelessWidget {
  const Taskbar({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final writing = context.select<EditSessionViewModel, bool>(
      (e) => e.writing,
    );
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: p.shadowMd),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: p.surface.withValues(alpha: 0.92),
              child: Stack(
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _ProfileButton(),
                        ),
                      ),
                      const _Nav(),
                      Expanded(child: _Status(compact: compact)),
                    ],
                  ),
                  if (writing)
                    const Positioned(
                      left: 6,
                      right: 6,
                      bottom: 0,
                      child: _WriteProgress(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

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
          final hovered =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed) ||
              shell.profileMenuOpen;
          return AnimatedContainer(
            duration: n.motion.fast,
            height: 38,
            padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 10, 0),
            decoration: BoxDecoration(
              color: hovered ? n.hoverTint : Colors.transparent,
              borderRadius: n.radius.mdAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppMark(size: 26),
                const SizedBox(width: 9),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('PROFILE'),
                        style: n.text.kicker.copyWith(
                          height: 1.15,
                          color: n.textSecondary,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          tr(shell.profileName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: n.text.small.copyWith(height: 1.15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Icon(
                  AppIcons.caretUp,
                  size: 11,
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

class _Nav extends StatelessWidget {
  const _Nav();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final shell = context.watch<ShellViewModel>();
    final dirty = context.watch<EditSessionViewModel>().dirtySections;
    return Semantics(
      label: 'Sections',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: n.bg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            for (final section in AppSection.values)
              _NavItem(
                section: section,
                active: shell.section == section,
                changed:
                    section.settingsSection != null &&
                    dirty.contains(section.settingsSection),
                onPressed: () => shell.selectSection(section),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.active,
    required this.changed,
    required this.onPressed,
  });

  final AppSection section;
  final bool active;
  final bool changed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Pressable(
      onPressed: onPressed,
      tooltip: section.label,
      semanticLabel: section.label,
      selected: active,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final fg = active || hovered ? n.textColor : n.textMuted;
        return AnimatedContainer(
          duration: n.motion.medium,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: active ? n.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(section.icon, size: 18, color: active ? n.accent : fg),
                  if (active) ...[
                    const SizedBox(width: 8),
                    EntranceTransition(
                      kind: Entrance.fade,
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        tr(section.label),
                        maxLines: 1,
                        softWrap: false,
                        style: n.text.small.copyWith(color: fg),
                      ),
                    ),
                  ],
                ],
              ),
              if (active)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 2,
                  child: _Underline(),
                ),
              if (changed)
                PositionedDirectional(
                  end: -6,
                  top: 6,
                  child: Tooltip(
                    message: tr('Unsaved changes'),
                    child: const ChangedDot(size: 5),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Underline extends StatelessWidget {
  const _Underline();

  @override
  Widget build(BuildContext context) {
    final accent = context.nocturne.accent;
    return FractionallySizedBox(
      widthFactor: 0.4,
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: accent, blurRadius: 6)],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final edit = context.watch<EditSessionViewModel>();
    final shell = context.watch<ShellViewModel>();
    final count = edit.pendingCount;
    final staged = edit.hasPending && !edit.writing;
    final synced =
        shell.isOnline &&
        !edit.hasPending &&
        !edit.writing &&
        !shell.deviceOff &&
        !shell.deviceAsleep;
    final pendingText = '$count unsaved change${count == 1 ? '' : 's'}';
    final muted = n.text.caption.copyWith(
      fontSize: 12.5,
      color: n.textSecondary,
    );
    return ClipRect(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 6,
        children: [
          const _ThemeToggle(),
          if (edit.autoApply && !edit.writing)
            Tooltip(
              message: tr('Changes are written automatically — see Settings'),
              child: const Tag(
                label: 'Auto-apply',
                variant: TagVariant.neutral,
                icon: AppIcons.lightning,
                compact: true,
              ),
            ),
          if (synced)
            Flexible(
              child: Tooltip(
                message: tr('Everything is written to the mouse'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Icon(
                        AppIcons.checkCircle,
                        size: 16,
                        color: n.palette.success,
                      ),
                      Flexible(
                        child: Text(
                          tr('Synced'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (staged) ...[
            Flexible(
              child: EntranceTransition(
                kind: Entrance.fade,
                child: Tooltip(
                  message: tr(compact ? pendingText : ''),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        const ChangedDot(glow: true),
                        if (!compact)
                          Flexible(
                            child: Text(
                              tr(pendingText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: muted.copyWith(color: n.palette.a(300)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (compact)
              AppIconButton(
                icon: AppIcons.arrowCounterClockwise,
                tooltip: 'Discard staged changes',
                variant: AppButtonVariant.ghost,
                neutralForeground: true,
                size: 32,
                onPressed: edit.canDiscard ? edit.discard : null,
              )
            else
              AppButton.ghost(
                label: 'Discard',
                icon: AppIcons.arrowCounterClockwise,
                size: AppButtonSize.small,
                neutralForeground: true,
                tooltip: 'Discard staged changes',
                onPressed: edit.canDiscard ? edit.discard : null,
              ),
            AppButton.primary(
              label: 'Apply',
              icon: AppIcons.uploadSimple,
              size: AppButtonSize.small,
              tooltip: edit.mouseOff
                  ? 'Turn the mouse on to apply'
                  : !shell.isOnline
                  ? 'Reconnect the mouse to apply'
                  : 'Write changes to the mouse (Ctrl+S)',
              onPressed: edit.canApply ? () => unawaited(edit.apply()) : null,
            ),
          ],
          if (edit.writing)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    const Spinner(size: 16),
                    Flexible(
                      child: Text(
                        tr('Writing ${edit.writeLabel}…'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final light = !n.palette.isDark;
    final settings = context.read<SettingsViewModel>();
    return Pressable(
      onPressed: () =>
          unawaited(settings.setTheme(light ? AppTheme.dark : AppTheme.light)),
      tooltip: light ? 'Switch to dark theme' : 'Switch to light theme',
      semanticLabel: light ? 'Switch to dark theme' : 'Switch to light theme',
      builder: (context, states) => AnimatedContainer(
        duration: n.motion.fast,
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? n.hoverTint
              : Colors.transparent,
          borderRadius: n.radius.mdAll,
        ),
        child: Icon(
          light ? AppIcons.moon : AppIcons.sun,
          size: 16,
          color: n.textColor,
        ),
      ),
    );
  }
}

class _WriteProgress extends StatelessWidget {
  const _WriteProgress();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final value = context.select<EditSessionViewModel, double>(
      (e) => e.writeProgress,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 2,
        color: n.palette.n(800),
        alignment: AlignmentDirectional.centerStart,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 400),
          curve: Curves.ease,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: n.accent,
                boxShadow: [BoxShadow(color: n.accent, blurRadius: 8)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
