import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/repositories/apply_plan.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_session.dart';
import 'package:openx11se/data/repositories/device_state.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/domain/button_assignment.dart';
import 'package:openx11se/domain/device_info.dart';
import 'package:openx11se/domain/device_settings.dart';
import 'package:openx11se/domain/macro.dart';
import 'package:openx11se/domain/polling_rate.dart';

import '../support/fake_hid.dart';
import '../support/golden_vectors.dart';

const instant = DeviceTiming(
  reportGap: Duration.zero,
  readDelay: Duration.zero,
  ackTimeout: Duration(milliseconds: 20),
);

final defaults = DeviceSettings.factoryDefaults;

final forwardMacro = Macro(
  id: 7,
  name: 'Click',
  events: const [
    MacroEvent(
      kind: MacroEventKind.key,
      code: 0x04,
      action: MacroAction.press,
      delayMs: 10,
    ),
    MacroEvent(
      kind: MacroEventKind.key,
      code: 0x04,
      action: MacroAction.release,
      delayMs: 10,
    ),
  ],
);

Future<DeviceReady> waitReady(DeviceRepository repository) async {
  final state = repository.state;
  if (state is DeviceReady) return state;
  return (await repository.states.firstWhere((s) => s is DeviceReady))
      as DeviceReady;
}

