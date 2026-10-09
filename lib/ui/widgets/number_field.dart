import 'package:flutter/material.dart';

import 'text_input.dart';

class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onCommit,
    this.width,
    this.min = 0,
    this.max,
    this.suffix,
    this.semanticLabel,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback? onCommit;
  final double? width;
  final int min;
  final int? max;
  final String? suffix;
  final String? semanticLabel;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final _text = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant NumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && '${widget.value}' != _text.text) {
      _text.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) return;
    widget.onCommit?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus) _text.text = '${widget.value}';
    });
  }

  void _onChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    final max = widget.max;
    widget.onChanged(max == null ? parsed : parsed.clamp(widget.min, max));
  }

  @override
  Widget build(BuildContext context) => TextInput(
    controller: _text,
    focusNode: _focus,
    width: widget.width,
    numeric: true,
    dense: true,
    maxLength: widget.max == null ? null : '${widget.max}'.length,
    suffixText: widget.suffix,
    semanticLabel: widget.semanticLabel,
    onChanged: _onChanged,
    onSubmitted: (_) => _focus.unfocus(),
  );
}
