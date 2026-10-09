import 'package:flutter/material.dart';

import '../../core/theme/nocturne_theme.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final n = context.nocturne;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: n.backdrop,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(parent: animation, curve: n.motion.popCurve);
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: t,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - t.value)),
            child: Transform.scale(scale: 0.98 + 0.02 * t.value, child: child),
          ),
        ),
      );
    },
  );
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.body,
    this.icon,
    this.danger = false,
    this.content,
    this.actions = const [],
    this.width = 440,
  });

  final String title;
  final String? body;
  final IconData? icon;
  final bool danger;
  final Widget? content;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final n = context.nocturne;
    final p = n.palette;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: n.text.dialogTitle),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(
            body!,
            style: n.text.body.copyWith(
              color: n.textColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(n.space.s4),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: EdgeInsets.all(n.space.s4),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: n.radius.lgAll,
                boxShadow: p.shadowLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (icon == null)
                    heading
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: danger
                                ? p.danger.withValues(alpha: 0.15)
                                : p.a(900),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: danger ? p.danger : p.accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: heading),
                      ],
                    ),
                  if (content != null) ...[
                    SizedBox(height: n.space.s3),
                    content!,
                  ],
                  if (actions.isNotEmpty) ...[
                    SizedBox(height: n.space.s3 + n.space.s2),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: n.space.s2,
                      runSpacing: n.space.s2,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
