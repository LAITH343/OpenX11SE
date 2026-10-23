# OpenX11SE

OpenX11SE is an open-source app for setting up the Attack Shark X11SE mouse. It runs on Windows, macOS and
Linux and covers the settings you'd otherwise change in the vendor software. It talks to the mouse
directly over USB, through the cable or the 2.4 GHz dongle, and needs no drivers.

[![Latest release](https://img.shields.io/github/v/release/LAITH343/OpenX11SE?label=release)](https://github.com/LAITH343/OpenX11SE/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/LAITH343/OpenX11SE/total)](https://github.com/LAITH343/OpenX11SE/releases)
[![Windows](https://img.shields.io/badge/Windows-10%201809%2B-0078D4?logo=windows&logoColor=white)](#windows)
[![macOS](https://img.shields.io/badge/macOS-12%2B-000000?logo=apple&logoColor=white)](#macos-and-linux)
[![Linux](https://img.shields.io/badge/Linux-x86__64-FCC624?logo=linux&logoColor=black)](#macos-and-linux)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Why I made this

I built OpenX11SE because the official app only runs on Windows, and even there it isn't great to use.
The interface is hard to find your way around, changing simple things takes more clicks than it should,
and some features I wanted just weren't there. So I made the app I wished came with the mouse: one that
runs everywhere and keeps every setting easy to reach.

I hope you enjoy using it ^_^

## Features

What you can change:

- DPI stages, polling rate, angle snap and ripple control
- Button remapping with keyboard shortcuts, media keys and macros
- Lighting modes, brightness and speed
- Sleep, deep sleep and debounce
- Macros, recorded or written by hand
- Profiles, with import and export, and import from the vendor software

It also shows the battery level and charging state, and it can sit in the tray and start with your system.

This project isn't affiliated with Attack Shark.

## Install

Once installed, the app updates itself from Settings > About > Check for updates.

### Windows

Download `OpenX11SE-Setup-<version>.exe` from the
[latest release](https://github.com/LAITH343/OpenX11SE/releases/latest) and run it. It installs for your user
only, so you won't get an administrator prompt.

### macOS and Linux

Run this in a terminal:

```
curl -fsSL https://raw.githubusercontent.com/LAITH343/OpenX11SE/master/install.sh | sh
```

- **macOS:** the app goes to `/Applications` (or `~/Applications` if you can't write there).
- **Linux:** the AppImage goes to `~/.local/bin/OpenX11SE.AppImage`, along with a menu entry and icon. The
  first time, the script asks for `sudo` to add a udev rule (`/etc/udev/rules.d/70-openx11se.rules`) so you
  can talk to the mouse without root. Unplug the mouse and plug it back in after that.

A few notes for Linux:

- Only x86_64 builds are published for now.
- The tray icon needs an AppIndicator host. On GNOME, that means the AppIndicator extension.
- The import and export dialogs use `zenity` or `kdialog`, so you need one of them installed.

## Development

You need the [Flutter](https://docs.flutter.dev/get-started/install) stable SDK, plus the desktop toolchain
for the platform you're building on.

```
flutter pub get
flutter run -d windows   # or macos, or linux
```

On Linux, install the build dependencies first (Debian/Ubuntu names):

```
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libayatana-appindicator3-dev
```

Release builds have a script per platform. Each one writes its output and a `.sha256` file under `build/`:

| Platform | Command | Output |
|---|---|---|
| Windows | `powershell -ExecutionPolicy Bypass -File tool\build_windows_installer.ps1` (needs [Inno Setup 6](https://jrsoftware.org/isinfo.php)) | `build\installer` |
| macOS | `./tool/build_macos_release.sh` | `build/macos-release` |
| Linux | `./tool/build_linux_appimage.sh` | `build/linux-release` |

The macOS build is signed with a self-signed certificate. Using the same one for every release means macOS
keeps the app's permissions after an update. Create it once and keep the `.p12` and its password somewhere
safe:

```
MACOS_CERTIFICATE_PASSWORD=<password> ./tool/create_macos_signing_cert.sh
security import openx11se-signing.p12 -k ~/Library/Keychains/login.keychain-db -P <password> -T /usr/bin/codesign
```

Set `MACOS_SIGN_IDENTITY` if your certificate isn't named `OpenX11SE Self-Signed`.

Pushing a `v<version>` tag builds all three platforms and publishes the release. The details are in
[docs/releasing.md](docs/releasing.md).

## Testing

Run the unit and widget tests with:

```
flutter test
```

They don't need a mouse. Anything that touches the actual hardware is covered by the manual checklist in
[docs/hardware-checklist.md](docs/hardware-checklist.md). Please go through it, over both the cable and the
dongle, before a release or after changing anything in the HID or protocol code.

## License and disclaimer

OpenX11SE is released under the [MIT License](LICENSE).

This isn't an official Attack Shark tool. OpenX11SE writes settings straight to the mouse, and a bad write
could leave it misbehaving or, in the worst case, unusable. **You use this software at your own risk.** The authors aren't responsible for any
damage to your device, any data loss or any other problem that comes from using it. If something goes
wrong, Settings > Restore mouse to factory defaults is the first thing to try.
