import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'system_integration.dart';

SystemIntegration createPlatformIntegration() => Platform.isWindows
    ? WindowsSystemIntegration()
    : const NoSystemIntegration();

typedef _SetValueN =
    Int32 Function(
      IntPtr,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Uint32,
      Pointer<Void>,
      Uint32,
    );
typedef _SetValueD =
    int Function(int, Pointer<Utf16>, Pointer<Utf16>, int, Pointer<Void>, int);
typedef _DeleteValueN = Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>);
typedef _DeleteValueD = int Function(int, Pointer<Utf16>, Pointer<Utf16>);

class WindowsSystemIntegration
    with TrayListener, WindowListener
    implements SystemIntegration {
  static const _currentUser = 0x80000001;
  static const _stringValue = 1;
  static const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'OpenX11SE';
  static const _showKey = 'show';
  static const _quitKey = 'quit';

  bool _tray = false;
  bool _listening = false;

  @override
  bool get supportsStartup => true;

  @override
  bool get supportsTray => true;

  @override
  Future<void> setLaunchAtStartup(bool enabled) async {
    final advapi = DynamicLibrary.open('advapi32.dll');
    final key = _runKey.toNativeUtf16();
    final name = _valueName.toNativeUtf16();
    try {
      if (enabled) {
        final setValue = advapi.lookupFunction<_SetValueN, _SetValueD>(
          'RegSetKeyValueW',
        );
        final command =
            '"${Platform.resolvedExecutable}" $startMinimisedArgument';
        final data = command.toNativeUtf16();
        try {
          setValue(
            _currentUser,
            key,
            name,
            _stringValue,
            data.cast(),
            (command.length + 1) * 2,
          );
        } finally {
          calloc.free(data);
        }
      } else {
        advapi.lookupFunction<_DeleteValueN, _DeleteValueD>(
          'RegDeleteKeyValueW',
        )(_currentUser, key, name);
      }
    } finally {
      calloc.free(key);
      calloc.free(name);
    }
  }

  @override
  Future<void> setMinimiseToTray(bool enabled) async {
    if (enabled == _tray) return;
    _tray = enabled;
    if (!_listening) {
      _listening = true;
      trayManager.addListener(this);
      windowManager.addListener(this);
    }
    await windowManager.setPreventClose(enabled);
    if (!enabled) {
      await trayManager.destroy();
      return;
    }
    await trayManager.setIcon('assets/icons/tray.ico');
    await trayManager.setToolTip('OpenX11SE');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _showKey, label: 'Show OpenX11SE'),
          MenuItem.separator(),
          MenuItem(key: _quitKey, label: 'Quit'),
        ],
      ),
    );
  }

  @override
  Future<void> quit() async {
    try {
      if (_tray) await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } finally {
      exit(0);
    }
  }

  Future<void> _show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() => _show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _showKey:
        _show();
      case _quitKey:
        windowManager.destroy();
    }
  }

  @override
  void onWindowClose() {
    if (_tray) windowManager.hide();
  }
}
