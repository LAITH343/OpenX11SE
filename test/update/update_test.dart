import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openx11se/data/db/app_database.dart';
import 'package:openx11se/data/repositories/device_repository.dart';
import 'package:openx11se/data/repositories/device_timing.dart';
import 'package:openx11se/data/repositories/macro_repository.dart';
import 'package:openx11se/data/repositories/profile_repository.dart';
import 'package:openx11se/data/repositories/settings_repository.dart';
import 'package:openx11se/data/update/update_repository.dart';
import 'package:openx11se/data/update/update_repository_io.dart';
import 'package:openx11se/domain/app_version.dart';
import 'package:openx11se/domain/polling_rate.dart';
import 'package:openx11se/ui/settings/update_view_model.dart';
import 'package:openx11se/ui/shell/edit_session_view_model.dart';
import 'package:openx11se/ui/widgets/toast_host.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_hid.dart';

AppVersion v(String text) => AppVersion.tryParse(text)!;

Map<String, Object?> releaseJson({
  String tag = 'v1.2.0',
  bool draft = false,
  bool prerelease = false,
  bool installer = true,
  bool checksum = true,
  String host = 'https://github.com',
}) {
  final version = tag.replaceFirst('v', '');
  final name = 'OpenX11SE-Setup-$version.exe';
  return {
    'tag_name': tag,
    'draft': draft,
    'prerelease': prerelease,
    'body': '  Faster apply\n',
    'html_url': 'https://github.com/LAITH343/OpenX11SE/releases/tag/$tag',
    'published_at': '2026-10-01T12:00:00Z',
    'assets': [
      if (installer)
        {'name': name, 'size': 1234, 'browser_download_url': '$host/d/$name'},
      if (checksum)
        {
          'name': '$name.sha256',
          'size': 90,
          'browser_download_url': '$host/d/$name.sha256',
        },
      {'name': 'notes.txt'},
    ],
  };
}

AppRelease release({String version = '1.2.0', String host = ''}) {
  final name = 'OpenX11SE-Setup-$version.exe';
  return AppRelease(
    version: v(version),
    tag: 'v$version',
    installer: ReleaseAsset(name: name, url: Uri.parse('$host/$name')),
    checksum: ReleaseAsset(
      name: '$name.sha256',
      url: Uri.parse('$host/$name.sha256'),
    ),
    notes: 'Notes',
  );
}

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

class FakeUpdateRepository implements UpdateRepository {
  final checks = <UpdateCheckResult>[];
  final downloads = <UpdateDownloadResult>[];
  UpdateErrorKind? installError;
  final installed = <String>[];
  int checkCount = 0;
  Completer<void>? downloadGate;

  @override
  bool get isSupported => true;

  @override
  Future<UpdateCheckResult> check(AppVersion current) async {
    checkCount++;
    return checks.removeAt(0);
  }

  @override
  Future<UpdateDownloadResult> download(
    AppRelease release, {
    DownloadProgress? onProgress,
  }) async {
    onProgress?.call(500, 1000);
    await downloadGate?.future;
    onProgress?.call(1000, 1000);
    return downloads.removeAt(0);
  }

  @override
  Future<UpdateErrorKind?> install(String installerPath) async {
    installed.add(installerPath);
    return installError;
  }
}

