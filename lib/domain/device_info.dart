enum ConnectionType { wired, dongle }

enum ChargeState { unknown, discharging, charging, charged }

class DeviceInfo {
  const DeviceInfo({
    required this.connection,
    this.firmwareVersion,
    this.batteryPercent,
    this.chargeState = ChargeState.unknown,
  });

  final ConnectionType connection;
  final int? firmwareVersion;
  final int? batteryPercent;
  final ChargeState chargeState;

  String? get firmwareLabel {
    final v = firmwareVersion;
    if (v == null) return null;
    return '${v >> 8}.${(v & 0xFF).toString().padLeft(2, '0')}';
  }

  DeviceInfo copyWith({
    ConnectionType? connection,
    int? firmwareVersion,
    int? batteryPercent,
    ChargeState? chargeState,
  }) => DeviceInfo(
    connection: connection ?? this.connection,
    firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    batteryPercent: batteryPercent ?? this.batteryPercent,
    chargeState: chargeState ?? this.chargeState,
  );

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo &&
      other.connection == connection &&
      other.firmwareVersion == firmwareVersion &&
      other.batteryPercent == batteryPercent &&
      other.chargeState == chargeState;

  @override
  int get hashCode =>
      Object.hash(connection, firmwareVersion, batteryPercent, chargeState);

  @override
  String toString() =>
      'DeviceInfo($connection, fw: $firmwareLabel, battery: $batteryPercent, '
      '$chargeState)';
}
