import 'device_settings.dart';

enum SettingsSection { performance, buttons, lighting, power }

List<SettingsSection> changedFields(DeviceSettings a, DeviceSettings b) {
  final changes = <SettingsSection>[];
  void check(bool differs, SettingsSection section) {
    if (differs) changes.add(section);
  }

  for (var i = 0; i < a.dpi.stages.length; i++) {
    final x = a.dpi.stages[i];
    final y = b.dpi.stages[i];
    check(x.enabled != y.enabled, SettingsSection.performance);
    check(x.dpi != y.dpi, SettingsSection.performance);
    check(x.color != y.color, SettingsSection.performance);
  }
  check(
    a.dpi.activeStageIndex != b.dpi.activeStageIndex,
    SettingsSection.performance,
  );
  check(a.sensor.angleSnap != b.sensor.angleSnap, SettingsSection.performance);
  check(a.sensor.ripple != b.sensor.ripple, SettingsSection.performance);
  check(a.polling != b.polling, SettingsSection.performance);
  for (var slot = 0; slot < a.buttons.length; slot++) {
    check(a.buttons[slot] != b.buttons[slot], SettingsSection.buttons);
  }
  check(a.lighting.mode != b.lighting.mode, SettingsSection.lighting);
  check(a.lighting.color != b.lighting.color, SettingsSection.lighting);
  check(
    a.lighting.brightness != b.lighting.brightness,
    SettingsSection.lighting,
  );
  check(a.lighting.speed != b.lighting.speed, SettingsSection.lighting);
  check(a.power.sleepMinutes != b.power.sleepMinutes, SettingsSection.power);
  check(
    a.power.deepSleepMinutes != b.power.deepSleepMinutes,
    SettingsSection.power,
  );
  check(a.power.debounceMs != b.power.debounceMs, SettingsSection.power);
  return changes;
}
