import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nocturne_theme.dart';
import '../buttons/buttons_view_model.dart';
import '../buttons/function_picker.dart';
import '../macros/macro_assign_dialog.dart';
import '../macros/macro_library_view_model.dart';
import '../settings/update_dialog.dart';
import '../settings/update_view_model.dart';
import '../widgets/toast_host.dart';
import 'device_pane.dart';
import 'device_states.dart';
import 'dialog_layer.dart';
import 'edit_session_view_model.dart';
import 'profile_menu.dart';
import 'section_content.dart';
import 'shell_view_model.dart';
import 'taskbar.dart';
import 'title_bar.dart';
import 'window/window_controls.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const compactWidth = 1080.0;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _menuLink = LayerLink();
  String? _title;

  void _syncTitle(String profileName) {
    final title = 'OpenX11SE — $profileName';
    if (!hasWindowChrome || title == _title) return;
    _title = title;
    unawaited(setWindowTitle(title));
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final shell = context.read<ShellViewModel>();
    final edit = context.read<EditSessionViewModel>();
    final buttons = context.read<ButtonsViewModel>();
    final macros = context.read<MacroLibraryViewModel>();
    final updates = context.read<UpdateViewModel>();
    final profileName = context.select<ShellViewModel, String>(
      (s) => s.profileName,
    );
    _syncTitle(profileName);
    final status = context.select<ShellViewModel, ConnectionStatus>(
      (s) => s.status,
    );
    final showsContent =
        status == ConnectionStatus.connected ||
        status == ConnectionStatus.disconnected;
    final showsTaskbar = showsContent || status == ConnectionStatus.loading;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            unawaited(edit.apply()),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            unawaited(edit.apply()),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            shell.dismissTopmost() ||
            updates.closeDialog() ||
            buttons.closePicker() ||
            macros.closeAssign(),
      },
      child: Focus(
        autofocus: true,
        child: ProfileMenuAnchor(
          link: _menuLink,
          child: Material(
            color: n.bg,
            child: Column(
              children: [
                if (hasWindowChrome) TitleBar(profileName: profileName),
                Expanded(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < AppShell.compactWidth;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (showsContent)
                                      DevicePane(compact: compact),
                                    const Expanded(child: _Main()),
                                  ],
                                ),
                              ),
                              if (showsTaskbar)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Taskbar(compact: compact),
                                ),
                            ],
                          );
                        },
                      ),
                      const ProfileMenuLayer(),
                      const FunctionPickerLayer(),
                      const MacroAssignLayer(),
                      const UpdateDialogLayer(),
                      const DialogLayer(),
                      const _Toasts(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Main extends StatelessWidget {
  const _Main();

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final status = context.select<ShellViewModel, ConnectionStatus>(
      (s) => s.status,
    );
    final writing = context.select<EditSessionViewModel, bool>(
      (e) => e.writing,
    );
    final section = context.select<ShellViewModel, Object>((s) => s.section);
    final body = switch (status) {
      ConnectionStatus.none => const NoDeviceState(),
      ConnectionStatus.asleep => const AsleepState(),
      ConnectionStatus.off => const OffState(),
      ConnectionStatus.loading => const LoadingState(),
      ConnectionStatus.connected ||
      ConnectionStatus.disconnected => SectionContent(key: ValueKey(section)),
    };
    return Stack(
      children: [
        Positioned.fill(child: body),
        if (writing)
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.progress,
              child: AbsorbPointer(
                child: ColoredBox(color: n.bg.withValues(alpha: 0.3)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Toasts extends StatelessWidget {
  const _Toasts();

  @override
  Widget build(BuildContext context) {
    final toasts = context.watch<ToastController>();
    return ToastHost(toasts: toasts.toasts, onDismiss: toasts.dismiss);
  }
}
