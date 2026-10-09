import 'device_settings.dart';

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.settings,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final DeviceSettings settings;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile copyWith({
    String? name,
    DeviceSettings? settings,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    settings: settings ?? this.settings,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.name == name &&
      other.settings == settings &&
      other.isActive == isActive &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, settings, isActive, createdAt, updatedAt);

  @override
  String toString() => 'Profile($id, $name, active: $isActive)';
}
