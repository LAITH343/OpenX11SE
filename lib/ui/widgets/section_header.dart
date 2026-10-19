import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/nocturne_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr(title),
          style: n.text.title.copyWith(fontSize: 26, letterSpacing: -0.26),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            tr(description!),
            style: n.text.small.copyWith(color: n.textSecondary),
          ),
        ],
      ],
    );
    if (trailing == null) return heading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        const SizedBox(width: 16),
        trailing!,
      ],
    );
  }
}
