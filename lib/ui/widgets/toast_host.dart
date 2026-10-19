import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/nocturne_theme.dart';
import 'app_button.dart';
import 'motion.dart';

enum ToastKind { info, success, warning, error }

@immutable
class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.text,
    this.kind = ToastKind.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final int id;
  final String text;
  final ToastKind kind;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  bool get hasAction => actionLabel != null && onAction != null;
}

class ToastController extends ChangeNotifier {
  ToastController({
    this.lifetime = const Duration(milliseconds: 3600),
    this.maxVisible = 3,
  });

  final Duration lifetime;
  final int maxVisible;

  final List<ToastMessage> _toasts = [];
  final Map<int, Timer> _timers = {};
  int _nextId = 0;
  bool _disposed = false;

  List<ToastMessage> get toasts => List.unmodifiable(_toasts);

  void show(
    String text, {
    ToastKind kind = ToastKind.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? lifetime,
  }) {
    final toast = ToastMessage(
      id: _nextId++,
      text: text,
      kind: kind,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _toasts.add(toast);
    while (_toasts.length > maxVisible) {
      _timers.remove(_toasts.removeAt(0).id)?.cancel();
    }
    _timers[toast.id] = Timer(
      lifetime ?? this.lifetime,
      () => dismiss(toast.id),
    );
    notifyListeners();
  }

  void dismiss(int id) {
    if (_disposed) return;
    _timers.remove(id)?.cancel();
    final before = _toasts.length;
    _toasts.removeWhere((t) => t.id == id);
    if (_toasts.length != before) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.toasts, this.onDismiss});

  final List<ToastMessage> toasts;
  final ValueChanged<int>? onDismiss;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      end: 16,
      bottom: 72,
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in toasts)
              Padding(
                key: ValueKey(t.id),
                padding: const EdgeInsets.only(top: 8),
                child: EntranceTransition(
                  kind: Entrance.pop,
                  duration: const Duration(milliseconds: 250),
                  child: _ToastCard(
                    toast: t,
                    onTap: onDismiss == null ? null : () => onDismiss!(t.id),
                    onAction: t.hasAction
                        ? () {
                            onDismiss?.call(t.id);
                            t.onAction!();
                          }
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.toast, this.onTap, this.onAction});

  final ToastMessage toast;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final (color, fallback) = switch (toast.kind) {
      ToastKind.success => (p.success, AppIconsFill.checkCircle),
      ToastKind.error => (p.danger, AppIconsFill.xCircle),
      ToastKind.warning => (p.warning, AppIconsFill.warning),
      ToastKind.info => (p.accent, AppIconsFill.info),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 380),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: n.radius.mdAll,
          boxShadow: p.shadowMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(toast.icon ?? fallback, size: 18, color: color),
            const SizedBox(width: 10),
            Flexible(child: Text(tr(toast.text), style: n.text.small)),
            if (onAction != null) ...[
              const SizedBox(width: 10),
              AppButton(
                label: toast.actionLabel!,
                size: AppButtonSize.small,
                variant: AppButtonVariant.ghost,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
