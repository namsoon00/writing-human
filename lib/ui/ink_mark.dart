import 'package:flutter/material.dart';

class InkMark extends StatelessWidget {
  const InkMark({super.key, this.size = 20, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: Image.asset(
        'assets/images/ink-mark-bleed.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        color: color,
        colorBlendMode: color == null ? null : BlendMode.srcIn,
      ),
    ),
  );
}
