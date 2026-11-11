import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'book_details.dart';
import 'reading_details.dart';
import 'paper_palette.dart';
import '../data/book_detail_style.dart';
export 'paper_palette.dart';
export 'ink_mark.dart';

const writingSurfaceMaxWidth = 760.0;

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
  const PaperBackdrop({
    super.key,
    required this.child,
    this.color = paper,
    this.binding = const BookDetailChoice(),
    this.coverIndex,
    this.pagesBefore = 0,
    this.pagesAfter = 0,
    this.grainOpacity = .24,
  });
  final Widget child;
  final Color color;
  final BookDetailChoice binding;
  final int? coverIndex;
  final int pagesBefore, pagesAfter;
  final double grainOpacity;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: appPaper,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: writingSurfaceMaxWidth),
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
                          opacity: grainOpacity,
                          colorFilter: ColorFilter.mode(
                            color,
                            BlendMode.modulate,
                          ),
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: !binding.enabled
                              ? null
                              : LinearGradient(
                                  colors: [
                                    const Color(
                                      0xff92816a,
                                    ).withValues(alpha: .10),
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
            Positioned.fill(child: BookBinding(choice: binding)),
            if (coverIndex case final index?)
              Positioned.fill(
                child: _BookPageEdges(
                  color: color,
                  coverIndex: index,
                  before: pagesBefore,
                  after: pagesAfter,
                ),
              ),
            child,
          ],
        ),
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

const coverNames = ['밤색 리넨', '아이보리 리넨', '푸른 리넨'];
const _coverColors = [Color(0xff715344), Color(0xffa38b6f), Color(0xff454d64)];
const _coverAssets = [
  'assets/images/linen-cover.png',
  'assets/images/ivory-linen-cover.png',
  'assets/images/blue-linen-cover.png',
];
// The PNGs have transparent margins. Keep the decorations on the linen face.
const _coverFaceBounds = [
  Rect.fromLTRB(22 / 682, 37 / 1024, 659 / 682, 986 / 1024),
  Rect.fromLTRB(21 / 738, 22 / 1024, 713 / 738, 1001 / 1024),
  Rect.fromLTRB(27 / 738, 19 / 1024, 708 / 738, 1001 / 1024),
];

/// Aligns the actual cloth face to the viewport edges, excluding the PNG's
/// transparent margins. Wide covers crop vertically to retain their spine.
class BookCoverMaterial extends StatelessWidget {
  const BookCoverMaterial({
    super.key,
    required this.variant,
    required this.back,
    required this.binding,
  });
  final int variant;
  final bool back;
  final BookDetailChoice binding;

