import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../shell/app_section.dart';
import '../widgets/app_button.dart';
import '../widgets/dashed_border.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/section_header.dart';
import '../widgets/status_banner.dart';
import '../widgets/surface_card.dart';
import '../widgets/tag.dart';
import 'buttons_view_model.dart';
import 'mouse_illustration.dart';

class ButtonsSection extends StatelessWidget {
  const ButtonsSection({super.key});

  static const _columnMin = 300.0;
  static const _gap = 14.0;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ButtonsViewModel>();
    const section = AppSection.buttons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        SectionHeader(
          title: section.label,
          description: section.description,
          trailing: AppButton(
            label: 'Reset all buttons',
            icon: AppIcons.arrowCounterClockwise,
            onPressed: vm.anyCustom && vm.canEdit ? vm.resetAll : null,
          ),
        ),
        if (vm.noLeftClick) const _NoLeftClickBanner(),
        if (vm.hasSettings)
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < _columnMin * 2 + _gap) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _gap,
                  children: [_IllustrationCard(), _ButtonList()],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: _gap,
                children: [
                  Expanded(child: _IllustrationCard()),
                  Expanded(child: _ButtonList()),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _NoLeftClickBanner extends StatelessWidget {
  const _NoLeftClickBanner();

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ButtonsViewModel>();
    return StatusBanner(
      kind: BannerKind.warning,
      icon: AppIcons.warning,
      message: const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'No button is set to '),
            TextSpan(
              text: 'Left click',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text:
                  ". After applying you won't be able to click with this "
                  'mouse.',
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Restore Left click',
          size: AppButtonSize.small,
          onPressed: vm.restoreLeftClick,
        ),
      ],
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: n.radius.lgAll,
        boxShadow: p.shadowSm,
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.6,
          colors: [
            Color.alphaBlend(p.accent.withValues(alpha: 0.08), p.surface),
            p.surface,
          ],
        ),
      ),
      child: Column(
        spacing: 12,
        children: [
          const MouseIllustration(),
          Text(
            'Top-down view · hover to highlight',
            style: n.text.caption.copyWith(
              color: n.textColor.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonList extends StatelessWidget {
  const _ButtonList();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<ButtonsViewModel>();
    return MouseRegion(
      onExit: (_) => vm.setHovered(null),
      child: SurfaceCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            for (final row in vm.mainRows) _ButtonRowTile(row: row),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Pressable(
                onPressed: vm.toggleAdvanced,
                toggled: vm.showAdvanced,
                builder: (context, states) => AnimatedContainer(
                  duration: n.motion.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: states.contains(WidgetState.hovered)
                        ? n.textColor.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: n.radius.mdAll,
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(
                        vm.showAdvanced ? AppIcons.caretUp : AppIcons.caretDown,
                        size: 14,
                        color: n.textLabel,
                      ),
                      Text(
                        'Advanced · DPI button and wheel',
                        style: n.text.caption.copyWith(
                          fontSize: 12.5,
                          color: n.textLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (vm.showAdvanced)
              EntranceTransition(
                kind: Entrance.slideIn,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 2,
                  children: [
                    for (final row in vm.advancedRows)
                      _ButtonRowTile(row: row, advanced: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ButtonRowTile extends StatelessWidget {
  const _ButtonRowTile({required this.row, this.advanced = false});

  final ButtonRow row;
  final bool advanced;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final vm = context.read<ButtonsViewModel>();
    final slot = row.info.slot;
    final hovered = context.select<ButtonsViewModel, bool>(
      (b) => b.hoveredSlot == slot,
    );
    final badge = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: advanced ? null : p.n(800),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${row.info.number}',
        style: n.text.tabular(n.text.micro.copyWith(height: 1)),
      ),
    );
    return Pressable(
      onPressed: () => vm.openPicker(slot),
      onHover: (v) => v ? vm.setHovered(slot) : vm.endHover(slot),
      semanticLabel: '${row.info.title}: ${row.label}',
      builder: (context, states) => AnimatedContainer(
        duration: n.motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hovered
              ? n.textColor.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: n.radius.mdAll,
        ),
        child: Row(
          spacing: 12,
          children: [
            if (advanced)
              DashedBorder(
                color: p.n(600),
                radius: BorderRadius.circular(6),
                child: badge,
              )
            else
              badge,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.info.title,
                    style: n.text.caption.copyWith(
                      color: n.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                  Row(
                    spacing: 6,
                    children: [
                      Icon(
                        row.icon,
                        size: 14,
                        color: n.textColor.withValues(alpha: 0.6),
                      ),
                      Flexible(
                        child: Text(
                          row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: n.text.body,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (row.changed)
              const Tooltip(
                message: 'Changed — not applied yet',
                child: ChangedDot(),
              ),
            if (row.custom)
              AppIconButton(
                icon: AppIcons.arrowCounterClockwise,
                tooltip: 'Reset to ${row.defaultLabel}',
                variant: AppButtonVariant.ghost,
                size: 30,
                onPressed: vm.canEdit ? () => vm.resetButton(slot) : null,
              ),
            Icon(
              AppIcons.caretRight,
              size: 14,
              color: n.textColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
