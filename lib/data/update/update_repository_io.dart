import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../domain/app_version.dart';
import 'update_repository.dart';

UpdateRepository createPlatformUpdateRepository() =>
    Platform.isWindows ? GitHubUpdateRepository() : const NoUpdateRepository();

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
  }) : _client = client ?? HttpClient.new,
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
      return evaluateRelease(json, current);
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
      await _launch(installerPath, installerArguments);
      return null;
    } on Object {
      return UpdateErrorKind.launchFailed;
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
