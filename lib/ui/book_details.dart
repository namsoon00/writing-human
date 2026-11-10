import 'package:flutter/material.dart';
import '../data/book_detail_style.dart';
import 'book_detail_design.dart';
import 'ink_mark.dart';
import 'paper_palette.dart';

Widget _decoration(Widget child) => IgnorePointer(
  child: ExcludeSemantics(child: RepaintBoundary(child: child)),
);

/// The location is supplied by the parent. The ribbon only owns its appearance.
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
    final shape = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0);
    switch (variant) {
      case 1:
        shape
          ..lineTo(size.width, size.height)
          ..lineTo(size.width / 2, size.height - 7)
          ..lineTo(0, size.height);
      case 2:
        shape
          ..lineTo(size.width, size.height - 5)
          ..quadraticBezierTo(
            size.width / 2,
            size.height + 3,
            0,
            size.height - 5,
          );
      default:
        shape
          ..lineTo(size.width, size.height - 4)
          ..lineTo(0, size.height);
    }
    shape.close();
    canvas.drawShadow(shape, const Color(0x35614c3b), 2, false);
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, Colors.black, .15)!,
            color,
            Color.lerp(color, Colors.white, .12)!,
            color,
          ],
          stops: const [0, .2, .65, 1],
        ).createShader(Offset.zero & size),
    );
    final thread = Paint()
      ..color = const Color(0x20ffffff)
      ..strokeWidth = .5;
    for (var y = 1.0; y < size.height; y += 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + .5), thread);
    }
    canvas.drawLine(const Offset(1.5, 0), Offset(1.5, size.height), thread);
    canvas.drawLine(
      Offset(size.width - 1.5, 0),
      Offset(size.width - 1.5, size.height),
      thread,
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
    this.width = 38,
    this.choice = const BookDetailChoice(),
  });
  final double width;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) => choice.enabled
      ? _decoration(
          CustomPaint(
            size: Size(width, 5),
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)),
      Paint()..color = const Color(0xffd5c5aa),
    );
    for (var x = 1.0; x < size.width - 1; x += 3) {
      canvas.drawLine(
        Offset(x, 1),
        Offset(x + 1, size.height - 1),
        Paint()
          ..color = color.withValues(alpha: x.toInt().isEven ? .7 : .35)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_Headband old) => old.color != color;
}

/// Occupies the material layer, never changes page padding or editable bounds.
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
    if (!choice.enabled) return;
    final color = BookDetailDesign.color(BookDetailKind.binding, choice);
    final width = cover ? (size.width * .08).clamp(2.0, 14.0) : 16.0;
    final area = Rect.fromLTWH(0, 0, width, size.height);
    canvas.drawRect(
      area,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .15), color.withValues(alpha: 0)],
        ).createShader(area),
    );
    if (choice.variant == 0) {
      if (!cover) {
        canvas.save();
        canvas.translate(12, 0);
        _Headband(color).paint(canvas, const Size(38, 5));
        canvas.translate(0, size.height - 5);
        _Headband(color).paint(canvas, const Size(38, 5));
        canvas.restore();
      } else {
        canvas.drawLine(
          Offset(width * .6, 2),
          Offset(width * .6, size.height - 2),
          Paint()
            ..color = color.withValues(alpha: .5)
            ..strokeWidth = .6,
        );
      }
    } else if (choice.variant == 1) {
      final thread = Paint()
        ..color = color.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8;
      final step = cover ? 12.0 : 64.0;
      for (var y = step / 2; y < size.height - 8; y += step) {
        canvas.drawPath(
          Path()
            ..moveTo(width * .35, y)
            ..quadraticBezierTo(width * 1.2, y + 4, width * .35, y + 8),
          thread,
        );
      }
    } else {
      final thread = Paint()
        ..color = color.withValues(alpha: .18)
        ..strokeWidth = .5;
      for (var x = 1.0; x < width * .75; x += 2) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), thread);
      }
      for (var y = 1.0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(width * .75, y), thread);
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
  });
  final String date;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) {
    final color = BookDetailDesign.color(BookDetailKind.dateStamp, choice);
    final framed = choice.enabled && choice.variant != 2;
    return Semantics(
      label: '기록 시작일 ${date.replaceAll('-', '.')}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: framed ? 9 : 0, vertical: 5),
        decoration: framed
            ? BoxDecoration(
                border: Border.all(
                  color: color.withValues(alpha: .5),
                  width: .7,
                ),
                borderRadius: BorderRadius.circular(
                  choice.variant == 1 ? 30 : 1,
                ),
              )
            : null,
        child: Text(
          date.replaceAll('-', ' . '),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: choice.enabled ? 1 : .2,
            color: choice.enabled ? color : muted,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class SourceSlip extends StatelessWidget {
  const SourceSlip({
    super.key,
    required this.child,
    this.compact = false,
    this.choice = const BookDetailChoice(),
  });
  final Widget child;
  final bool compact;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: choice.enabled ? _SlipDetail(choice.variant) : null,
    child: Container(
      decoration: choice.enabled
          ? BoxDecoration(
              color: BookDetailDesign.color(BookDetailKind.sourceSlip, choice),
              border: choice.variant == 0
                  ? Border(
                      left: BorderSide(
                        color: brandInk.withValues(alpha: .3),
                        width: 2,
                      ),
                    )
                  : null,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12614c3b),
                  offset: Offset(1, 3),
                  blurRadius: 5,
                ),
              ],
            )
          : null,
      padding: EdgeInsets.all(compact ? 10 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            const Text(
              '책 사이에 끼운 메모',
              style: TextStyle(color: muted, fontSize: 11, letterSpacing: .6),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    ),
  );
}

class _SlipDetail extends CustomPainter {
  const _SlipDetail(this.variant);
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    if (variant == 1) {
      final wire = Paint()
        ..color = muted.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawPath(
        Path()
          ..moveTo(size.width - 18, 14)
          ..lineTo(size.width - 18, 4)
          ..cubicTo(
            size.width - 18,
            -2,
            size.width - 10,
            -2,
            size.width - 10,
            4,
          )
          ..lineTo(size.width - 10, 19)
          ..cubicTo(
            size.width - 10,
            24,
            size.width - 23,
            24,
            size.width - 23,
            18,
          )
          ..lineTo(size.width - 23, 3),
        wire,
      );
    } else if (variant == 2) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width - 13, 0)
          ..lineTo(size.width - 13, 13)
          ..lineTo(size.width, 13)
          ..close(),
        Paint()..color = brandInk.withValues(alpha: .12),
      );
      canvas.drawLine(
        Offset(size.width - 13, 0),
        Offset(size.width, 13),
        Paint()
          ..color = brandInk.withValues(alpha: .15)
          ..strokeWidth = .5,
      );
    }
  }

  @override
  bool shouldRepaint(_SlipDetail old) => old.variant != variant;
}

