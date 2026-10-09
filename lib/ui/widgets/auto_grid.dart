import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class AutoGrid extends StatelessWidget {
  const AutoGrid({
    super.key,
    required this.minItemWidth,
    required this.spacing,
    required this.children,
    this.runSpacing,
    this.stretch = false,
    this.fill = false,
  });

  final double minItemWidth;
  final double spacing;
  final double? runSpacing;
  final bool stretch;
  final bool fill;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      var columns = math.max(
        1,
        ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor(),
      );
      if (!fill) columns = math.min(columns, children.length);
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += columns) {
        final cells = <Widget>[
          for (var k = 0; k < columns; k++)
            Expanded(
              child: i + k < children.length
                  ? children[i + k]
                  : const SizedBox.shrink(),
            ),
        ];
        final row = Row(
          crossAxisAlignment: stretch
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          spacing: spacing,
          children: cells,
        );
        rows.add(stretch ? IntrinsicHeight(child: row) : row);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: runSpacing ?? spacing,
        children: rows,
      );
    },
  );
}
