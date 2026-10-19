import 'package:flutter/widgets.dart';

import 'arabic.dart';

enum AppLanguage {
  english('en', 'English'),
  arabic('ar', 'العربية');

  const AppLanguage(this.code, this.nativeName);

  final String code;
  final String nativeName;

  Locale get locale => Locale(code);

  bool get isRtl => this == arabic;

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => english);
}

abstract final class AppStrings {
  static AppLanguage language = AppLanguage.english;
}

final RegExp _latin = RegExp('[A-Za-z]');
final RegExp _edges = RegExp(r'^(\s*)([\s\S]*?)(\s*)$');
final RegExp _separators = RegExp(r'( · | — |: |, )');
final RegExp _trailing = RegExp(r'^(.*?)([.…?!:]+)$');

final Map<String, String> _lower = {
  for (final e in arabicStrings.entries) e.key.toLowerCase(): e.value,
};

String tr(String text) {
  if (AppStrings.language != AppLanguage.arabic) return text;
  return _translate(text);
}

String? _core(String text) {
  final exact = arabicStrings[text] ?? _lower[text.toLowerCase()];
  if (exact != null) return exact;
  for (final (pattern, build) in arabicPatterns) {
    final m = pattern.firstMatch(text);
    if (m != null) return build(m, _translate);
  }
  return null;
}

String _translate(String text) {
  if (text.isEmpty || !_latin.hasMatch(text)) return text;
  final edges = _edges.firstMatch(text)!;
  final body = edges[2]!;
  var result = _core(body);
  if (result == null) {
    final parts = body.splitMapJoin(
      _separators,
      onMatch: (m) => '\u0000${m[0] == ', ' ? '، ' : m[0]}\u0000',
      onNonMatch: (s) => s,
    );
    final pieces = parts.split('\u0000');
    if (pieces.length > 1) {
      var changed = false;
      final joined = StringBuffer();
      for (var i = 0; i < pieces.length; i++) {
        if (i.isOdd) {
          joined.write(pieces[i]);
          continue;
        }
        final x = _core(pieces[i]);
        if (x != null) changed = true;
        joined.write(x ?? pieces[i]);
      }
      if (changed) result = joined.toString();
    }
  }
  if (result == null) {
    final m = _trailing.firstMatch(body);
    if (m != null) {
      final x = _core(m[1]!);
      if (x != null) result = x + m[2]!.replaceAll('?', '؟');
    }
  }
  return result == null ? text : '${edges[1]}$result${edges[3]}';
}
