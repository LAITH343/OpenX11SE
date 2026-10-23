import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/hid/hid_transport.dart';
import 'package:openx11se/data/hid/linux/hidraw.dart';
import 'package:openx11se/data/hid/linux/linux_hid_transport.dart';
import 'package:openx11se/domain/device_info.dart';

/// Vendor collection on [page] with one feature and/or input report.
List<int> _descriptor(
  int page, {
  int reportId = 0x08,
  int featureBytes = 0,
  int inputBytes = 0,
}) => [
  0x05, page, // Usage Page
  0x09, 0x01, // Usage
  0xA1, 0x01, // Collection (Application)
  0x85, reportId, // Report ID
  0x75, 0x08, // Report Size (8)
  if (featureBytes > 0) ...[0x95, featureBytes, 0x09, 0x01, 0xB1, 0x02],
  if (inputBytes > 0) ...[0x95, inputBytes, 0x09, 0x01, 0x81, 0x02],
  0xC0, // End Collection
];

const _mouse = [
  0x05, 0x01, 0x09, 0x02, 0xA1, 0x01, // Generic Desktop, Mouse
  0x09, 0x01, 0xA1, 0x00, // Pointer (Physical)
  0x05, 0x09, 0x19, 0x01, 0x29, 0x05, // Buttons 1..5
  0x75, 0x01, 0x95, 0x05, 0x81, 0x02,
  0x75, 0x03, 0x95, 0x01, 0x81, 0x01, // Padding
  0x05, 0x01, 0x09, 0x30, 0x09, 0x31, // X, Y
  0x75, 0x10, 0x95, 0x02, 0x81, 0x06,
  0xC0, 0xC0,
];

HidrawNode _node(
  String name, {
  required List<int> descriptor,
  int productId = X11seUsb.wiredProductId,
  String physical = 'usb-0000:00:14.0-2/input0',
}) => HidrawNode(
  devicePath: '/dev/$name',
  vendorId: X11seUsb.vendorId,
  productId: productId,
  physical: physical,
  productName: 'X11SE',
  descriptor: parseReportDescriptor(descriptor),
);

