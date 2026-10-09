import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/protocol/button_report.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/domain/button_assignment.dart';
import 'package:openx11se/domain/keyboard_keys.dart';
import 'package:openx11se/domain/macro.dart';
import 'package:openx11se/domain/settings_changes.dart';
import 'package:openx11se/ui/buttons/buttons_view_model.dart';
import 'package:openx11se/ui/buttons/function_catalog.dart';
import 'package:openx11se/ui/shell/edit_session_view_model.dart';
import 'package:openx11se/ui/widgets/toast_host.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_hid.dart';

const instant = DeviceTiming(
  reportGap: Duration.zero,
  readDelay: Duration.zero,
  ackTimeout: Duration(milliseconds: 20),
);

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

FunctionItem item(ButtonFunctionGroup group, String label) =>
    functionItems[group]!.firstWhere((i) => i.label == label);

void main() {
  group('labels', () {
    test('describe assignments readably', () {
      expect(
        describeAssignment(const FunctionButton(ButtonFunction.volumeUp)),
        'Volume up',
      );
      expect(
        describeAssignment(
          const KeyButton(0x06, modifiers: KeyModifiers(ctrl: true)),
        ),
        'Copy',
      );
      expect(
        describeAssignment(
          const KeyButton(
            0x3D,
            modifiers: KeyModifiers(ctrl: true, shift: true),
          ),
        ),
        'Ctrl + Shift + F4',
      );
      expect(
        describeAssignment(
          const MacroButton(
            macroId: 3,
            playback: MacroPlayback(mode: MacroPlaybackMode.once, loopCount: 3),
          ),
          macroName: (id) => id == 3 ? 'Reload' : null,
        ),
        'Macro: Reload · ×3',
      );
      expect(describeAssignment(const DisabledButton()), 'Disabled');
    });

    test('name keyboard usages', () {
      expect(hidKeyName(0x04), 'A');
      expect(hidKeyName(0x1E), '1');
      expect(hidKeyName(0x27), '0');
      expect(hidKeyName(0x3A), 'F1');
      expect(hidKeyName(0x45), 'F12');
      expect(hidKeyName(0x68), 'F13');
      expect(hidKeyName(0x59), 'Num 1');
      expect(hidKeyName(0x2C), 'Space');
    });

    test('lists every group in the documented order', () {
      expect(
        functionItems[ButtonFunctionGroup.mouse]!.map((i) => i.label).last,
        'Disable button',
      );
      final browser = functionItems[ButtonFunctionGroup.browser]!
          .map((i) => i.label)
          .toList();
      expect(browser.indexOf('Favourites'), browser.indexOf('Search') + 1);
      expect(functionItems[ButtonFunctionGroup.shortcuts], hasLength(16));
      expect(searchFunctions('ctrl + c').map((i) => i.label), contains('Copy'));
    });
  });

  group('view model', () {
    late FakeHidTransport transport;
    late DeviceRepository device;
    late ToastController toasts;
    late MacroRepository macros;
    late EditSessionViewModel edit;
    late ButtonsViewModel vm;

    setUp(() async {
      final db = AppDatabase(sqlite3.openInMemory());
      final profiles = ProfileRepository(db);
      await profiles.ensureDefault();
      macros = MacroRepository(db);
      transport = FakeHidTransport();
      device = DeviceRepository(transport, timing: (_) => instant);
      toasts = ToastController();
      edit = EditSessionViewModel(
        device: device,
        profiles: profiles,
        macros: macros,
        settings: SettingsRepository(db),
        toasts: toasts,
      );
      vm = ButtonsViewModel(edit: edit, macros: macros);
      device.start();
      transport.setPresent([wiredDevice]);
      await until(() => edit.staged != null);
    });

    tearDown(() async {
      vm.dispose();
      edit.dispose();
      toasts.dispose();
      await device.dispose();
    });

    test('shows the device buttons', () {
      expect(vm.mainRows.map((r) => r.label), [
        'Left click',
        'Right click',
        'Middle click',
        'Forward',
        'Back',
      ]);
      expect(vm.advancedRows.map((r) => r.label), [
        'DPI cycle',
        'Scroll up',
        'Scroll down',
      ]);
      expect(vm.anyCustom, isFalse);
      expect(vm.noLeftClick, isFalse);
    });

    test('assigns a function through the picker', () {
      vm.openPicker(ButtonSlot.forward);
      final picker = vm.picker!;
      expect(picker.group, ButtonFunctionGroup.mouse);
      expect(picker.currentLabel, 'Forward');
      picker
        ..selectGroup(ButtonFunctionGroup.media)
        ..pick(item(ButtonFunctionGroup.media, 'Volume up'));
      expect(picker.nextLabel, 'Volume up');
      picker.assign();
      expect(vm.picker, isNull);
      final row = vm.mainRows[3];
      expect(row.label, 'Volume up');
      expect(row.changed, isTrue);
      expect(row.custom, isTrue);
      expect(edit.isDirty(SettingsSection.buttons), isTrue);
      vm.resetButton(ButtonSlot.forward);
      expect(edit.isDirty(SettingsSection.buttons), isFalse);
    });

    test('captures a key with modifiers', () {
      vm.openPicker(ButtonSlot.back);
      final picker = vm.picker!..selectGroup(ButtonFunctionGroup.keyboard);
      expect(picker.showKeyboard, isTrue);
      picker
        ..captureKey(HidUsage.leftCtrl)
        ..captureKey(0x17, held: const KeyModifiers(ctrl: true, shift: true));
      expect(picker.capturedKeyLabel, 'T');
      expect(
        picker.selection,
        const KeyButton(0x17, modifiers: KeyModifiers(ctrl: true, shift: true)),
      );
      picker.toggleModifier(const KeyModifiers(shift: true));
      expect(picker.nextLabel, 'Ctrl + T');
      picker.assign();
      expect(vm.mainRows[4].label, 'Ctrl + T');

      vm.openPicker(ButtonSlot.back);
      expect(vm.picker!.group, ButtonFunctionGroup.keyboard);
      expect(vm.picker!.capturedKeyLabel, 'T');
    });

    test('warns when no button keeps Left click', () {
      vm.openPicker(ButtonSlot.left);
      final picker = vm.picker!..pick(item(ButtonFunctionGroup.mouse, 'Back'));
      expect(picker.leftClickWarning, isTrue);
      picker.assign();
      expect(vm.noLeftClick, isTrue);
      vm.restoreLeftClick();
      expect(vm.noLeftClick, isFalse);
    });

    test('limits macros to buttons that hold one', () async {
      final macro = await macros.create(
        Macro(
          name: 'Reload',
          events: const [
            MacroEvent(
              kind: MacroEventKind.key,
              code: 0x04,
              action: MacroAction.press,
              delayMs: 20,
            ),
          ],
        ),
      );
      await until(() => vm.picker == null && _hasMacro(vm));

      vm.openPicker(ButtonSlot.dpi);
      expect(vm.picker!.macroAllowed, isFalse);
      vm.closePicker();

      vm.openPicker(ButtonSlot.forward);
      final picker = vm.picker!
        ..selectGroup(ButtonFunctionGroup.macro)
        ..selectMacro(macro.id!)
        ..setLoopCount(3);
      expect(picker.nextLabel, 'Macro: Reload · ×3');
      picker.assign();
      expect(vm.mainRows[3].label, 'Macro: Reload · ×3');
    });

    test('reset all keeps hidden slots and applies the full report', () async {
      edit.stage(
        (s) => s
            .withButton(ButtonSlot.forward, const DisabledButton())
            .withButton(
              ButtonSlot.wheelUp,
              const FunctionButton(ButtonFunction.volumeUp),
            )
            .withButton(3, const FunctionButton(ButtonFunction.mute)),
      );
      expect(vm.anyCustom, isTrue);
      vm.resetAll();
      expect(vm.anyCustom, isFalse);
      expect(
        edit.staged!.buttons[3],
        const FunctionButton(ButtonFunction.mute),
      );

      vm.openPicker(ButtonSlot.right);
      vm.picker!
        ..pick(item(ButtonFunctionGroup.shortcuts, 'Copy'))
        ..assign();
      await edit.apply();
      final connection = transport.opened.single;
      final report = connection.sent.lastWhere((r) => r[0] == ReportId.buttons);
      final buttons = decodeButtonReport(report);
      expect(
        buttons[ButtonSlot.right],
        const KeyButton(0x06, modifiers: KeyModifiers(ctrl: true)),
      );
      expect(buttons[3], const FunctionButton(ButtonFunction.mute));
      expect(buttons[ButtonSlot.left], factoryButtonAssignments[0]);
      expect(buttons[ButtonSlot.wheelDown], factoryButtonAssignments[17]);
      expect(report.sublist(6, 9), [0x11, 0x01, 0x06]);
    });
  });
}

bool _hasMacro(ButtonsViewModel vm) {
  vm.openPicker(ButtonSlot.forward);
  final has = vm.picker!.macros.isNotEmpty;
  vm.closePicker();
  return has;
}
