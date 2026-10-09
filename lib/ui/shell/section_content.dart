import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../buttons/buttons_section.dart';
import '../lighting/lighting_section.dart';
import '../performance/performance_section.dart';
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
                const _DisconnectedBanner()
              else if (shell.deviceOff)
                const _OffBanner(),
              if (error != null) _WriteErrorBanner(error: error),
              EntranceTransition(
                child: switch (shell.section) {
                  AppSection.performance => const PerformanceSection(),
                  AppSection.buttons => const ButtonsSection(),
                  AppSection.lighting => const LightingSection(),
                  final section => SectionPlaceholder(section: section),
                },
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
    final off = shell.deviceOff;
    final asleep = !off && shell.deviceAsleep;
    final reading = shell.isReconnecting && !asleep && !off;
    return StatusBanner(
      kind: BannerKind.warning,
      icon: off
          ? AppIcons.power
          : asleep
          ? AppIcons.moon
          : AppIcons.plugs,
      message: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: off
                  ? 'Mouse is off.'
                  : asleep
                  ? 'Mouse is asleep.'
                  : 'X11SE disconnected.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: off
                  ? " Your edits are kept — apply them when it's back on."
                  : asleep
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

class _OffBanner extends StatelessWidget {
  const _OffBanner();

  @override
  Widget build(BuildContext context) => const StatusBanner(
    kind: BannerKind.warning,
    icon: AppIcons.power,
    message: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Mouse is off.',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: " Your edits are kept — apply them when it's back on.",
          ),
        ],
      ),
    ),
  );
}

class _WriteErrorBanner extends StatelessWidget {
  const _WriteErrorBanner({required this.error});

  final WriteError error;

  @override
  Widget build(BuildContext context) {
    final edit = context.read<EditSessionViewModel>();
    return StatusBanner(
      kind: BannerKind.error,
      icon: error.off
          ? AppIcons.power
          : error.asleep
          ? AppIcons.moon
          : AppIcons.xCircle,
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
