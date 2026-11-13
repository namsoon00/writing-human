import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/book_detail_style.dart';
import 'book_detail_design.dart';
import 'ink_mark.dart';
import 'reading_details.dart';
import 'paper_palette.dart';

const detailMetadataInk = Color(0xff655747);

Widget _decoration(Widget child) => IgnorePointer(
  child: ExcludeSemantics(child: RepaintBoundary(child: child)),
);

/// The parent supplies the location. The ribbon only owns its appearance.
class RibbonBookmark extends StatelessWidget {
  const RibbonBookmark({
    super.key,
    this.width = 13,
    this.height = 42,
    this.color,
    this.choice = const BookDetailChoice(),
  });
  final double width, height;
  final Color? color;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) => choice.enabled
      ? _decoration(
          CustomPaint(
            size: Size(width, height),
            painter: _Ribbon(
              color ?? BookDetailDesign.color(BookDetailKind.ribbon, choice),
              choice.variant,
            ),
          ),
        )
      : const SizedBox.shrink();
}

class _Ribbon extends CustomPainter {
  const _Ribbon(this.color, this.variant);
  final Color color;
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final tip = math.min(size.width * .42, size.height * .2);
    final shape = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0);
    switch (variant) {
      case 1:
        shape
          ..lineTo(size.width, size.height)
          ..lineTo(size.width / 2, size.height - tip)
          ..lineTo(0, size.height);
      case 2:
        shape
          ..lineTo(size.width, size.height - tip)
          ..quadraticBezierTo(
            size.width / 2,
            size.height + tip * .55,
            0,
            size.height - tip,
          );
      default:
        shape
          ..lineTo(size.width, size.height - tip * .65)
          ..lineTo(0, size.height);
    }
    shape.close();
    canvas.drawShadow(shape, const Color(0x28614c3b), 1.2, false);
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, Colors.black, .08)!,
            Color.lerp(color, Colors.white, .04)!,
            color,
            Color.lerp(color, Colors.black, .05)!,
          ],
          stops: const [0, .25, .72, 1],
        ).createShader(Offset.zero & size),
    );
    final weft = Paint()
      ..color = const Color(0x1cffffff)
      ..strokeWidth = .45;
    for (var y = 1.0; y < size.height; y += 1.7) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + math.sin(y * 1.3) * .15),
        weft,
      );
    }
    final warp = Paint()
      ..color = const Color(0x13000000)
      ..strokeWidth = .4;
    for (var x = 1.0; x < size.width; x += 2.1) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), warp);
    }
    final inset = (size.width * .16).clamp(.8, 2.3);
    final stitch = Paint()
      ..color = const Color(0x40ffffff)
      ..strokeWidth = .55
      ..strokeCap = StrokeCap.round;
    for (var y = 2.0; y < size.height - tip - 2; y += 4.3) {
      for (final x in [inset, size.width - inset]) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 1.6), stitch);
      }
    }
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0x1b000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Ribbon old) =>
      old.color != color || old.variant != variant;
}

class BindingHeadband extends StatelessWidget {
  const BindingHeadband({
    super.key,
    this.width = 28,
    this.choice = const BookDetailChoice(),
  });
  final double width;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) => choice.enabled
      ? _decoration(
          CustomPaint(
            size: Size(width, 4),
            painter: _Headband(
              BookDetailDesign.color(BookDetailKind.binding, choice),
            ),
          ),
        )
      : const SizedBox.shrink();
}

class _Headband extends CustomPainter {
  const _Headband(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(1.5),
    );
    canvas.drawRRect(bounds, Paint()..color = const Color(0xffd7c9b1));
    canvas.save();
    canvas.clipRRect(bounds);
    for (var x = .8; x < size.width; x += 2.4) {
      canvas.drawLine(
        Offset(x, .5),
        Offset(x + .9, size.height - .5),
        Paint()
          ..color = color.withValues(alpha: .5)
          ..strokeWidth = .9,
      );
    }
    canvas.drawLine(
      Offset(0, size.height * .45),
      Offset(size.width, size.height * .45),
      Paint()
        ..color = const Color(0x30ffffff)
        ..strokeWidth = .6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Headband old) => old.color != color;
}

