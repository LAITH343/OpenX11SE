import '../../domain/app_version.dart';
import 'update_repository_none.dart'
    if (dart.library.ffi) 'update_repository_io.dart'
    as platform;

enum UpdateErrorKind {
  offline,
  rateLimited,
  malformedResponse,
  serverError,
  noInstaller,
  checksumMissing,
  checksumMismatch,
  downloadFailed,
  storageFailed,
  launchFailed,
  moveRequired,
  folderNotWritable,
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.release);

  final AppRelease release;
}

class UpToDate extends UpdateCheckResult {
  const UpToDate([this.latest]);

  final AppVersion? latest;
}

class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.kind, {this.retryAt});

  final UpdateErrorKind kind;
  final DateTime? retryAt;
}

sealed class UpdateDownloadResult {
  const UpdateDownloadResult();
}

class UpdateDownloaded extends UpdateDownloadResult {
  const UpdateDownloaded(this.path);

  final String path;
}

class UpdateDownloadFailed extends UpdateDownloadResult {
  const UpdateDownloadFailed(this.kind);

  final UpdateErrorKind kind;
}

typedef DownloadProgress = void Function(int received, int? total);

abstract interface class UpdateRepository {
  bool get isSupported;

  Future<UpdateCheckResult> check(AppVersion current);

  Future<UpdateDownloadResult> download(
    AppRelease release, {
    DownloadProgress? onProgress,
  });

  Future<UpdateErrorKind?> install(String installerPath);
}

class NoUpdateRepository implements UpdateRepository {
  const NoUpdateRepository();

  @override
  bool get isSupported => false;

  @override
  Future<UpdateCheckResult> check(AppVersion current) async => const UpToDate();

  @override
  Future<UpdateDownloadResult> download(
    AppRelease release, {
    DownloadProgress? onProgress,
  }) async => const UpdateDownloadFailed(UpdateErrorKind.downloadFailed);

  @override
  Future<UpdateErrorKind?> install(String installerPath) async =>
      UpdateErrorKind.launchFailed;
}

const releasesRepository = 'LAITH343/OpenX11SE';

final latestReleaseUrl = Uri.https(
  'api.github.com',
  '/repos/$releasesRepository/releases/latest',
);

const installerArguments = [
  '/VERYSILENT',
  '/SUPPRESSMSGBOXES',
  '/CLOSEAPPLICATIONS',
  '/RESTARTAPPLICATIONS',
  '/RELAUNCH=1',
];

enum UpdatePlatform {
  windows,
  macos,
  linux;

  String assetName(AppVersion version) => switch (this) {
    windows => 'OpenX11SE-Setup-$version.exe',
    macos => 'OpenX11SE-macOS-$version.dmg',
    linux => 'OpenX11SE-Linux-$version-x86_64.AppImage',
  };
}

UpdateRepository createUpdateRepository() =>
    platform.createPlatformUpdateRepository();

UpdateCheckResult evaluateRelease(
  Object? json,
  AppVersion current, {
  UpdatePlatform platform = UpdatePlatform.windows,
}) {
  if (json is! Map<String, Object?>) {
    return const UpdateCheckFailed(UpdateErrorKind.malformedResponse);
  }
  if (json['draft'] == true || json['prerelease'] == true) {
    return const UpToDate();
  }
  final tag = json['tag_name'];
  final version = tag is String ? AppVersion.tryParse(tag) : null;
  if (tag is! String || version == null) {
    return const UpdateCheckFailed(UpdateErrorKind.malformedResponse);
  }
  if (version.isPreRelease || !(version > current)) return UpToDate(version);
  final assets = json['assets'];
  if (assets is! List<Object?>) {
    return const UpdateCheckFailed(UpdateErrorKind.malformedResponse);
  }
  final installerName = platform.assetName(version).toLowerCase();
  ReleaseAsset? installer;
  ReleaseAsset? checksum;
  for (final asset in assets.map(_parseAsset).nonNulls) {
    final name = asset.name.toLowerCase();
    if (name == installerName) installer = asset;
    if (name == '$installerName.sha256') checksum = asset;
  }
  if (installer == null) {
    return const UpdateCheckFailed(UpdateErrorKind.noInstaller);
  }
  if (checksum == null) {
    return const UpdateCheckFailed(UpdateErrorKind.checksumMissing);
  }
  final body = json['body'];
  final page = json['html_url'];
  final published = json['published_at'];
  return UpdateAvailable(
    AppRelease(
      version: version,
      tag: tag,
      installer: installer,
      checksum: checksum,
      notes: body is String ? body.trim() : '',
      pageUrl: page is String ? Uri.tryParse(page) : null,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
    ),
  );
}

ReleaseAsset? _parseAsset(Object? json) {
  if (json is! Map<String, Object?>) return null;
  final name = json['name'];
  final url = json['browser_download_url'];
  final size = json['size'];
  if (name is! String || url is! String) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return null;
  return ReleaseAsset(name: name, url: uri, size: size is int ? size : null);
}

final _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

String? parseChecksumFile(String text, String fileName) {
  String? single;
  var lines = 0;
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.first.isEmpty) continue;
    lines++;
    if (!_sha256Pattern.hasMatch(parts.first)) continue;
    final hash = parts.first.toLowerCase();
    if (parts.length == 1) {
      single = hash;
      continue;
    }
    final name = parts.sublist(1).join(' ').replaceFirst(RegExp(r'^\*'), '');
    if (name.toLowerCase() == fileName.toLowerCase()) return hash;
  }
  return lines == 1 ? single : null;
}

UpdateCheckFailed? rateLimitFailure(
  int status,
  String? Function(String name) header, {
  DateTime? now,
}) {
  if (status != 403 && status != 429) return null;
  final retryAfter = int.tryParse(header('retry-after') ?? '');
  if (status == 403 &&
      header('x-ratelimit-remaining') != '0' &&
      retryAfter == null) {
    return const UpdateCheckFailed(UpdateErrorKind.serverError);
  }
  final reset = int.tryParse(header('x-ratelimit-reset') ?? '');
  return UpdateCheckFailed(
    UpdateErrorKind.rateLimited,
    retryAt: retryAfter != null
        ? (now ?? DateTime.now()).add(Duration(seconds: retryAfter))
        : reset != null
        ? DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true)
        : null,
  );
}
