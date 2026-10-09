import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/protocol/macro_report.dart';
import 'package:openx11se/data/protocol/report_format.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/domain/button_assignment.dart';
import 'package:openx11se/domain/macro.dart';
import 'package:openx11se/domain/settings_changes.dart';
import 'package:openx11se/ui/macros/macro_editor_view_model.dart';
import 'package:openx11se/ui/macros/macro_library_view_model.dart';
import 'package:openx11se/ui/shell/dialog_request.dart';
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

const _a = 0x04;
const _ctrl = 0xE0;

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('MacroEditorViewModel', () {
    late MacroEditorViewModel editor;

    setUp(() {
      editor = MacroEditorViewModel(
        Macro(id: 1, name: 'Reload', events: const []),
      );
    });

    void record(List<(int, bool, int)> keys) {
      for (final (usage, down, at) in keys) {
        editor.recordKey(usage, down: down, timestamp: ms(at));
      }
    }

    test('records real delays rounded to 20 ms', () {
      editor.toggleRecording();
      record([(_ctrl, true, 1000), (_a, true, 1093), (_a, false, 1180)]);
      editor.toggleRecording();
      expect(editor.events.map((e) => e.delayMs), [100, 80, 20]);
      expect(editor.events.map((e) => e.code), [_ctrl, _a, _a]);
      expect(editor.events.map((e) => e.action), [
        MacroAction.press,
        MacroAction.press,
        MacroAction.release,
      ]);
      expect(editor.dirty, isTrue);
    });

    test('fixed and no-delay modes', () {
      editor
        ..setDelayMode(RecordDelayMode.fixed)
        ..setFixedDelay(55)
        ..toggleRecording();
      record([(_a, true, 0), (_a, false, 900)]);
      expect(editor.events.first.delayMs, 60);
      editor
        ..toggleRecording()
        ..setDelayMode(RecordDelayMode.none)
        ..clear()
        ..toggleRecording();
      record([(_a, true, 0), (_a, false, 900)]);
      expect(editor.events.map((e) => e.delayMs), [0, 0]);
    });

    test('ignores keys when not recording and non-key usages', () {
      editor.recordKey(_a, down: true, timestamp: Duration.zero);
      expect(editor.isEmpty, isTrue);
      editor
        ..toggleRecording()
        ..recordKey(0x01, down: true, timestamp: Duration.zero);
      expect(editor.isEmpty, isTrue);
    });

    test('insert, capture, toggle, reorder and delete', () {
      editor.addKey();
      final key = editor.rows.single.key;
      expect(editor.capturingRow, key);
      editor.captureKey(0x15);
      expect(editor.events.single.code, 0x15);
      expect(editor.capturingRow, isNull);

      editor
        ..addMouse()
        ..addDelay()
        ..toggleAction(key);
      expect(editor.events.first.action, MacroAction.release);
      expect(editor.events[1].code, MacroMouseCode.left);
      expect(editor.events[2].isDelay, isTrue);

      editor.move(2, 0);
      expect(editor.events.first.isDelay, isTrue);
      editor.remove(editor.rows.first.key);
      expect(editor.rows, hasLength(2));

      editor.startCapture(editor.rows.last.key);
      expect(editor.capturingRow, isNull);
    });

    test('delays clamp and round on commit', () {
      editor.addDelay();
      final key = editor.rows.single.key;
      editor.setDelay(key, 99999);
      expect(editor.events.single.delayMs, macroMaxDelayMs);
      editor
        ..setDelay(key, 1234)
        ..roundDelay(key);
      expect(editor.events.single.delayMs, 1240);
    });

    test('capacity counts long delays and blocks saving', () {
      editor.addKey();
      editor.setDelay(editor.rows.first.key, 1000);
      editor.addDelay();
      expect(editor.isExtended(0), isTrue);
      expect(editor.isExtended(1), isFalse);
      expect(editor.pairs, 2);
      for (var i = 0; i < 49; i++) {
        editor.addMouse();
      }
      expect(editor.pairs, 51);
      expect(editor.overCapacity, isTrue);
      expect(editor.canSave, isFalse);
    });

    test('cancel restores the saved macro', () {
      editor
        ..setName('Other')
        ..addMouse()
        ..cancel();
      expect(editor.dirty, isFalse);
      expect(editor.name, 'Reload');
    });

    test('blank names save as untitled', () {
      editor.setName('   ');
      expect(editor.draft.name, MacroEditorViewModel.untitledName);
    });
  });

  group('MacroLibraryViewModel', () {
    late FakeHidTransport transport;
    late DeviceRepository device;
    late MacroRepository macros;
    late ToastController toasts;
    late EditSessionViewModel edit;
    late MacroLibraryViewModel vm;
    late List<DialogRequest> dialogs;
    var answer = true;

    setUp(() async {
      final db = AppDatabase(sqlite3.openInMemory());
      final profiles = ProfileRepository(db);
      await profiles.ensureDefault();
      macros = MacroRepository(db);
      transport = FakeHidTransport();
      device = DeviceRepository(transport, timing: (_) => instant);
      toasts = ToastController();
      dialogs = [];
      answer = true;
      edit = EditSessionViewModel(
        device: device,
        profiles: profiles,
        macros: macros,
        settings: SettingsRepository(db),
        toasts: toasts,
      );
      vm = MacroLibraryViewModel(
        repository: macros,
        edit: edit,
        toasts: toasts,
        confirm: (request) async {
          dialogs.add(request);
          return answer;
        },
      );
      device.start();
      transport.setPresent([wiredDevice]);
      await until(() => edit.staged != null && vm.loaded);
    });

    tearDown(() async {
      vm.dispose();
      edit.dispose();
      toasts.dispose();
      await device.dispose();
    });

    Future<MacroEditorViewModel> newMacro() async {
      await vm.create();
      return vm.editor!;
    }

    test('creates, searches and selects macros', () async {
      final first = await newMacro();
      expect(first.name, 'New macro 1');
      final second = await newMacro();
      expect(vm.items.map((i) => i.selected), [false, true]);
      vm.setSearch('1');
      expect(vm.items.single.id, first.id);
      vm.setSearch('zzz');
      expect(vm.noResults, isTrue);
      await vm.select(first.id!);
      expect(vm.editor!.id, first.id);
      expect(second.id, isNot(first.id));
    });

    test('guards unsaved edits when switching', () async {
      final first = await newMacro();
      final second = await newMacro();
      second.addMouse();
      answer = false;
      await vm.select(first.id!);
      expect(dialogs.single.title, 'Discard macro changes?');
      expect(vm.editor, same(second));
      answer = true;
      await vm.select(first.id!);
      expect(vm.editor!.id, first.id);
    });

    test('saving an assigned macro marks buttons for upload', () async {
      final editor = await newMacro();
      editor.addMouse();
      await vm.openAssign();
      expect(editor.dirty, isFalse);
      expect(vm.assign!.slot, ButtonSlot.forward);
      vm
        ..setAssignLoopCount(3)
        ..confirmAssign();
      expect(
        edit.staged!.buttons[ButtonSlot.forward],
        MacroButton(
          macroId: editor.id,
          playback: const MacroPlayback(
            mode: MacroPlaybackMode.once,
            loopCount: 3,
          ),
        ),
      );
      expect(vm.assignedTo(editor.id!), ['Forward']);
      await edit.apply();
      expect(edit.hasPending, isFalse);

      final connection = transport.opened.last..sent.clear();
      editor.addDelay();
      await vm.save();
      expect(edit.isDirty(SettingsSection.buttons), isTrue);
      await edit.apply();
      expect(edit.hasPending, isFalse);
      expect(connection.sent.map((w) => w[0]), [
        ReportId.buttons,
        ReportId.macro,
        ReportId.macro,
        ReportId.macro,
      ]);
    });

    test('left click warning in the assign dialog', () async {
      await newMacro();
      await vm.openAssign();
      vm.setAssignSlot(ButtonSlot.left);
      expect(vm.assignLeftWarning, isTrue);
      expect(vm.currentLabel(ButtonSlot.left), 'Left click');
      expect(vm.closeAssign(), isTrue);
      expect(vm.assign, isNull);
    });

    test('deleting resets buttons that used the macro', () async {
      final editor = await newMacro();
      await vm.openAssign();
      vm.confirmAssign();
      await vm.delete();
      expect(dialogs.single.body, contains('Forward'));
      expect(
        edit.staged!.buttons[ButtonSlot.forward],
        factoryButtonAssignments[ButtonSlot.forward],
      );
      expect(await macros.macro(editor.id!), isNull);
      expect(vm.editor, isNull);
    });

    test('blocks saving over capacity', () async {
      final editor = await newMacro();
      for (var i = 0; i <= macroPairLimit; i++) {
        editor.addMouse();
      }
      expect(await vm.save(), isFalse);
      expect(vm.canAssign, isFalse);
    });
  });
}