void main() {
  group('parseReportDescriptor', () {
    test('reads top-level usage pages and report lengths', () {
      final info = parseReportDescriptor(
        _descriptor(X11seUsb.featureUsagePage, featureBytes: 64),
      );
      expect(info.usagePages, {X11seUsb.featureUsagePage});
      expect(info.featureLength, 65);
      expect(info.inputLength, 0);
    });

    test('ignores nested collections and keeps the longest report', () {
      final info = parseReportDescriptor([
        ..._mouse,
        ..._descriptor(
          X11seUsb.notificationUsagePage,
          reportId: 0x03,
          inputBytes: 15,
        ),
      ]);
      expect(info.usagePages, {0x01, X11seUsb.notificationUsagePage});
      expect(info.inputLength, 16);
      expect(info.featureLength, 0);
    });

    test('stops cleanly on a truncated descriptor', () {
      final full = _descriptor(X11seUsb.featureUsagePage, featureBytes: 8);
      expect(
        parseReportDescriptor(full.sublist(0, full.length - 3)).usagePages,
        {X11seUsb.featureUsagePage},
      );
    });
  });

  test('parseHidId reads vendor and product from a uevent', () {
    expect(
      parseHidId(
        'DRIVER=hid-generic\nHID_ID=0003:00001D57:0000FA60\nHID_NAME=X11SE\n',
      ),
      (0x1D57, 0xFA60),
    );
    expect(parseHidId('DRIVER=hid-generic\n'), isNull);
  });

  group('groupHidrawNodes', () {
    test('pairs feature and notification nodes per physical device', () {
      final devices = groupHidrawNodes([
        _node('hidraw0', descriptor: _mouse),
        _node(
          'hidraw1',
          physical: 'usb-0000:00:14.0-2/input1',
          descriptor: _descriptor(X11seUsb.featureUsagePage, featureBytes: 64),
        ),
        _node(
          'hidraw2',
          physical: 'usb-0000:00:14.0-2/input2',
          descriptor: _descriptor(
            X11seUsb.notificationUsagePage,
            reportId: 0x03,
            inputBytes: 15,
          ),
        ),
        _node(
          'hidraw3',
          productId: X11seUsb.dongleProductId,
          physical: 'usb-0000:00:14.0-3/input1',
          descriptor: [
            ..._descriptor(X11seUsb.featureUsagePage, featureBytes: 64),
            ..._descriptor(
              X11seUsb.notificationUsagePage,
              reportId: 0x03,
              inputBytes: 15,
            ),
          ],
        ),
      ]);

      expect(devices, hasLength(2));
      final wired = devices.firstWhere(
        (d) => d.info.connection == ConnectionType.wired,
      );
      expect(wired.featurePath, '/dev/hidraw1');
      expect(wired.featureLength, 65);
      expect(wired.notificationPath, '/dev/hidraw2');
      expect(wired.notificationLength, 16);
      final dongle = devices.firstWhere(
        (d) => d.info.connection == ConnectionType.dongle,
      );
      expect(dongle.featurePath, '/dev/hidraw3');
      expect(dongle.notificationPath, '/dev/hidraw3');
    });

    test('skips devices without a feature report', () {
      expect(groupHidrawNodes([_node('hidraw0', descriptor: _mouse)]), isEmpty);
    });
  });

  group('readHidrawNodes', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('hidraw-test'));
    tearDown(() => root.deleteSync(recursive: true));

    void addNode(String name, String hidId, List<int> descriptor) {
      final device = Directory('${root.path}/sys/$name/device')
        ..createSync(recursive: true);
      File('${device.path}/uevent').writeAsStringSync(
        'DRIVER=hid-generic\nHID_ID=$hidId\nHID_NAME=Attack Shark X11SE\n'
        'HID_PHYS=usb-0000:00:14.0-2/input1\n',
      );
      File('${device.path}/report_descriptor').writeAsBytesSync(descriptor);
    }

    test('lists only X11SE nodes with their descriptors', () async {
      addNode(
        'hidraw4',
        '0003:00001D57:00002125',
        _descriptor(X11seUsb.featureUsagePage, featureBytes: 64),
      );
      addNode('hidraw5', '0003:0000046D:0000C52B', _mouse);

      final nodes = await readHidrawNodes(
        sysfs: '${root.path}/sys',
        dev: '/dev',
      );

      expect(nodes, hasLength(1));
      final node = nodes.single;
      expect(node.devicePath, '/dev/hidraw4');
      expect(node.productId, X11seUsb.wiredProductId);
      expect(node.productName, 'Attack Shark X11SE');
      expect(node.physical, 'usb-0000:00:14.0-2/input1');
      expect(node.descriptor.featureLength, 65);
    });

    test('returns nothing when hidraw is missing', () async {
      expect(await readHidrawNodes(sysfs: '${root.path}/none'), isEmpty);
    });
  });

  test('transport enumerates grouped devices', () async {
    final transport = LinuxHidTransport(
      nodes: () async => [
        _node(
          'hidraw1',
          descriptor: _descriptor(X11seUsb.featureUsagePage, featureBytes: 64),
        ),
      ],
    );
    addTearDown(transport.dispose);

    final devices = await transport.enumerate();

    expect(devices, hasLength(1));
    expect(devices.single.productId, X11seUsb.wiredProductId);
    expect(transport.availability, HidAvailability.available);
  });

  test('feature ioctl numbers match linux/hidraw.h', () {
    // HIDIOCSFEATURE(65) and HIDIOCGFEATURE(65) as computed by the C macros.
    expect(Hidraw.setFeatureRequest(65), 0xC0414806);
    expect(Hidraw.getFeatureRequest(65), 0xC0414807);
  });
}
