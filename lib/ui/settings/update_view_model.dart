import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/theme/app_icons.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/update/update_repository.dart';
import '../../domain/app_settings.dart';
import '../../domain/app_version.dart';
import '../shell/edit_session_view_model.dart';
import '../widgets/toast_host.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  ready,
  installing,
  failed,
}

enum _Step { check, download, install }

class UpdateViewModel extends ChangeNotifier {
  UpdateViewModel({
    required this._repository,
    required this._settings,
    required this._edit,
    required this._toasts,
    required this.currentVersion,
    required this._quit,
    AppSettings initial = AppSettings.defaults,
    DateTime Function()? now,
    this.checkInterval = const Duration(days: 1),
  }) : _appSettings = initial,
       _now = now ?? DateTime.now {
    _edit.addListener(_onEdit);
    _subscription = _settings.watchSettings().listen(
      _onSettings,
      onError: (_) {},
    );
  }

  final UpdateRepository _repository;
  final SettingsRepository _settings;
  final EditSessionViewModel _edit;
  final ToastController _toasts;
  final Future<void> Function() _quit;
  final DateTime Function() _now;
  final AppVersion currentVersion;
  final Duration checkInterval;
  late final StreamSubscription<AppSettings> _subscription;

  AppSettings _appSettings;
  UpdateStatus _status = UpdateStatus.idle;
  AppRelease? _release;
  String? _installerPath;
  int _received = 0;
  int? _total;
  UpdateErrorKind? _error;
  DateTime? _retryAt;
  _Step _failedStep = _Step.check;
  bool _dialogOpen = false;
  bool _writing = false;
  bool _hasPending = false;
  bool _disposed = false;

  bool get isSupported => _repository.isSupported;

  UpdateStatus get status => _status;

  AppRelease? get release => _release;

  bool get dialogOpen => _dialogOpen;

  bool get autoCheck => _appSettings.autoCheckUpdates;

  DateTime? get lastCheck => _appSettings.lastUpdateCheck;

  UpdateErrorKind? get error => _error;

  int get received => _received;

  int? get total => _total;

  double? get progress {
    final total = _total;
    if (total == null || total <= 0) return null;
    return (_received / total).clamp(0, 1);
  }

  bool get busy =>
      _status == UpdateStatus.checking ||
      _status == UpdateStatus.downloading ||
      _status == UpdateStatus.installing;

  bool get writeInProgress => _edit.writing;

  bool get hasUnappliedEdits => _edit.hasPending;

  bool get canInstall => _status == UpdateStatus.ready && !_edit.writing;

  String get versionLabel => 'Version $currentVersion';

  String get statusText => switch (_status) {
    UpdateStatus.idle => versionLabel,
    UpdateStatus.checking => 'Checking for updates…',
    UpdateStatus.upToDate => 'Version $currentVersion · up to date',
    UpdateStatus.available => 'Version ${_release!.version} is available',
    UpdateStatus.downloading => 'Downloading version ${_release!.version}…',
    UpdateStatus.ready => 'Version ${_release!.version} is ready to install',
    UpdateStatus.installing => 'Starting the installer…',
    UpdateStatus.failed => errorText ?? versionLabel,
  };

  String? get errorText {
    final error = _error;
    if (error == null) return null;
    return switch (error) {
      UpdateErrorKind.offline =>
        'Couldn’t reach GitHub. Check your connection and try again.',
      UpdateErrorKind.rateLimited => switch (_retryAt) {
        final DateTime at =>
          'GitHub is limiting update checks. Try again after '
              '${_clock(at.toLocal())}.',
        null => 'GitHub is limiting update checks. Try again later.',
      },
      UpdateErrorKind.malformedResponse =>
        'GitHub returned an unexpected response. Try again later.',
      UpdateErrorKind.serverError =>
        'GitHub couldn’t answer right now. Try again later.',
      UpdateErrorKind.noInstaller =>
        'The latest release has no Windows installer yet.',
      UpdateErrorKind.checksumMissing =>
        'The release has no checksum, so the installer can’t be verified.',
      UpdateErrorKind.checksumMismatch =>
        'The downloaded installer failed verification and was deleted. '
            'Nothing was installed.',
      UpdateErrorKind.downloadFailed =>
        'The download didn’t complete. Try again.',
      UpdateErrorKind.storageFailed =>
        'The installer couldn’t be saved to the temp folder.',
      UpdateErrorKind.launchFailed => 'The installer couldn’t be started.',
    };
  }

