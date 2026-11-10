import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'paper.dart';
import 'paper_swipe.dart';
import 'book_details.dart';
import '../data/book_detail_style.dart';

/// Small, native controls over the same paper as the editor. Decorative
/// materials never replace editable text or accessible button labels.
class WritingHeader extends StatelessWidget {
  const WritingHeader({
    super.key,
    required this.onCollection,
    required this.onNewSheet,
    this.bookTitle,
    this.compact = false,
    this.useDevelopmentTypeface = true,
    this.bookmarked = false,
    this.ribbon = const BookDetailChoice(),
  });
  final VoidCallback onCollection, onNewSheet;
  final String? bookTitle;
  final bool compact, useDevelopmentTypeface;
  final bool bookmarked;
  final BookDetailChoice ribbon;

  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        (compact ? 68 : 98) +
        (MediaQuery.textScalerOf(context).scale(20) - 20) * 1.3,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (bookmarked)
          Positioned(
            right: 64,
            top: 0,
            child: RibbonBookmark(height: compact ? 23 : 38, choice: ribbon),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 88),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const InkMark(size: 22),
              const SizedBox(height: 3),
              Text(
                '쓰는 인간',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: appFontFamily,
                  fontFamilyFallback: appFontFallback,
                  fontSize: 20,
                  color: brandInk,
                  height: 1.3,
                  letterSpacing: .4,
                ),
              ),
              if (bookTitle != null && !compact) ...[
                const SizedBox(height: 5),
                Text(
                  bookTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onCollection,
            style: TextButton.styleFrom(
              foregroundColor: brandInk,
              minimumSize: const Size(68, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('보관함', style: TextStyle(fontSize: 13)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: onNewSheet,
            tooltip: '새 종이',
            color: brandInk,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(CupertinoIcons.plus, size: 25),
          ),
        ),
      ],
    ),
  );
}

class WritingFooter extends StatelessWidget {
  const WritingFooter({
    super.key,
    required this.status,
    required this.onTools,
    required this.onMore,
    required this.onDone,
    required this.focused,
    this.pageLabel,
    this.pageCount = 1,
    this.onPages,
    this.onPrevious,
    this.onNext,
    this.onTurnStart,
    this.onTurnUpdate,
    this.onTurnEnd,
    this.onTurnCancel,
    this.failed = false,
    this.ornament = const BookDetailChoice(),
  });
  final String status;
  final VoidCallback onTools, onMore, onDone;
  final VoidCallback? onPages, onPrevious, onNext;
  final String? pageLabel;
  final int pageCount;
  final VoidCallback? onTurnStart, onTurnCancel;
  final ValueChanged<double>? onTurnUpdate;
  final void Function(double distance, double velocity)? onTurnEnd;
  final bool focused, failed;
  final BookDetailChoice ornament;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64 + (MediaQuery.textScalerOf(context).scale(13) - 13) * 2,
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Tooltip(
            message: '쓰기 도구',
            child: TextButton(
              onPressed: onTools,
              style: TextButton.styleFrom(
                foregroundColor: brandInk,
                minimumSize: const Size(48, 48),
              ),
              child: Semantics(
                label: '쓰기 도구',
                excludeSemantics: true,
                child: const CustomPaint(
                  painter: _Underline(),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        fontFamily: appFontFamily,
                        fontFamilyFallback: appFontFallback,
                        fontSize: 21,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: PaperSwipe(
            key: const ValueKey('page-number-swipe'),
            onTurnStart: onTurnStart,
            onTurnUpdate: onTurnUpdate,
            onTurnEnd: onTurnEnd,
            onTurnCancel: onTurnCancel,
            onPrevious: onPrevious,
            onNext: onNext,
            child: Semantics(
              label: '$pageLabel쪽, 전체 $pageCount쪽',
              onIncrease: onNext,
              onDecrease: onPrevious,
              child: Tooltip(
                message: '페이지 목록',
                child: TextButton(
                  key: const ValueKey('page-number'),
                  onPressed: onPages,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: muted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PageOrnament(
                        choice: ornament,
                        child: Text(
                          pageLabel ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Semantics(
                        liveRegion: failed,
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: failed ? burgundy : muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: focused
              ? TextButton(
                  onPressed: onDone,
                  child: const Text('완료', style: TextStyle(fontSize: 12)),
                )
              : IconButton(
                  tooltip: '더 보기',
                  onPressed: onMore,
                  color: brandInk,
                  icon: const Icon(CupertinoIcons.ellipsis, size: 23),
                ),
        ),
      ],
    ),
  );
}

class _Underline extends CustomPainter {
  const _Underline();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(-2, size.height - 1)
        ..quadraticBezierTo(
          size.width * .5,
          size.height - 5,
          size.width + 2,
          size.height - 3,
        ),
      Paint()
        ..color = brandInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Underline oldDelegate) => false;
}
