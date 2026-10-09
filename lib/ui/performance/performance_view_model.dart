import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/formatting/number_format.dart';
import '../../core/theme/app_icons.dart';
import '../../data/protocol/dpi_codec.dart';
import '../../data/repositories/device_repository.dart';
import '../../domain/device_settings.dart';
import '../../domain/dpi_settings.dart';
import '../../domain/polling_rate.dart';
import '../../domain/rgb_color.dart';
import '../../domain/settings_changes.dart';
import '../shell/edit_session_view_model.dart';
import '../widgets/toast_host.dart';

class PerformanceViewModel extends ChangeNotifier {
  PerformanceViewModel({
    required this._edit,
    required DeviceRepository device,
    required this._toasts,
    this.snapNoteDuration = const Duration(milliseconds: 2600),
    this.flashDuration = const Duration(milliseconds: 1100),
  }) {
    _edit.addListener(_onEdit);
    _stageChanges = device.stageChanges.listen(_onStageChange);
    _onEdit();
  }

  static const dpiTicks = [50, 2500, 5000, 10000, 16000, 24000];
  static const highRangeStart = 10000;

  final EditSessionViewModel _edit;
  final ToastController _toasts;
  final Duration snapNoteDuration;
  final Duration flashDuration;
  late final StreamSubscription<int> _stageChanges;

  int? _selected;
  String? _snapNote;
  Timer? _snapTimer;
  int? _flashStage;
  int _flashSerial = 0;
  Timer? _flashTimer;

  DeviceSettings? get _staged => _edit.staged;

  DeviceSettings? get _saved => _edit.saved;

  bool get hasSettings => _staged != null;

  bool get canEdit => _staged != null && !_edit.writing;

  bool get dirty => _edit.isDirty(SettingsSection.performance);

  List<DpiStage> get stages => _staged?.dpi.stages ?? const [];

  int get activeIndex => _staged?.dpi.activeStageIndex ?? 0;

  int get selectedIndex => _selected ?? activeIndex;

  DpiStage? get selectedStage => _staged == null ? null : stages[selectedIndex];

  int get enabledCount => stages.where((s) => s.enabled).length;

  PollingRate get polling => _staged?.polling ?? PollingRate.factoryDefault;

  bool get angleSnap => _staged?.sensor.angleSnap ?? false;

  bool get ripple => _staged?.sensor.ripple ?? false;

  String? get snapNote => _snapNote;

  int? get flashStage => _flashStage;

  int get flashSerial => _flashSerial;

  bool stageChanged(int index) {
    final saved = _saved;
    final staged = _staged;
    if (saved == null || staged == null) return false;
    return saved.dpi.stages[index] != staged.dpi.stages[index] ||
        (saved.dpi.activeStageIndex == index) !=
            (staged.dpi.activeStageIndex == index);
  }

  bool get pollingChanged =>
      _saved != null && _staged != null && _saved!.polling != _staged!.polling;

  bool get angleSnapChanged =>
      _saved != null &&
      _staged != null &&
      _saved!.sensor.angleSnap != _staged!.sensor.angleSnap;

  bool get rippleChanged =>
      _saved != null &&
      _staged != null &&
      _saved!.sensor.ripple != _staged!.sensor.ripple;

  static int dpiToSliderValue(int dpi) => dpiToRaw(dpi);

  static int sliderValueToDpi(int value) =>
      rawToDpi(value.clamp(minDpiRaw, maxDpiRaw));

  static double sliderFraction(int dpi) =>
      (dpiToRaw(dpi) - minDpiRaw) / (maxDpiRaw - minDpiRaw);

  void selectStage(int index) {
    if (index == _selected) return;
    _selected = index;
    _clearSnapNote();
    notifyListeners();
  }

  void toggleStage(int index) {
    final staged = _staged;
    if (staged == null || !canEdit) return;
    final stage = staged.dpi.stages[index];
    if (stage.enabled && enabledCount == 1) {
      _toasts.show(
        'At least one DPI stage must stay enabled',
        kind: ToastKind.warning,
        icon: AppIconsFill.warning,
      );
      return;
    }
    _stageDpi((dpi) {
      var next = dpi.withStage(index, stage.copyWith(enabled: !stage.enabled));
      if (stage.enabled && dpi.activeStageIndex == index) {
        next = next.copyWith(
          activeStageIndex: next.stages.indexWhere((s) => s.enabled),
        );
      }
      return next;
    });
  }

  void setActive(int index) {
    if (!stages[index].enabled) return;
    _stageDpi((dpi) => dpi.copyWith(activeStageIndex: index));
  }

  void setDpi(int index, int dpi) {
    final value = snapDpi(dpi);
    _stageDpi((s) => s.withStage(index, s.stages[index].copyWith(dpi: value)));
  }

  void stepDpi(int index, int direction) {
    if (_staged == null) return;
    final raw = dpiToRaw(stages[index].dpi) + direction;
    setDpi(index, sliderValueToDpi(raw));
  }

  void commitDpiText(String text) {
    if (_staged == null) return;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final typed = int.parse(digits);
    final snapped = snapDpi(typed);
    setDpi(selectedIndex, snapped);
    if (snapped == typed) {
      _clearSnapNote();
    } else {
      _snapNote = 'Snapped to ${formatThousands(snapped)}';
      _snapTimer?.cancel();
      _snapTimer = Timer(snapNoteDuration, () {
        _snapNote = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void setColor(int index, RgbColor color) => _stageDpi(
    (s) => s.withStage(index, s.stages[index].copyWith(color: color)),
  );

  void setPolling(PollingRate rate) =>
      _edit.stage((s) => s.copyWith(polling: rate));

  void setAngleSnap(bool value) => _edit.stage(
    (s) => s.copyWith(sensor: s.sensor.copyWith(angleSnap: value)),
  );

  void setRipple(bool value) =>
      _edit.stage((s) => s.copyWith(sensor: s.sensor.copyWith(ripple: value)));

  void _stageDpi(DpiSettings Function(DpiSettings dpi) change) =>
      _edit.stage((s) => s.copyWith(dpi: change(s.dpi)));

  void _clearSnapNote() {
    _snapTimer?.cancel();
    _snapNote = null;
  }

  void _onEdit() => notifyListeners();

  void _onStageChange(int index) {
    _flashStage = index;
    _flashSerial++;
    _flashTimer?.cancel();
    _flashTimer = Timer(flashDuration, () {
      _flashStage = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _edit.removeListener(_onEdit);
    unawaited(_stageChanges.cancel());
    _snapTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }
}