/// Material-layer binding never changes padding or editable bounds.
class BookBinding extends StatelessWidget {
  const BookBinding({
    super.key,
    this.choice = const BookDetailChoice(),
    this.cover = false,
  });
  final BookDetailChoice choice;
  final bool cover;
  @override
  Widget build(BuildContext context) => _decoration(
    CustomPaint(
      painter: _Binding(choice, cover),
      child: const SizedBox.expand(),
    ),
  );
}

class _Binding extends CustomPainter {
  const _Binding(this.choice, this.cover);
  final BookDetailChoice choice;
  final bool cover;
  @override
  void paint(Canvas canvas, Size size) {
    if (!choice.enabled || size.isEmpty) return;
    final color = BookDetailDesign.color(BookDetailKind.binding, choice);
    final width = cover
        ? (size.width * .045).clamp(2.0, 12.0)
        : (size.width * .045).clamp(8.0, 18.0);
    final area = Rect.fromLTWH(0, 0, width, size.height);
    canvas.drawRect(
      area,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: .11),
            color.withValues(alpha: .035),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .45, 1],
        ).createShader(area),
    );
    canvas.drawLine(
      const Offset(.5, 0),
      Offset(.5, size.height),
      Paint()
        ..color = color.withValues(alpha: .12)
        ..strokeWidth = .5,
    );
    if (choice.variant == 0) {
      if (!cover && size.height > 12) {
        canvas.save();
        canvas.translate(4, 1);
        _Headband(color).paint(canvas, const Size(28, 4));
        canvas.translate(0, size.height - 6);
        _Headband(color).paint(canvas, const Size(28, 4));
        canvas.restore();
      } else if (cover) {
        canvas.drawLine(
          Offset(width * .6, 2),
          Offset(width * .6, size.height - 2),
          Paint()
            ..color = color.withValues(alpha: .35)
            ..strokeWidth = .6,
        );
      }
    } else if (choice.variant == 1) {
      final thread = Paint()
        ..color = color.withValues(alpha: .38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..strokeCap = StrokeCap.round;
      final hole = Paint()..color = color.withValues(alpha: .3);
      final step = cover ? (size.height * .08).clamp(9.0, 28.0) : 72.0;
      final x = cover ? width * .35 : 4.5;
      for (var y = step / 2; y < size.height - 9; y += step) {
        canvas.drawCircle(Offset(x, y), .7, hole);
        canvas.drawCircle(Offset(x, y + 8), .7, hole);
        canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..cubicTo(x + 5, y + 1, x + 5, y + 7, x, y + 8),
          thread,
        );
      }
    } else {
      final clothWidth = width * .55;
      final warp = Paint()
        ..color = color.withValues(alpha: .12)
        ..strokeWidth = .4;
      for (var x = 1.0; x < clothWidth; x += 1.8) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), warp);
      }
      final weft = Paint()
        ..color = color.withValues(alpha: .08)
        ..strokeWidth = .5;
      for (var y = 1.0; y < size.height; y += 2.5) {
        canvas.drawLine(Offset(0, y), Offset(clothWidth, y + .3), weft);
      }
    }
  }

  @override
  bool shouldRepaint(_Binding old) =>
      old.choice != choice || old.cover != cover;
}