  void openDialog() {
    if (_dialogOpen || _release == null) return;
    _dialogOpen = true;
    notifyListeners();
  }

  bool closeDialog() {
    if (!_dialogOpen) return false;
    _dialogOpen = false;
    notifyListeners();
    return true;
  }

  Future<void> setAutoCheck(bool value) async {
    if (value == autoCheck) return;
    _onSettings(_appSettings.copyWith(autoCheckUpdates: value));
    try {
      await _settings.update((s) => s.copyWith(autoCheckUpdates: value));
    } on Object {
      return;
    }
  }

  Future<void> checkOnStartup() async {
    if (!isSupported || !autoCheck || busy) return;
    final last = lastCheck;
    if (last != null && _now().difference(last) < checkInterval) return;
    await _check(silent: true);
  }

  Future<void> checkNow() async {
    if (!isSupported || busy) return;
    await _check(silent: false);
  }

  Future<void> retry() => switch (_failedStep) {
    _Step.check => checkNow(),
    _Step.download => download(),
    _Step.install => install(),
  };

  Future<void> download() async {
    final release = _release;
    if (release == null || busy) return;
    _set(UpdateStatus.downloading, received: 0, total: release.installer.size);
    final result = await _repository.download(
      release,
      onProgress: (received, total) {
        if (_disposed || _status != UpdateStatus.downloading) return;
        _received = received;
        _total = total;
        notifyListeners();
      },
    );
    if (_disposed) return;
    switch (result) {
      case UpdateDownloaded(:final path):
        _installerPath = path;
        _set(UpdateStatus.ready);
      case UpdateDownloadFailed(:final kind):
        _fail(_Step.download, kind);
        if (kind == UpdateErrorKind.checksumMismatch) {
          _toasts.show(
            'Update rejected — the installer failed verification',
            kind: ToastKind.error,
          );
        }
    }
  }

  Future<void> install() async {
    final path = _installerPath;
    if (path == null || _edit.writing || _status == UpdateStatus.installing) {
      return;
    }
    _set(UpdateStatus.installing);
    final error = await _repository.install(path);
    if (_disposed) return;
    if (error != null) {
      _fail(_Step.install, error);
      return;
    }
    await _quit();
  }

  Future<void> _check({required bool silent}) async {
    _set(UpdateStatus.checking);
    final result = await _repository.check(currentVersion);
    if (_disposed) return;
    switch (result) {
      case UpdateAvailable(:final release):
        _release = release;
        _set(UpdateStatus.available);
        await _recordCheck();
        if (silent) {
          _toasts.show(
            'Update available — OpenX11SE ${release.version}',
            icon: AppIconsFill.downloadSimple,
            actionLabel: 'View',
            onAction: openDialog,
            lifetime: const Duration(seconds: 10),
          );
        } else {
          openDialog();
        }
      case UpToDate():
        _release = null;
        _set(UpdateStatus.upToDate);
        await _recordCheck();
      case UpdateCheckFailed(:final kind, :final retryAt):
        _fail(_Step.check, kind, retryAt: retryAt);
    }
  }

  Future<void> _recordCheck() async {
    final at = _now().toUtc();
    _appSettings = _appSettings.copyWith(lastUpdateCheck: at);
    try {
      await _settings.update((s) => s.copyWith(lastUpdateCheck: at));
    } on Object {
      return;
    }
  }

  void _set(UpdateStatus status, {int? received, int? total}) {
    _status = status;
    _error = null;
    _retryAt = null;
    if (received != null) _received = received;
    if (status == UpdateStatus.downloading) _total = total;
    notifyListeners();
  }

  void _fail(_Step step, UpdateErrorKind kind, {DateTime? retryAt}) {
    _status = UpdateStatus.failed;
    _failedStep = step;
    _error = kind;
    _retryAt = retryAt;
    if (step != _Step.install) _installerPath = null;
    notifyListeners();
  }

  void _onSettings(AppSettings next) {
    if (next == _appSettings) return;
    _appSettings = next;
    notifyListeners();
  }

  void _onEdit() {
    if (_edit.writing == _writing && _edit.hasPending == _hasPending) return;
    _writing = _edit.writing;
    _hasPending = _edit.hasPending;
    notifyListeners();
  }

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _edit.removeListener(_onEdit);
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
