import 'button_assignment.dart';
import 'dpi_settings.dart';
import 'lighting_settings.dart';
import 'list_equality.dart';
import 'polling_rate.dart';
import 'power_settings.dart';

class DeviceSettings {
  DeviceSettings({
    required this.dpi,
    required this.sensor,
    required this.lighting,
    required this.power,
    required this.polling,
    required List<ButtonAssignment> buttons,
  }) : assert(buttons.length == ButtonSlot.count),
       buttons = List.unmodifiable(buttons);

  static final factoryDefaults = DeviceSettings(
    dpi: DpiSettings.factoryDefaults,
    sensor: SensorOptions.factoryDefaults,
    lighting: LightingSettings.factoryDefaults,
    power: PowerSettings.factoryDefaults,
    polling: PollingRate.factoryDefault,
    buttons: factoryButtonAssignments,
  );

  final DpiSettings dpi;
  final SensorOptions sensor;
  final LightingSettings lighting;
  final PowerSettings power;
  final PollingRate polling;
  final List<ButtonAssignment> buttons;

  DeviceSettings copyWith({
    DpiSettings? dpi,
    SensorOptions? sensor,
    LightingSettings? lighting,
    PowerSettings? power,
    PollingRate? polling,
    List<ButtonAssignment>? buttons,
  }) => DeviceSettings(
    dpi: dpi ?? this.dpi,
    sensor: sensor ?? this.sensor,
    lighting: lighting ?? this.lighting,
    power: power ?? this.power,
    polling: polling ?? this.polling,
    buttons: buttons ?? this.buttons,
  );

  DeviceSettings withButton(int slot, ButtonAssignment assignment) =>
      copyWith(buttons: [...buttons]..[slot] = assignment);

  @override
  bool operator ==(Object other) =>
      other is DeviceSettings &&
      other.dpi == dpi &&
      other.sensor == sensor &&
      other.lighting == lighting &&
      other.power == power &&
      other.polling == polling &&
      elementsEqual(other.buttons, buttons);

  @override
  int get hashCode => Object.hash(
    dpi,
    sensor,
    lighting,
    power,
    polling,
    Object.hashAll(buttons),
  );

  @override
  String toString() =>
      'DeviceSettings($dpi, $sensor, $lighting, $power, $polling, $buttons)';
}
