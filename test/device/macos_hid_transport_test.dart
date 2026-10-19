import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/hid/hid_transport.dart';
import 'package:openx11se/data/hid/macos/macos_hid_transport.dart';

const _methods = MethodChannel('test/hid');
const _events = EventChannel('test/hid/events');

Map<String, Object?> _interface(
  String id, {
  int productId = X11seUsb.wiredProductId,
  int locationId = 0x14200000,
  List<int> pages = const [],
  int featureLength = 0,
  int inputLength = 0,
}) => {
  'id': id,
  'vendorId': X11seUsb.vendorId,
  'productId': productId,
  'locationId': locationId,
  'product': 'X11SE',
  'usages': [
    for (final page in pages) [page, 1],
  ],
  'featureLength': featureLength,
  'inputLength': inputLength,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('groupMacInterfaces', () {
    test('pairs feature and notification interfaces per device', () {
      final devices = groupMacInterfaces(
        [
          _interface('1', pages: [0x01], inputLength: 8),
          _interface(
            '2',
            pages: [X11seUsb.featureUsagePage],
            featureLength: 65,
          ),
          _interface(
            '3',
            pages: [X11seUsb.notificationUsagePage],
            inputLength: 6,
          ),
          _interface(
            '4',
            productId: X11seUsb.dongleProductId,
            locationId: 0x14300000,
            pages: [X11seUsb.featureUsagePage, X11seUsb.notificationUsagePage],
            featureLength: 65,
            inputLength: 6,
          ),
        ].map(MacHidInterface.fromMap),
      );
      expect(devices, hasLength(2));
      final wired = devices.firstWhere(
        (d) => d.info.productId == X11seUsb.wiredProductId,
      );
      expect(wired.feature.id, '2');
      expect(wired.notification?.id, '3');
      final dongle = devices.firstWhere(
        (d) => d.info.productId == X11seUsb.dongleProductId,
      );
      expect(dongle.feature.id, '4');
      expect(dongle.notification?.id, '4');
    });

    test('ignores other devices and groups without feature reports', () {
      final devices = groupMacInterfaces(
        [
          {..._interface('1', featureLength: 65), 'vendorId': 0x1234},
          _interface(
            '2',
            pages: [X11seUsb.notificationUsagePage],
            inputLength: 6,
          ),
        ].map(MacHidInterface.fromMap),
      );
      expect(devices, isEmpty);
    });
  });

  group('MacHidTransport', () {
    late List<MethodCall> calls;
    late StreamController<Object?> events;
    late Map<String, Object? Function(MethodCall)> handlers;
    var nextHandle = 1;

    setUp(() {
      calls = [];
      nextHandle = 1;
      events = StreamController<Object?>();
      handlers = {
        'enumerate': (_) => [
          _interface(
            'f',
            pages: [X11seUsb.featureUsagePage],
            featureLength: 65,
          ),
          _interface(
            'n',
            pages: [X11seUsb.notificationUsagePage],
            inputLength: 6,
          ),
        ],
        'open': (_) => nextHandle++,
        'listen': (_) => null,
        'close': (_) => null,
        'setFeature': (_) => null,
        'getFeature': (call) {
          final args = call.arguments as Map<Object?, Object?>;
          return Uint8List(args['length']! as int)
            ..[0] = args['reportId']! as int;
        },
      };
      messenger.setMockMethodCallHandler(_methods, (call) async {
        calls.add(call);
        return handlers[call.method]!(call);
      });
      messenger.setMockStreamHandler(
        _events,
        MockStreamHandler.inline(
          onListen: (_, sink) => events.stream.listen(sink.success),
        ),
      );
    });

    tearDown(() async {
      messenger.setMockMethodCallHandler(_methods, null);
      messenger.setMockStreamHandler(_events, null);
      await events.close();
    });

    MacHidTransport transport() =>
        MacHidTransport(methods: _methods, events: _events);

    test('enumerates and opens feature and notification interfaces', () async {
      final hid = transport();
      final devices = await hid.enumerate();
      expect(devices.single.productId, X11seUsb.wiredProductId);
      final connection = await hid.open(devices.single);
      expect(connection.supportsNotifications, isTrue);
      expect(calls.where((c) => c.method == 'open').map((c) => c.arguments), [
        {'id': 'f'},
        {'id': 'n'},
      ]);
      final listen = calls.singleWhere((c) => c.method == 'listen');
      expect(listen.arguments, {'handle': 2, 'length': 6});

      await connection.setFeature(Uint8List.fromList([4, 1, 2]));
      final report = await connection.getFeature(0x0B, 8);
      expect(report, hasLength(8));
      expect(report[0], 0x0B);
      expect(calls.singleWhere((c) => c.method == 'getFeature').arguments, {
        'handle': 1,
        'reportId': 0x0B,
        'length': 8,
      });

      final received = connection.notifications.first;
      events.add({
        'handle': 2,
        'event': 'report',
        'data': Uint8List.fromList([3, 7, 0x40, 1, 80]),
      });
      expect(await received, [3, 7, 0x40, 1, 80]);

      await connection.close();
      expect(calls.where((c) => c.method == 'close').map((c) => c.arguments), [
        {'handle': 2},
        {'handle': 1},
      ]);
      await hid.dispose();
    });

    test('closes the connection when the device is removed', () async {
      final hid = transport();
      final connection = await hid.open((await hid.enumerate()).single);
      events.add({'handle': 1, 'event': 'removed'});
      await connection.closed.timeout(const Duration(seconds: 1));
      await expectLater(
        connection.setFeature(Uint8List.fromList([4])),
        throwsA(
          isA<HidException>().having(
            (e) => e.disconnected,
            'disconnected',
            true,
          ),
        ),
      );
      await hid.dispose();
    });

    test('maps platform errors to HID exceptions', () async {
      handlers['setFeature'] = (_) =>
          throw PlatformException(code: 'disconnected', message: 'gone');
      final hid = transport();
      final connection = await hid.open((await hid.enumerate()).single);
      await expectLater(
        connection.setFeature(Uint8List.fromList([4])),
        throwsA(
          isA<HidException>().having(
            (e) => e.disconnected,
            'disconnected',
            true,
          ),
        ),
      );
      await connection.closed.timeout(const Duration(seconds: 1));
      await hid.dispose();
    });

    test('releases handles when the device goes away while opening', () async {
      handlers['open'] = (call) async {
        final handle = nextHandle++;
        if ((call.arguments as Map<Object?, Object?>)['id'] == 'n') {
          events.add({'handle': 1, 'event': 'removed'});
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return handle;
      };
      final hid = transport();
      await expectLater(
        hid.open((await hid.enumerate()).single),
        throwsA(
          isA<HidException>().having(
            (e) => e.disconnected,
            'disconnected',
            true,
          ),
        ),
      );
      expect(
        calls
            .where((c) => c.method == 'close')
            .map((c) => (c.arguments as Map<Object?, Object?>)['handle']),
        unorderedEquals([1, 2]),
      );
      expect(calls.where((c) => c.method == 'listen'), isEmpty);
      await hid.dispose();
    });

    test('opens without notifications when listening fails', () async {
      handlers['listen'] = (_) =>
          throw PlatformException(code: 'failed', message: 'no');
      final hid = transport();
      final connection = await hid.open((await hid.enumerate()).single);
      expect(connection.supportsNotifications, isFalse);
      await hid.dispose();
    });
  });
}
