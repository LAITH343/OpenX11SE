import 'package:flutter/widgets.dart';

const minimumAppSize = Size(880, 600);
const minimumWindowSize = Size(896, 640);

class MinimumSizeViewport extends StatelessWidget {
  const MinimumSizeViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < minimumAppSize.width;
        final short = constraints.maxHeight < minimumAppSize.height;
        if (!narrow && !short) return child;
        final width = narrow ? minimumAppSize.width : constraints.maxWidth;
        final height = short ? minimumAppSize.height : constraints.maxHeight;
        return SingleChildScrollView(
          primary: false,
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            primary: false,
            child: SizedBox(width: width, height: height, child: child),
          ),
        );
      },
    );
  }
}
