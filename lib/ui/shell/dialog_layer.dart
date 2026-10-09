import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/motion.dart';
import '../widgets/text_input.dart';
import 'dialog_request.dart';
import 'shell_view_model.dart';

class DialogLayer extends StatelessWidget {
  const DialogLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final request = context.select<ShellViewModel, DialogRequest?>(
      (s) => s.dialog,
    );
    if (request == null) return const SizedBox.shrink();
    final shell = context.read<ShellViewModel>();
    return Positioned.fill(
      child: EntranceTransition(
        kind: Entrance.fade,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: shell.closeDialog,
                child: ColoredBox(color: context.nocturne.backdrop),
              ),
            ),
            EntranceTransition(
              kind: Entrance.pop,
              duration: const Duration(milliseconds: 200),
              child: _ConfirmDialog(key: ObjectKey(request), request: request),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({super.key, required this.request});

  final DialogRequest request;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  late final _text = TextEditingController(text: widget.request.initialText);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _confirm() => context.read<ShellViewModel>().closeDialog(
    widget.request.hasInput ? _text.text : '',
  );

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final shell = context.read<ShellViewModel>();
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: r.title,
      child: AppDialog(
        title: r.title,
        body: r.body,
        icon: r.icon ?? AppIcons.info,
        danger: r.danger,
        content: r.hasInput
            ? TextInput(
                controller: _text,
                autofocus: true,
                semanticLabel: 'Name',
                onSubmitted: (_) => _confirm(),
              )
            : null,
        actions: [
          AppButton(label: 'Cancel', onPressed: shell.closeDialog),
          r.danger
              ? AppButton(
                  label: r.confirmLabel,
                  variant: AppButtonVariant.danger,
                  onPressed: _confirm,
                )
              : AppButton.primary(label: r.confirmLabel, onPressed: _confirm),
        ],
      ),
    );
  }
}
