import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/motion.dart';
import '../widgets/status_banner.dart';
import 'update_view_model.dart';

class UpdateDialogLayer extends StatelessWidget {
  const UpdateDialogLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final open = context.select<UpdateViewModel, bool>(
      (vm) => vm.isSupported && vm.dialogOpen && vm.release != null,
    );
    if (!open) return const SizedBox.shrink();
    final vm = context.read<UpdateViewModel>();
    return Positioned.fill(
      child: EntranceTransition(
        kind: Entrance.fade,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: vm.closeDialog,
                child: ColoredBox(color: context.nocturne.backdrop),
              ),
            ),
            const EntranceTransition(
              kind: Entrance.pop,
              duration: Duration(milliseconds: 200),
              child: _UpdateDialog(),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final vm = context.watch<UpdateViewModel>();
    final release = vm.release;
    if (release == null) return const SizedBox.shrink();
    final status = vm.status;
    final published = release.publishedAt?.toLocal();
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Update available',
      child: AppDialog(
        title: 'OpenX11SE ${release.version} is available',
        body:
            'You have version ${vm.currentVersion}.'
            '${published == null ? '' : ' Released ${_date(published)}.'}',
        icon: AppIcons.downloadSimple,
        width: 520,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            if (release.notes.isNotEmpty) _ReleaseNotes(text: release.notes),
            if (status == UpdateStatus.downloading)
              _DownloadProgress(
                value: vm.progress,
                received: vm.received,
                total: vm.total,
              ),
            if (status == UpdateStatus.failed && vm.errorText != null)
              StatusBanner(
                kind: BannerKind.error,
                icon: AppIconsFill.warningCircle,
                message: Text(vm.errorText!),
              )
            else if (vm.writeInProgress && status == UpdateStatus.ready)
              const StatusBanner(
                kind: BannerKind.warning,
                icon: AppIconsFill.warning,
                message: Text(
                  'Writing to the mouse — install once it finishes.',
                ),
              )
            else if (vm.hasUnappliedEdits &&
                (status == UpdateStatus.ready ||
                    status == UpdateStatus.available))
              const StatusBanner(
                kind: BannerKind.warning,
                icon: AppIconsFill.warning,
                message: Text(
                  'You have unapplied edits. Apply them first — they are '
                  'lost when the app restarts to install.',
                ),
              ),
            if (status == UpdateStatus.ready)
              Text(
                'The installer runs silently, then OpenX11SE restarts. '
                'Profiles, macros and settings are kept.',
                style: n.text.caption.copyWith(color: n.textSecondary),
              ),
          ],
        ),
        actions: [
          AppButton(
            label: status == UpdateStatus.downloading ? 'Hide' : 'Later',
            onPressed: vm.closeDialog,
          ),
          _PrimaryAction(vm: vm),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.vm});

  final UpdateViewModel vm;

  @override
  Widget build(BuildContext context) {
    return switch (vm.status) {
      UpdateStatus.downloading => AppButton.primary(
        label: switch (vm.progress) {
          final double p => 'Downloading ${(p * 100).round()}%',
          null => 'Downloading…',
        },
        icon: AppIcons.circleNotch,
        onPressed: null,
      ),
      UpdateStatus.ready => AppButton.primary(
        label: 'Install and restart',
        icon: AppIcons.arrowsClockwise,
        onPressed: vm.canInstall ? () => unawaited(vm.install()) : null,
      ),
      UpdateStatus.installing => const AppButton.primary(
        label: 'Starting installer…',
        icon: AppIcons.circleNotch,
        onPressed: null,
      ),
      UpdateStatus.failed => AppButton.primary(
        label: 'Retry',
        icon: AppIcons.arrowClockwise,
        onPressed: () => unawaited(vm.retry()),
      ),
      _ => AppButton.primary(
        label: 'Download',
        icon: AppIcons.downloadSimple,
        onPressed: () => unawaited(vm.download()),
      ),
    };
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text('What’s new', style: n.text.caption.copyWith(color: n.textLabel)),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: n.palette.bg,
            borderRadius: n.radius.mdAll,
            border: Border.all(color: n.divider),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SelectableText(text, style: n.text.small),
          ),
        ),
      ],
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({
    required this.value,
    required this.received,
    required this.total,
  });

  final double? value;
  final int received;
  final int? total;

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        ClipRRect(
          borderRadius: n.radius.smAll,
          child: Container(
            height: 4,
            color: n.palette.n(900),
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value ?? 0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                child: ColoredBox(color: n.accent),
              ),
            ),
          ),
        ),
        Text(
          total == null
              ? '${_mb(received)} MB'
              : '${_mb(received)} of ${_mb(total!)} MB',
          style: n.text.tabular(
            n.text.caption.copyWith(color: n.textSecondary),
          ),
        ),
      ],
    );
  }
}
