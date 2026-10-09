import 'dart:async';
import 'dart:io';

import 'package:openx11se/data/hid/hid_transport_factory.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_state.dart';
import 'package:openx11se/domain/button_assignment.dart';

Future<void> main(List<String> args) async {
  final listenSeconds = args.isEmpty ? 10 : int.parse(args.first);
  final repository = DeviceRepository(createHidTransport());
  final ready = Completer<void>();
  repository.states.listen((state) {
    stdout.writeln('state: $state');
    switch (state) {
      case DeviceReady(:final settings, :final includesButtons):
        if (ready.isCompleted) return;
        final dpi = settings.dpi;
        for (var i = 0; i < dpi.stages.length; i++) {
          final s = dpi.stages[i];
          stdout.writeln(
            '  stage ${i + 1}: ${s.enabled ? 'on ' : 'off'} ${s.dpi} dpi '
            '${s.color}${i == dpi.activeStageIndex ? '  <- active' : ''}',
          );
        }
        stdout
          ..writeln('  sensor: ${settings.sensor}')
          ..writeln('  polling: ${settings.polling}')
          ..writeln('  lighting: ${settings.lighting}')
          ..writeln('  power: ${settings.power}');
        if (includesButtons) {
          for (final (slot, name) in const [
            (ButtonSlot.left, 'left'),
            (ButtonSlot.right, 'right'),
            (ButtonSlot.middle, 'middle'),
            (ButtonSlot.forward, 'forward'),
            (ButtonSlot.back, 'back'),
          ]) {
            stdout.writeln('  button $name: ${settings.buttons[slot]}');
          }
        }
        ready.complete();
      case DeviceFailed():
        if (!ready.isCompleted) ready.completeError(state.error);
      default:
    }
  });
  repository.stageChanges.listen(
    (stage) => stdout.writeln('dpi stage changed: ${stage + 1}'),
  );
  repository.start();
  try {
    await ready.future.timeout(const Duration(seconds: 15));
    stdout.writeln('listening for notifications for ${listenSeconds}s...');
    await Future<void>.delayed(Duration(seconds: listenSeconds));
  } on TimeoutException {
    stderr.writeln('no device found');
    exitCode = 1;
  } on Object catch (e) {
    stderr.writeln('read failed: $e');
    exitCode = 1;
  } finally {
    await repository.dispose();
  }
}
