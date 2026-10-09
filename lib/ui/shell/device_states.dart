import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/motion.dart';
import 'shell_view_model.dart';

class _StatePage extends StatelessWidget {
  const _StatePage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: EntranceTransition(
                  duration: const Duration(milliseconds: 350),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 18,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: n.text.display),
        const SizedBox(height: 6),
        Text(body, style: n.text.body.copyWith(color: n.textSecondary)),
      ],
    );
  }
}

class _DeviceDisc extends StatelessWidget {
  const _DeviceDisc({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: n.surface,
        shape: BoxShape.circle,
        boxShadow: n.palette.shadowSm,
      ),
      child: child,
    );
  }
}

class NoDeviceState extends StatelessWidget {
  const NoDeviceState({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final shell = context.watch<ShellViewModel>();
    final web = shell.needsUserGrant;
    final muted = n.text.small.copyWith(color: n.textSecondary);
    return _StatePage(
      children: [
        PulseRings(
          child: _DeviceDisc(
            child: Icon(AppIcons.mouseSimple, size: 32, color: n.accent),
          ),
        ),
        _Heading(
          title: 'Connect your X11SE',
          body: web
              ? 'Your browser needs your permission before it can talk to the '
                    'mouse.'
              : 'OpenX11SE finds the mouse on its own — no restart needed.',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            const _Step(1, 'Plug in the USB-C cable, or the 2.4 GHz dongle.'),
            const _Step(
              2,
              'Set the switch on the underside to 2.4G (or use the cable).',
            ),
            _Step(
              3,
              web
                  ? 'Click Connect and choose “X11SE” in the browser prompt.'
                  : 'It appears here within a second or two.',
            ),
          ],
        ),
        if (shell.failureText != null)
          Text(
            shell.failureText!,
            style: muted.copyWith(color: n.palette.warning),
          ),
        if (web)
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton.primary(
                label: 'Connect device',
                icon: AppIcons.usb,
                onPressed: shell.connect,
              ),
              Text(
                'Needs Chrome, Edge or Opera (WebHID)',
                style: n.text.caption.copyWith(
                  color: n.textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          )
        else
          Wrap(
            spacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spinner(),
                  const SizedBox(width: 8),
                  Text('Searching for devices…', style: muted),
                ],
              ),
              AppButton.ghost(
                label: 'Check again',
                onPressed: shell.checkAgain,
              ),
            ],
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: n.palette.n(800),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$number', style: n.text.caption),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(text, style: n.text.body)),
      ],
    );
  }
}

class AsleepState extends StatelessWidget {
  const AsleepState({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final shell = context.watch<ShellViewModel>();
    return _StatePage(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Positioned(
                left: -8,
                top: -8,
                right: -8,
                bottom: -8,
                child: Halo(size: 88),
              ),
              _DeviceDisc(
                child: Doze(
                  child: Icon(AppIcons.mouseSimple, size: 32, color: p.n(300)),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIconsFill.moonStars,
                    size: 16,
                    color: p.a(300),
                  ),
                ),
              ),
            ],
          ),
        ),
        const _Heading(
          title: 'Mouse is asleep',
          body:
              'Move or click the mouse to wake it. Settings will load '
              'automatically.',
        ),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Breathe(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: n.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  shell.sleepChecking
                      ? 'Checking…'
                      : 'Dongle connected · retrying automatically',
                  style: n.text.small.copyWith(color: n.textSecondary),
                ),
              ],
            ),
            AppButton(
              label: 'Check again',
              icon: AppIcons.arrowsClockwise,
              onPressed: shell.sleepChecking ? null : shell.checkSleep,
            ),
          ],
        ),
      ],
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: EntranceTransition(
          kind: Entrance.fade,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Row(
                children: [
                  const Spinner(),
                  const SizedBox(width: 10),
                  Text(
                    'Reading settings from X11SE…',
                    style: n.text.small.copyWith(color: n.textSecondary),
                  ),
                ],
              ),
              const Skeleton(width: 220, height: 26),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = ((c.maxWidth + 8) / 132).floor().clamp(1, 8);
                  final w = (c.maxWidth - (cols - 1) * 8) / cols;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < 8; i++)
                        Skeleton(width: w, height: 104),
                    ],
                  );
                },
              ),
              const Skeleton(height: 200, large: true),
              const Row(
                spacing: 12,
                children: [
                  Expanded(child: Skeleton(height: 120, large: true)),
                  Expanded(child: Skeleton(height: 120, large: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
