import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/model.dart';
import 'paper.dart';
import 'book_details.dart';
import 'reading_details.dart';
import 'new_book_dialog.dart';

class CollectionSheet extends StatefulWidget {
  const CollectionSheet({
    super.key,
    required this.controller,
    required this.onRecord,
    required this.onNewSheet,
    required this.onNewBook,
  });
  final LibraryController controller;
  final ValueChanged<WritingRecord> onRecord;
  final ValueChanged<String?> onNewSheet;
  final VoidCallback onNewBook;
  @override
  State<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends State<CollectionSheet> {
  bool books = false;
  String? bookId;
  String query = '';
  LibraryController get c => widget.controller;
  Future<void> _owner(Book book) async {
    final controller = c;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => BookOwnerDialog(owner: book.owner),
    );
    if (name != null && mounted && controller == c) {
      c.setBookOwner(book.id, name);
    }
  }

  Future<void> _indexName(Book book) async {
    final controller = c;
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          BookIndexDialog(label: book.indexLabel, title: book.title),
    );
    if (name != null && mounted && controller == c) {
      c.setBookIndexLabel(book.id, name);
    }
  }

  Widget _indexTabs() => SizedBox(
    height: math.max(
      64.0,
      MediaQuery.textScalerOf(context).scale(13) * 1.4 + 40,
    ),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
      itemCount: c.library.books.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final book = c.library.books[i];
        return BookIndexTab(
          key: ValueKey('book-index-${book.id}'),
          label: book.indexLabel.isEmpty ? book.title : book.indexLabel,
          choice: c.library.style.bookDetails.indexTab,
          selected: bookId == book.id,
          onTap: () => setState(() {
            books = false;
            bookId = book.id;
            query = '';
          }),
        );
      },
    ),
  );

  String _excerpt(WritingRecord r) {
    final pages = c.library.pages.where((p) => p.recordId == r.id);
    final text = pages
        .map((p) => p.text.trim())
        .where((t) => t.isNotEmpty)
        .firstOrNull;
    return text?.split('\n').first ?? '아직 비어 있는 종이';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final book = c.library.books.where((b) => b.id == bookId).firstOrNull;
      final records = c.library.records.reversed
          .where(
            (r) =>
                (bookId == null || r.bookId == bookId) &&
                '${_excerpt(r)} ${r.title} ${c.library.books.where((b) => b.id == r.bookId).firstOrNull?.title ?? ''}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
          )
          .toList();
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
                child: Row(
                  children: [
                    if (bookId != null)
                      IconButton(
                        tooltip: '모든 책',
                        onPressed: () => setState(() {
                          bookId = null;
                          books = true;
                        }),
                        icon: const Icon(CupertinoIcons.chevron_left, size: 18),
                      ),
                    Expanded(
                      child: Text(
                        book?.title ?? '보관함',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: appFontFamily,
                          fontFamilyFallback: appFontFallback,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark, size: 18),
                    ),
                  ],
                ),
              ),
              if (bookId == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      for (final item in [(false, '내 글'), (true, '책')])
                        Padding(
                          padding: const EdgeInsets.only(right: 22),
                          child: TextButton(
                            onPressed: () => setState(() {
                              books = item.$1;
                              query = '';
                            }),
                            style: TextButton.styleFrom(
                              foregroundColor: books == item.$1 ? ink : muted,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              item.$2,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: books == item.$1
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if ((books || bookId != null) &&
                  c.library.books.isNotEmpty &&
                  c.library.style.bookDetails.indexTab.enabled)
                _indexTabs(),
              if (!books && c.library.records.length > 5)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '문장 찾기',
                      prefixIcon: Icon(CupertinoIcons.search, size: 17),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
              Expanded(
                child: books && bookId == null
                    ? _books()
                    : records.isEmpty && book == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.doc_plaintext,
                              color: muted,
                              size: 28,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '써 내려간 문장은\n여기에 차곡차곡.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: muted,
                                fontSize: 14,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        itemCount: records.length + (book == null ? 0 : 1),
                        separatorBuilder: (_, i) => book != null
                            ? i == 0
                                  ? const SizedBox(height: 12)
                                  : RecordDivider(
                                      choice: c
                                          .library
                                          .style
                                          .bookDetails
                                          .recordDivider,
                                    )
                            : const Divider(color: line, height: 1),
                        itemBuilder: (context, i) {
                          if (book != null && i == 0) {
                            final ids = c.library.records
                                .where((r) => r.bookId == book.id)
                                .map((r) => r.id)
                                .toSet();
                            final pageCount = c.library.pages
                                .where((p) => ids.contains(p.recordId))
                                .length;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Bookplate(
                                  flower:
                                      c.library.style.bookDetails.pressedFlower,
                                  choice: c.library.style.bookDetails.bookplate,
                                  title: book.title,
                                  owner: book.owner,
                                  onOwner: () => _owner(book),
                                  summary:
                                      '${ids.length}편 · $pageCount쪽${book.author.isEmpty ? '' : ' · ${book.author}'}',
                                ),
                                Tooltip(
                                  message: '색인 이름 고치기',
                                  child: TextButton.icon(
                                    key: const ValueKey('edit-book-index'),
                                    onPressed: () => _indexName(book),
                                    icon: const Icon(
                                      Icons.label_outline,
                                      size: 16,
                                    ),
                                    label: Text(
                                      '색인 이름 · ${book.indexLabel.isEmpty ? book.title : book.indexLabel}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          final r = records[i - (book == null ? 0 : 1)];
                          final b = c.library.books
                              .where((b) => b.id == r.bookId)
                              .firstOrNull;
                          final recordPages =
                              c.library.pages
                                  .where((p) => p.recordId == r.id)
                                  .toList()
                                ..sort((a, b) => a.number.compareTo(b.number));
                          final date = recordPages.firstOrNull?.writtenOn;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            title: Text(
                              _excerpt(r),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: appFontFamily,
                                fontFamilyFallback: appFontFallback,
                                fontSize: 18,
                                height: 1.7,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 9),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${b?.title ?? '책 없이 쓴 글'} · ${recordPages.length}쪽',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (date != null)
                                    DateStamp(
                                      date: date,
                                      choice:
                                          c.library.style.bookDetails.dateStamp,
                                    ),
                                ],
                              ),
                            ),
                            trailing: r.id == c.library.activeRecord?.id
                                ? Semantics(
                                    label: '이어서 쓰는 글',
                                    child: RibbonBookmark(
                                      choice:
                                          c.library.style.bookDetails.ribbon,
                                      width: 10,
                                      height: 30,
                                    ),
                                  )
                                : const Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 13,
                                    color: muted,
                                  ),
                            onTap: () => widget.onRecord(r),
                          );
                        },
                      ),
              ),
              if (c.saveError != null)
                TextButton(
                  onPressed: c.retrySave,
                  child: const Text(
                    '저장 실패 · 다시 시도',
                    style: TextStyle(color: burgundy),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: widget.onNewBook,
                      child: const Text(
                        '새 책 만들기',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => widget.onNewSheet(bookId),
                      icon: const Icon(CupertinoIcons.plus, size: 16),
                      label: const Text('새 종이'),
                      style: FilledButton.styleFrom(
                        backgroundColor: burgundy,
                        foregroundColor: paper,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _books() => c.library.books.isEmpty
      ? const Center(
          child: Text(
            '책으로 묶는 건, 나중에 해도 괜찮아요.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
        )
      : ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: c.library.books.length,
          separatorBuilder: (_, _) => const Divider(color: line, height: 1),
          itemBuilder: (context, i) {
            final book = c.library.books[i];
            final count = c.library.records
                .where((r) => r.bookId == book.id)
                .length;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              leading: BookCover(
                details: c.library.style.bookDetails,
                title: book.title,
                width: 42,
                variant: i,
                bookmarked: book.id == c.library.activeBook?.id,
              ),
              title: Text(
                book.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${book.author.isEmpty ? '나의 문장 모음' : book.author} · $count편',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              trailing: IconButton(
                tooltip: '즐겨찾기',
                onPressed: () => c.toggleFavorite(book.id),
                icon: Icon(
                  c.library.style.favoriteBookIds.contains(book.id)
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                  size: 17,
                  color: muted,
                ),
              ),
              onTap: () => setState(() {
                books = false;
                bookId = book.id;
              }),
            );
          },
        );
}