void main() {
  group('DeviceSession', () {
    test('reads version through the busy response', () async {
      final connection = FakeHidConnection(wiredDevice, busyResponses: 2);
      final session = DeviceSession(connection, instant);
      expect(await session.readVersion(), 0x0105);
      expect(connection.sent.single, hex('A0 0B 08 00 01 00 00 00'));
    });

    test('decodes the captured snapshot', () async {
      final session = DeviceSession(FakeHidConnection(wiredDevice), instant);
      final result = await session.readSettings(0x0105);
      expect(result.includesButtons, isTrue);
      expect(result.settings, defaults);
    });

    test('reads individual reports on 0x07xx firmware', () async {
      final connection = FakeHidConnection(wiredDevice, version: 0x0701);
      connection.responses
        ..[ReportId.dpi] = defaultDpiReport
        ..[ReportId.lighting] = hex(
          '05 0F 01 00 03 A8 00 FF 00 01 04 01 AF 00 00',
        )
        ..[ReportId.polling] = hex('06 09 01 01 FE 00 00 00 00');
      final result = await DeviceSession(
        connection,
        instant,
      ).readSettings(0x0701);
      expect(result.includesButtons, isFalse);
      expect(result.settings.dpi, defaults.dpi);
      expect(result.settings.polling, PollingRate.hz1000);
      expect(connection.sent.map((r) => r[1]).toList(), [
        ReportId.polling,
        ReportId.lighting,
        ReportId.dpi,
      ]);
    });

    test('fails when the device never answers', () async {
      final connection = FakeHidConnection(wiredDevice, busyResponses: 1000);
      expect(
        DeviceSession(connection, instant).readVersion(),
        throwsA(isA<DeviceReadException>()),
      );
    });

    test('skips a stale reply with a matching header', () async {
      final connection = FakeHidConnection(wiredDevice);
      final stale = Uint8List.fromList(defaultSnapshot)..[2] = 0x00;
      connection.staleResponses.add(stale);
      final result = await DeviceSession(
        connection,
        instant,
      ).readSettings(0x0105);
      expect(result.settings, defaults);
    });

    test('flags an echoed request as no response', () async {
      final connection = FakeHidConnection(dongleDevice)..asleep = true;
      expect(
        DeviceSession(connection, instant).readVersion(),
        throwsA(
          isA<DeviceReadException>().having(
            (e) => e.noResponse,
            'noResponse',
            isTrue,
          ),
        ),
      );
    });

    test('waits for acknowledgements', () async {
      final connection = FakeHidConnection(wiredDevice);
      final progress = <int>[];
      await DeviceSession(connection, instant).apply(
        planApply(
          previous: null,
          next: defaults,
          connection: ConnectionType.wired,
        ),
        onProgress: (done, _, _) => progress.add(done),
      );
      expect(connection.writtenReportIds, [0x04, 0x05, 0x06, 0x08]);
      expect(progress, [0, 1, 2, 3, 4]);
    });

    test('retries then reports a missing acknowledgement', () async {
      final connection = FakeHidConnection(wiredDevice, autoAck: false);
      await expectLater(
        DeviceSession(connection, instant).apply([
          OutgoingReport(ReportId.polling, [hex('06 09 01 01 FE 00 00 00 00')]),
        ]),
        throwsA(
          isA<DeviceWriteException>().having(
            (e) => e.failure,
            'failure',
            DeviceWriteFailure.noAcknowledgement,
          ),
        ),
      );
      expect(connection.writtenReportIds, [0x06, 0x06, 0x06]);
    });

    test('falls back to timing without a notification channel', () async {
      final connection = FakeHidConnection(
        wiredDevice,
        supportsNotifications: false,
        autoAck: false,
      );
      await DeviceSession(connection, instant).apply([
        OutgoingReport(ReportId.polling, [hex('06 09 01 01 FE 00 00 00 00')]),
      ]);
      expect(connection.writtenReportIds, [0x06]);
    });

    test('reports disconnection as a typed write error', () async {
      final connection = FakeHidConnection(wiredDevice)..isClosed = true;
      expect(
        DeviceSession(connection, instant).apply([
          OutgoingReport(ReportId.polling, [hex('06 09 01 01 FE 00 00 00 00')]),
        ]),
        throwsA(
          isA<DeviceWriteException>().having(
            (e) => e.failure,
            'failure',
            DeviceWriteFailure.disconnected,
          ),
        ),
      );
    });
  });

  group('planApply', () {
    List<int> ids(List<OutgoingReport> reports) =>
        reports.map((r) => r.reportId).toList();

    test('sends nothing when unchanged', () {
      expect(
        planApply(
          previous: defaults,
          next: defaults,
          connection: ConnectionType.wired,
        ),
        isEmpty,
      );
    });

    test('sends only changed sections', () {
      final next = defaults.copyWith(polling: PollingRate.hz500);
      final reports = planApply(
        previous: defaults,
        next: next,
        connection: ConnectionType.wired,
      );
      expect(ids(reports), [ReportId.polling]);
      expect(reports.single.chunks.single, hex('06 09 01 02 FD 00 00 00 00'));
    });

    test('power changes resend the lighting report', () {
      final next = defaults.copyWith(
        power: defaults.power.copyWith(sleepMinutes: 5),
      );
      expect(
        ids(
          planApply(
            previous: defaults,
            next: next,
            connection: ConnectionType.wired,
          ),
        ),
        [ReportId.lighting],
      );
    });

    test('restore sends 0x0C then every section in order', () {
      final reports = planApply(
        previous: defaults,
        next: defaults,
        connection: ConnectionType.wired,
        restoreDefaults: true,
      );
      expect(ids(reports), [0x0C, 0x04, 0x05, 0x06, 0x08]);
      expect(reports.first.expectAck, isFalse);
      expect(reports[1].chunks.single, defaultDpiReport);
    });

    test('macro assignment sends 0x08 then three 0x09 chunks', () {
      const playback = MacroPlayback(
        mode: MacroPlaybackMode.once,
        loopCount: 3,
      );
      final next = defaults.withButton(
        ButtonSlot.forward,
        const MacroButton(macroId: 7, playback: playback),
      );
      final reports = planApply(
        previous: defaults,
        next: next,
        connection: ConnectionType.dongle,
        macros: {7: forwardMacro},
      );
      expect(ids(reports), [ReportId.buttons, ReportId.macro]);
      final chunks = reports.last.chunks;
      expect(chunks, hasLength(3));
      expect(chunks.map((c) => c.sublist(0, 4)).toList(), [
        hex('09 40 0D 00'),
        hex('09 40 0D 01'),
        hex('09 0C 0D 02'),
      ]);
    });

    test('edited macro content is resent without a button change', () {
      final assigned = defaults.withButton(
        ButtonSlot.forward,
        const MacroButton(macroId: 7),
      );
      final reports = planApply(
        previous: assigned,
        next: assigned,
        connection: ConnectionType.wired,
        macros: {7: forwardMacro},
        changedMacroIds: {7},
      );
      expect(ids(reports), [ReportId.macro]);
    });
  });

  group('DeviceRepository', () {
    late FakeHidTransport transport;
    late DeviceRepository repository;

    setUp(() {
      transport = FakeHidTransport();
      repository = DeviceRepository(
        transport,
        timing: (_) => instant,
        wakeRetryInterval: const Duration(milliseconds: 10),
      );
    });

    tearDown(() => repository.dispose());

    test('connects and reads the device', () async {
      repository.start();
      transport.setPresent([wiredDevice]);
      final ready = await waitReady(repository);
      expect(ready.info.connection, ConnectionType.wired);
      expect(ready.info.firmwareVersion, 0x0105);
      expect(ready.settings, defaults);
    });

    test('prefers the cable over the dongle', () async {
      repository.start();
      transport.setPresent([dongleDevice]);
      await waitReady(repository);
      transport.setPresent([dongleDevice, wiredDevice]);
      await repository.states.firstWhere(
        (s) => s is DeviceReady && s.device == wiredDevice,
      );
      expect(transport.opened.first.isClosed, isTrue);
    });

    test('battery and DPI stage notifications update live', () async {
      repository.start();
      transport.setPresent([dongleDevice]);
      await waitReady(repository);
      final stages = <int>[];
      final sub = repository.stageChanges.listen(stages.add);
      final connection = transport.opened.single;
      connection
        ..notify('03 07 40 01 57')
        ..notify('03 07 10 04 00');
      await pumpEventQueue();
      final ready = repository.state as DeviceReady;
      expect(ready.info.batteryPercent, 0x57);
      expect(ready.info.chargeState, ChargeState.discharging);
      expect(ready.settings.dpi.activeStageIndex, 3);
      expect(stages, [3]);
      await sub.cancel();
    });

    test('unplugging returns to absent', () async {
      repository.start();
      transport.setPresent([wiredDevice]);
      await waitReady(repository);
      transport.setPresent(const []);
      await repository.states.firstWhere((s) => s is DeviceAbsent);
      expect(transport.opened.single.isClosed, isTrue);
    });

    test('apply sends changed reports and updates the device state', () async {
      repository.start();
      transport.setPresent([wiredDevice]);
      await waitReady(repository);
      final next = defaults.copyWith(polling: PollingRate.hz500);
      await repository.apply(next);
      expect(transport.opened.single.writtenReportIds, [ReportId.polling]);
      expect((repository.state as DeviceReady).settings, next);
    });

    test('a sleeping mouse is not polled until it sends a report', () async {
      final connection = FakeHidConnection(dongleDevice)..asleep = true;
      transport.factories['dongle'] = () => connection;
      repository.start();
      transport.setPresent([dongleDevice]);
      await repository.states.firstWhere((s) => s is DeviceAsleep);
      final sentWhileAsleep = connection.sent.length;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(connection.sent.length, sentWhileAsleep);
      expect(repository.state, isA<DeviceAsleep>());
    });

    test(
      'without a notification channel a sleeping mouse is retried',
      () async {
        final connection = FakeHidConnection(
          dongleDevice,
          supportsNotifications: false,
        )..asleep = true;
        transport.factories['dongle'] = () => connection;
        repository.start();
        transport.setPresent([dongleDevice]);
        await repository.states.firstWhere((s) => s is DeviceAsleep);
        connection.asleep = false;
        final ready = await waitReady(repository);
        expect(ready.settings, defaults);
      },
    );

    test('a battery report wakes the read immediately', () async {
      final connection = FakeHidConnection(dongleDevice)..asleep = true;
      transport.factories['dongle'] = () => connection;
      repository = DeviceRepository(
        transport,
        timing: (_) => instant,
        wakeRetryInterval: const Duration(hours: 1),
      );
      repository.start();
      transport.setPresent([dongleDevice]);
      await repository.states.firstWhere((s) => s is DeviceAsleep);
      connection.asleep = false;
      connection.notify('03 07 40 01 63');
      final ready = await waitReady(repository);
      expect(ready.info.batteryPercent, 0x63);
    });

    test('read failure surfaces as a failed state', () async {
      transport.factories['wired'] = () =>
          FakeHidConnection(wiredDevice, busyResponses: 1000);
      repository.start();
      transport.setPresent([wiredDevice]);
      final failed = await repository.states.firstWhere(
        (s) => s is DeviceFailed,
      );
      expect((failed as DeviceFailed).error, isA<DeviceReadException>());
    });
  });
}