class DateStamp extends StatelessWidget {
  const DateStamp({
    super.key,
    required this.date,
    this.choice = const BookDetailChoice(),
    this.compact = false,
  });
  final String date;
  final bool compact;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) {
    final color = BookDetailDesign.color(BookDetailKind.dateStamp, choice);
    final framed = choice.enabled && choice.variant != 2;
    return Semantics(
      label: '기록 시작일 ${date.replaceAll('-', '.')}',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: framed ? _StampFrame(choice.variant, color) : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: framed ? (compact ? 7 : 10) : 0,
            vertical: compact ? 3 : 6,
          ),
          color: framed ? color.withValues(alpha: .022) : null,
          child: Text(
            date.replaceAll('-', compact ? '.' : ' . '),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: choice.enabled && !compact ? .85 : .2,
              color: choice.enabled ? color : detailMetadataInk,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _StampFrame extends CustomPainter {
  const _StampFrame(this.variant, this.color);
  final int variant;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final frame = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.7),
          Radius.circular(variant == 1 ? size.height / 2 : 1.5),
        ),
      );
    canvas.drawPath(
      frame,
      Paint()
        ..color = color.withValues(alpha: .08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    final metric = frame.computeMetrics().first;
    // Deterministic, tiny interruptions suggest an ink impression, not damage.
    for (var i = 0; i < 8; i++) {
      canvas.drawPath(
        metric.extractPath(
          metric.length * i / 8,
          metric.length * (i + .975) / 8,
        ),
        Paint()
          ..color = color.withValues(alpha: i.isEven ? .55 : .43)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .75,
      );
    }
  }

  @override
  bool shouldRepaint(_StampFrame old) =>
      old.variant != variant || old.color != color;
}

class SourceSlip extends StatelessWidget {
  const SourceSlip({
    super.key,
    required this.child,
    this.compact = false,
    this.showCaption = true,
    this.choice = const BookDetailChoice(),
  });
  final Widget child;
  final bool compact, showCaption;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: choice.enabled
        ? _SlipPaper(
            BookDetailDesign.color(BookDetailKind.sourceSlip, choice),
            choice.variant,
          )
        : null,
    foregroundPainter: choice.enabled
        ? _SlipDetail(
            choice.variant,
            BookDetailDesign.color(BookDetailKind.sourceSlip, choice),
          )
        : null,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        compact ? 10 : 20,
        choice.enabled && choice.variant != 0
            ? (compact ? 24 : 30)
            : (compact ? 12 : 20),
        compact ? 11 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact && showCaption) ...[
            const Text(
              '책 사이에 끼운 메모',
              style: TextStyle(
                color: detailMetadataInk,
                fontSize: 11,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    ),
  );
}

class _SlipPaper extends CustomPainter {
  const _SlipPaper(this.color, this.variant);
  final Color color;
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fold = math.min(13.0, size.width * .1);
    final shape = Path()..moveTo(0, 0);
    if (variant == 2) {
      shape
        ..lineTo(size.width - fold, 0)
        ..lineTo(size.width, fold);
    } else {
      shape.lineTo(size.width, 0);
    }
    shape.lineTo(size.width, size.height - .5);
    for (var x = size.width; x > 0; x -= 7) {
      shape.lineTo(x, size.height - .55 + math.sin(x * .73) * .35);
    }
    shape
      ..lineTo(0, size.height - .4)
      ..close();
    canvas.drawShadow(shape, const Color(0x22614c3b), 1.5, false);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, .1)!, color],
        ).createShader(Offset.zero & size),
    );
    final fiber = Paint()
      ..color = brandInk.withValues(alpha: .035)
      ..strokeWidth = .4;
    for (var y = 9.0; y < size.height; y += 17) {
      canvas.drawLine(Offset(3, y), Offset(8, y + 1.2), fiber);
      canvas.drawLine(
        Offset(size.width - 8, y + 3),
        Offset(size.width - 3, y + 2),
        fiber,
      );
    }
    if (variant == 0) {
      canvas.drawLine(
        const Offset(1, 0),
        Offset(1, size.height - 1),
        Paint()
          ..color = brandInk.withValues(alpha: .22)
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        const Offset(3, 0),
        Offset(3, size.height - 1),
        Paint()
          ..color = brandInk.withValues(alpha: .055)
          ..strokeWidth = .5,
      );
    }
  }

  @override
  bool shouldRepaint(_SlipPaper old) =>
      old.color != color || old.variant != variant;
}