class Bookplate extends StatelessWidget {
  const Bookplate({
    super.key,
    required this.title,
    required this.owner,
    required this.onOwner,
    required this.summary,
    this.choice = const BookDetailChoice(),
    this.margin = const EdgeInsets.fromLTRB(24, 4, 24, 16),
  });
  final String title, owner, summary;
  final VoidCallback onOwner;
  final BookDetailChoice choice;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) {
    final color = BookDetailDesign.color(BookDetailKind.bookplate, choice);
    return Container(
      margin: margin,
      color: choice.enabled ? const Color(0xfffcf8ed) : null,
      child: CustomPaint(
        foregroundPainter: choice.enabled
            ? _PlateFrame(choice.variant, color)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (choice.enabled) ...[
                const InkMark(size: 20),
                const SizedBox(height: 8),
                Text(
                  '나의 장서표',
                  style: TextStyle(
                    fontFamily: appFontFamily,
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12,
                    color: color,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
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
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              TextButton(
                onPressed: onOwner,
                child: Text(
                  owner.isEmpty ? '이 책의 주인 이름 남기기' : '$owner의 책 · 이름 고치기',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateFrame extends CustomPainter {
  const _PlateFrame(this.variant, this.color);
  final int variant;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color.withValues(alpha: .4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    if (variant == 0) {
      canvas.drawRect((Offset.zero & size).deflate(.5), pen);
      canvas.drawRect(
        (Offset.zero & size).deflate(5),
        pen..color = color.withValues(alpha: .2),
      );
    } else if (variant == 1) {
      for (final corner in [
        Offset(7, 7),
        Offset(size.width - 7, 7),
        Offset(7, size.height - 7),
        Offset(size.width - 7, size.height - 7),
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
      }
    } else {
      canvas.drawLine(
        Offset(size.width * .36, size.height - 5),
        Offset(size.width * .64, size.height - 5),
        pen,
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
          constraints.maxWidth < 110 ||
          MediaQuery.textScalerOf(context).scale(10) > 15) {
        return child;
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _decoration(
            CustomPaint(
              size: const Size(23, 12),
              painter: _Ornament(choice, false),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: child),
          const SizedBox(width: 8),
          _decoration(
            CustomPaint(
              size: const Size(23, 12),
              painter: _Ornament(choice, true),
            ),
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
    final pen = Paint()
      ..color = BookDetailDesign.color(
        BookDetailKind.ornament,
        choice,
      ).withValues(alpha: .7)
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke;
    canvas.save();
    if (mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (choice.variant == 0) {
      canvas.drawLine(const Offset(0, 6), const Offset(12, 6), pen);
      canvas.drawCircle(
        const Offset(21, 6),
        1,
        pen..style = PaintingStyle.fill,
      );
    } else if (choice.variant == 1) {
      canvas.drawLine(const Offset(0, 6), const Offset(13, 6), pen);
      canvas.drawPath(
        Path()
          ..moveTo(17, 6)
          ..lineTo(20, 3)
          ..lineTo(23, 6)
          ..lineTo(20, 9)
          ..close(),
        pen,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(0, 9)
          ..quadraticBezierTo(12, 8, 22, 3),
        pen,
      );
      canvas.drawPath(
        Path()
          ..moveTo(9, 8)
          ..quadraticBezierTo(5, 0, 16, 5)
          ..quadraticBezierTo(20, 12, 9, 8),
        pen,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Ornament old) =>
      old.choice != choice || old.mirrored != mirrored;
}
