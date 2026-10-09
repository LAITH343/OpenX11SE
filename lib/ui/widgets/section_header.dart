import 'package:flutter/material.dart';

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
        Text(title, style: n.text.title),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
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
