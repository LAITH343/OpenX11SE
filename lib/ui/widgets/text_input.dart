import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/nocturne_theme.dart';

class TextInput extends StatelessWidget {
  const TextInput({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixText,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.width,
    this.numeric = false,
    this.monospace = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.maxLength,
    this.autofocus = false,
    this.enabled = true,
    this.semanticLabel,
    this.inputFormatters,
    this.dense = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final String? suffixText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final double? width;
  final bool numeric;
  final bool monospace;
  final TextAlign textAlign;
  final TextStyle? style;
  final int? maxLength;
  final bool autofocus;
  final bool enabled;
  final String? semanticLabel;
  final List<TextInputFormatter>? inputFormatters;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final base = monospace ? n.text.mono : n.text.body;
    var textStyle = base.merge(style);
    if (numeric) textStyle = n.text.tabular(textStyle);

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      textAlign: textAlign,
      style: textStyle,
      cursorColor: n.accent,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (numeric) FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ...?inputFormatters,
      ],
      decoration: InputDecoration(
        hintText: hint == null ? null : tr(hint!),
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 7)
            : null,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 16, color: n.textMuted),
        prefixIconConstraints: const BoxConstraints(minWidth: 30),
        suffixText: suffixText,
        suffixStyle: n.text.micro.copyWith(color: n.textMuted),
      ),
    );

    final sized = SizedBox(
      width: width,
      child: Semantics(label: semanticLabel ?? label, child: field),
    );
    if (label == null) return sized;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr(label!), style: n.text.caption.copyWith(color: n.textLabel)),
        const SizedBox(height: 5),
        sized,
      ],
    );
  }
}
