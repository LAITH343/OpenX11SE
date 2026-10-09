import '../../domain/device_info.dart';
import '../../domain/device_settings.dart';
import '../hid/hid_transport.dart';

sealed class DeviceState {
  const DeviceState();
}

final class DeviceAbsent extends DeviceState {
  const DeviceAbsent();

  @override
  String toString() => 'DeviceAbsent()';
}

final class DeviceConnecting extends DeviceState {
  const DeviceConnecting(this.device);

  final HidDeviceInfo device;

  @override
  String toString() => 'DeviceConnecting($device)';
}

final class DeviceAsleep extends DeviceState {
  const DeviceAsleep(this.device);

  final HidDeviceInfo device;

  @override
  String toString() => 'DeviceAsleep($device)';
}

final class DeviceReady extends DeviceState {
  const DeviceReady({
    required this.device,
    required this.info,
    required this.settings,
    required this.includesButtons,
  });

  final HidDeviceInfo device;
  final DeviceInfo info;
  final DeviceSettings settings;
  final bool includesButtons;

  DeviceReady copyWith({
    DeviceInfo? info,
    DeviceSettings? settings,
    bool? includesButtons,
  }) => DeviceReady(
    device: device,
    info: info ?? this.info,
    settings: settings ?? this.settings,
    includesButtons: includesButtons ?? this.includesButtons,
  );

  @override
  String toString() => 'DeviceReady($info)';
}

final class DeviceFailed extends DeviceState {
  const DeviceFailed(this.device, this.error);

  final HidDeviceInfo device;
  final Object error;

  @override
  String toString() => 'DeviceFailed($device, $error)';
}
