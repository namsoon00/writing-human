import 'dart:math';
import 'package:flutter/material.dart';

const ink = Color(0xff2d332e);
const muted = Color(0xff7b817a);
const green = Color(0xff526759);
const burgundy = green;
const line = Color(0xffe6e8e1);
const paper = Color(0xfffbfaf6);
const appPaper = Color(0xfff2f3ef);
const serif = 'NanumMyeongjo';
const paperColors = [
  Color(0xfffbfaf6),
  Color(0xfff6f0e4),
  Color(0xffedeeea),
  Color(0xfff5ecd9),
];
const paperNames = ['순면지', '미색지', '회백지', '크림지'];
const penColors = [Color(0xff30372f), Color(0xff795c49), Color(0xff50647a)];
const fontNames = ['나눔명조', '나눔명조 Bold', '나눔고딕'];

TextStyle writingTextStyle(int font, {double size = 23, Color color = ink}) =>
    TextStyle(
      fontFamily: font == 2 ? 'NanumGothic' : serif,
      fontWeight: font == 1 ? FontWeight.w700 : FontWeight.w400,
      fontSize: size,
      height: 1.8,
      color: color,
      letterSpacing: .15,
    );

class PaperSurface extends StatelessWidget {
  const PaperSurface({
    super.key,
    required this.child,
    this.color = paper,
    this.torn = false,
    this.guides = false,
  });
  final Widget child;
  final Color color;
  final bool torn, guides;
  @override
  Widget build(BuildContext context) => PhysicalShape(
    clipper: _PaperEdge(torn),
    color: color,
    elevation: 1,
    shadowColor: const Color(0x18545b4d),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: _PaperMaterial(color: color, strength: .16)),
        CustomPaint(
          painter: PaperGrain(guides: guides, opacity: .1),
          child: child,
        ),
      ],
    ),
  );
}

/// Static material lives behind the editor, outside its text/selection painting.
/// RepaintBoundary keeps fibers and lighting from repainting on every keystroke.
class PaperBackdrop extends StatelessWidget {
  const PaperBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      const Positioned.fill(
        child: _PaperMaterial(color: appPaper, strength: .52),
      ),
      child,
    ],
  );
}

class _PaperMaterial extends StatelessWidget {
  const _PaperMaterial({required this.color, required this.strength});
  final Color color;
  final double strength;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            image: DecorationImage(
              image: const AssetImage('assets/images/cotton-paper.jpg'),
              repeat: ImageRepeat.repeat,
              scale: 2,
              opacity: strength,
              colorFilter: ColorFilter.mode(color, BlendMode.modulate),
            ),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0, .24, .7, 1],
                colors: [
                  Color(0x38ffffff),
                  Color(0x10ffffff),
                  Color(0x00bd8b51),
                  Color(0x12b68a59),
                ],
              ),
              border: Border(
                top: BorderSide(color: Color(0x90fffaf0), width: .8),
                left: BorderSide(color: Color(0x65fffaf0), width: .7),
                right: BorderSide(color: Color(0x18a1815c), width: .6),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PaperEdge extends CustomClipper<Path> {
  _PaperEdge(this.torn);
  final bool torn;
  @override
  Path getClip(Size s) {
    if (!torn) {
      return Path()..addRRect(
        RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(3)),
      );
    }
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height - 6);
    final random = Random(42);
    for (double x = s.width; x > 0; x -= 1.3) {
      final wave = sin(x * .12) * .6 + sin(x * .031) * .8;
      p.lineTo(x, s.height - 3.2 - random.nextDouble() * 2.7 - wave);
    }
    return p
      ..lineTo(0, s.height - 4)
      ..close();
  }

  @override
  bool shouldReclip(_PaperEdge old) => old.torn != torn;
}

class PaperGrain extends CustomPainter {
  PaperGrain({this.guides = false, this.opacity = 1});
  final bool guides;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(17);
    final p = Paint()..strokeWidth = .5;
    for (var i = 0; i < size.width * size.height / 48; i++) {
      p.color = Color.fromRGBO(
        117,
        81,
        47,
        (.035 + random.nextDouble() * .04) * opacity,
      );
      final x = random.nextDouble() * size.width,
          y = random.nextDouble() * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + random.nextDouble() * 2.1, y + .6),
        p,
      );
    }
    if (guides) {
      p
        ..color = const Color(0x18a48460)
        ..strokeWidth = .6;
      for (double y = 56; y < size.height; y += 41.4) {
        canvas.drawLine(Offset(27, y), Offset(size.width - 27, y), p);
      }
    }
  }

  @override
  bool shouldRepaint(PaperGrain old) =>
      old.guides != guides || old.opacity != opacity;
}

class BotanicalMark extends StatelessWidget {
  const BotanicalMark({super.key, this.size = 34, this.color = ink});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _Twig(color)),
  );
}

class _Twig extends CustomPainter {
  _Twig(this.color);
  final Color color;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 80, size.height / 80);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      Path()
        ..moveTo(12, 74)
        ..quadraticBezierTo(46, 44, 60, 8),
      p,
    );
    for (final leaf in [
      const Offset(22, 63),
      const Offset(32, 50),
      const Offset(41, 36),
      const Offset(49, 22),
    ]) {
      c.drawPath(
        Path()
          ..moveTo(leaf.dx, leaf.dy)
          ..quadraticBezierTo(
            leaf.dx - 18,
            leaf.dy - 20,
            leaf.dx - 9,
            leaf.dy - 23,
          )
          ..quadraticBezierTo(leaf.dx + 3, leaf.dy - 15, leaf.dx, leaf.dy),
        p,
      );
      c.drawPath(
        Path()
          ..moveTo(leaf.dx + 3, leaf.dy - 5)
          ..quadraticBezierTo(
            leaf.dx + 18,
            leaf.dy - 24,
            leaf.dx + 24,
            leaf.dy - 18,
          )
          ..quadraticBezierTo(
            leaf.dx + 20,
            leaf.dy - 6,
            leaf.dx + 3,
            leaf.dy - 5,
          ),
        p,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_Twig old) => old.color != color;
}

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    this.width = 132,
    this.variant = 0,
  });
  final String title;
  final double width;
  final int variant;
  @override
  Widget build(BuildContext context) {
    final light = variant % 3 == 1;
    return SizedBox(
      width: width,
      height: width * 1.36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            [
              'assets/images/linen-cover.png',
              'assets/images/ivory-linen-cover.png',
              'assets/images/blue-linen-cover.png',
            ][variant % 3],
            fit: BoxFit.fill,
          ),
          Positioned(
            left: width * .12,
            right: width * .09,
            top: width * .34,
            child: Text(
              title,
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: serif,
                fontWeight: FontWeight.w700,
                color: light ? ink : const Color(0xffdbc79a),
                fontSize: width * .125,
                height: 1.65,
                letterSpacing: width * .008,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
