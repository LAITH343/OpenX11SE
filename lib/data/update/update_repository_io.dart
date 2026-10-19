import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../domain/app_version.dart';
import 'update_repository.dart';

UpdateRepository createPlatformUpdateRepository() =>
    Platform.isWindows || Platform.isMacOS
    ? GitHubUpdateRepository()
    : const NoUpdateRepository();

String? macAppBundle(String executable) {
  final parts = executable.split('/');
  if (parts.length < 4 ||
      parts[parts.length - 2] != 'MacOS' ||
      parts[parts.length - 3] != 'Contents' ||
      !parts[parts.length - 4].endsWith('.app')) {
    return null;
  }
  return parts.sublist(0, parts.length - 3).join('/');
}

const macSwapScript = r'''
pid="$1"; src="$2"; dst="$3"
while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
new="$dst.new"; old="$dst.old"
rm -rf "$new" "$old"
if /usr/bin/ditto "$src" "$new"; then
  if mv "$dst" "$old"; then
    if mv "$new" "$dst"; then rm -rf "$old"; else mv "$old" "$dst"; fi
  fi
fi
rm -rf "$new" "$(dirname "$src")"
/usr/bin/xattr -dr com.apple.quarantine "$dst" 2>/dev/null
/usr/bin/open "$dst"
''';

Future<String> sha256OfFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

Future<bool> verifyInstaller(File file, String expectedSha256) async {
  final actual = await sha256OfFile(file);
  if (actual == expectedSha256.toLowerCase()) return true;
  try {
    await file.delete();
  } on FileSystemException {
    return false;
  }
  return false;
}

class GitHubUpdateRepository implements UpdateRepository {
  GitHubUpdateRepository({
    HttpClient Function()? client,
    Directory? downloadDirectory,
    Future<Process> Function(String, List<String>)? launcher,
    Future<ProcessResult> Function(String, List<String>)? runner,
    UpdatePlatform? platform,
    String? executable,
  }) : platform =
           platform ??
           (Platform.isMacOS ? UpdatePlatform.macos : UpdatePlatform.windows),
       _executable = executable ?? Platform.resolvedExecutable,
       _run = runner ?? Process.run,
       _client = client ?? HttpClient.new,
       _downloads =
           downloadDirectory ??
           Directory(
             '${Directory.systemTemp.path}${Platform.pathSeparator}'
             'OpenX11SE-update',
           ),
       _launch = launcher ?? _startDetached;

  static const _connectTimeout = Duration(seconds: 15);
  static const _idleTimeout = Duration(seconds: 30);
  static const _maxChecksumBytes = 4096;

  final UpdatePlatform platform;
  final String _executable;
  final Future<ProcessResult> Function(String, List<String>) _run;
  final HttpClient Function() _client;
  final Directory _downloads;
  final Future<Process> Function(String, List<String>) _launch;

  @override
  bool get isSupported => true;

