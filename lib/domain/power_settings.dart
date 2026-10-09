class PowerSettings {
  const PowerSettings({
    required this.sleepMinutes,
    required this.deepSleepMinutes,
    required this.debounceMs,
  });

  static const minMinutes = 1;
  static const maxMinutes = 60;
  static const minDebounceMs = 4;
  static const maxDebounceMs = 50;
  static const debounceStepMs = 2;

  static const factoryDefaults = PowerSettings(
    sleepMinutes: 1,
    deepSleepMinutes: 10,
    debounceMs: 8,
  );

  final int sleepMinutes;
  final int deepSleepMinutes;
  final int debounceMs;

  PowerSettings copyWith({
    int? sleepMinutes,
    int? deepSleepMinutes,
    int? debounceMs,
  }) => PowerSettings(
    sleepMinutes: sleepMinutes ?? this.sleepMinutes,
    deepSleepMinutes: deepSleepMinutes ?? this.deepSleepMinutes,
    debounceMs: debounceMs ?? this.debounceMs,
  );

  @override
  bool operator ==(Object other) =>
      other is PowerSettings &&
      other.sleepMinutes == sleepMinutes &&
      other.deepSleepMinutes == deepSleepMinutes &&
      other.debounceMs == debounceMs;

  @override
  int get hashCode => Object.hash(sleepMinutes, deepSleepMinutes, debounceMs);

  @override
  String toString() =>
      'PowerSettings(sleep: $sleepMinutes, deepSleep: $deepSleepMinutes, '
      'debounce: $debounceMs)';
}
