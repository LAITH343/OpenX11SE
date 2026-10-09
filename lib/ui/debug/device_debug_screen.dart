import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/device_state.dart';
import '../widgets/app_button.dart';
import '../widgets/section_header.dart';
import '../widgets/surface_card.dart';
import '../widgets/tag.dart';
import 'device_debug_view_model.dart';

class DeviceDebugScreen extends StatelessWidget {
  const DeviceDebugScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => DeviceDebugViewModel(context.read<DeviceRepository>()),
    child: const _DeviceDebugBody(),
  );
}

class _DeviceDebugBody extends StatelessWidget {
  const _DeviceDebugBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeviceDebugViewModel>();
    final n = context.nocturne;
    final state = vm.state;
    return Scaffold(
      backgroundColor: n.bg,
      body: ListView(
        padding: EdgeInsets.all(n.space.s8),
        children: [
          SectionHeader(
            title: 'Device diagnostics',
            description: vm.isSupported
                ? 'Read-only view of the connected mouse.'
                : 'HID is not available on this platform.',
            trailing: Wrap(
              spacing: n.space.s3,
              children: [
                if (vm.requiresUserGrant)
                  AppButton.primary(
                    label: 'Connect device',
                    icon: AppIcons.plugsConnected,
                    onPressed: vm.requestDevice,
                  ),
                AppButton(
                  label: 'Check again',
                  icon: AppIcons.magnifyingGlass,
                  onPressed: vm.rescan,
                ),
                AppButton(
                  label: 'Read again',
                  icon: AppIcons.arrowsClockwise,
                  onPressed: state is DeviceReady ? vm.refresh : null,
                ),
              ],
            ),
          ),
          SizedBox(height: n.space.s6),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeading(
                  title: 'Connection',
                  icon: AppIcons.mouse,
                  trailing: Tag(label: _stateLabel(state)),
                ),
                SizedBox(height: n.space.s4),
                if (state is DeviceReady) ...[
                  Text('${state.info}', style: n.text.mono),
                  Text('${state.device}', style: n.text.mono),
                ],
                if (state is DeviceFailed)
                  Text('${state.error}', style: n.text.mono),
                for (final line in vm.settingsLines)
                  Text(line, style: n.text.mono),
              ],
            ),
          ),
          SizedBox(height: n.space.s6),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardHeading(title: 'Events', icon: AppIcons.pulse),
                SizedBox(height: n.space.s4),
                for (final line in vm.log)
                  SelectableText(line, style: n.text.mono),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _stateLabel(DeviceState state) => switch (state) {
    DeviceAbsent() => 'No device',
    DeviceConnecting() => 'Reading',
    DeviceAsleep() => 'Asleep',
    DeviceReady(:final info) => info.connection.name,
    DeviceFailed() => 'Error',
  };
}
