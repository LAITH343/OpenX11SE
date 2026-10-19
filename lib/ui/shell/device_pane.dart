import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting/number_format.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/device_info.dart';
import '../buttons/mouse_illustration.dart';
import '../power/power_view_model.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import 'app_section.dart';
import 'edit_session_view_model.dart';
import 'shell_view_model.dart';

class DeviceStatus {
  const DeviceStatus({
    required this.label,
    required this.icon,
    required this.color,
    required this.tip,
    this.spin = false,
    this.tint,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String tip;
  final bool spin;
  final Color? tint;

  static DeviceStatus of(
    BuildContext context,
    ShellViewModel shell, {
    required bool asleep,
    required bool off,
  }) {
    final p = context.nocturne.palette;
    if (off) {
      return DeviceStatus(
        label: '2.4 GHz · Off',
        icon: AppIcons.power,
        color: p.n(400),
        tint: p.n(500).withValues(alpha: 0.14),
        tip: 'Dongle connected · the mouse is switched off or out of range',
      );
    }
    if (asleep) {
      return DeviceStatus(
        label: '2.4 GHz · Asleep',
        icon: AppIcons.moon,
        color: p.n(400),
        tip: 'Dongle connected · the mouse is asleep. Retrying automatically.',
      );
    }
    final wired = shell.connection == ConnectionType.wired;
    return switch (shell.status) {
      ConnectionStatus.connected => DeviceStatus(
        label: wired ? 'Wired' : '2.4 GHz',
        icon: wired ? AppIcons.plugsConnected : AppIcons.broadcast,
        color: p.success,
        tip: wired
            ? 'Connected by USB cable'
            : 'Connected through the 2.4 GHz dongle',
      ),
      ConnectionStatus.loading => DeviceStatus(
        label: 'Reading…',
        icon: AppIcons.circleNotch,
        color: p.n(400),
        tip: 'Reading settings from the mouse',
        spin: true,
      ),
      ConnectionStatus.disconnected => DeviceStatus(
        label: 'Disconnected',
        icon: AppIcons.plugs,
        color: p.danger,
        tip: 'Connection lost — edits are kept',
      ),
      ConnectionStatus.asleep ||
      ConnectionStatus.off ||
      ConnectionStatus.none => DeviceStatus(
        label: 'No device',
        icon: AppIcons.plugs,
        color: p.n(400),
        tip: 'Plug in the cable or dongle',
      ),
    };
  }
}

class DevicePane extends StatelessWidget {
  const DevicePane({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final stage = context.select<ShellViewModel, Color?>((s) {
      final stage = s.activeStage;
      return stage == null ? null : Color(0xFF000000 | stage.color.rgb);
    });
    final glow = stage ?? n.accent;
    return AnimatedContainer(
      duration: n.motion.medium,
      width: compact ? 250 : 330,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.08),
          radius: 0.62,
          colors: [glow.withValues(alpha: 0.09), glow.withValues(alpha: 0)],
          stops: const [0, 0.8],
        ),
      ),
      child: Stack(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 16, 14, 70),
            child: Column(
              spacing: 16,
              children: [
                _Header(),
                Expanded(child: _Mouse()),
                _StageReadout(),
                _BatteryCard(),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: _FadingRule(color: n.divider),
          ),
        ],
      ),
    );
  }
}

class _FadingRule extends StatelessWidget {
  const _FadingRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final ramp = c.maxHeight > 96 ? 48 / c.maxHeight : 0.5;
      return Container(
        width: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0),
              color,
              color,
              color.withValues(alpha: 0),
            ],
            stops: [0, ramp, 1 - ramp, 1],
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final shell = context.watch<ShellViewModel>();
    final writeAsleep = context.select<EditSessionViewModel, bool>(
      (e) => e.writeError?.asleep ?? false,
    );
    final off = shell.deviceOff;
    final asleep = !off && (shell.deviceAsleep || writeAsleep);
    final status = DeviceStatus.of(context, shell, asleep: asleep, off: off);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('X11SE', style: n.text.subheading.copyWith(height: 1.3)),
          if (shell.firmwareLabel != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Firmware version read from the mouse',
              child: Text(
                'FW ${shell.firmwareLabel}',
                style: n.text.micro.copyWith(color: n.textSecondary),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Tooltip(
                message: status.tip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: status.tint ?? status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status.spin)
                        Spinner(size: 12, color: status.color)
                      else
                        Icon(status.icon, size: 12, color: status.color),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: n.text.micro.copyWith(color: status.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mouse extends StatelessWidget {
  const _Mouse();

  static const _scale = 0.8;

  @override
  Widget build(BuildContext context) {
    final buttons = context.select<ShellViewModel, bool>(
      (s) => s.section == AppSection.buttons,
    );
    final width =
        (MouseIllustration.bodySize.width + MouseIllustration.gutter * 2) *
        _scale;
    final height = MouseIllustration.bodySize.height * _scale;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: width,
          height: height,
          child: FittedBox(child: MouseIllustration(interactive: buttons)),
        ),
      ),
    );
  }
}

