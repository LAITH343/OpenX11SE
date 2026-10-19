import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/nocturne_theme.dart';

typedef PressableBuilder =
    Widget Function(BuildContext context, Set<WidgetState> states);

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.onHover,
    this.focusRadius,
    this.tooltip,
    this.semanticLabel,
    this.selected,
    this.toggled,
    this.focusNode,
    this.autofocus = false,
    this.dimWhenDisabled = true,
    this.isButton = true,
  });

  final VoidCallback? onPressed;
  final PressableBuilder builder;
  final ValueChanged<bool>? onHover;
  final BorderRadius? focusRadius;
  final String? tooltip;
  final String? semanticLabel;
  final bool? selected;
  final bool? toggled;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool dimWhenDisabled;
  final bool isButton;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  Set<WidgetState> get _states => {
    if (!_enabled) WidgetState.disabled,
    if (_hovered && _enabled) WidgetState.hovered,
    if (_pressed && _enabled) WidgetState.pressed,
    if (_focused) WidgetState.focused,
    if (widget.selected ?? false) WidgetState.selected,
  };

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHover?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final radius = widget.focusRadius ?? n.radius.mdAll;
    final ringInset = -(n.focusRingOffset + n.focusRingWidth);

    Widget child = Stack(
      clipBehavior: Clip.none,
      children: [
        widget.builder(context, _states),
        if (_focused)
          Positioned(
            left: ringInset,
            top: ringInset,
            right: ringInset,
            bottom: ringInset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius + BorderRadius.circular(-ringInset),
                  border: Border.all(color: n.accent, width: n.focusRingWidth),
                ),
              ),
            ),
          ),
      ],
    );

    child = FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onShowHoverHighlight: _setHovered,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: child,
      ),
    );

    if (!_enabled && widget.dimWhenDisabled) {
      child = Opacity(opacity: n.disabledOpacity, child: child);
    }

    child = Semantics(
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      child: child,
    );

    final tip = widget.tooltip;
    if (tip != null && tip.isNotEmpty) {
      child = Tooltip(message: tr(tip), child: child);
    }
    return child;
  }
}
