import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../domain/device_info.dart';
import '../widgets/app_button.dart';
import '../widgets/motion.dart';
import 'edit_session_view_model.dart';
import 'shell_view_model.dart';

class TitleBarActions extends StatelessWidget {
  const TitleBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final edit = context.watch<EditSessionViewModel>();
    final online = context.select<ShellViewModel, bool>((s) => s.isOnline);
    final count = edit.pendingCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          size: AppButtonSize.small,
          label: 'Discard',
          icon: AppIcons.arrowCounterClockwise,
          tooltip: 'Discard staged changes',
          onPressed: edit.canDiscard ? edit.discard : null,
        ),
        const SizedBox(width: 8),
        AppButton.primary(
          size: AppButtonSize.small,
          label: edit.writing ? 'Writing…' : 'Apply',
          icon: edit.writing ? null : AppIcons.uploadSimple,
          tooltip: edit.mouseOff
              ? 'Turn the mouse on to apply'
              : !online
              ? 'Reconnect the mouse to apply'
              : count > 0
              ? 'Write changes to the mouse (Ctrl+S)'
              : 'No changes to apply',
          trailing: edit.writing
              ? null
              : count > 0
              ? _CountBadge(count: count)
              : null,
          onPressed: edit.canApply ? edit.apply : null,
        ),
      ],
    );
  }
}
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: n.palette.a(800),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$count',
        style: n.text.tabular(n.text.micro.copyWith(color: n.palette.a(100))),
      ),
    );
  }
}

class DeviceStatus {
  const DeviceStatus({
    required this.label,
    required this.icon,
    required this.color,
    required this.tip,
    this.spin = false,
    this.dot,
    this.tint,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String tip;
  final bool spin;
  final Color? dot;
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
        dot: p.n(500),
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
        label: 'Readingâ€¦',
        icon: AppIcons.circleNotch,
        color: p.n(400),
        tip: 'Reading settings from the mouse',
        spin: true,
      ),
      ConnectionStatus.disconnected => DeviceStatus(
        label: 'Disconnected',
        icon: AppIcons.plugs,
        color: p.danger,
        tip: 'Connection lost â€” edits are kept',
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

class DeviceSummary extends StatelessWidget {
  const DeviceSummary({super.key, this.titleBar = false});

  final bool titleBar;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final shell = context.watch<ShellViewModel>();
    final writeAsleep = context.select<EditSessionViewModel, bool>(
      (e) => e.writeError?.asleep ?? false,
    );
    final off = shell.deviceOff;
    final asleep = !off && (shell.deviceAsleep || writeAsleep);
    final status = DeviceStatus.of(context, shell, asleep: asleep, off: off);
    final online = shell.isOnline;
    final battery = shell.batteryPercent;
    final showBattery =
        battery != null && (online || shell.deviceAsleep || off);
    final sub = switch (shell.status) {
      ConnectionStatus.asleep => 'Retrying automatically',
      ConnectionStatus.off => 'Waiting for the mouse',
      ConnectionStatus.disconnected => 'Edits kept · reconnect to apply',
      ConnectionStatus.loading => 'Reading settingsâ€¦',
      _ when !shell.isHidAvailable => 'Device connection unavailable',
      _ => 'Plug in cable or dongle',
    };
    final badgeIcon = Icon(status.icon, size: 12, color: status.color);
    if (titleBar) {
      return Tooltip(
        message: status.tip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'X11SE',
              style: n.text.small.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: status.dot ?? status.color,
                shape: BoxShape.circle,
              ),
            ),
            if (online && shell.firmwareLabel != null) ...[
              const SizedBox(width: 12),
              _TitleBarSeparator(color: n.divider),
              const SizedBox(width: 12),
              Text(
                'FW ${shell.firmwareLabel}',
                style: n.text.caption.copyWith(color: n.textSecondary),
              ),
            ],
            if (showBattery) ...[
              const SizedBox(width: 12),
              _TitleBarSeparator(color: n.divider),
              const SizedBox(width: 12),
              _Battery(
                percent: battery,
                charge: shell.chargeState,
                stale: asleep || off,
              ),
            ],
            const SizedBox(width: 12),
            _TitleBarSeparator(color: n.divider),
            const SizedBox(width: 12),
            Icon(status.icon, size: 13, color: status.color),
            const SizedBox(width: 5),
            Text(
              status.label,
              style: n.text.caption.copyWith(color: status.color),
            ),
          ],
        ),
      );
    }
    return Tooltip(
      message: status.tip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: n.radius.mdAll,
                    boxShadow: p.shadowSm,
                  ),
                  child: Icon(
                    AppIcons.mouseSimple,
                    size: 20,
                    color: online && !asleep && !off ? n.textColor : p.n(500),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: status.dot ?? status.color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: p.bg, spreadRadius: 2)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'X11SE',
                      style: n.text.subheading.copyWith(height: 1.3),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              status.tint ??
                              status.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status.spin)
                              Spinner(size: 12, color: status.color)
                            else
                              badgeIcon,
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                status.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: n.text.micro.copyWith(
                                  color: status.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                DefaultTextStyle(
                  style: n.text.tabular(
                    n.text.micro.copyWith(color: n.textSecondary),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (online && shell.firmwareLabel != null) ...[
                        Tooltip(
                          message: 'Firmware version read from the mouse',
                          child: Text('FW ${shell.firmwareLabel}'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (showBattery)
                        _Battery(
                          percent: battery,
                          charge: shell.chargeState,
                          stale: asleep || off,
                        ),
                      if (!online) Flexible(child: Text(sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBarSeparator extends StatelessWidget {
  const _TitleBarSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 16,
    color: color,
  );
}

class _Battery extends StatelessWidget {
  const _Battery({
    required this.percent,
    required this.charge,
    required this.stale,
  });

  final int percent;
  final ChargeState charge;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final charging =
        charge == ChargeState.charging || charge == ChargeState.charged;
    final full = charge == ChargeState.charged;
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
    final color = stale
        ? p.n(500)
        : full
        ? p.success
        : charging
        ? p.a(300)
        : percent < 15
        ? p.danger
        : n.textSecondary;
    final tip = stale
        ? 'Last known level'
        : full
        ? 'Fully charged · $percent% · cable connected'
        : charging
        ? 'Charging over USB · $percent%'
        : 'Running on battery · $percent%';
    return Tooltip(
      message: tip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('$percent%', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