class _SlipDetail extends CustomPainter {
  const _SlipDetail(this.variant, this.color);
  final int variant;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (variant == 1) {
      final path = Path()
        ..moveTo(size.width - 18, 14)
        ..lineTo(size.width - 18, 5)
        ..cubicTo(size.width - 18, -1, size.width - 11, -1, size.width - 11, 5)
        ..lineTo(size.width - 11, 19)
        ..cubicTo(size.width - 11, 25, size.width - 23, 25, size.width - 23, 19)
        ..lineTo(size.width - 23, 4);
      canvas.drawPath(
        path.shift(const Offset(.5, 1)),
        Paint()
          ..color = const Color(0x16614c3b)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xff9a8d78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.05
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x44ffffff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .3,
      );
    } else if (variant == 2) {
      final fold = math.min(13.0, size.width * .1);
      final flap = Path()
        ..moveTo(size.width - fold, 0)
        ..lineTo(size.width - fold, fold)
        ..lineTo(size.width, fold)
        ..close();
      canvas.drawPath(flap, Paint()..color = Color.lerp(color, brandInk, .09)!);
      canvas.drawLine(
        Offset(size.width - fold, 0),
        Offset(size.width, fold),
        Paint()
          ..color = brandInk.withValues(alpha: .19)
          ..strokeWidth = .5,
      );
      canvas.drawLine(
        Offset(size.width - fold, fold),
        Offset(size.width, fold),
        Paint()
          ..color = brandInk.withValues(alpha: .08)
          ..strokeWidth = .8,
      );
    }
  }

  @override
  bool shouldRepaint(_SlipDetail old) =>
      old.variant != variant || old.color != color;
}

class Bookplate extends StatelessWidget {
  const Bookplate({
    super.key,
    required this.title,
    required this.owner,
    required this.onOwner,
    required this.summary,
    this.choice = const BookDetailChoice(),
    this.stockColor = paper,
    this.margin = const EdgeInsets.fromLTRB(24, 4, 24, 16),
    this.flower = const BookDetailChoice(enabled: false),
  });
  final String title, owner, summary;
  final VoidCallback onOwner;
  final BookDetailChoice choice;
  final Color stockColor;
  final EdgeInsets margin;
  final BookDetailChoice flower;
  @override
  Widget build(BuildContext context) {
    final color = BookDetailDesign.color(BookDetailKind.bookplate, choice);
    return Container(
      margin: margin,
      child: CustomPaint(
        painter: choice.enabled ? _PlateStock(stockColor) : null,
        foregroundPainter: choice.enabled
            ? _PlateFrame(choice.variant, color)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (choice.enabled) ...[
                InkMark(size: 20, color: color),
                const SizedBox(height: 10),
                Text(
                  '나의 장서표',
                  style: TextStyle(
                    fontFamily: appFontFamily,
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12,
                    color: color,
                    letterSpacing: .9,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: appFontFamily,
                  fontFamilyFallback: appFontFallback,
                  fontSize: 18,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                summary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: detailMetadataInk,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              if (choice.enabled)
                const Text(
                  '이 책의 주인',
                  style: TextStyle(
                    color: detailMetadataInk,
                    fontSize: 11,
                    letterSpacing: .4,
                  ),
                ),
              Tooltip(
                message: owner.isEmpty ? '장서표 이름 남기기' : '장서표 이름 고치기',
                child: TextButton.icon(
                  onPressed: onOwner,
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: color.withValues(alpha: .72),
                  ),
                  label: Text(
                    owner.isEmpty ? '이름 남기기' : '$owner의 책',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontSize: 13, height: 1.5),
                  ),
                ),
              ),
              if (flower.enabled)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: flowerAlignment(flower),
                    child: PressedFlower(choice: flower, size: 58),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateStock extends CustomPainter {
  const _PlateStock(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, .42)!,
            Color.lerp(color, Colors.white, .18)!,
          ],
        ).createShader(bounds),
    );
    final grain = Paint()
      ..color = brandInk.withValues(alpha: .028)
      ..strokeWidth = .4;
    for (var y = 13.0; y < size.height; y += 19) {
      canvas.drawLine(Offset(9, y), Offset(13, y + .5), grain);
      canvas.drawLine(
        Offset(size.width - 14, y + 5),
        Offset(size.width - 9, y + 4.5),
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(_PlateStock old) => color != old.color;
}

class _PlateFrame extends CustomPainter {
  const _PlateFrame(this.variant, this.color);
  final int variant;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color.withValues(alpha: .30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65;
    if (variant == 0) {
      canvas.drawRect((Offset.zero & size).deflate(1), pen);
      canvas.drawRect(
        (Offset.zero & size).deflate(6),
        pen
          ..color = color.withValues(alpha: .16)
          ..strokeWidth = .5,
      );
    } else if (variant == 1) {
      for (final corner in [
        const Offset(8, 8),
        Offset(size.width - 8, 8),
        Offset(8, size.height - 8),
        Offset(size.width - 8, size.height - 8),
      ]) {
        final dx = corner.dx < size.width / 2 ? 1.0 : -1.0,
            dy = corner.dy < size.height / 2 ? 1.0 : -1.0;
        canvas.drawPath(
          Path()
            ..moveTo(corner.dx + dx * 17, corner.dy)
            ..lineTo(corner.dx, corner.dy)
            ..lineTo(corner.dx, corner.dy + dy * 17),
          pen,
        );
        canvas.drawCircle(
          corner + Offset(dx * 3.5, dy * 3.5),
          .75,
          Paint()..color = color.withValues(alpha: .35),
        );
      }
    } else {
      final y = size.height - 6;
      canvas.drawLine(
        Offset(size.width * .35, y),
        Offset(size.width * .65, y),
        pen,
      );
      canvas.drawCircle(
        Offset(size.width * .5, y),
        1.3,
        Paint()..color = color.withValues(alpha: .5),
      );
    }
  }

  @override
  bool shouldRepaint(_PlateFrame old) =>
      old.variant != variant || old.color != color;
}

class PageOrnament extends StatelessWidget {
  const PageOrnament({
    super.key,
    required this.child,
    this.choice = const BookDetailChoice(),
  });
  final Widget child;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!choice.enabled ||
          constraints.maxWidth < 96 ||
          MediaQuery.textScalerOf(context).scale(10) > 15) {
        return child;
      }
      final compact = constraints.maxWidth < 144;
      final size = Size(compact ? 15 : 23, 12);
      final gap = SizedBox(width: compact ? 5 : 8);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _decoration(
            CustomPaint(size: size, painter: _Ornament(choice, false)),
          ),
          gap,
          Flexible(child: child),
          gap,
          _decoration(
            CustomPaint(size: size, painter: _Ornament(choice, true)),
          ),
        ],
      );
    },
  );
}

