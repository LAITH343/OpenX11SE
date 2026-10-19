import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/app_settings.dart';
import '../widgets/app_button.dart';
import '../widgets/auto_grid.dart';
import '../widgets/pressable.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_control.dart';
import '../widgets/surface_card.dart';
import '../widgets/toggle.dart';
import 'settings_view_model.dart';
import 'update_view_model.dart';

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
            SectionHeader(title: 'Settings'),
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
  const _SettingRow({required this.title, required this.trailing});

  final String title;
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
          child: Text(tr(title), style: n.text.row),
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
          trailing: SegmentedControl<bool>(
            options: const [
              SegmentOption(value: false, label: 'OpenX11SE violet'),
              SegmentOption(value: true, label: 'Active DPI stage'),
            ],
            selected: vm.accentFollowsStage,
            onChanged: (v) => unawaited(vm.setAccentFollowsStage(v)),
          ),
        ),
        const _SettingRow(title: 'Language', trailing: _LanguageField()),
      ],
    );
  }
}

class _LanguageField extends StatelessWidget {
  const _LanguageField();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<SettingsViewModel>();
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(n.surface),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
        minimumSize: const WidgetStatePropertyAll(Size(180, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: n.radius.mdAll,
            side: BorderSide(color: n.divider),
          ),
        ),
      ),
      menuChildren: [
        for (final language in AppLanguage.values)
          MenuItemButton(
            onPressed: () => unawaited(vm.setLanguage(language)),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(172, 34)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: n.radius.smAll),
              ),
            ),
            leadingIcon: SizedBox(
              width: 14,
              child: language == vm.language
                  ? Icon(AppIcons.check, size: 14, color: n.accent)
                  : null,
            ),
            child: Text(language.nativeName, style: n.text.small),
          ),
      ],
      builder: (context, controller, _) => Pressable(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        semanticLabel: tr('Language'),
        builder: (context, states) => AnimatedContainer(
          duration: n.motion.fast,
          width: 180,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: n.surface,
            borderRadius: n.radius.mdAll,
            border: Border.all(
              color: states.contains(WidgetState.hovered)
                  ? n.textColor.withValues(alpha: 0.45)
                  : n.divider,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(vm.language.nativeName, style: n.text.small),
              ),
              Icon(AppIcons.caretDown, size: 12, color: n.textMuted),
            ],
          ),
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
    final updates = context.watch<UpdateViewModel>();
    return _RowsCard(
      children: [
        ToggleRow(
          title: 'Auto-apply changes',
          value: vm.autoApply,
          onChanged: (v) => unawaited(vm.setAutoApply(v)),
        ),
        if (vm.supportsStartup)
          ToggleRow(
            title: 'Start with system',
            value: vm.startWithSystem,
            onChanged: (v) => unawaited(vm.setStartWithSystem(v)),
          ),
        if (vm.supportsTray)
          ToggleRow(
            title: 'Minimise to tray',
            value: vm.minimiseToTray,
            onChanged: (v) => unawaited(vm.setMinimiseToTray(v)),
          ),
        if (updates.isSupported)
          ToggleRow(
            title: 'Automatically check for updates',
            value: updates.autoCheck,
            onChanged: (v) => unawaited(updates.setAutoCheck(v)),
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
            tr(label),
            style: n.text.small.copyWith(color: n.textSecondary),
          ),
        ),
        Text(
          tr(value),
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
          Text(tr('Device'), style: n.text.subheading),
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
          Text(tr('About'), style: n.text.subheading),
          _InfoLine('OpenX11SE', vm.appVersion),
          _InfoLine('Build', vm.buildText),
          const _UpdateRow(),
          Text(
            tr('${vm.platformNote} Not affiliated with Attack Shark.'),
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
                  applicationVersion: vm.appVersion,
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
        tr(label),
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

class _UpdateRow extends StatelessWidget {
  const _UpdateRow();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<UpdateViewModel>();
    if (!vm.isSupported) return const SizedBox.shrink();
    final failed = vm.status == UpdateStatus.failed;
    final (label, icon, action) = switch (vm.status) {
      UpdateStatus.checking => ('Checking…', AppIcons.circleNotch, null),
      UpdateStatus.available ||
      UpdateStatus.downloading ||
      UpdateStatus.ready ||
      UpdateStatus.installing => (
        'View update',
        AppIcons.downloadSimple,
        vm.openDialog,
      ),
      UpdateStatus.failed => (
        'Retry',
        AppIcons.arrowClockwise,
        () => unawaited(vm.retry()),
      ),
      _ => (
        'Check for updates',
        AppIcons.arrowsClockwise,
        () => unawaited(vm.checkNow()),
      ),
    };
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: Text(
            tr(vm.statusText),
            style: n.text.small.copyWith(
              color: failed ? n.palette.danger : n.textSecondary,
            ),
          ),
        ),
        AppButton(
          label: label,
          icon: icon,
          size: AppButtonSize.small,
          onPressed: action,
        ),
      ],
    );
  }
}
