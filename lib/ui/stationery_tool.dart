import 'package:flutter/material.dart';

import 'paper_palette.dart';
import 'paper_tool.dart';

/// Static stationery specimens. Interaction and names belong to the buttons.
class StationeryTool extends StatelessWidget {
  const StationeryTool({
    super.key,
    required this.tool,
    required this.color,
    this.width = 136,
    this.height = 42,
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

  void _body(Canvas canvas, Rect rect, Color tint, double radius) {
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      shape.shift(const Offset(0, 3)),
      Paint()
        ..color = brandInk.withValues(alpha: .14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(tint, Colors.white, .18)!,
            tint,
            Color.lerp(tint, Colors.black, .28)!,
          ],
          stops: const [0, .35, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = brandInk.withValues(alpha: .3),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // A single uniform scale keeps the nib and barrel in proportion.
    final scale = (size.width / 140).clamp(0.0, size.height / 42);
    canvas.translate(
      (size.width - 140 * scale) / 2,
      (size.height - 42 * scale) / 2,
    );
    canvas.scale(scale);
    final brass = Paint()..color = const Color(0xffb39a69);
    final edge = Paint()
      ..color = const Color(0xff685135)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65;
    switch (tool) {
      case PaperTool.writing:
        _body(canvas, const Rect.fromLTWH(37, 13, 99, 16), color, 5);
        _body(canvas, const Rect.fromLTWH(23, 15, 16, 12), ink, 2);
        canvas.drawRect(const Rect.fromLTWH(37, 13, 2, 16), brass);
        canvas.drawRect(const Rect.fromLTWH(104, 13, 1.8, 16), brass);
        canvas.drawRect(const Rect.fromLTWH(108, 13, .7, 16), brass);
        final nib = Path()
          ..moveTo(3, 21)
          ..lineTo(16, 15)
          ..lineTo(24, 17)
          ..lineTo(24, 25)
          ..lineTo(16, 27)
          ..close();
        canvas.drawPath(nib, brass);
        canvas.drawPath(nib, edge);
        canvas.drawLine(const Offset(3, 21), const Offset(19, 21), edge);
        canvas.drawCircle(const Offset(19, 21), 1, Paint()..color = ink);
      case PaperTool.highlighter:
        final plastic = Color.lerp(color, paper, .58)!;
        _body(canvas, const Rect.fromLTWH(40, 9, 95, 24), plastic, 4);
        _body(canvas, const Rect.fromLTWH(21, 13, 24, 16), plastic, 3);
        _body(canvas, const Rect.fromLTWH(128, 11, 7, 20), plastic, 2);
        final tip = Path()
          ..moveTo(5, 18)
          ..lineTo(20, 15)
          ..lineTo(21, 26)
          ..lineTo(8, 26)
          ..close();
        canvas.drawPath(tip, Paint()..color = color);
        canvas.drawPath(tip, edge);
        canvas.drawLine(
          const Offset(45, 13),
          const Offset(45, 29),
          Paint()
            ..color = brandInk.withValues(alpha: .2)
            ..strokeWidth = .6,
        );
      case PaperTool.eraser:
        _body(
          canvas,
          const Rect.fromLTWH(42, 10, 56, 23),
          const Color(0xffcfae99),
          3,
        );
        canvas.drawRect(
          const Rect.fromLTWH(61, 10, 27, 23),
          Paint()..color = paper,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StationeryPainter old) =>
      tool != old.tool || color != old.color;
}
