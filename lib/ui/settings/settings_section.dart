import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/app_settings.dart';
import '../widgets/app_button.dart';
import '../widgets/auto_grid.dart';
import '../widgets/pressable.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_control.dart';
import '../widgets/surface_card.dart';
import '../widgets/tag.dart';
import '../widgets/toggle.dart';
import 'settings_view_model.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            SectionHeader(
              title: 'Settings',
              description: 'App preferences and device information.',
            ),
            _AppearanceCard(),
            _BehaviourCard(),
            AutoGrid(
              minItemWidth: 320,
              spacing: 12,
              stretch: true,
              children: [_DeviceCard(), _AboutCard()],
            ),
          ],
        ),
      ),
    );
  }
}

class _RowsCard extends StatelessWidget {
  const _RowsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: child,
          ),
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.trailing,
    this.description,
    this.badge,
  });

  final String title;
  final String? description;
  final Widget? badge;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 8,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Text(title, style: n.text.row),
                  ?badge,
                ],
              ),
              if (description != null)
                Text(
                  description!,
                  style: n.text.caption.copyWith(color: n.textSecondary),
                ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return _RowsCard(
      children: [
        _SettingRow(
          title: 'Theme',
          description: 'System follows your OS setting.',
          trailing: SegmentedControl<AppTheme>(
            options: const [
              SegmentOption(
                value: AppTheme.dark,
                label: 'Dark',
                icon: AppIcons.moon,
              ),
              SegmentOption(
                value: AppTheme.light,
                label: 'Light',
                icon: AppIcons.sun,
              ),
              SegmentOption(
                value: AppTheme.system,
                label: 'System',
                icon: AppIcons.desktop,
              ),
            ],
            selected: vm.theme,
            onChanged: (t) => unawaited(vm.setTheme(t)),
          ),
        ),
        _SettingRow(
          title: 'Accent colour',
          description: 'Follow the active DPI stage colour across the app.',
          trailing: SegmentedControl<bool>(
            options: const [
              SegmentOption(value: false, label: 'OpenX11SE violet'),
              SegmentOption(value: true, label: 'Active DPI stage'),
            ],
            selected: vm.accentFollowsStage,
            onChanged: (v) => unawaited(vm.setAccentFollowsStage(v)),
          ),
        ),
        const _SettingRow(
          title: 'Language',
          badge: Tag(
            label: 'Coming soon',
            variant: TagVariant.neutral,
            compact: true,
          ),
          trailing: _LanguageField(),
        ),
      ],
    );
  }
}

class _LanguageField extends StatelessWidget {
  const _LanguageField();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Opacity(
      opacity: 0.6,
      child: Container(
        width: 180,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: n.palette.bg,
          borderRadius: n.radius.mdAll,
          border: Border.all(color: n.divider),
        ),
        child: Row(
          children: [
            Expanded(child: Text('English', style: n.text.small)),
            Icon(AppIcons.caretDown, size: 12, color: n.textMuted),
          ],
        ),
      ),
    );
  }
}

class _BehaviourCard extends StatelessWidget {
  const _BehaviourCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return _RowsCard(
      children: [
        ToggleRow(
          title: 'Auto-apply changes',
          description:
              'Write each change to the mouse straight away instead of '
              'staging it.',
          value: vm.autoApply,
          onChanged: (v) => unawaited(vm.setAutoApply(v)),
        ),
        if (vm.supportsStartup)
          ToggleRow(
            title: 'Start with system',
            description: 'Launch OpenX11SE minimised when you sign in.',
            value: vm.startWithSystem,
            onChanged: (v) => unawaited(vm.setStartWithSystem(v)),
          ),
        if (vm.supportsTray)
          ToggleRow(
            title: 'Minimise to tray',
            description:
                'Closing the window keeps the app running in the system tray.',
            value: vm.minimiseToTray,
            onChanged: (v) => unawaited(vm.setMinimiseToTray(v)),
          ),
        if (vm.showsReconnect)
          ToggleRow(
            title: 'Reconnect paired mouse',
            description:
                'Reconnect automatically to a mouse this browser was already '
                'allowed to use.',
            value: vm.autoReconnect,
            onChanged: (v) => unawaited(vm.setAutoReconnect(v)),
          ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: n.text.small.copyWith(color: n.textSecondary),
          ),
        ),
        Text(
          value,
          style: n.text.small.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<SettingsViewModel>();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text('Device', style: n.text.subheading),
          for (final row in vm.deviceInfo) _InfoLine(row.label, row.value),
          AppButton(
            label: 'Restore mouse to factory defaults',
            icon: AppIcons.warning,
            variant: AppButtonVariant.danger,
            onPressed: () => unawaited(vm.restoreFactoryDefaults()),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<SettingsViewModel>();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text('About', style: n.text.subheading),
          const _InfoLine('OpenX11SE', SettingsViewModel.appVersion),
          _InfoLine('Build', vm.buildText),
          Text(
            '${vm.platformNote} Not affiliated with Attack Shark.',
            style: n.text.caption.copyWith(color: n.textSecondary),
          ),
          Row(
            spacing: 14,
            children: [
              _Link(
                label: 'Open-source licences',
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'OpenX11SE',
                  applicationVersion: SettingsViewModel.appVersion,
                ),
              ),
              _Link(
                label: 'Source code',
                onPressed: () => unawaited(
                  launchUrl(Uri.parse(SettingsViewModel.sourceUrl)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Pressable(
      onPressed: onPressed,
      builder: (context, states) => Text(
        label,
        style: n.text.small.copyWith(
          color: n.accent,
          decoration: states.contains(WidgetState.hovered)
              ? TextDecoration.underline
              : TextDecoration.none,
          decorationColor: n.accent,
        ),
      ),
    );
  }
}