void main() {
  group('AppVersion', () {
    test('parses tags and build metadata', () {
      expect(v('v1.2.3'), const AppVersion(1, 2, 3));
      expect(v('1.0.0+7'), const AppVersion(1, 0, 0));
      expect(v('2.0.0-beta.1').isPreRelease, isTrue);
      expect(AppVersion.tryParse('1.2'), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
    });

    test('compares numerically and ranks pre-releases lower', () {
      expect(v('1.10.0') > v('1.9.9'), isTrue);
      expect(v('2.0.0') > v('1.99.99'), isTrue);
      expect(v('1.0.1') > v('1.0.0'), isTrue);
      expect(v('1.0.0') == v('v1.0.0+3'), isTrue);
      expect(v('1.0.0-rc.1') < v('1.0.0'), isTrue);
      expect(v('1.0.0-alpha') < v('1.0.0-alpha.1'), isTrue);
      expect(v('1.0.0-alpha.2') < v('1.0.0-alpha.10'), isTrue);
      expect(v('1.0.0-alpha.1') < v('1.0.0-beta'), isTrue);
    });
  });

  group('release parsing', () {
    test('finds a newer release with its installer and checksum', () {
      final result = evaluateRelease(releaseJson(), v('1.0.0'));
      expect(result, isA<UpdateAvailable>());
      final r = (result as UpdateAvailable).release;
      expect(r.version, v('1.2.0'));
      expect(r.tag, 'v1.2.0');
      expect(r.installer.name, 'OpenX11SE-Setup-1.2.0.exe');
      expect(r.installer.size, 1234);
      expect(r.checksum.name, 'OpenX11SE-Setup-1.2.0.exe.sha256');
      expect(r.notes, 'Faster apply');
      expect(r.publishedAt, DateTime.utc(2026, 10, 1, 12));
    });

    test('reports up to date for the same or an older release', () {
      expect(evaluateRelease(releaseJson(), v('1.2.0')), isA<UpToDate>());
      expect(evaluateRelease(releaseJson(), v('1.3.0')), isA<UpToDate>());
    });

    test('skips drafts and pre-releases', () {
      expect(
        evaluateRelease(releaseJson(draft: true), v('1.0.0')),
        isA<UpToDate>(),
      );
      expect(
        evaluateRelease(releaseJson(prerelease: true), v('1.0.0')),
        isA<UpToDate>(),
      );
      expect(
        evaluateRelease(releaseJson(tag: 'v2.0.0-beta.1'), v('1.0.0')),
        isA<UpToDate>(),
      );
    });

    UpdateErrorKind? failure(Object? json) =>
        switch (evaluateRelease(json, v('1.0.0'))) {
          UpdateCheckFailed(:final kind) => kind,
          _ => null,
        };

    test('turns malformed responses into typed failures', () {
      expect(failure(null), UpdateErrorKind.malformedResponse);
      expect(failure(<Object?>[]), UpdateErrorKind.malformedResponse);
      expect(failure({'tag_name': 5}), UpdateErrorKind.malformedResponse);
      expect(
        failure({'tag_name': 'nightly'}),
        UpdateErrorKind.malformedResponse,
      );
      expect(
        failure({'tag_name': 'v1.2.0', 'assets': 'x'}),
        UpdateErrorKind.malformedResponse,
      );
      expect(
        failure(releaseJson(installer: false)),
        UpdateErrorKind.noInstaller,
      );
      expect(
        failure(releaseJson(checksum: false)),
        UpdateErrorKind.checksumMissing,
      );
      expect(
        failure(releaseJson(host: 'http://example.com')),
        UpdateErrorKind.noInstaller,
      );
    });

    test('picks the macOS disk image for macOS', () {
      final json = releaseJson();
      expect(
        evaluateRelease(json, v('1.0.0'), platform: UpdatePlatform.macos),
        isA<UpdateCheckFailed>().having(
          (f) => f.kind,
          'kind',
          UpdateErrorKind.noInstaller,
        ),
      );
      const dmg = 'OpenX11SE-macOS-1.2.0.dmg';
      const zip = 'OpenX11SE-macOS-1.2.0.zip';
      json['assets'] = [
        ...json['assets']! as List<Object?>,
        for (final name in [zip, '$zip.sha256', dmg, '$dmg.sha256'])
          {'name': name, 'browser_download_url': 'https://github.com/d/$name'},
      ];
      final result = evaluateRelease(
        json,
        v('1.0.0'),
        platform: UpdatePlatform.macos,
      );
      final release = (result as UpdateAvailable).release;
      expect(release.installer.name, dmg);
      expect(release.checksum.name, '$dmg.sha256');
    });

    test('picks the x86_64 AppImage for Linux', () {
      final json = releaseJson();
      const image = 'OpenX11SE-Linux-1.2.0-x86_64.AppImage';
      json['assets'] = [
        ...json['assets']! as List<Object?>,
        for (final name in [image, '$image.sha256'])
          {'name': name, 'browser_download_url': 'https://github.com/d/$name'},
      ];
      final result = evaluateRelease(
        json,
        v('1.0.0'),
        platform: UpdatePlatform.linux,
      );
      final release = (result as UpdateAvailable).release;
      expect(release.installer.name, image);
      expect(release.checksum.name, '$image.sha256');
    });

    test('classifies rate limits', () {
      final now = DateTime.utc(2026, 10, 9, 12);
      final limited = rateLimitFailure(
        403,
        (name) => {
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '1791547200',
        }[name],
      );
      expect(limited?.kind, UpdateErrorKind.rateLimited);
      expect(
        limited?.retryAt,
        DateTime.fromMillisecondsSinceEpoch(1791547200000, isUtc: true),
      );
      final retryAfter = rateLimitFailure(
        429,
        (name) => name == 'retry-after' ? '60' : null,
        now: now,
      );
      expect(retryAfter?.kind, UpdateErrorKind.rateLimited);
      expect(retryAfter?.retryAt, now.add(const Duration(minutes: 1)));
      expect(
        rateLimitFailure(403, (_) => null)?.kind,
        UpdateErrorKind.serverError,
      );
      expect(rateLimitFailure(200, (_) => null), isNull);
    });
  });

  group('checksums', () {
    const hash =
        '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';

    test('parses sha256 files', () {
      expect(parseChecksumFile('$hash  Setup.exe\n', 'Setup.exe'), hash);
      expect(parseChecksumFile('$hash *setup.EXE', 'Setup.exe'), hash);
      expect(parseChecksumFile(hash.toUpperCase(), 'Setup.exe'), hash);
      expect(parseChecksumFile('$hash  Other.exe', 'Setup.exe'), isNull);
      expect(parseChecksumFile('not a hash', 'Setup.exe'), isNull);
      expect(parseChecksumFile('', 'Setup.exe'), isNull);
    });

    test('verifies installers and deletes tampered files', () async {
      final dir = await Directory.systemTemp.createTemp('update_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/Setup.exe')..writeAsStringSync('test');
      expect(await sha256OfFile(file), hash);
      expect(await verifyInstaller(file, hash.toUpperCase()), isTrue);
      expect(file.existsSync(), isTrue);
      file.writeAsStringSync('tampered');
      expect(await verifyInstaller(file, hash), isFalse);
      expect(file.existsSync(), isFalse);
    });
  });

  group('GitHubUpdateRepository', () {
    late HttpServer server;
    late Directory downloads;
    late Map<String, List<int>> files;
    late String host;

    setUp(() async {
      files = {};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      host = 'http://${server.address.host}:${server.port}';
      server.listen((request) async {
        final body = files[request.uri.path];
        if (body == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.contentLength = body.length;
          request.response.add(body);
        }
        await request.response.close();
      });
      downloads = await Directory.systemTemp.createTemp('update_downloads');
    });

    tearDown(() async {
      await server.close(force: true);
      if (downloads.existsSync()) await downloads.delete(recursive: true);
    });

    void publish(List<int> installer, {List<int>? checksumOf}) {
      final r = release();
      files['/${r.installer.name}'] = installer;
      files['/${r.checksum.name}'] = utf8.encode(
        '${sha256.convert(checksumOf ?? installer)}  ${r.installer.name}\n',
      );
    }

    test('downloads and verifies the installer with progress', () async {
      final payload = List<int>.generate(200000, (i) => i % 251);
      publish(payload);
      final repo = GitHubUpdateRepository(downloadDirectory: downloads);
      final progress = <int>[];
      final result = await repo.download(
        release(host: host),
        onProgress: (received, total) {
          progress.add(received);
          expect(total, payload.length);
        },
      );
      expect(result, isA<UpdateDownloaded>());
      final path = (result as UpdateDownloaded).path;
      expect(File(path).readAsBytesSync(), payload);
      expect(progress.last, payload.length);
    });

    test('rejects and deletes a tampered installer', () async {
      publish(utf8.encode('tampered'), checksumOf: utf8.encode('original'));
      final repo = GitHubUpdateRepository(downloadDirectory: downloads);
      final result = await repo.download(release(host: host));
      expect(
        (result as UpdateDownloadFailed).kind,
        UpdateErrorKind.checksumMismatch,
      );
      expect(downloads.listSync(), isEmpty);
    });

    test('fails when the checksum asset is missing', () async {
      files['/${release().installer.name}'] = [1, 2, 3];
      final repo = GitHubUpdateRepository(downloadDirectory: downloads);
      final result = await repo.download(release(host: host));
      expect(
        (result as UpdateDownloadFailed).kind,
        UpdateErrorKind.checksumMissing,
      );
    });

    test('reports offline when the network is unreachable', () async {
      final repo = GitHubUpdateRepository(
        client: () => HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:1',
        downloadDirectory: downloads,
      );
      final result = await repo.check(v('1.0.0'));
      expect((result as UpdateCheckFailed).kind, UpdateErrorKind.offline);
      final download = await repo.download(release(host: 'http://127.0.0.1:1'));
      expect((download as UpdateDownloadFailed).kind, UpdateErrorKind.offline);
    });

    test('launches the installer silently', () async {
      final file = File('${downloads.path}/Setup.exe')..writeAsStringSync('x');
      final launched = <(String, List<String>)>[];
      final repo = GitHubUpdateRepository(
        downloadDirectory: downloads,
        launcher: (path, args) async {
          launched.add((path, args));
          return Process.start('cmd', ['/c', 'exit', '0']);
        },
      );
      expect(await repo.install(file.path), isNull);
      expect(launched.single.$1, file.path);
      expect(launched.single.$2, containsAll(['/VERYSILENT', '/RELAUNCH=1']));
      expect(
        await repo.install('${downloads.path}/missing.exe'),
        UpdateErrorKind.launchFailed,
      );
    }, testOn: 'windows');

    test('finds the app bundle of the running executable', () {
      expect(
        macAppBundle('/Applications/OpenX11SE.app/Contents/MacOS/OpenX11SE'),
        '/Applications/OpenX11SE.app',
      );
      expect(macAppBundle('/usr/local/bin/openx11se'), isNull);
    });

    test('stages the macOS update and launches the swap script', () async {
      final apps = await Directory.systemTemp.createTemp('update_apps');
      addTearDown(() => apps.delete(recursive: true));
      final executable = '${apps.path}/OpenX11SE.app/Contents/MacOS/OpenX11SE';
      final archive = File('${downloads.path}/OpenX11SE-macOS-1.2.0.dmg')
        ..writeAsStringSync('dmg');
      final mount = '${downloads.path}/mount';
      final ran = <(String, List<String>)>[];
      final launched = <(String, List<String>)>[];
      final repo = GitHubUpdateRepository(
        downloadDirectory: downloads,
        platform: UpdatePlatform.macos,
        executable: executable,
        runner: (path, args) async {
          ran.add((path, args));
          if (args.first == 'attach') {
            Directory('$mount/OpenX11SE.app').createSync(recursive: true);
          } else if (path == '/usr/bin/ditto') {
            Directory(args.last).createSync(recursive: true);
          }
          return ProcessResult(0, 0, '', '');
        },
        launcher: (path, args) async {
          launched.add((path, args));
          return Process.start('true', const []);
        },
      );
      expect(await repo.install(archive.path), isNull);
      expect(ran.map((r) => r.$1), [
        '/usr/bin/hdiutil',
        '/usr/bin/ditto',
        '/usr/bin/hdiutil',
      ]);
      expect(ran[0].$2, [
        'attach',
        '-nobrowse',
        '-readonly',
        '-noautoopen',
        '-mountpoint',
        mount,
        archive.path,
      ]);
      expect(ran[1].$2, [
        '$mount/OpenX11SE.app',
        '${downloads.path}/staged/OpenX11SE.app',
      ]);
      expect(ran[2].$2, ['detach', mount, '-force']);
      final (shell, args) = launched.single;
      expect(shell, '/bin/sh');
      expect(args[1], macSwapScript);
      expect(args[3], '$pid');
      expect(args[4], '${downloads.path}/staged/OpenX11SE.app');
      expect(args[5], '${apps.path}/OpenX11SE.app');
    }, testOn: '!windows');

    test('launches the AppImage swap script', () async {
      final bin = await Directory.systemTemp.createTemp('update_bin');
      addTearDown(() => bin.delete(recursive: true));
      final image = File('${downloads.path}/OpenX11SE-Linux-1.2.0.AppImage')
        ..writeAsStringSync('new');
      final launched = <(String, List<String>)>[];
      final repo = GitHubUpdateRepository(
        downloadDirectory: downloads,
        platform: UpdatePlatform.linux,
        appImage: '${bin.path}/OpenX11SE.AppImage',
        launcher: (path, args) async {
          launched.add((path, args));
          return Process.start('true', const []);
        },
      );

      expect(await repo.install(image.path), isNull);
      final (shell, args) = launched.single;
      expect(shell, '/bin/sh');
      expect(args[1], linuxSwapScript);
      expect(args[3], '$pid');
      expect(args[4], image.path);
      expect(args[5], '${bin.path}/OpenX11SE.AppImage');
    }, testOn: 'linux');

    test('the AppImage swap script replaces and relaunches', () async {
      final bin = await Directory.systemTemp.createTemp('update_bin');
      addTearDown(() => bin.delete(recursive: true));
      final target = File('${bin.path}/OpenX11SE.AppImage')
        ..writeAsStringSync('old');
      final marker = File('${bin.path}/started');
      final image = File('${downloads.path}/OpenX11SE-Linux-1.2.0.AppImage')
        ..writeAsStringSync('#!/bin/sh\ntouch "${marker.path}"\n');
      final exited = await Process.start('true', const []);
      await exited.exitCode;

      final result = await Process.run('/bin/sh', [
        '-c',
        linuxSwapScript,
        'openx11se-update',
        '${exited.pid}',
        image.path,
        target.path,
      ]);

      expect(result.exitCode, 0);
      expect(target.readAsStringSync(), startsWith('#!/bin/sh'));
      expect(target.statSync().modeString(), 'rwxr-xr-x');
      expect(image.existsSync(), isFalse);
      expect(File('${target.path}.new').existsSync(), isFalse);
      for (var i = 0; i < 50 && !marker.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(marker.existsSync(), isTrue);
    }, testOn: 'linux');

    test('needs a writable AppImage folder', () async {
      final image = File('${downloads.path}/OpenX11SE-Linux-1.2.0.AppImage')
        ..writeAsStringSync('new');
      Future<UpdateErrorKind?> install(String? appImage) =>
          GitHubUpdateRepository(
            downloadDirectory: downloads,
            platform: UpdatePlatform.linux,
            appImage: appImage,
            launcher: (_, _) => fail('should not launch'),
          ).install(image.path);

      expect(
        await install('/proc/OpenX11SE.AppImage'),
        UpdateErrorKind.folderNotWritable,
      );
      expect(await install(null), UpdateErrorKind.launchFailed);
    }, testOn: 'linux');

    test('rejects a macOS image without an app', () async {
      final apps = await Directory.systemTemp.createTemp('update_apps');
      addTearDown(() => apps.delete(recursive: true));
      final archive = File('${downloads.path}/update.dmg')
        ..writeAsStringSync('dmg');
      var launched = false;
      final ran = <String>[];
      var attachCode = 0;
      final repo = GitHubUpdateRepository(
        downloadDirectory: downloads,
        platform: UpdatePlatform.macos,
        executable: '${apps.path}/OpenX11SE.app/Contents/MacOS/OpenX11SE',
        runner: (_, args) async {
          ran.add(args.first);
          return ProcessResult(
            0,
            args.first == 'attach' ? attachCode : 0,
            '',
            '',
          );
        },
        launcher: (_, _) async {
          launched = true;
          return Process.start('true', const []);
        },
      );
      expect(await repo.install(archive.path), UpdateErrorKind.launchFailed);
      expect(ran, ['attach', 'detach']);
      ran.clear();
      attachCode = 1;
      expect(await repo.install(archive.path), UpdateErrorKind.launchFailed);
      expect(ran, ['detach', 'attach', 'detach']);
      expect(launched, isFalse);
      expect(Directory('${downloads.path}/staged').existsSync(), isFalse);
    }, testOn: '!windows');

    test('unmounts the image when copying throws', () async {
      final apps = await Directory.systemTemp.createTemp('update_apps');
      addTearDown(() => apps.delete(recursive: true));
      final archive = File('${downloads.path}/update.dmg')
        ..writeAsStringSync('dmg');
      final ran = <String>[];
      final repo = GitHubUpdateRepository(
        downloadDirectory: downloads,
        platform: UpdatePlatform.macos,
        executable: '${apps.path}/OpenX11SE.app/Contents/MacOS/OpenX11SE',
        runner: (path, args) async {
          ran.add(path == '/usr/bin/ditto' ? 'ditto' : args.first);
          if (args.first == 'attach') {
            Directory(
              '${downloads.path}/mount/OpenX11SE.app',
            ).createSync(recursive: true);
          }
          if (path == '/usr/bin/ditto') {
            throw const ProcessException('ditto', []);
          }
          return ProcessResult(0, 0, '', '');
        },
        launcher: (_, _) async => Process.start('true', const []),
      );
      expect(await repo.install(archive.path), UpdateErrorKind.launchFailed);
      expect(ran, ['attach', 'ditto', 'detach']);
      expect(
        await GitHubUpdateRepository(
          downloadDirectory: downloads,
          platform: UpdatePlatform.macos,
          executable: '/usr/local/bin/openx11se',
        ).install(archive.path),
        UpdateErrorKind.launchFailed,
      );
      expect(
        await GitHubUpdateRepository(
          downloadDirectory: downloads,
          platform: UpdatePlatform.macos,
          executable:
              '/private/var/folders/x/AppTranslocation/1/d/OpenX11SE.app'
              '/Contents/MacOS/OpenX11SE',
        ).install(archive.path),
        UpdateErrorKind.moveRequired,
      );
    }, testOn: '!windows');
  });

  group('UpdateViewModel', () {
    late FakeUpdateRepository repo;
    late SettingsRepository settings;
    late DeviceRepository device;
    late FakeHidTransport transport;
    late EditSessionViewModel edit;
    late ToastController toasts;
    late UpdateViewModel vm;
    late int quits;
    late DateTime now;

    setUp(() async {
      final db = AppDatabase(sqlite3.openInMemory());
      final profiles = ProfileRepository(db);
      await profiles.ensureDefault();
      settings = SettingsRepository(db);
      transport = FakeHidTransport();
      device = DeviceRepository(
        transport,
        timing: (_) => const DeviceTiming(
          reportGap: Duration.zero,
          readDelay: Duration.zero,
          ackTimeout: Duration(milliseconds: 150),
        ),
      );
      toasts = ToastController();
      edit = EditSessionViewModel(
        device: device,
        profiles: profiles,
        macros: MacroRepository(db),
        settings: settings,
        toasts: toasts,
      );
      repo = FakeUpdateRepository();
      quits = 0;
      now = DateTime.utc(2026, 10, 9, 9);
      vm = UpdateViewModel(
        repository: repo,
        settings: settings,
        edit: edit,
        toasts: toasts,
        currentVersion: v('1.0.0'),
        quit: () async => quits++,
        now: () => now,
      );
    });

    tearDown(() async {
      vm.dispose();
      edit.dispose();
      toasts.dispose();
      await device.dispose();
    });

    test('manual check finds an update and opens the dialog', () async {
      repo.checks.add(UpdateAvailable(release()));
      final statuses = <UpdateStatus>[];
      vm.addListener(() => statuses.add(vm.status));
      await vm.checkNow();
      expect(statuses.first, UpdateStatus.checking);
      expect(vm.status, UpdateStatus.available);
      expect(vm.dialogOpen, isTrue);
      expect(vm.statusText, 'Version 1.2.0 is available');
      expect((await settings.settings()).lastUpdateCheck, now);
    });

    test('reports up to date', () async {
      repo.checks.add(const UpToDate());
      await vm.checkNow();
      expect(vm.status, UpdateStatus.upToDate);
      expect(vm.dialogOpen, isFalse);
      expect(vm.statusText, 'Version 1.0.0 · up to date');
    });

    test('offline and rate-limited checks fail with retry', () async {
      repo.checks
        ..add(const UpdateCheckFailed(UpdateErrorKind.offline))
        ..add(
          UpdateCheckFailed(
            UpdateErrorKind.rateLimited,
            retryAt: DateTime(2026, 10, 9, 14, 5),
          ),
        )
        ..add(UpdateAvailable(release()));
      await vm.checkNow();
      expect(vm.status, UpdateStatus.failed);
      expect(vm.errorText, contains('connection'));
      expect((await settings.settings()).lastUpdateCheck, isNull);
      await vm.retry();
      expect(vm.errorText, contains('14:05'));
      await vm.retry();
      expect(vm.status, UpdateStatus.available);
    });

    test('downloads with progress, then installs and quits', () async {
      repo.checks.add(UpdateAvailable(release()));
      repo.downloads.add(const UpdateDownloaded('C:/tmp/Setup.exe'));
      repo.downloadGate = Completer();
      await vm.checkNow();
      final download = vm.download();
      expect(vm.status, UpdateStatus.downloading);
      expect(vm.progress, 0.5);
      repo.downloadGate!.complete();
      await download;
      expect(vm.status, UpdateStatus.ready);
      expect(vm.canInstall, isTrue);
      await vm.install();
      expect(repo.installed, ['C:/tmp/Setup.exe']);
      expect(quits, 1);
    });

    test('a tampered installer is rejected with a clear message', () async {
      repo.checks.add(UpdateAvailable(release()));
      repo.downloads
        ..add(const UpdateDownloadFailed(UpdateErrorKind.checksumMismatch))
        ..add(const UpdateDownloaded('C:/tmp/Setup.exe'));
      await vm.checkNow();
      await vm.download();
      expect(vm.status, UpdateStatus.failed);
      expect(vm.errorText, contains('failed verification'));
      expect(vm.canInstall, isFalse);
      expect(
        toasts.toasts.map((t) => t.text),
        contains('Update rejected — the installer failed verification'),
      );
      await vm.install();
      expect(repo.installed, isEmpty);
      await vm.retry();
      expect(vm.status, UpdateStatus.ready);
    });

    test('a failed launch keeps the app running', () async {
      repo.checks.add(UpdateAvailable(release()));
      repo.downloads.add(const UpdateDownloaded('C:/tmp/Setup.exe'));
      repo.installError = UpdateErrorKind.launchFailed;
      await vm.checkNow();
      await vm.download();
      await vm.install();
      expect(vm.status, UpdateStatus.failed);
      expect(quits, 0);
      repo.installError = null;
      await vm.retry();
      expect(quits, 1);
    });

    test('blocks installing while writing and warns about edits', () async {
      transport.factories['wired'] = () =>
          FakeHidConnection(wiredDevice, autoAck: false);
      device.start();
      transport.setPresent([wiredDevice]);
      await until(() => edit.staged != null);
      repo.checks.add(UpdateAvailable(release()));
      repo.downloads.add(const UpdateDownloaded('C:/tmp/Setup.exe'));
      await vm.checkNow();
      await vm.download();
      edit.stage((s) => s.copyWith(polling: PollingRate.hz500));
      expect(vm.hasUnappliedEdits, isTrue);
      final apply = edit.apply();
      await until(() => edit.writing);
      expect(vm.writeInProgress, isTrue);
      expect(vm.canInstall, isFalse);
      await vm.install();
      expect(repo.installed, isEmpty);
      await apply;
      await until(() => !edit.writing);
      expect(vm.canInstall, isTrue);
    });

    test('start-up check runs at most once a day and toasts', () async {
      repo.checks
        ..add(UpdateAvailable(release()))
        ..add(const UpToDate());
      await vm.checkOnStartup();
      expect(repo.checkCount, 1);
      expect(vm.dialogOpen, isFalse);
      final toast = toasts.toasts.singleWhere((t) => t.hasAction);
      expect(toast.text, 'Update available — OpenX11SE 1.2.0');
      toast.onAction!();
      expect(vm.dialogOpen, isTrue);

      now = now.add(const Duration(hours: 23));
      await vm.checkOnStartup();
      expect(repo.checkCount, 1);
      now = now.add(const Duration(hours: 2));
      await vm.checkOnStartup();
      expect(repo.checkCount, 2);
    });

    test('start-up check is skipped when turned off', () async {
      await vm.setAutoCheck(false);
      expect((await settings.settings()).autoCheckUpdates, isFalse);
      await vm.checkOnStartup();
      expect(repo.checkCount, 0);
    });
  });

  test('unsupported platforms have no updater', () async {
    const repo = NoUpdateRepository();
    expect(repo.isSupported, isFalse);
    expect(await repo.check(v('1.0.0')), isA<UpToDate>());
  });
}
