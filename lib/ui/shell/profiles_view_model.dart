import 'package:flutter/foundation.dart';

import '../../core/theme/app_icons.dart';
import '../../data/files/profile_files.dart';
import '../../data/json/profile_file_json.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/profile_transfer_repository.dart';
import '../../domain/profile.dart';
import '../widgets/toast_host.dart';
import 'dialog_request.dart';
import 'edit_session_view_model.dart';

typedef ConfirmRequest = Future<bool> Function(DialogRequest request);
typedef PromptRequest = Future<String?> Function(DialogRequest request);

class ProfilesViewModel extends ChangeNotifier {
  ProfilesViewModel({
    required this._profiles,
    required this._transfer,
    required this._edit,
    required this._toasts,
    required this._confirm,
    required this._prompt,
    this._files = const ProfileFiles(),
  });

  final ProfileRepository _profiles;
  final ProfileTransferRepository _transfer;
  final EditSessionViewModel _edit;
  final ToastController _toasts;
  final ConfirmRequest _confirm;
  final PromptRequest _prompt;
  final ProfileFiles _files;

  bool _busy = false;
  bool _disposed = false;

  bool get busy => _busy;

  bool get supportsVendorImport => _files.supportsVendorImport;

  Future<void> select(Profile profile) => _run(() async {
    if (profile.isActive) return;
    await _profiles.activate(profile.id);
    _edit.loadProfile(profile.id, profile.settings);
    _toasts.show(
      'Loaded “${profile.name}” — apply to write it to the mouse',
      icon: AppIconsFill.userSwitch,
    );
  });

  Future<void> create() => _run(() async {
    final count = (await _profiles.profiles()).length;
    final profile = await _profiles.create(
      'Profile ${count + 1}',
      activate: true,
    );
    _edit.loadProfile(profile.id, profile.settings);
    _toasts.show(
      'Created “${profile.name}”',
      kind: ToastKind.success,
      icon: AppIconsFill.plus,
    );
  });

  Future<void> duplicate() => _run(() async {
    final active = await _profiles.activeProfile();
    final copy = await _profiles.create(
      '${active.name} copy',
      settings: _edit.staged ?? active.settings,
      activate: true,
    );
    _toasts.show(
      'Duplicated as “${copy.name}”',
      kind: ToastKind.success,
      icon: AppIconsFill.copy,
    );
  });

  Future<void> rename() => _run(() async {
    final active = await _profiles.activeProfile();
    final name = await _prompt(
      DialogRequest(
        title: 'Rename profile',
        body: 'Profiles are stored on this computer.',
        confirmLabel: 'Rename',
        icon: AppIcons.pencilSimple,
        initialText: active.name,
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == active.name) return;
    await _profiles.rename(active.id, trimmed);
  });

  Future<void> delete() => _run(() async {
    final all = await _profiles.profiles();
    if (all.length < 2) {
      _toasts.show(
        'Keep at least one profile',
        kind: ToastKind.warning,
        icon: AppIconsFill.warning,
      );
      return;
    }
    final active = all.firstWhere((p) => p.isActive);
    final confirmed = await _confirm(
      DialogRequest(
        title: 'Delete “${active.name}”?',
        body:
            'This removes the profile from this computer. The mouse keeps '
            'its current settings.',
        confirmLabel: 'Delete profile',
        icon: AppIcons.trash,
        danger: true,
      ),
    );
    if (!confirmed) return;
    await _profiles.delete(active.id);
    final next = await _profiles.activeProfile();
    _edit.loadProfile(next.id, next.settings);
    _toasts.show('Deleted “${active.name}”', icon: AppIconsFill.trash);
  });

  Future<void> importFile() => _run(() async {
    final bytes = await _files.pickProfile();
    if (bytes == null) return;
    try {
      final profile = await _transfer.importFile(bytes);
      _toasts.show(
        'Imported “${profile.name}”',
        kind: ToastKind.success,
        icon: AppIconsFill.fileArrowUp,
      );
    } on FormatException {
      _toasts.show(
        "That file isn't an OpenX11SE profile",
        kind: ToastKind.error,
        icon: AppIconsFill.xCircle,
      );
    }
  });

  Future<void> export() => _run(() async {
    final active = await _profiles.activeProfile();
    final bytes = await _transfer.export(
      active.name,
      _edit.staged ?? active.settings,
    );
    final fileName = '${_fileSafe(active.name)}.$profileFileExtension';
    if (!await _files.saveProfile(fileName, bytes)) return;
    _toasts.show(
      'Exported “$fileName”',
      kind: ToastKind.success,
      icon: AppIconsFill.downloadSimple,
    );
  });

  Future<void> importVendor() => _run(() async {
    if (!supportsVendorImport) return;
    final bytes = await _files.readVendorProfile();
    if (bytes == null) return;
    try {
      final result = await _transfer.importVendor(bytes);
      final skipped = result.unmappedSlots.length;
      _toasts.show(
        skipped == 0
            ? 'Imported “${result.profile.name}” from the vendor software'
            : 'Imported “${result.profile.name}” · $skipped '
                  '${skipped == 1 ? 'button' : 'buttons'} kept at default',
        kind: ToastKind.success,
        icon: AppIconsFill.arrowSquareIn,
      );
    } on FormatException {
      _toasts.show(
        "Couldn't read the vendor profile file",
        kind: ToastKind.error,
        icon: AppIconsFill.xCircle,
      );
    }
  });

  Future<void> restoreDefaults() => _run(() async {
    final confirmed = await _confirm(
      DialogRequest(
        title: 'Restore defaults?',
        body:
            'Writes factory default settings to the mouse and this profile. '
            'Your other profiles and macros are kept.',
        confirmLabel: 'Restore defaults',
        icon: AppIcons.arrowCounterClockwise,
        danger: true,
      ),
    );
    if (confirmed) await stageDefaults();
  });

  Future<void> stageDefaults() async {
    final online = _edit.isOnline && !_edit.mouseOff;
    if (await _edit.restoreDefaults() || online) return;
    _toasts.show(
      'Defaults staged — apply when the mouse reconnects',
      icon: AppIconsFill.info,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } on Object {
      _toasts.show(
        'Something went wrong — profiles were not changed',
        kind: ToastKind.error,
        icon: AppIconsFill.xCircle,
      );
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String _fileSafe(String name) {
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
    return safe.isEmpty ? 'profile' : safe;
  }
}
