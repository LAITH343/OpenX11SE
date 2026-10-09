import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/protocol/button_report.dart';
import 'package:openx11se/data/protocol/device_reads.dart';
import 'package:openx11se/data/protocol/dpi_codec.dart';
import 'package:openx11se/data/protocol/dpi_report.dart';
import 'package:openx11se/data/protocol/lighting_report.dart';
import 'package:openx11se/data/protocol/macro_report.dart';
import 'package:openx11se/data/protocol/notifications.dart';
import 'package:openx11se/data/protocol/polling_report.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/protocol/snapshot.dart';
import 'package:openx11se/domain/button_assignment.dart';
import 'package:openx11se/domain/device_info.dart';
import 'package:openx11se/domain/device_settings.dart';
import 'package:openx11se/domain/dpi_settings.dart';
import 'package:openx11se/domain/lighting_settings.dart';
import 'package:openx11se/domain/macro.dart';
import 'package:openx11se/domain/polling_rate.dart';
import 'package:openx11se/domain/power_settings.dart';
import 'package:openx11se/domain/rgb_color.dart';

import '../support/golden_vectors.dart';

final defaults = DeviceSettings.factoryDefaults;

LightingSettings light(LightingMode mode, int rgb, {int brightness = 8}) =>
    LightingSettings(
      mode: mode,
      color: RgbColor.hex(rgb),
      brightness: brightness,
      speed: 6,
    );

