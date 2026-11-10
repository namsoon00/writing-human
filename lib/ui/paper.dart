import 'package:flutter/material.dart';

const ink = Color(0xff302c27);
const brandInk = Color(0xff70472f);
const muted = Color(0xff776a5b);
const green = Color(0xff4e5a42);
const burgundy = Color(0xff7a4a4a);
const line = Color(0xffe4dacb);
const paper = Color(0xfff7f2e8);
const appPaper = Color(0xffeee9e0);
const serif = 'NanumMyeongjo';
const developmentSerif = 'WritingHumanDevelopment';
const developmentFontLabel = '쓰는 인간체';
const appFontFamily = developmentSerif;
const appFontFallback = [serif, 'NanumGothic'];
const paperColors = [
  paper,
  Color(0xfff3e7d2),
  Color(0xffe9e6df),
  Color(0xfff3dfbd),
];
const paperNames = ['순면지', '미색지', '회백지', '크림지'];
const penColors = [ink, brandInk, Color(0xff5b6f8e)];
const fontNames = ['나눔명조', '나눔명조 Bold', '나눔고딕'];

EdgeInsets writingPagePadding(Size size) => EdgeInsets.fromLTRB(
  size.width < 500 ? 30 : 64,
  size.height < 400 ? 24 : 54,
  size.width < 500 ? 30 : 64,
  44,
);

TextStyle writingTextStyle(
  int font, {
  double size = 23,
  Color color = ink,
  bool useDevelopmentTypeface = true,
}) => TextStyle(
  fontFamily: useDevelopmentTypeface
      ? developmentSerif
      : font == 2
      ? 'NanumGothic'
      : serif,
  fontFamilyFallback: useDevelopmentTypeface
      ? const [serif, 'NanumGothic']
      : null,
  fontWeight: !useDevelopmentTypeface && font == 1
      ? FontWeight.w700
      : FontWeight.w400,
  fontSize: size,
  height: 1.8,
  color: color,
  letterSpacing: .15,
);

/// A continuous interior page behind header, editable text and footer.
/// The material is static and never participates in hit testing or semantics.
class PaperBackdrop extends StatelessWidget {
  const PaperBackdrop({super.key, required this.child, this.color = paper});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: appPaper,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        image: DecorationImage(
                          image: const AssetImage(
                            'assets/images/cotton-paper.jpg',
                          ),
                          repeat: ImageRepeat.repeat,
                          scale: 2,
                          opacity: .24,
                          colorFilter: ColorFilter.mode(
                            color,
                            BlendMode.modulate,
                          ),
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xff92816a).withValues(alpha: .17),
                              color.withValues(alpha: 0),
                              const Color(0x12ffffff),
                            ],
                            stops: const [0, .045, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

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

/// Guides follow the actual text padding, line height and scroll without
/// changing the editor controller, selection or composing range.
class WritingGuides extends CustomPainter {
  const WritingGuides({
    required this.top,
    required this.left,
    required this.right,
    required this.lineHeight,
    required this.scroll,
    required this.enabled,
  });
  final double top, left, right, lineHeight, scroll;
  final bool enabled;
  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final paint = Paint()
      ..color = const Color(0x188c765d)
      ..strokeWidth = .6;
    final first = top + lineHeight * .83 - scroll;
    final start = first < 0
        ? first + ((-first / lineHeight).ceil() * lineHeight)
        : first;
    for (var y = start; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), paint);
    }
  }

  @override
  bool shouldRepaint(WritingGuides old) =>
      old.top != top ||
      old.left != left ||
      old.right != right ||
      old.lineHeight != lineHeight ||
      old.scroll != scroll ||
      old.enabled != enabled;
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
                fontFamily: appFontFamily,
                fontFamilyFallback: appFontFallback,
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
