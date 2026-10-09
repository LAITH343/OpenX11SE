# Releasing

The Windows app checks `https://api.github.com/repos/LAITH343/OpenX11SE/releases/latest` and offers any
newer, non-draft, non-pre-release version. A release is only offered when it carries both assets:

- `OpenX11SE-Setup-<version>.exe`
- `OpenX11SE-Setup-<version>.exe.sha256` (`<sha256>  OpenX11SE-Setup-<version>.exe`)

The tag must be `v<version>`, matching `version` in `pubspec.yaml` (build number after `+` is ignored).

## Automated (tag push)

1. Bump `version` in `pubspec.yaml`, e.g. `1.1.0+2`, and commit it to `master`.
2. Tag and push:

   ```powershell
   git tag v1.1.0
   git push origin master v1.1.0
   ```

3. `.github/workflows/release.yml` runs the tests, builds the installer with Inno Setup, writes the
   checksum and publishes the GitHub release with both assets. The release notes list every commit message
   since the previous `v*.*.*` tag (all commits for the first release); they are shown in the update dialog
   and can be edited on GitHub afterwards.

## Manual

1. Bump `version` in `pubspec.yaml` and commit.
2. Build (requires Inno Setup 6):

   ```powershell
   .\tool\build_windows_installer.ps1
   ```

   Output: `build\installer\OpenX11SE-Setup-<version>.exe` and `.exe.sha256`.
3. Create the release with both files:

   ```powershell
   gh release create v1.1.0 build\installer\OpenX11SE-Setup-1.1.0.exe build\installer\OpenX11SE-Setup-1.1.0.exe.sha256 --title "OpenX11SE 1.1.0" --notes-file notes.md
   ```

Do not mark it as a pre-release or leave it as a draft; those are skipped by the updater.

## How an update installs

The app downloads the installer to `%TEMP%\OpenX11SE-update`, verifies its SHA-256 against the `.sha256`
asset (a mismatch deletes the file and nothing is installed), then runs it with
`/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /RELAUNCH=1` and quits. The installer
starts the new version when `/RELAUNCH=1` is given. Profiles, macros and settings live in the application
support directory and are not touched by the installer.

## Verifying an update

1. Install an older build (e.g. `1.0.0`).
2. Publish a newer release as above.
3. Settings > About > Check for updates: the dialog shows the new version and notes; Download, then Install
   and restart. The app restarts on the new version with profiles and settings intact.
4. Tampering check: replace the `.sha256` asset with a wrong hash; the download is rejected with
   "The downloaded installer failed verification and was deleted."
