# Releasing

The Windows and macOS apps check `https://api.github.com/repos/LAITH343/OpenX11SE/releases/latest` and
offer any newer, non-draft, non-pre-release version. A release is only offered on a platform when it carries
both of that platform's assets:

- Windows: `OpenX11SE-Setup-<version>.exe` and `OpenX11SE-Setup-<version>.exe.sha256`
  (`<sha256>  OpenX11SE-Setup-<version>.exe`)
- macOS: `OpenX11SE-macOS-<version>.zip` and `OpenX11SE-macOS-<version>.zip.sha256`
  (`<sha256>  OpenX11SE-macOS-<version>.zip`)

The tag must be `v<version>`, matching `version` in `pubspec.yaml` (build number after `+` is ignored).

## Automated (tag push)

1. Bump `version` in `pubspec.yaml`, e.g. `1.1.0+2`, and commit it to `master`.
2. Tag and push:

   ```powershell
   git tag v1.1.0
   git push origin master v1.1.0
   ```

3. `.github/workflows/release.yml` runs the tests, builds the Windows installer with Inno Setup and the
   signed macOS archive, writes the checksums and publishes the GitHub release with all four assets. The release notes list every commit message
   since the previous `v*.*.*` tag (all commits for the first release); they are shown in the update dialog
   and can be edited on GitHub afterwards.

The macOS job signs with the self-signed certificate from two repository secrets:

- `MACOS_CERTIFICATE`: the base64 `.p12` (`openx11se-signing.p12.base64` from
  `tool/create_macos_signing_cert.sh`)
- `MACOS_CERTIFICATE_PASSWORD`: its password

Always use the same certificate. macOS ties permissions to it, and a new certificate makes users grant them
again after updating.

## Manual

1. Bump `version` in `pubspec.yaml` and commit.
2. Build (requires Inno Setup 6):

   ```powershell
   .\tool\build_windows_installer.ps1
   ```

   Output: `build\installer\OpenX11SE-Setup-<version>.exe` and `.exe.sha256`.
3. On a Mac with the signing certificate in the login keychain:

   ```sh
   ./tool/build_macos_release.sh
   ```

   Output: `build/macos-release/OpenX11SE-macOS-<version>.zip` and `.zip.sha256`.
4. Create the release with all four files:

   ```powershell
   gh release create v1.1.0 build\installer\OpenX11SE-Setup-1.1.0.exe build\installer\OpenX11SE-Setup-1.1.0.exe.sha256 build\macos-release\OpenX11SE-macOS-1.1.0.zip build\macos-release\OpenX11SE-macOS-1.1.0.zip.sha256 --title "OpenX11SE 1.1.0" --notes-file notes.md
   ```

Do not mark it as a pre-release or leave it as a draft; those are skipped by the updater.

## How an update installs

The app downloads the installer to `%TEMP%\OpenX11SE-update`, verifies its SHA-256 against the `.sha256`
asset (a mismatch deletes the file and nothing is installed), then runs it with
`/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /RELAUNCH=1` and quits. The installer
starts the new version when `/RELAUNCH=1` is given. Profiles, macros and settings live in the application
support directory and are not touched by the installer.

On macOS the app downloads the archive to the temp folder, verifies it the same way, extracts it with
`ditto` and quits. A detached script waits for the app to exit, replaces the running `OpenX11SE.app` with
the new one and opens it. The folder holding the app must be writable by the user; otherwise the install
step fails and nothing is changed.

## Verifying an update

1. Install an older build (e.g. `1.0.0`).
2. Publish a newer release as above.
3. Settings > About > Check for updates: the dialog shows the new version and notes; Download, then Install
   and restart. The app restarts on the new version with profiles and settings intact.
4. Tampering check: replace the `.sha256` asset with a wrong hash; the download is rejected with
   "The downloaded installer failed verification and was deleted."