  @override
  Widget build(BuildContext context) {
    final index = variant % _coverAssets.length;
    final face = _coverFaceBounds[index];
    return Transform.flip(
      flipX: back,
      child: LayoutBuilder(
        builder: (context, box) {
          final faceHeight = math.max(box.maxHeight, box.maxWidth / .88);
          final width = box.maxWidth / face.width;
          final height = faceHeight / face.height;
          final top = (box.maxHeight - faceHeight) / 2;
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const [
                  Color(0xff41432d),
                  Color(0xffe8d8bc),
                  Color(0xff3f4a59),
                ][index],
              ),
              Positioned(
                left: -face.left * width,
                top: top - face.top * height,
                width: width,
                height: height,
                child: Image.asset(_coverAssets[index], fit: BoxFit.fill),
              ),
              BookBinding(choice: binding, cover: true),
            ],
          );
        },
      ),
    );
  }
}

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    this.width = 132,
    this.variant = 0,
    this.bookmarked = false,
    this.pageCount = 0,
    this.back = false,
    this.details = const BookDetailsStyle(),
  });
  final String title;
  final double width;
  final int variant, pageCount;
  final bool bookmarked, back;
  final BookDetailsStyle details;

  static double totalWidthFactor(BookDetailsStyle details) =>
      details.indexTab.enabled ? 1.04 : 1;

  @override
  Widget build(BuildContext context) => Transform.flip(
    flipX: back,
    child: SizedBox(
      width: width * totalWidthFactor(details),
      height: width * 1.36,
      child: LayoutBuilder(
        builder: (context, box) {
          final imageWidth = box.maxWidth / totalWidthFactor(details);
          return _buildCover(imageWidth, box.maxHeight);
        },
      ),
    ),
  );

  Widget _buildCover(double width, double height) {
    final index = variant % coverNames.length;
    final light = index == 1;
    final bounds = _coverFaceBounds[index];
    final face = Rect.fromLTRB(
      bounds.left * width,
      bounds.top * height,
      bounds.right * width,
      bounds.bottom * height,
    );
    final pageDepth = math.min(5.0, width * .022);
    final pages = Rect.fromLTRB(
      face.left + width * .025,
      face.top + height * .025,
      face.right + pageDepth,
      face.bottom + pageDepth * .45,
    );
    final tabWidth = width * .105;
    return Stack(
      children: [
        if (pageCount > 0)
          Positioned.fromRect(
            rect: pages,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(width * .022),
              child: ColoredBox(
                color: paper,
                child: _BookPageEdges(
                  color: paper,
                  coverIndex: index,
                  before: 0,
                  after: pageCount,
                  maxDepth: pageDepth,
                  bottomStart: 0,
                ),
              ),
            ),
          ),
        if (details.indexTab.enabled)
          Positioned(
            left: face.right + width * .065 - tabWidth,
            top: face.top + face.height * .38,
            child: BookIndexEdge(choice: details.indexTab, width: tabWidth),
          ),
        Positioned(
          left: 0,
          top: 0,
          width: width,
          height: height,
          child: _coverArtwork(width, face, index, light),
        ),
      ],
    );
  }

  Widget _coverArtwork(double width, Rect face, int index, bool light) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(_coverAssets[index], fit: BoxFit.fill),
      Positioned.fromRect(
        rect: face.deflate(width * .018),
        child: BookBinding(choice: details.binding, cover: true),
      ),
      if (bookmarked && !back)
        Positioned(
          right: width * .14,
          top: 0,
          child: RibbonBookmark(
            width: width * .13,
            height: width * .42,
            choice: details.ribbon,
          ),
        ),
      if (details.pressedFlower.enabled && !back)
        Positioned(
          left: width * .12,
          right: width * .09,
          bottom: width * .08,
          child: Align(
            alignment: flowerAlignment(details.pressedFlower),
            child: PressedFlower(
              choice: details.pressedFlower,
              size: width * .27,
            ),
          ),
        ),
      if (!back)
        Positioned(
          left: width * .12,
          right: width * .09,
          top: width * .34,
          child: Text(
            title,
            textScaler: width < 80 ? TextScaler.noScaling : null,
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
  );
}

class _BookPageEdges extends StatelessWidget {
  const _BookPageEdges({
    required this.color,
    required this.coverIndex,
    required this.before,
    required this.after,
    this.maxDepth = 7,
    this.bottomStart = .53,
  });
  final Color color;
  final int coverIndex, before, after;
  final double maxDepth, bottomStart;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: CustomPaint(
        painter: _PageEdgesPainter(
          color,
          _coverColors[coverIndex],
          before,
          after,
          maxDepth,
          bottomStart,
        ),
      ),
    ),
  );
}

class _PageEdgesPainter extends CustomPainter {
  const _PageEdgesPainter(
    this.paper,
    this.cover,
    this.before,
    this.after,
    this.maxDepth,
    this.bottomStart,
  );
  final Color paper, cover;
  final int before, after;
  final double maxDepth, bottomStart;

  @override
  void paint(Canvas canvas, Size size) {
    void stack(int count, {required bool right}) {
      if (count < 1 || size.shortestSide < 12) return;
      final layers = (1 + math.log(count) / math.ln2).floor().clamp(1, 7);
      final depth = math.min(maxDepth, 1 + layers * .8);
      canvas.save();
      if (!right) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      for (var i = 0; i <= layers; i++) {
        final offset = depth * i / (layers + 1);
        final x = size.width - offset;
        final bottom = size.height - offset * .65;
        final foot = size.width * bottomStart;
        final stroke = Paint()
          ..color = i == 0
              ? cover.withValues(alpha: .76)
              : Color.lerp(paper, cover, i.isEven ? .35 : .16)!
          ..strokeWidth = i == 0 ? 1.8 : .7
          ..style = PaintingStyle.stroke;
        final edge = Path()
          ..moveTo(x, 0)
          ..lineTo(x, bottom - 5)
          ..quadraticBezierTo(x, bottom, x - 6, bottom)
          ..lineTo(foot, bottom);
        canvas.drawPath(edge, stroke);
      }
      canvas.restore();
    }

    stack(before, right: false);
    stack(after, right: true);
  }

  @override
  bool shouldRepaint(_PageEdgesPainter old) =>
      paper != old.paper ||
      cover != old.cover ||
      before != old.before ||
      after != old.after ||
      maxDepth != old.maxDepth ||
      bottomStart != old.bottomStart;
}
