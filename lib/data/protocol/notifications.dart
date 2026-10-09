import '../../domain/device_info.dart';

const notificationLength = 5;

sealed class DeviceNotification {
  const DeviceNotification();
}

final class BatteryNotification extends DeviceNotification {
  const BatteryNotification({required this.percent, required this.chargeState});

  final int percent;
  final ChargeState chargeState;

  @override
  bool operator ==(Object other) =>
      other is BatteryNotification &&
      other.percent == percent &&
      other.chargeState == chargeState;

  @override
  int get hashCode => Object.hash(percent, chargeState);

  @override
  String toString() => 'BatteryNotification($percent%, $chargeState)';
}

final class WriteAckNotification extends DeviceNotification {
  const WriteAckNotification(this.reportId);

  final int reportId;

  @override
  bool operator ==(Object other) =>
      other is WriteAckNotification && other.reportId == reportId;

  @override
  int get hashCode => reportId;

  @override
  String toString() => 'WriteAckNotification(0x${reportId.toRadixString(16)})';
}

final class DpiStageNotification extends DeviceNotification {
  const DpiStageNotification(this.stageIndex);

  final int stageIndex;

  @override
  bool operator ==(Object other) =>
      other is DpiStageNotification && other.stageIndex == stageIndex;

  @override
  int get hashCode => stageIndex;

  @override
  String toString() => 'DpiStageNotification($stageIndex)';
}

DeviceNotification? decodeNotification(List<int> bytes) {
  if (bytes.length < notificationLength ||
      bytes[0] != 0x03 ||
      bytes[1] != 0x07) {
    return null;
  }
  return switch (bytes[2]) {
    0x40 => BatteryNotification(
      percent: bytes[4] > 100 ? 100 : bytes[4],
      chargeState: switch (bytes[3]) {
        0x01 => ChargeState.discharging,
        0x02 => ChargeState.charged,
        0x03 => ChargeState.charging,
        _ => ChargeState.unknown,
      },
    ),
    0x50 => WriteAckNotification(bytes[4]),
    0x10 when bytes[3] >= 1 && bytes[3] <= 8 => DpiStageNotification(
      bytes[3] - 1,
    ),
    _ => null,
  };
}
