import '../../domain/device_info.dart';

class DeviceTiming {
  const DeviceTiming({
    required this.reportGap,
    this.readDelay = const Duration(milliseconds: 100),
    this.readAttempts = 5,
    this.busyPolls = 3,
    this.ackTimeout = const Duration(seconds: 3),
    this.writeAttempts = 3,
  });

  static const wired = DeviceTiming(reportGap: Duration(milliseconds: 200));
  static const wireless = DeviceTiming(reportGap: Duration(milliseconds: 500));

  static DeviceTiming forConnection(ConnectionType connection) =>
      connection == ConnectionType.wired ? wired : wireless;

  final Duration reportGap;
  final Duration readDelay;
  final int readAttempts;
  final int busyPolls;
  final Duration ackTimeout;
  final int writeAttempts;
}