class _Ornament extends CustomPainter {
  const _Ornament(this.choice, this.mirrored);
  final BookDetailChoice choice;
  final bool mirrored;
  @override
  void paint(Canvas canvas, Size size) {
    final color = BookDetailDesign.color(BookDetailKind.ornament, choice);
    final pen = Paint()
      ..color = color.withValues(alpha: .66)
      ..strokeWidth = .65
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.save();
    if (mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(size.width / 23, size.height / 12);
    if (choice.variant == 0) {
      canvas.drawLine(const Offset(1, 6), const Offset(13, 6), pen);
      canvas.drawCircle(
        const Offset(20, 6),
        .85,
        Paint()..color = color.withValues(alpha: .72),
      );
    } else if (choice.variant == 1) {
      canvas.drawLine(const Offset(1, 6), const Offset(12, 6), pen);
      canvas.drawPath(
        Path()
          ..moveTo(16, 6)
          ..lineTo(19, 3.5)
          ..lineTo(22, 6)
          ..lineTo(19, 8.5)
          ..close(),
        pen,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(1, 9.5)
          ..quadraticBezierTo(12, 8, 22, 3),
        pen,
      );
      for (final leaf in [
        Path()
          ..moveTo(7, 8.4)
          ..quadraticBezierTo(4, 3, 11, 5)
          ..quadraticBezierTo(11, 8, 7, 8.4)
          ..close(),
        Path()
          ..moveTo(13, 6.7)
          ..quadraticBezierTo(17, 11, 19, 6)
          ..quadraticBezierTo(16, 4.5, 13, 6.7)
          ..close(),
      ]) {
        canvas.drawPath(leaf, Paint()..color = color.withValues(alpha: .12));
        canvas.drawPath(leaf, pen);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Ornament old) =>
      old.choice != choice || old.mirrored != mirrored;
}