class _StageReadout extends StatelessWidget {
  const _StageReadout();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final shell = context.watch<ShellViewModel>();
    final dpi = shell.dpi;
    if (dpi == null) return const SizedBox.shrink();
    return Column(
      spacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: 6,
          children: [
            Text(
              formatThousands(dpi.activeStage.dpi),
              style: n.text.tabular(
                n.text.display.copyWith(
                  fontSize: 34,
                  letterSpacing: -0.68,
                  height: 1.1,
                ),
              ),
            ),
            Text('DPI', style: n.text.caption.copyWith(color: n.textSecondary)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            for (var i = 0; i < dpi.stages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == dpi.activeStageIndex ? 22 : 8,
                height: 4,
                decoration: BoxDecoration(
                  color: dpi.stages[i].enabled
                      ? Color(0xFF000000 | dpi.stages[i].color.rgb)
                      : p.n(700).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
        Text(
          'Stage ${dpi.activeStageIndex + 1}',
          style: n.text.tabular(
            n.text.micro.copyWith(fontSize: 11.5, color: n.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final shell = context.watch<ShellViewModel>();
    final percent = shell.batteryPercent;
    final sleep = context.select<PowerViewModel, int?>(
      (v) => v.hasSettings ? v.power.sleepMinutes : null,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: n.radius.lgAll,
        boxShadow: p.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (percent != null) ..._level(context, shell, percent),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: _Stat(
                  label: 'Sleeps after',
                  value: sleep == null ? '—' : '$sleep min',
                  tooltip: 'Sleep and power settings',
                  onPressed: () => shell.selectSection(AppSection.power),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Report rate',
                  value: '${shell.polling?.hz ?? '—'} Hz',
                  tooltip: 'Polling rate',
                  onPressed: () => shell.selectSection(AppSection.performance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _level(BuildContext context, ShellViewModel shell, int percent) {
    final n = context.nocturne;
    final p = n.palette;
    final charge = shell.chargeState;
    final stale = !shell.isOnline || shell.deviceAsleep || shell.deviceOff;
    final full = charge == ChargeState.charged;
    final charging = charge == ChargeState.charging;
    final icon = full
        ? AppIcons.batteryFull
        : charging
        ? AppIcons.batteryCharging
        : percent >= 90
        ? AppIcons.batteryFull
        : percent >= 60
        ? AppIcons.batteryHigh
        : percent >= 35
        ? AppIcons.batteryMedium
        : percent >= 15
        ? AppIcons.batteryLow
        : AppIcons.batteryWarning;
    final fill = stale
        ? p.n(500)
        : full
        ? p.success
        : percent < ShellViewModel.lowBatteryPercent
        ? p.danger
        : n.accent;
    final (state, stateIcon, stateBg, stateFg) = full
        ? (
            'Fully charged',
            AppIcons.checkCircle,
            p.success.withValues(alpha: 0.14),
            p.success,
          )
        : charging
        ? ('Charging', AppIcons.lightning, p.a(900), p.a(200))
        : ('Charger disconnected', AppIcons.plugs, p.n(800), p.n(200));
    final tip = stale
        ? 'Last known level'
        : full
        ? 'Fully charged · $percent% · cable connected'
        : charging
        ? 'Charging over USB · $percent%'
        : 'Running on battery · $percent% · charger disconnected';
    final stateIconWidget = Icon(stateIcon, size: 12, color: stateFg);
    return [
      Tooltip(
        message: tip,
        child: Row(
          children: [
            Icon(icon, size: 22, color: fill),
            const SizedBox(width: 10),
            Text('$percent%', style: n.text.valueSmall),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: stateBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      if (charging && !full)
                        Blink(
                          period: const Duration(milliseconds: 1800),
                          child: stateIconWidget,
                        )
                      else
                        stateIconWidget,
                      Flexible(
                        child: Text(
                          state,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: n.text.micro.copyWith(color: stateFg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 4,
          color: p.n(800),
          alignment: AlignmentDirectional.centerStart,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: percent.clamp(0, 100) / 100),
            duration: const Duration(milliseconds: 400),
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final String value;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Pressable(
      onPressed: onPressed,
      tooltip: tooltip,
      builder: (context, states) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: n.text.micro.copyWith(
              fontSize: 11.5,
              color: n.textSecondary,
            ),
          ),
          Text(value, style: n.text.tabular(n.text.small)),
        ],
      ),
    );
  }
}
