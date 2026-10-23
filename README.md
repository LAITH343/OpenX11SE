# OpenX11SE

Open-source configuration app for the Attack Shark X11SE mouse on Windows, macOS and Linux.

- DPI stages, polling rate, angle snap and ripple control
- Button remapping with keyboard shortcuts, media keys and macros
- Lighting modes, brightness and speed
- Sleep, deep sleep and debounce
- Macro recorder and editor
- Profiles with import, export and import from the vendor software

Not affiliated with Attack Shark.

## Requirements

- Windows 10 1809 or later, macOS 12 or later, or x86_64 Linux with GTK 3.
- The mouse connected over the USB-C cable or the 2.4 GHz dongle.

## Development

```
flutter pub get
flutter run -d windows
flutter run -d macos
flutter run -d linux
flutter test
```

## Windows installer

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```
powershell -ExecutionPolicy Bypass -File tool\build_windows_installer.ps1
```

The installer and its SHA-256 file are written to `build\installer`. It installs per user under
`%LOCALAPPDATA%\Programs\OpenX11SE` and needs no administrator rights.

## Linux AppImage

Install the latest version (x86_64):

```
curl -fsSL https://raw.githubusercontent.com/LAITH343/OpenX11SE/master/install.sh | sh
```

The AppImage goes to `~/.local/bin/OpenX11SE.AppImage`, with a menu entry and icon under `~/.local/share`.
The script also asks for `sudo` once to add `/etc/udev/rules.d/70-openx11se.rules`, which lets the logged-in
user open the mouse without root (`TAG+="uaccess"`, so it needs systemd-logind or elogind). Replug the mouse
after the rule is added. Later versions install from Settings > About > Check for updates, or by running the
script again.

- The tray icon needs an AppIndicator host; on GNOME install the AppIndicator extension.
- File dialogs for profile import and export use `zenity` or `kdialog`.

Build it (needs `clang cmake ninja-build pkg-config libgtk-3-dev libayatana-appindicator3-dev`):

```
./tool/build_linux_appimage.sh
```

The AppImage and its SHA-256 file are written to `build/linux-release`.

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
