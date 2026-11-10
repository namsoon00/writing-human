import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/model.dart';
import 'paper.dart';

class CollectionSheet extends StatefulWidget {
  const CollectionSheet({
    super.key,
    required this.controller,
    required this.onRecord,
    required this.onNewSheet,
    required this.onNewBook,
    this.onDemo,
  });
  final LibraryController controller;
  final ValueChanged<WritingRecord> onRecord;
  final ValueChanged<String?> onNewSheet;
  final VoidCallback onNewBook;
  final VoidCallback? onDemo;
  @override
  State<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends State<CollectionSheet> {
  bool books = false;
  String? bookId;
  String query = '';
  LibraryController get c => widget.controller;
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
                        style: const TextStyle(
                          fontFamily: serif,
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
                    : records.isEmpty
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
                            if (widget.onDemo != null)
                              TextButton(
                                onPressed: widget.onDemo,
                                child: const Text(
                                  '예시 둘러보기',
                                  style: TextStyle(fontSize: 12),
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
                        itemCount: records.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: line, height: 1),
                        itemBuilder: (context, i) {
                          final r = records[i];
                          final b = c.library.books
                              .where((b) => b.id == r.bookId)
                              .firstOrNull;
                          final pages = c.library.pages
                              .where((p) => p.recordId == r.id)
                              .length;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            title: Text(
                              _excerpt(r),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: serif,
                                fontSize: 18,
                                height: 1.7,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 9),
                              child: Text(
                                '${b?.title ?? '책 없이 쓴 글'} · $pages쪽',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              size: 13,
                              color: muted,
                            ),
                            onTap: () => widget.onRecord(r),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: widget.onNewBook,
                      child: const Text(
                        '새 책 만들기',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    const Spacer(),
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
              leading: BookCover(title: book.title, width: 42, variant: i),
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
