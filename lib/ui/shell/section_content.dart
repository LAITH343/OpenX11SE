import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../widgets/app_button.dart';
import '../widgets/motion.dart';
import '../widgets/section_header.dart';
import '../widgets/status_banner.dart';
import 'app_section.dart';
import 'edit_session_view_model.dart';
import 'shell_view_model.dart';

class SectionContent extends StatelessWidget {
  const SectionContent({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellViewModel>();
    final error = context.select<EditSessionViewModel, WriteError?>(
      (e) => e.writeError,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1004),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              if (shell.status == ConnectionStatus.disconnected)
                const _DisconnectedBanner(),
              if (error != null) _WriteErrorBanner(error: error),
              EntranceTransition(
                child: SectionPlaceholder(section: shell.section),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) =>
      SectionHeader(title: section.label, description: section.description);
}

class _DisconnectedBanner extends StatelessWidget {
  const _DisconnectedBanner();

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellViewModel>();
    final asleep = shell.deviceAsleep;
    final reading = shell.isReconnecting && !asleep;
    return StatusBanner(
      kind: BannerKind.warning,
      icon: asleep ? AppIcons.moon : AppIcons.plugs,
      message: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: asleep ? 'Mouse is asleep.' : 'X11SE disconnected.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: asleep
                  ? ' Move or click it to reconnect — your edits are kept.'
                  : ' Your edits are kept — apply them when the mouse is '
                        'back.',
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: reading ? 'Reading…' : 'Reconnect',
          icon: AppIcons.arrowsClockwise,
          size: AppButtonSize.small,
          onPressed: reading ? null : shell.reconnect,
        ),
      ],
    );
  }
}

class _WriteErrorBanner extends StatelessWidget {
  const _WriteErrorBanner({required this.error});

  final WriteError error;

  @override
  Widget build(BuildContext context) {
    final edit = context.read<EditSessionViewModel>();
    return StatusBanner(
      kind: BannerKind.error,
      icon: error.asleep ? AppIcons.moon : AppIcons.xCircle,
      message: Text(error.message),
      actions: [
        AppButton.ghost(
          label: 'Dismiss',
          size: AppButtonSize.small,
          neutralForeground: true,
          onPressed: edit.dismissError,
        ),
        AppButton.primary(
          label: 'Retry',
          icon: AppIcons.arrowsClockwise,
          size: AppButtonSize.small,
          onPressed: () => edit.retry(),
        ),
      ],
    );
  }
}
