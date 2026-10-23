import 'dart:typed_data';

import '../../domain/device_info.dart';

abstract final class X11seUsb {
  static const vendorId = 0x1D57;
  static const wiredProductId = 0x2125;
  static const dongleProductId = 0xFA60;
  static const productIds = [wiredProductId, dongleProductId];
  static const featureUsagePage = 0x000B;
  static const notificationUsagePage = 0x000A;

  static ConnectionType? connectionFor(int productId) => switch (productId) {
    wiredProductId => ConnectionType.wired,
    dongleProductId => ConnectionType.dongle,
    _ => null,
  };
}

class HidDeviceInfo {
  const HidDeviceInfo({
    required this.id,
    required this.vendorId,
    required this.productId,
    this.productName,
  });

  final String id;
  final int vendorId;
  final int productId;
  final String? productName;

  ConnectionType get connection =>
      X11seUsb.connectionFor(productId) ?? ConnectionType.wired;

  @override
  bool operator ==(Object other) =>
      other is HidDeviceInfo &&
      other.id == id &&
      other.vendorId == vendorId &&
      other.productId == productId &&
      other.productName == productName;

  @override
  int get hashCode => Object.hash(id, vendorId, productId, productName);

  @override
  String toString() =>
      'HidDeviceInfo($id, ${vendorId.toRadixString(16)}:'
      '${productId.toRadixString(16)})';
}

class HidException implements Exception {
  const HidException(
    this.message, {
    this.disconnected = false,
    this.permissionDenied = false,
  });

  final String message;
  final bool disconnected;
  final bool permissionDenied;

  @override
  String toString() => 'HidException: $message';
}

enum HidAvailability { available, unsupported }

abstract interface class HidTransport {
  HidAvailability get availability;

  Stream<List<HidDeviceInfo>> get devices;

  Future<List<HidDeviceInfo>> enumerate();

  Future<HidConnection> open(HidDeviceInfo device);

  Future<void> dispose();
}

abstract interface class HidConnection {
  HidDeviceInfo get device;

  ConnectionType get connectionType;

  bool get supportsNotifications;

  Future<void> setFeature(Uint8List report);

  Future<Uint8List> getFeature(int reportId, int length);

  Stream<Uint8List> get notifications;

  Future<void> get closed;

  Future<void> close();
}