void main() {
  group('DPI codec', () {
    test('confirmed codes', () {
      final cases = {
        800: (0x12, false, false),
        1600: (0x25, false, false),
        2400: (0x38, false, false),
        3200: (0x4B, false, false),
        5000: (0x75, false, false),
        22000: (0x81, true, true),
      };
      cases.forEach((dpi, expected) {
        final c = encodeDpiRaw(dpiToRaw(dpi));
        expect((c.code, c.flag, c.highRange), expected, reason: '$dpi');
      });
    });

    test('dpi and raw convert both ways', () {
      expect(dpiToRaw(50), 1);
      expect(dpiToRaw(10000), 200);
      expect(dpiToRaw(10100), 201);
      expect(dpiToRaw(24000), 340);
      expect(rawToDpi(320), 22000);
      for (var raw = minDpiRaw; raw <= maxDpiRaw; raw++) {
        expect(dpiToRaw(rawToDpi(raw)), raw);
      }
    });

    test('snaps to valid steps', () {
      expect(snapDpi(0), 50);
      expect(snapDpi(824), 800);
      expect(snapDpi(826), 850);
      expect(snapDpi(10049), 10000);
      expect(snapDpi(10051), 10100);
      expect(snapDpi(15549), 15500);
      expect(snapDpi(99999), 24000);
    });

    test('every raw value decodes back', () {
      for (var raw = minDpiRaw; raw <= maxDpiRaw; raw++) {
        final decoded = decodeDpiRaw(encodeDpiRaw(raw));
        if (raw <= 300) {
          expect(decoded, raw);
        } else {
          expect(encodeDpiRaw(decoded), encodeDpiRaw(raw));
        }
      }
    });
  });

  group('Report 0x04', () {
    test('factory defaults match capture', () {
      expect(encodeDpiReport(defaults.dpi, defaults.sensor), defaultDpiReport);
    });

    test('decodes capture', () {
      final r = decodeDpiReport(defaultDpiReport);
      expect(r.dpi, DpiSettings.factoryDefaults);
      expect(r.sensor, SensorOptions.factoryDefaults);
    });

    test('round-trips edited values', () {
      final dpi = defaults.dpi
          .withStage(
            0,
            const DpiStage(
              enabled: true,
              dpi: 12000,
              color: RgbColor.hex(0x123456),
            ),
          )
          .withStage(
            6,
            const DpiStage(
              enabled: true,
              dpi: 15000,
              color: RgbColor.hex(0xABCDEF),
            ),
          )
          .copyWith(activeStageIndex: 6);
      const sensor = SensorOptions(angleSnap: true, ripple: false);
      final r = decodeDpiReport(encodeDpiReport(dpi, sensor));
      expect(r.dpi, dpi);
      expect(r.sensor, sensor);
    });

    test('rejects bad checksum', () {
      final bad = Uint8List.fromList(defaultDpiReport)..[51] ^= 1;
      expect(() => decodeDpiReport(bad), throwsA(isA<ProtocolException>()));
    });
  });

  group('Report 0x05', () {
    const power = PowerSettings.factoryDefaults;
    final cases = {
      '05 0F 01 10 03 A8 FF 00 00 01 04 01 BF 00 00': light(
        LightingMode.staticColor,
        0xFF0000,
      ),
      '05 0F 01 10 03 A2 FF 00 00 01 04 01 B9 00 00': light(
        LightingMode.staticColor,
        0xFF0000,
        brightness: 2,
      ),
      '05 0F 01 20 03 A8 00 00 FF 01 04 01 CF 00 00': light(
        LightingMode.breathing,
        0x0000FF,
      ),
      '05 0F 01 30 03 A8 FF 00 00 01 04 01 DF 00 00': light(
        LightingMode.neon,
        0xFF0000,
      ),
      '05 0F 01 50 03 A8 FF 00 00 01 04 01 FF 00 00': light(
        LightingMode.staticDpi,
        0xFF0000,
      ),
      '05 0F 01 00 03 A8 00 FF 00 01 04 01 AF 00 00':
          LightingSettings.factoryDefaults,
    };

    cases.forEach((bytes, lighting) {
      test('encodes ${lighting.mode.name} ${lighting.brightness}', () {
        expect(encodeLightingReport(lighting, power), hex(bytes));
      });
      test('decodes ${lighting.mode.name} ${lighting.brightness}', () {
        final r = decodeLightingReport(hex(bytes));
        expect(r.lighting, lighting);
        expect(r.power, power);
      });
    });

    test('brightness only encoded for static modes', () {
      final r = encodeLightingReport(
        light(LightingMode.breathing, 0xFF0000, brightness: 2),
        power,
      );
      expect(r[5] & 0x0F, 8);
    });

    test('round-trips power and speed', () {
      const lighting = LightingSettings(
        mode: LightingMode.breathingDpi,
        color: RgbColor.hex(0x102030),
        brightness: 8,
        speed: 1,
      );
      const p = PowerSettings(
        sleepMinutes: 60,
        deepSleepMinutes: 47,
        debounceMs: 50,
      );
      final r = decodeLightingReport(encodeLightingReport(lighting, p));
      expect(r.lighting, lighting);
      expect(r.power, p);
    });
  });

  group('Report 0x06', () {
    test('matches captures', () {
      expect(
        encodePollingReport(PollingRate.hz500),
        hex('06 09 01 02 FD 00 00 00 00'),
      );
      expect(
        encodePollingReport(PollingRate.hz1000),
        hex('06 09 01 01 FE 00 00 00 00'),
      );
    });

    test('round-trips', () {
      for (final rate in PollingRate.values) {
        expect(decodePollingReport(encodePollingReport(rate)), rate);
      }
    });
  });

  group('Report 0x08', () {
    final forwardMacro = hex(
      '08 3B 01 02 00 00 03 00 00 04 00 00 01 00 00 01 00 00 0D 00 00 12 00 0D 05 00 00 '
      '01 00 00 01 00 00 01 00 00 01 00 00 01 00 00 01 00 00 01 00 00 01 00 00 '
      '09 00 00 0A 00 00 00 57',
    );

    test('macro on Forward', () {
      final buttons = defaults
          .withButton(ButtonSlot.forward, const MacroButton(macroId: 7))
          .buttons;
      expect(encodeButtonReport(buttons), forwardMacro);
    });

    test('decodes macro entry', () {
      final buttons = decodeButtonReport(forwardMacro);
      expect(buttons[ButtonSlot.forward], isA<MacroButton>());
      expect(
        buttons[ButtonSlot.left],
        const FunctionButton(ButtonFunction.leftClick),
      );
      expect(
        buttons[ButtonSlot.dpi],
        const FunctionButton(ButtonFunction.dpiCycle),
      );
      expect(buttons[3], const DisabledButton());
    });

    test('shortcut entries', () {
      final cut = buttonShortcuts.firstWhere((s) => s.label == 'Cut').key;
      final capture = buttonShortcuts
          .firstWhere((s) => s.label == 'Screen capture')
          .key;
      final lock = buttonShortcuts.firstWhere((s) => s.label == 'Lock PC').key;
      expect(encodeButtonEntry(0, cut), (0x11, 0x01, 0x1B));
      expect(encodeButtonEntry(0, capture), (0x11, 0x0A, 0x16));
      expect(encodeButtonEntry(0, lock), (0x11, 0x08, 0x0F));
    });

    test('every function and shortcut round-trips', () {
      for (final f in ButtonFunction.values) {
        final (b0, b1, b2) = encodeButtonEntry(0, FunctionButton(f));
        expect(decodeButtonEntry(b0, b1, b2), FunctionButton(f));
      }
      for (final s in buttonShortcuts) {
        final (b0, b1, b2) = encodeButtonEntry(0, s.key);
        expect(decodeButtonEntry(b0, b1, b2), s.key);
      }
      expect(decodeButtonEntry(0x13, 0, 0), const UnmappedButton(0x13, 0, 0));
      expect(encodeButtonEntry(0, const UnmappedButton(0x13, 0, 0)), (
        0x13,
        0,
        0,
      ));
    });

    test('macro slot ids', () {
      expect([0, 1, 2, 6, 7].map(macroSlotId), [1, 5, 9, 13, 17]);
      expect(
        () => encodeButtonEntry(ButtonSlot.dpi, const MacroButton()),
        throwsArgumentError,
      );
    });
  });

  group('Report 0x09', () {
    const events = [
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
      MacroEvent(
        kind: MacroEventKind.mouse,
        code: MacroMouseCode.left,
        action: MacroAction.press,
        delayMs: 2000,
      ),
      MacroEvent(
        kind: MacroEventKind.mouse,
        code: MacroMouseCode.left,
        action: MacroAction.release,
        delayMs: 10,
      ),
    ];
    const playback = MacroPlayback(mode: MacroPlaybackMode.once, loopCount: 3);
    final body = Uint8List(ReportLength.macroBody)
      ..setAll(0, [0x09, 0x83, 0x0D, 0x00, 0x00, 0x00, 0x00, 0x03])
      ..[28] = 0x05
      ..setAll(29, hex('01 04 81 04 01 F1 0A 03 81 F1'))
      ..setAll(129, [0x03, 0x03]);

    test('capacity counts extended delays', () {
      expect(macroPairCount(events), 5);
      expect(macroPairsLeft(events), 45);
      expect(fitsMacroCapacity(List.filled(50, events[0])), isTrue);
      expect(fitsMacroCapacity(List.filled(26, events[2])), isFalse);
    });

    test('captured macro body', () {
      expect(encodeMacroBody(0x0D, events, playback), body);
    });

    test('wired chunks', () {
      final chunks = encodeMacroReports(
        0x0D,
        events,
        playback,
        connection: ConnectionType.wired,
      );
      expect(chunks, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(chunks[i], hasLength(64));
        expect(chunks[i].sublist(0, 4), [0x09, 0x40, 0x0D, i]);
      }
      expect(chunks[0].sublist(4), body.sublist(3, 63));
      expect(chunks[1].sublist(4), body.sublist(63, 123));
      expect(chunks[2].sublist(4, 12), body.sublist(123, 131));
      expect(chunks[2].sublist(12).every((b) => b == 0), isTrue);
    });

    test('wireless last chunk length', () {
      final chunks = encodeMacroReports(
        0x0D,
        events,
        playback,
        connection: ConnectionType.dongle,
      );
      expect(chunks.map((c) => c[1]), [0x40, 0x40, 0x0C]);
    });

    test('release flag and rounding', () {
      expect(
        encodeMacroEvent(
          const MacroEvent(
            kind: MacroEventKind.key,
            code: 4,
            action: MacroAction.release,
            delayMs: 1270,
          ),
        ),
        [0xFF, 4],
      );
      expect(
        encodeMacroEvent(
          const MacroEvent(
            kind: MacroEventKind.key,
            code: 4,
            action: MacroAction.press,
            delayMs: 1300,
          ),
        ),
        [0x0B, 4, 6, 3],
      );
    });

    test('rejects overflow', () {
      expect(
        () => encodeMacroBody(1, List.filled(51, events[0]), playback),
        throwsArgumentError,
      );
    });
  });

  group('Reads', () {
    test('request bytes', () {
      expect(versionReadRequest(), hex('A0 0B 08 00 01 00 00 00'));
      expect(snapshotReadRequest(), hex('A0 0A 80 00 01 00 00 00'));
      expect(dpiReadRequest(), hex('A0 04 38 00 01 00 00 00'));
      expect(lightingReadRequest(), hex('A0 05 0F 00 01 00 00 00'));
      expect(pollingReadRequest(), hex('A0 06 09 00 01 00 00 00'));
    });

    test('version and busy', () {
      expect(isBusyResponse(hex('A0 01 00 00 00 00 00 00')), isTrue);
      expect(isBusyResponse(hex('0B 08 01 05 00 00 00 00')), isFalse);
      expect(decodeVersion(hex('0B 08 01 05 00 00 00 00')), 0x0105);
      expect(usesIndividualReads(0x0105), isFalse);
      expect(usesIndividualReads(0x0712), isTrue);
    });

    test('restore defaults', () {
      expect(
        encodeRestoreDefaultsReport(),
        hex('0C 0A 01 FE 01 FE 00 00 00 00'),
      );
    });
  });

  group('Snapshot 0x0A', () {
    test('decodes factory defaults', () {
      final s = decodeSnapshot(defaultSnapshot);
      expect(s, defaults);
      expect(s.dpi.activeStageIndex, 2);
      expect(s.polling, PollingRate.hz1000);
    });

    test('re-encodes to captured writes', () {
      final s = decodeSnapshot(defaultSnapshot);
      expect(encodeDpiReport(s.dpi, s.sensor), defaultDpiReport);
      expect(
        encodeLightingReport(s.lighting, s.power),
        hex('05 0F 01 00 03 A8 00 FF 00 01 04 01 AF 00 00'),
      );
      expect(encodePollingReport(s.polling), hex('06 09 01 01 FE 00 00 00 00'));
    });

    test('rejects bad checksum', () {
      final bad = Uint8List.fromList(defaultSnapshot)..[63] ^= 1;
      expect(() => decodeSnapshot(bad), throwsA(isA<ProtocolException>()));
    });
  });

  group('Settings round-trip', () {
    test('all reports', () {
      final edited = defaults.copyWith(
        dpi: defaults.dpi.withStage(
          3,
          const DpiStage(
            enabled: false,
            dpi: 20200,
            color: RgbColor.hex(0x010203),
          ),
        ),
        sensor: const SensorOptions(angleSnap: true, ripple: true),
        lighting: light(LightingMode.staticDpi, 0x8B6CFF, brightness: 3),
        power: const PowerSettings(
          sleepMinutes: 5,
          deepSleepMinutes: 30,
          debounceMs: 12,
        ),
        polling: PollingRate.hz250,
        buttons: [...defaults.buttons]
          ..[ButtonSlot.back] = const KeyButton(
            0x06,
            modifiers: KeyModifiers(ctrl: true),
          )
          ..[ButtonSlot.wheelUp] = const FunctionButton(
            ButtonFunction.volumeUp,
          ),
      );
      final dpi = decodeDpiReport(encodeDpiReport(edited.dpi, edited.sensor));
      final lighting = decodeLightingReport(
        encodeLightingReport(edited.lighting, edited.power),
      );
      final decoded = DeviceSettings(
        dpi: dpi.dpi,
        sensor: dpi.sensor,
        lighting: lighting.lighting,
        power: lighting.power,
        polling: decodePollingReport(encodePollingReport(edited.polling)),
        buttons: decodeButtonReport(encodeButtonReport(edited.buttons)),
      );
      expect(decoded, edited);
    });
  });

  group('Notifications', () {
    test('battery', () {
      expect(
        decodeNotification(hex('03 07 40 01 64')),
        const BatteryNotification(
          percent: 100,
          chargeState: ChargeState.discharging,
        ),
      );
      expect(
        decodeNotification(hex('03 07 40 03 4C')),
        const BatteryNotification(
          percent: 76,
          chargeState: ChargeState.charging,
        ),
      );
      expect(
        decodeNotification(hex('03 07 40 03 64')),
        const BatteryNotification(
          percent: 100,
          chargeState: ChargeState.charging,
        ),
      );
      expect(
        decodeNotification(hex('03 07 40 02 64')),
        const BatteryNotification(
          percent: 100,
          chargeState: ChargeState.charged,
        ),
      );
    });

    test('ack and DPI stage', () {
      expect(
        decodeNotification(hex('03 07 50 00 05')),
        const WriteAckNotification(0x05),
      );
      expect(
        decodeNotification(hex('03 07 10 04 00')),
        const DpiStageNotification(3),
      );
      expect(
        decodeNotification(hex('03 07 10 05 00')),
        const DpiStageNotification(4),
      );
    });

    test('ignores unknown', () {
      expect(decodeNotification(hex('03 55 40 01 64')), isNull);
      expect(decodeNotification(hex('03 07 99 00 00')), isNull);
      expect(decodeNotification(hex('03 07')), isNull);
    });
  });
}
