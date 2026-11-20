import 'package:flutter/material.dart';

import 'paper_palette.dart';
import 'paper_tool.dart';

/// Small stationery drawings shared by the tool chooser and writing footer.
class StationeryTool extends StatelessWidget {
  const StationeryTool({
    super.key,
    required this.tool,
    required this.color,
    this.width = 72,
    this.height = 66,
  });

  final PaperTool tool;
  final Color color;
  final double width, height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(width, height),
      painter: _StationeryPainter(tool, color),
    ),
  );
}

class _StationeryPainter extends CustomPainter {
  const _StationeryPainter(this.tool, this.color);
  final PaperTool tool;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 72, size.height / 66);
    canvas.translate(36, 30);
    canvas.rotate(-.38);
    final edge = Paint()
      ..color = brandInk.withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    switch (tool) {
      case PaperTool.writing:
        final barrel = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-7, -27, 14, 35),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          barrel,
          Paint()
            ..shader = LinearGradient(
              colors: [
                Color.lerp(color, Colors.black, .2)!,
                color,
                Color.lerp(color, paper, .35)!,
                color,
              ],
            ).createShader(barrel.outerRect),
        );
        canvas.drawRRect(barrel, edge);
        canvas.drawRect(
          const Rect.fromLTWH(-7, 3, 14, 3),
          Paint()..color = const Color(0xffbd9c62),
        );
        final nib = Path()
          ..moveTo(-6, 8)
          ..lineTo(-5, 17)
          ..quadraticBezierTo(-2, 21, 0, 30)
          ..quadraticBezierTo(2, 21, 5, 17)
          ..lineTo(6, 8)
          ..close();
        canvas.drawPath(nib, Paint()..color = const Color(0xffc3a671));
        canvas.drawPath(nib, edge);
        canvas.drawLine(const Offset(0, 15), const Offset(0, 29), edge);
        canvas.drawCircle(const Offset(0, 14), 1.2, Paint()..color = color);
      case PaperTool.highlighter:
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-10, -25, 20, 39),
          const Radius.circular(3),
        );
        canvas.drawRRect(body, Paint()..color = const Color(0xffd4bf78));
        canvas.drawRRect(body, edge);
        canvas.drawRect(
          const Rect.fromLTWH(-10, -4, 20, 10),
          Paint()..color = const Color(0xfff4edd6),
        );
        canvas.drawLine(const Offset(-6, 1), const Offset(6, 1), edge);
        canvas.drawRect(
          const Rect.fromLTWH(-8, 14, 16, 4),
          Paint()..color = const Color(0xff6d644d),
        );
        final tip = Path()
          ..moveTo(-7, 18)
          ..lineTo(7, 18)
          ..lineTo(7, 24)
          ..lineTo(-7, 28)
          ..close();
        canvas.drawPath(tip, Paint()..color = const Color(0xffbca14b));
        canvas.drawPath(tip, edge);
      case PaperTool.eraser:
        final block = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-14, -22, 28, 48),
          const Radius.circular(4),
        );
        canvas.drawRRect(block, Paint()..color = const Color(0xffd3b3a0));
        canvas.drawRRect(block, edge);
        canvas.drawRect(
          const Rect.fromLTWH(-14, -14, 28, 25),
          Paint()..color = const Color(0xffeee5d5),
        );
        canvas.drawLine(const Offset(-14, -14), const Offset(14, -14), edge);
        canvas.drawLine(const Offset(-14, 11), const Offset(14, 11), edge);
        canvas.drawLine(const Offset(-7, -3), const Offset(7, -3), edge);
        canvas.drawLine(const Offset(-7, 1), const Offset(2, 1), edge);
    }
    canvas.rotate(.38);
    canvas.translate(-36, -30);
    final stroke = Paint()
      ..color = tool == PaperTool.highlighter
          ? const Color(0xffc6ae62).withValues(alpha: .65)
          : color.withValues(alpha: .8)
      ..strokeWidth = tool == PaperTool.highlighter ? 5 : 1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (tool != PaperTool.eraser) {
      canvas.drawPath(
        Path()
          ..moveTo(13, 61)
          ..quadraticBezierTo(32, 56, 59, 60),
        stroke,
      );
    } else {
      canvas.drawLine(
        const Offset(14, 61),
        const Offset(59, 61),
        stroke..color = muted.withValues(alpha: .35),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StationeryPainter old) =>
      tool != old.tool || color != old.color;
}
