import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/book_detail_style.dart';
import 'book_detail_design.dart';
import 'paper_palette.dart';

/// A real book-opening control when onTap is supplied; labels remain text.
class BookIndexTab extends StatelessWidget {
  const BookIndexTab({
    super.key,
    required this.label,
    this.choice = const BookDetailChoice(),
    this.onTap,
    this.selected = false,
  });
  final String label;
  final BookDetailChoice choice;
  final VoidCallback? onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    if (!choice.enabled) return const SizedBox.shrink();
    final color = BookDetailDesign.color(BookDetailKind.indexTab, choice);
    final text = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 22, 12),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: choice.variant == 1 ? const Color(0xfffffaf0) : ink,
        ),
      ),
    );
    final tab = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 48,
        minWidth: 48,
        maxWidth: 156,
      ),
      child: CustomPaint(
        painter: _Tab(choice.variant, color, selected),
        child: onTap == null
            ? text
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  excludeFromSemantics: true,
                  child: ExcludeSemantics(child: text),
                ),
              ),
      ),
    );
    if (onTap == null) return tab;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: '책 색인 · $label',
        button: true,
        selected: selected,
        onTap: onTap,
        child: tab,
      ),
    );
  }
}

/// The cover-edge marker repeats the active tab material at thumbnail size.
class BookIndexEdge extends StatelessWidget {
  const BookIndexEdge({super.key, required this.choice, required this.width});
  final BookDetailChoice choice;
  final double width;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: CustomPaint(
        size: Size(width, width * 1.3),
        painter: _Tab(
          choice.variant,
          BookDetailDesign.color(BookDetailKind.indexTab, choice),
          false,
        ),
      ),
    ),
  );
}

class _Tab extends CustomPainter {
  const _Tab(this.variant, this.color, this.selected);
  final int variant;
  final Color color;
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    final r = variant == 2 ? size.height / 2 : 5.0;
    final shape = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          (Offset.zero & size).deflate(.6),
          topRight: Radius.circular(r),
          bottomRight: Radius.circular(r),
        ),
      );
    canvas.drawShadow(shape, const Color(0x24614c3b), 1, false);
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawPath(
      shape,
      Paint()..color = variant == 1 ? color : Color.lerp(paper, color, .10)!,
    );
    if (variant == 1) {
      final weft = Paint()
        ..color = const Color(0x15ffffff)
        ..strokeWidth = .5;
      for (var y = 1.0; y < size.height; y += 2.1) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), weft);
      }
      for (var x = 1.0; x < size.width; x += 2.7) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), weft);
      }
    } else {
      final edge = math.min(9.0, size.width * .35);
      canvas.drawRect(
        Rect.fromLTWH(size.width - edge, 0, edge, size.height),
        Paint()..color = color.withValues(alpha: .8),
      );
    }
    final seam = math.min(6.0, size.width * .2);
    canvas.drawLine(
      Offset(seam, size.height * .12),
      Offset(seam, size.height * .88),
      Paint()
        ..color = color.withValues(alpha: .28)
        ..strokeWidth = .6,
    );
    canvas.restore();
    canvas.drawPath(
      shape,
      Paint()
        ..color = color.withValues(alpha: selected ? .85 : .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.2 : .6,
    );
  }

  @override
  bool shouldRepaint(_Tab old) =>
      variant != old.variant || color != old.color || selected != old.selected;
}

/// A paper ornament that separates adjacent entries in a list.
class RecordDivider extends StatelessWidget {
  const RecordDivider({super.key, this.choice = const BookDetailChoice()});
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: choice.enabled
        ? ExcludeSemantics(
            child: IgnorePointer(
              child: Center(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(148, 18),
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

/// Static native vector botany, excluded from input and accessibility.
class PressedFlower extends StatelessWidget {
  const PressedFlower({
    super.key,
    this.choice = const BookDetailChoice(),
    this.size = 64,
  });
  final BookDetailChoice choice;
  final double size;
  @override
  Widget build(BuildContext context) => choice.enabled
      ? ExcludeSemantics(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(size * .68, size),
                painter: _Botanical(
                  choice.variant,
                  BookDetailDesign.color(BookDetailKind.pressedFlower, choice),
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
