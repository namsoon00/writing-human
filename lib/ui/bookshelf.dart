import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/library_controller.dart';
import '../data/model.dart';
import 'paper.dart';

const loosePagesTitle = '낱장 모음';

class Bookshelf extends StatelessWidget {
  const Bookshelf({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onDetails,
    required this.onLoosePages,
    required this.onWrite,
    required this.query,
    this.scrollController,
  });

  final LibraryController controller;
  final ValueChanged<Book> onOpen, onDetails;
  final VoidCallback onWrite, onLoosePages;
  final String query;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final library = controller.library;
    final term = query.trim().toLowerCase();
    final recent = term.isEmpty
        ? library.activeBook ?? library.books.lastOrNull
        : null;
    final books = library.books
        .where((book) => book.title.toLowerCase().contains(term))
        .toList();
    final compact = books.length > 3;
    if (recent != null && !compact) {
      books.removeWhere((book) => book.id == recent.id);
    }
    final recordBooks = {
      for (final record in library.records) record.id: record.bookId,
    };
    final pageCounts = <String?, int>{};
    for (final page in library.pages) {
      if (!recordBooks.containsKey(page.recordId)) continue;
      final bookId = recordBooks[page.recordId];
      pageCounts.update(bookId, (count) => count + 1, ifAbsent: () => 1);
    }
    final loosePageCount = pageCounts[null] ?? 0;
    final showLoose = loosePageCount > 0 && loosePagesTitle.contains(term);
    final shelfCount = books.length + (showLoose ? 1 : 0);

    BookCover cover(Book book, double width, {bool thumbnail = false}) =>
        BookCover(
          title: thumbnail ? '' : book.title,
          width: width,
          variant: controller.coverIndexFor(book),
          details: controller.detailsFor(book),
          pageCount: pageCounts[book.id] ?? 0,
          bookmarked: !thumbnail && library.activeBook?.id == book.id,
        );

    if (recent == null && shelfCount == 0) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(term.isEmpty ? '아직 노트가 없어요.' : '일치하는 노트가 없어요.'),
              if (term.isEmpty) ...[
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: burgundy,
                    foregroundColor: paper,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onWrite,
                  child: const Text('새 종이'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    Widget openCoverSurface(
      String title,
      Widget child, {
      required Key key,
      required VoidCallback onTap,
    }) => Semantics(
      label: '$title 펼치기',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: child,
      ),
    );

    Widget openCover(Book book, double width) => openCoverSurface(
      book.title,
      cover(book, width),
      key: ValueKey('shelf-book-${book.id}'),
      onTap: () => onOpen(book),
    );

    Widget looseStack(double width) => openCoverSurface(
      loosePagesTitle,
      _LoosePaperStack(
        width: width,
        color: paperColors[library.style.paperIndex],
      ),
      key: const ValueKey('shelf-loose-pages'),
      onTap: onLoosePages,
    );

    Widget details(Book book) => IconButton(
      key: ValueKey('shelf-details-${book.id}'),
      tooltip: '${book.title} 상세',
      onPressed: () => onDetails(book),
      icon: const Icon(CupertinoIcons.ellipsis, size: 17, color: muted),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 18.0;
        final width = constraints.maxWidth - padding * 2;
        final columns = width < 270 ? 2 : 3;
        final slotWidth = width / columns;
        final coverWidth = math.min(142.0, slotWidth - 12);
        final featuredWidth = math.min(194.0, width * .57);
        return ListView.builder(
          key: const ValueKey('bookshelf-scroll'),
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(vertical: 14),
          itemCount: (shelfCount + columns - 1) ~/ columns + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (recent != null)
                    if (compact)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: padding,
                        ),
                        child: openCoverSurface(
                          recent.title,
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xffeee3d3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                            child: Row(
                              children: [
                                cover(recent, 42, thumbnail: true),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    recent.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 16,
                                  color: muted,
                                ),
                              ],
                            ),
                          ),
                          key: const ValueKey('shelf-recent'),
                          onTap: () => onOpen(recent),
                        ),
                      )
                    else ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: padding),
                        child: _ShelfLabel('최근 노트'),
                      ),
                      const SizedBox(height: 8),
                      Center(child: openCover(recent, featuredWidth)),
                      const _WoodShelf(),
                      Center(child: details(recent)),
                    ],
                  if (shelfCount > 0)
                    Padding(
                      padding: EdgeInsets.only(
                        left: padding,
                        right: padding,
                        top: recent == null ? 0 : 20,
                        bottom: 10,
                      ),
                      child: _ShelfLabel(
                        term.isNotEmpty
                            ? '검색 결과'
                            : recent != null && !compact
                            ? '다른 노트'
                            : '모든 노트',
                      ),
                    ),
                ],
              );
            }

            final start = (index - 1) * columns;
            final slots = [
              for (
                var i = start;
                i < math.min(start + columns, shelfCount);
                i++
              )
                if (showLoose && i == 0)
                  null
                else
                  books[i - (showLoose ? 1 : 0)],
            ];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: padding),
                    child: Row(
                      children: [
                        for (final book in slots)
                          SizedBox(
                            width: slotWidth,
                            child: Center(
                              child: book == null
                                  ? looseStack(coverWidth)
                                  : openCover(book, coverWidth),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const _WoodShelf(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: padding),
                    child: Row(
                      children: [
                        for (final book in slots)
                          SizedBox(
                            width: slotWidth,
                            child: Center(
                              child: book == null
                                  ? const SizedBox(
                                      height: kMinInteractiveDimension,
                                    )
                                  : details(book),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LoosePaperStack extends StatelessWidget {
  const _LoosePaperStack({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 1.36,
    child: Stack(
      children: [
        for (var layer = 2; layer >= 0; layer--)
          Positioned(
            top: 6.0 + (2 - layer) * 3.0,
            left: layer * 4.0,
            right: (2 - layer) * 4.0,
            bottom: 2.0 + layer * 3.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(color, brandInk, layer * .06),
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24513a29),
                    blurRadius: 5,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
              child: layer == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Text(
                          loosePagesTitle,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: brandInk, fontSize: 15),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    ),
  );
}

class _ShelfLabel extends StatelessWidget {
  const _ShelfLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontFamily: appFontFamily,
      fontFamilyFallback: appFontFallback,
      color: ink,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _WoodShelf extends StatelessWidget {
  const _WoodShelf();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 14,
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xffb68158),
            Color(0xffad7650),
            Color(0xff845434),
            Color(0xff634028),
          ],
          stops: [0, .19, .21, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x3d513019),
            blurRadius: 9,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: CustomPaint(painter: _WoodGrain()),
    ),
  );
}

class _WoodGrain extends CustomPainter {
  const _WoodGrain();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55;
    for (var i = 1; i <= 7; i++) {
      paint.color = i.isEven
          ? const Color(0x35ffdec0)
          : const Color(0x35381e13);
      final y = i * size.height / 9;
      final start = 4.0 + i * 1.8;
      canvas.drawPath(
        Path()
          ..moveTo(start, y)
          ..cubicTo(
            size.width * .28,
            y - 1.5,
            size.width * .56,
            y + 1.7,
            size.width - start,
            y - .2,
          ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WoodGrain oldDelegate) => false;
}