  @override
  Future<UpdateCheckResult> check(AppVersion current) async {
    final client = _newClient();
    try {
      final request = await client.getUrl(latestReleaseUrl);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set('X-GitHub-Api-Version', '2022-11-28');
      final response = await request.close().timeout(_idleTimeout);
      final body = await _readText(response, 1 << 20);
      if (response.statusCode == HttpStatus.notFound) return const UpToDate();
      final limited = rateLimitFailure(
        response.statusCode,
        response.headers.value,
      );
      if (limited != null) return limited;
      if (response.statusCode != HttpStatus.ok) {
        return const UpdateCheckFailed(UpdateErrorKind.serverError);
      }
      final Object? json;
      try {
        json = jsonDecode(body);
      } on FormatException {
        return const UpdateCheckFailed(UpdateErrorKind.malformedResponse);
      }
      return evaluateRelease(json, current, platform: platform);
    } on Object catch (error) {
      return UpdateCheckFailed(_networkKind(error));
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<UpdateDownloadResult> download(
    AppRelease release, {
    DownloadProgress? onProgress,
  }) async {
    final client = _newClient();
    File? target;
    try {
      final checksumResponse = await _get(client, release.checksum.url);
      if (checksumResponse.statusCode != HttpStatus.ok) {
        await checksumResponse.drain<void>();
        return const UpdateDownloadFailed(UpdateErrorKind.checksumMissing);
      }
      final checksumText = await _readText(checksumResponse, _maxChecksumBytes);
      final expected = parseChecksumFile(checksumText, release.installer.name);
      if (expected == null) {
        return const UpdateDownloadFailed(UpdateErrorKind.checksumMissing);
      }

      try {
        await _clearDownloads();
        target = File(
          '${_downloads.path}${Platform.pathSeparator}'
          '${release.installer.name}',
        );
      } on FileSystemException {
        return const UpdateDownloadFailed(UpdateErrorKind.storageFailed);
      }

      final response = await _get(client, release.installer.url);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return const UpdateDownloadFailed(UpdateErrorKind.downloadFailed);
      }
      final total = response.contentLength >= 0
          ? response.contentLength
          : release.installer.size;
      final sink = target.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(_idleTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }
      if (total != null && received != total) {
        await _deleteQuietly(target);
        return const UpdateDownloadFailed(UpdateErrorKind.downloadFailed);
      }
      if (!await verifyInstaller(target, expected)) {
        await _deleteQuietly(target);
        return const UpdateDownloadFailed(UpdateErrorKind.checksumMismatch);
      }
      return UpdateDownloaded(target.path);
    } on FileSystemException {
      await _deleteQuietly(target);
      return const UpdateDownloadFailed(UpdateErrorKind.storageFailed);
    } on Object catch (error) {
      await _deleteQuietly(target);
      final kind = _networkKind(error);
      return UpdateDownloadFailed(
        kind == UpdateErrorKind.serverError
            ? UpdateErrorKind.downloadFailed
            : kind,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<UpdateErrorKind?> install(String installerPath) async {
    if (!File(installerPath).existsSync()) return UpdateErrorKind.launchFailed;
    try {
      if (platform == UpdatePlatform.macos) {
        return await _installMacApp(installerPath);
      }
      await _launch(installerPath, installerArguments);
      return null;
    } on Object {
      return UpdateErrorKind.launchFailed;
    }
  }

  Future<UpdateErrorKind?> _installMacApp(String imagePath) async {
    final bundle = macAppBundle(_executable);
    if (bundle == null) return UpdateErrorKind.launchFailed;
    if (bundle.contains('/AppTranslocation/') ||
        !await _isWritable(File(bundle).parent)) {
      return UpdateErrorKind.moveRequired;
    }
    final staging = Directory('${_downloads.path}/staged');
    final mount = Directory('${_downloads.path}/mount');
    await _detach(mount);
    await _deleteQuietly(staging);
    await _deleteQuietly(mount);
    await staging.create(recursive: true);
    await mount.create(recursive: true);
    Directory? app;
    try {
      final attach = await _run('/usr/bin/hdiutil', [
        'attach',
        '-nobrowse',
        '-readonly',
        '-noautoopen',
        '-mountpoint',
        mount.path,
        imagePath,
      ]);
      if (attach.exitCode != 0) return await _abort(staging);
      final source = (await mount.list().toList())
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.app'))
          .firstOrNull;
      if (source == null) return await _abort(staging);
      final target = Directory(
        '${staging.path}/${source.uri.pathSegments.lastWhere((s) => s.isNotEmpty)}',
      );
      final copy = await _run('/usr/bin/ditto', [source.path, target.path]);
      if (copy.exitCode != 0) return await _abort(staging);
      app = target;
    } finally {
      await _detach(mount);
    }
    await _launch('/bin/sh', [
      '-c',
      macSwapScript,
      'openx11se-update',
      '$pid',
      app.path,
      bundle,
    ]);
    return null;
  }

  Future<UpdateErrorKind> _abort(Directory staging) async {
    await _deleteQuietly(staging);
    return UpdateErrorKind.launchFailed;
  }

  Future<void> _detach(Directory mount) async {
    if (!await mount.exists()) return;
    try {
      await _run('/usr/bin/hdiutil', ['detach', mount.path, '-force']);
    } on Object {
      return;
    }
  }

  static Future<bool> _isWritable(Directory directory) async {
    final probe = File(
      '${directory.path}/.openx11se-update-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await probe.writeAsBytes(const []);
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  HttpClient _newClient() => _client()
    ..connectionTimeout = _connectTimeout
    ..idleTimeout = _idleTimeout
    ..userAgent = 'OpenX11SE-updater';

  Future<HttpClientResponse> _get(HttpClient client, Uri url) async {
    final request = await client.getUrl(url);
    return request.close().timeout(_idleTimeout);
  }

  Future<String> _readText(HttpClientResponse response, int limit) async {
    final bytes = <int>[];
    await for (final chunk in response.timeout(_idleTimeout)) {
      bytes.addAll(chunk);
      if (bytes.length > limit) throw const FormatException('Too large');
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static UpdateErrorKind _networkKind(Object error) => switch (error) {
    SocketException() ||
    HandshakeException() ||
    TimeoutException() ||
    HttpException() => UpdateErrorKind.offline,
    FormatException() => UpdateErrorKind.malformedResponse,
    _ => UpdateErrorKind.serverError,
  };

  Future<void> _clearDownloads() async {
    if (await _downloads.exists()) {
      await for (final entry in _downloads.list()) {
        await _deleteQuietly(entry);
      }
    } else {
      await _downloads.create(recursive: true);
    }
  }

  static Future<void> _deleteQuietly(FileSystemEntity? entity) async {
    if (entity == null) return;
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } on FileSystemException {
      return;
    }
  }

  static Future<Process> _startDetached(String path, List<String> args) =>
      Process.start(path, args, mode: ProcessStartMode.detached);
}
