import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/book_detail_style.dart';
import 'book_detail_design.dart';
import 'paper_palette.dart';

/// A paper ornament that separates adjacent entries in a list.
class RecordDivider extends StatelessWidget {
  const RecordDivider({
    super.key,
    this.choice = const BookDetailChoice(),
    this.compact = false,
  });
  final BookDetailChoice choice;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 22 : 32,
    child: choice.enabled
        ? ExcludeSemantics(
            child: IgnorePointer(
              child: Center(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: compact ? const Size(112, 14) : const Size(148, 18),
                    painter: _Divider(
                      choice.variant,
                      BookDetailDesign.color(
                        BookDetailKind.recordDivider,
                        choice,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : null,
  );
}

class _Divider extends CustomPainter {
  const _Divider(this.variant, this.color);
  final int variant;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final middle = Offset(size.width / 2, size.height / 2);
    final pen = Paint()
      ..color = color.withValues(alpha: .75)
      ..strokeWidth = .7
      ..strokeCap = StrokeCap.round;
    switch (variant) {
      case 0:
        for (final x in [-10.0, 0.0, 10.0]) {
          canvas.drawCircle(middle + Offset(x, 0), 1.3, pen);
        }
      case 1:
        canvas.drawLine(
          middle - const Offset(26, 0),
          middle + const Offset(26, 0),
          pen,
        );
      default:
        canvas.drawLine(
          Offset(12, middle.dy),
          middle - const Offset(14, 0),
          pen,
        );
        canvas.drawLine(
          middle + const Offset(14, 0),
          Offset(size.width - 12, middle.dy),
          pen,
        );
        canvas.save();
        canvas.translate(middle.dx, middle.dy);
        for (var i = 0; i < 4; i++) {
          canvas.drawOval(const Rect.fromLTWH(-1.7, -5.2, 3.4, 4), pen);
          canvas.rotate(math.pi / 2);
        }
        canvas.restore();
        canvas.drawCircle(middle, .9, pen);
    }
  }

  @override
  bool shouldRepaint(_Divider old) =>
      variant != old.variant || color != old.color;
}

Alignment flowerAlignment(BookDetailChoice choice) =>
    switch (choice.placement) {
      1 => Alignment.bottomLeft,
      2 => Alignment.bottomCenter,
      _ => Alignment.bottomRight,
    };

/// The cover places this within a band reserved for decoration.
class CoverFlower extends StatelessWidget {
  const CoverFlower({
    super.key,
    required this.choice,
    required this.darkCloth,
    required this.maxSize,
  });

  final BookDetailChoice choice;
  final bool darkCloth;
  final double maxSize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = math.min(
        maxSize,
        math.min(box.maxHeight, box.maxWidth / .68),
      );
      return Align(
        alignment: flowerAlignment(choice),
        child: PressedFlower(
          choice: choice,
          size: size,
          onDarkCloth: darkCloth,
        ),
      );
    },
  );
}

/// Static native vector botany, excluded from input and accessibility.
class PressedFlower extends StatelessWidget {
  const PressedFlower({
    super.key,
    this.choice = const BookDetailChoice(),
    this.size = 64,
    this.onDarkCloth = false,
  });
  final BookDetailChoice choice;
  final double size;
  final bool onDarkCloth;
  @override
  Widget build(BuildContext context) => choice.enabled
      ? ExcludeSemantics(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(size * .68, size),
                painter: _Botanical(
                  choice.variant,
                  onDarkCloth
                      ? Color.lerp(
                          BookDetailDesign.color(
                            BookDetailKind.pressedFlower,
                            choice,
                          ),
                          const Color(0xffe9d8aa),
                          .72,
                        )!
                      : BookDetailDesign.color(
                          BookDetailKind.pressedFlower,
                          choice,
                        ),
                ),
              ),
            ),
          ),
        )
      : const SizedBox.shrink();
}

class _Botanical extends CustomPainter {
  const _Botanical(this.variant, this.color);
  final int variant;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 44, size.height / 64);
    final stem = Paint()
      ..color = Color.lerp(color, brandInk, .2)!.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65
      ..strokeCap = StrokeCap.round;
    final axis = Path()
      ..moveTo(17, 61)
      ..quadraticBezierTo(27, 37, 25, 8);
    canvas.drawPath(axis, stem);
    void leaf(Offset base, Offset tip, double breadth) {
      final dx = tip.dx - base.dx, dy = tip.dy - base.dy;
      final length = math.sqrt(dx * dx + dy * dy);
      final normal = Offset(-dy / length * breadth, dx / length * breadth);
      final middle = (base + tip) / 2;
      final shape = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          middle.dx + normal.dx,
          middle.dy + normal.dy,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          middle.dx - normal.dx,
          middle.dy - normal.dy,
          base.dx,
          base.dy,
        )
        ..close();
      canvas.drawPath(shape, Paint()..color = color.withValues(alpha: .43));
      canvas.drawPath(shape, stem..strokeWidth = .35);
      canvas.drawLine(base, tip, stem..strokeWidth = .4);
      for (var i = 2; i < 5; i++) {
        final t = i / 6, point = base + (tip - base) * t;
        final edge = point + normal * (math.sin(t * math.pi) * .32);
        canvas.drawLine(
          point,
          edge,
          stem
            ..color = color.withValues(alpha: .23)
            ..strokeWidth = .25,
        );
      }
      stem
        ..color = Color.lerp(color, brandInk, .2)!.withValues(alpha: .72)
        ..strokeWidth = .65;
    }

    switch (variant) {
      case 0:
        leaf(const Offset(23, 40), const Offset(5, 19), 7);
        leaf(const Offset(25, 26), const Offset(37, 3), 8);
        leaf(const Offset(22, 46), const Offset(36, 34), 5);
      case 1:
        leaf(const Offset(23, 43), const Offset(9, 34), 3.5);
        leaf(const Offset(24, 34), const Offset(37, 24), 3);
        canvas.save();
        canvas.translate(25, 14);
        canvas.rotate(-.15);
        for (var i = 0; i < 5; i++) {
          final petal = Path()
            ..moveTo(0, 0)
            ..cubicTo(-10, -3, -8, -17, -1, -13)
            ..cubicTo(5, -15, 9, -4, 0, 0);
          canvas.drawPath(petal, Paint()..color = color.withValues(alpha: .25));
          canvas.drawPath(
            petal,
            Paint()
              ..color = color.withValues(alpha: .38)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .4,
          );
          canvas.drawLine(
            Offset.zero,
            const Offset(-1, -10),
            stem..strokeWidth = .25,
          );
          canvas.rotate(math.pi * 2 / 5);
        }
        canvas.drawCircle(
          Offset.zero,
          1.5,
          Paint()..color = brandInk.withValues(alpha: .7),
        );
        canvas.restore();
      default:
        for (var i = 0; i < 8; i++) {
          final y = 49.0 - i * 5.2, width = 13 - i * .9;
          final base = Offset(24, y);
          leaf(base, Offset(24 - width, y - 10), 2.8 - i * .18);
          leaf(base, Offset(24 + width, y - 11), 2.8 - i * .18);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Botanical old) =>
      variant != old.variant || color != old.color;
}
