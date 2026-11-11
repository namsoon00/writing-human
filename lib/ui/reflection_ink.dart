import 'package:flutter/material.dart';

import 'paper_palette.dart';

const reflectionGraphite = Color(0xff485358);
const reflectionHandwriting = TextStyle(
  fontFamily: 'NanumPenScript',
  fontFamilyFallback: [appFontFamily, ...appFontFallback],
  fontSize: 27,
  height: 1.24,
  color: reflectionGraphite,
);

class ReflectionArrow extends CustomPainter {
  const ReflectionArrow();

  @override
  void paint(Canvas canvas, Size size) {
    final pencil = Paint()
      ..color = reflectionGraphite.withValues(alpha: .78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(1, 1)
        ..quadraticBezierTo(5, 19, 21, 15)
        ..moveTo(15, 11)
        ..lineTo(21, 15)
        ..lineTo(17, 19),
      pencil,
    );
  }

  @override
  bool shouldRepaint(ReflectionArrow oldDelegate) => false;
}
