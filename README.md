# OpenX11SE

Open-source configuration app for the Attack Shark X11SE mouse on Windows and macOS.

- DPI stages, polling rate, angle snap and ripple control
- Button remapping with keyboard shortcuts, media keys and macros
- Lighting modes, brightness and speed
- Sleep, deep sleep and debounce
- Macro recorder and editor
- Profiles with import, export and import from the vendor software

Not affiliated with Attack Shark.

## Requirements

- Windows 10 1809 or later, or macOS 12 or later.
- The mouse connected over the USB-C cable or the 2.4 GHz dongle.

## Development

```
flutter pub get
flutter run -d windows
flutter run -d macos
flutter test
```

## Windows installer

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```
powershell -ExecutionPolicy Bypass -File tool\build_windows_installer.ps1
```

The installer and its SHA-256 file are written to `build\installer`. It installs per user under
`%LOCALAPPDATA%\Programs\OpenX11SE` and needs no administrator rights.

## macOS app

Install the latest version from Terminal:

```
curl -fsSL https://raw.githubusercontent.com/LAITH343/OpenX11SE/master/install.sh | sh
```

Later versions install from Settings > About > Check for updates.

Keeping the same certificate for every release keeps macOS permissions across updates.

Create the certificate once and keep the `.p12` file and its password safe:

```
MACOS_CERTIFICATE_PASSWORD=<password> ./tool/create_macos_signing_cert.sh
security import openx11se-signing.p12 -k ~/Library/Keychains/login.keychain-db -P <password> -T /usr/bin/codesign
```

Build, sign and package:

```
./tool/build_macos_release.sh
```

The disk image and its SHA-256 file are written to `build/macos-release`. Set `MACOS_SIGN_IDENTITY` when the
certificate has a name other than `OpenX11SE Self-Signed`.

## Testing on hardware

See [docs/hardware-checklist.md](docs/hardware-checklist.md).

## License

MIT
