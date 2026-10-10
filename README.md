# OpenX11SE

Open-source configuration app for the Attack Shark X11SE mouse on Windows.

- DPI stages, polling rate, angle snap and ripple control
- Button remapping with keyboard shortcuts, media keys and macros
- Lighting modes, brightness and speed
- Sleep, deep sleep and debounce
- Macro recorder and editor
- Profiles with import, export and import from the vendor software

Not affiliated with Attack Shark.

## Requirements

- Windows 10 1809 or later.
- The mouse connected over the USB-C cable or the 2.4 GHz dongle.

## Development

```
flutter pub get
flutter run -d windows
flutter test
```

## Windows installer

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```
powershell -ExecutionPolicy Bypass -File tool\build_windows_installer.ps1
```

The installer and its SHA-256 file are written to `build\installer`. It installs per user under
`%LOCALAPPDATA%\Programs\OpenX11SE` and needs no administrator rights.

## Testing on hardware

See [docs/hardware-checklist.md](docs/hardware-checklist.md).

## License

MIT
