import 'package:flutter/material.dart';

class InkMark extends StatelessWidget {
  const InkMark({super.key, this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: Image.asset(
        'assets/images/ink-mark.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}
