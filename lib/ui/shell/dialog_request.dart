import 'dart:async';

import 'package:flutter/widgets.dart';

class DialogRequest {
  DialogRequest({
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.icon,
    this.danger = false,
    this.initialText,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final IconData? icon;
  final bool danger;
  final String? initialText;

  final _result = Completer<String?>();

  bool get hasInput => initialText != null;

  Future<String?> get result => _result.future;

  void complete(String? value) {
    if (!_result.isCompleted) _result.complete(value);
  }
}
