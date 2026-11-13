import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/library_controller.dart';
import '../data/model.dart';
import 'paper.dart';

class Bookshelf extends StatelessWidget {
  const Bookshelf({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onDetails,
    required this.onWrite,
    required this.query,
    this.scrollController,
  });

  final LibraryController controller;
  final ValueChanged<Book> onOpen, onDetails;
  final VoidCallback onWrite;
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
    final pageCounts = <String, int>{};
    for (final page in library.pages) {
      final bookId = recordBooks[page.recordId];
      if (bookId != null) {
        pageCounts.update(bookId, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    BookCover cover(Book book, double width, {bool thumbnail = false}) =>
        BookCover(
          title: thumbnail ? '' : book.title,
          width: width,
          variant: controller.coverIndexFor(book),
          details: library.style.bookDetails,
          pageCount: pageCounts[book.id] ?? 0,
        );

    if (recent == null && books.isEmpty) {
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

    Widget openBook(
      Book book,
      Widget child, {
      required Key key,
      double radius = 6,
    }) => Semantics(
      label: '${book.title} 펼치기',
      button: true,
      onTap: () => onOpen(book),
      excludeSemantics: true,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(radius),
        onTap: () => onOpen(book),
        child: child,
      ),
    );

    Widget openCover(Book book, double width) => openBook(
      book,
      cover(book, width),
      key: ValueKey('shelf-book-${book.id}'),
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
          padding: const EdgeInsets.fromLTRB(padding, 14, padding, 20),
          itemCount: (books.length + columns - 1) ~/ columns + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (recent != null)
                    if (compact)
                      openBook(
                        recent,
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xffeee3d3),
                            borderRadius: BorderRadius.circular(16),
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
                        radius: 16,
                      )
                    else ...[
                      const _ShelfLabel('최근 노트'),
                      const SizedBox(height: 8),
                      Center(child: openCover(recent, featuredWidth)),
                      const _WoodShelf(),
                      Center(child: details(recent)),
                    ],
                  if (books.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
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
            final row = books.skip(start).take(columns).toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final book in row)
                        SizedBox(
                          width: slotWidth,
                          child: Center(child: openCover(book, coverWidth)),
                        ),
                    ],
                  ),
                  const _WoodShelf(),
                  Row(
                    children: [
                      for (final book in row)
                        SizedBox(
                          width: slotWidth,
                          child: Center(child: details(book)),
                        ),
                    ],
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
    height: 12,
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffa77452), Color(0xff8c5c3d), Color(0xff5e3926)],
          stops: [0, .32, 1],
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
