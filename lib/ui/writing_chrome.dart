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
          child: Text(
            bookTitle ?? '쓰는 인간',
            key: const ValueKey('writing-title'),
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
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('open-bookshelf'),
            onPressed: onCollection,
            style: TextButton.styleFrom(
              foregroundColor: brandInk,
              minimumSize: const Size(68, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('책장', style: TextStyle(fontSize: 13)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: onNewSheet,
            tooltip: bookTitle == null ? '새 종이' : '이 책에 한 쪽 추가',
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
    this.pageLabel,
    this.pageCount = 1,
    this.onPages,
    this.onSource,
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
  final VoidCallback onTools, onMore;
  final VoidCallback? onPages, onPrevious, onNext, onSource;
  final String? pageLabel;
  final int pageCount;
  final VoidCallback? onTurnStart, onTurnCancel;
  final ValueChanged<double>? onTurnUpdate;
  final void Function(double distance, double velocity)? onTurnEnd;
  final bool failed;
  final BookDetailChoice ornament;

  static const _sourceWidth = 48.0;
  static const _moreWidth = 64.0;
  static const _pageSideInset = _sourceWidth + _moreWidth;

  @override
  Widget build(BuildContext context) => PaperSwipe(
    key: const ValueKey('page-number-swipe'),
    onTurnStart: onTurnStart,
    onTurnUpdate: onTurnUpdate,
    onTurnEnd: onTurnEnd,
    onTurnCancel: onTurnCancel,
    onPrevious: onPrevious,
    onNext: onNext,
    child: SizedBox(
      height: 64 + (MediaQuery.textScalerOf(context).scale(13) - 13) * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _pageSideInset),
              child: Tooltip(
                message: '쓰기 취향',
                excludeFromSemantics: true,
                child: TextButton(
                  onPressed: onTools,
                  style: TextButton.styleFrom(
                    foregroundColor: brandInk,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    '쓰기 취향',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: _pageSideInset,
            right: _pageSideInset,
            top: 0,
            bottom: 0,
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
                      horizontal: 4,
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
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _sourceWidth,
                  child: TextFieldTapRegion(
                    child: TextButton(
                      key: const ValueKey('writing-originals'),
                      onPressed: onSource,
                      style: TextButton.styleFrom(
                        foregroundColor: brandInk,
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('원문', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                SizedBox(
                  width: _moreWidth,
                  child: IconButton(
                    tooltip: '더 보기',
                    onPressed: onMore,
                    color: brandInk,
                    icon: const Icon(CupertinoIcons.ellipsis, size: 23),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
