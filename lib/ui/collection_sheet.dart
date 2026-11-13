import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/library_search.dart';
import '../data/model.dart';
import 'paper.dart';
import 'book_details.dart';
import 'bookshelf.dart';
import 'reading_details.dart';
import 'new_book_dialog.dart';
import 'writing_sheet_preview.dart';

class CollectionSheet extends StatefulWidget {
  const CollectionSheet({
    super.key,
    required this.controller,
    required this.onRecord,
    required this.onBook,
    required this.onNewSheet,
    required this.onNewBook,
    this.onPassage,
    this.onArchiveBook,
    this.onBookOriginals,
  });
  final LibraryController controller;
  final ValueChanged<WritingRecord> onRecord;
  final ValueChanged<Book> onBook;
  final ValueChanged<String?> onNewSheet;
  final VoidCallback onNewBook;
  final ValueChanged<Passage>? onPassage;
  final ValueChanged<Book>? onArchiveBook, onBookOriginals;
  @override
  State<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends State<CollectionSheet> {
  bool books = true;
  bool showSearch = false;
  String? bookId;
  String query = '';
  final searchField = TextEditingController();
  final shelfScroll = ScrollController();
  final writingScroll = ScrollController();
  final scrollStorage = PageStorageBucket();
  LibraryController get c => widget.controller;

  void _clearSearch() {
    searchField.clear();
    query = '';
    showSearch = false;
  }

  @override
  void dispose() {
    searchField.dispose();
    shelfScroll.dispose();
    writingScroll.dispose();
    super.dispose();
  }

  Future<void> _rename(Book book) async {
    final controller = c;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => BookTitleDialog(title: book.title),
    );
    if (name != null && mounted && controller == c) {
      c.setBookTitle(book.id, name);
    }
  }

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

  Future<void> _cover(Book book) async {
    final controller = c;
    final selected = c.coverIndexFor(book);
    final details = c.library.style.bookDetails;
    final choice = await showDialog<int>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('책 표지'),
        children: [
          for (var i = 0; i < coverNames.length; i++)
            ListTile(
              leading: ExcludeSemantics(
                child: BookCover(
                  title: book.title,
                  width: 34,
                  variant: i,
                  details: details,
                ),
              ),
              title: Text(coverNames[i]),
              selected: selected == i,
              trailing: selected == i ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(dialog, i),
            ),
        ],
      ),
    );
    if (choice != null && mounted && c == controller) {
      c.setBookMaterials(book.id, coverIndex: choice);
    }
  }

  Future<void> _paper(Book book) async {
    final controller = c;
    final selected = book.paperIndex ?? -1;
    final fallback = c.library.style.paperIndex;
    final choice = await showDialog<int>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('책 내지'),
        children: [
          for (var i = -1; i < paperNames.length; i++)
            ListTile(
              leading: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: paperColors[i < 0 ? fallback : i],
                  border: Border.all(color: line),
                ),
              ),
              title: Text(i < 0 ? '기본 종이 사용' : paperNames[i]),
              selected: selected == i,
              trailing: selected == i ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(dialog, i),
            ),
        ],
      ),
    );
    if (choice != null && mounted && c == controller) {
      c.setBookMaterials(
        book.id,
        paperIndex: choice < 0 ? null : choice,
        useDefaultPaper: choice < 0,
      );
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
            _clearSearch();
          }),
        );
      },
    ),
  );

  void _switchView() {
    FocusScope.of(context).unfocus();
    setState(() {
      books = !books;
      _clearSearch();
    });
  }

  void _toggleSearch() {
    if (showSearch) FocusScope.of(context).unfocus();
    setState(() {
      if (showSearch) {
        _clearSearch();
      } else {
        showSearch = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final book = c.library.books.where((b) => b.id == bookId).firstOrNull;
      final paperIndex = book?.paperIndex ?? c.library.style.paperIndex;
      final bookPaper = paperColors[paperIndex];
      final records = c.library.records.reversed
          .where((r) => bookId == null || r.bookId == bookId)
          .toList();
      final passages = !books && widget.onPassage != null
          ? LibraryPassages(c.library)
          : null;
      final shelf = books && bookId == null;
      final searching = passages != null && query.trim().isNotEmpty;
      final topLevel = bookId == null;
      final canSearch = shelf || (records.isNotEmpty && passages != null);
      final searchLabel = shelf ? '노트 검색' : '내 글 검색';
      final revisit =
          !books && !searching && bookId == null && widget.onPassage != null
          ? passages?.revisit(DateTime.now())
          : null;
      final media = MediaQuery.of(context);
      final keyboard = media.viewInsets.bottom;
      final sheet = SizedBox(
        height: math.max(
          0.0,
          math.min(media.size.height * .88, media.size.height - keyboard - 44),
        ),
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
                          _clearSearch();
                        }),
                        icon: const Icon(CupertinoIcons.chevron_left, size: 18),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          if (topLevel) ...[
                            const InkMark(size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              book?.title ?? (shelf ? '책장' : '내 글'),
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
                        ],
                      ),
                    ),
                    if (topLevel && canSearch)
                      IconButton(
                        tooltip: showSearch ? '$searchLabel 닫기' : searchLabel,
                        onPressed: _toggleSearch,
                        icon: Icon(
                          showSearch
                              ? CupertinoIcons.xmark_circle
                              : CupertinoIcons.search,
                          size: 19,
                        ),
                      ),
                    if (book != null)
                      IconButton(
                        tooltip: '책 이름 변경',
                        onPressed: () => _rename(book),
                        icon: const Icon(CupertinoIcons.pencil, size: 18),
                      ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark, size: 18),
                    ),
                  ],
                ),
              ),
              if (topLevel && keyboard == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _switchView,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              shelf
                                  ? CupertinoIcons.doc_text
                                  : CupertinoIcons.book,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(shelf ? '내 글' : '책장'),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: shelf
                            ? widget.onNewBook
                            : () => widget.onNewSheet(null),
                        icon: const Icon(CupertinoIcons.plus, size: 15),
                        label: Text(shelf ? '새 노트' : '새 종이'),
                      ),
                    ],
                  ),
                ),
              if (shelf && showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: TextField(
                    key: const ValueKey('shelf-title-search'),
                    controller: searchField,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '노트 제목 찾기',
                      prefixIcon: Icon(CupertinoIcons.search, size: 17),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
              if (keyboard == 0 &&
                  bookId != null &&
                  c.library.books.isNotEmpty &&
                  c.library.style.bookDetails.indexTab.enabled)
                _indexTabs(),
              if (!shelf && canSearch && (showSearch || !topLevel))
                Padding(
                  key: const ValueKey('collection-search'),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: TextField(
                    controller: searchField,
                    autofocus: topLevel,
                    decoration: InputDecoration(
                      hintText: '문장, 책, 날짜 찾기',
                      prefixIcon: const Icon(CupertinoIcons.search, size: 17),
                      isDense: true,
                      enabledBorder: book == null
                          ? null
                          : const UnderlineInputBorder(
                              borderSide: BorderSide(color: line),
                            ),
                      focusedBorder: book == null
                          ? null
                          : const UnderlineInputBorder(
                              borderSide: BorderSide(color: brandInk),
                            ),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
              Expanded(
                key: const ValueKey('collection-results'),
                child: shelf
                    ? Bookshelf(
                        key: query.trim().isEmpty
                            ? const PageStorageKey('books')
                            : ValueKey(query.trim().toLowerCase()),
                        controller: c,
                        scrollController: query.trim().isEmpty
                            ? shelfScroll
                            : null,
                        query: query,
                        onOpen: widget.onBook,
                        onWrite: () => widget.onNewSheet(null),
                        onDetails: (book) => setState(() {
                          books = false;
                          bookId = book.id;
                          _clearSearch();
                        }),
                      )
                    : topLevel
                    ? _writingSheets(
                        records,
                        revisit: revisit,
                        results: searching
                            ? passages.search(query).toList()
                            : null,
                      )
                    : searching
                    ? _results(passages.search(query, bookId: bookId).toList())
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        itemCount:
                            records.length +
                            (book == null && revisit == null ? 0 : 1),
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
                          if (revisit != null && i == 0) {
                            return _passageTile(revisit, revisit: true);
                          }
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
                                  stockColor: bookPaper,
                                  flower:
                                      c.library.style.bookDetails.pressedFlower,
                                  choice: c.library.style.bookDetails.bookplate,
                                  title: book.title,
                                  owner: book.owner,
                                  onOwner: () => _owner(book),
                                  summary:
                                      '${ids.length}편 · $pageCount쪽${book.author.isEmpty ? '' : ' · ${book.author}'}',
                                ),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    if (widget.onBookOriginals != null)
                                      TextButton.icon(
                                        onPressed: () =>
                                            widget.onBookOriginals!(book),
                                        icon: const Icon(
                                          CupertinoIcons.quote_bubble,
                                          size: 16,
                                        ),
                                        label: const Text('원문'),
                                      ),
                                    TextButton.icon(
                                      onPressed: () => _cover(book),
                                      icon: const Icon(
                                        CupertinoIcons.book,
                                        size: 16,
                                      ),
                                      label: const Text('표지 고르기'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _paper(book),
                                      icon: const Icon(
                                        CupertinoIcons.doc,
                                        size: 16,
                                      ),
                                      label: const Text('내지 고르기'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          c.toggleFavorite(book.id),
                                      icon: Icon(
                                        c.library.style.favoriteBookIds
                                                .contains(book.id)
                                            ? CupertinoIcons.bookmark_fill
                                            : CupertinoIcons.bookmark,
                                        size: 16,
                                      ),
                                      label: const Text('즐겨찾기'),
                                    ),
                                    if (widget.onArchiveBook != null)
                                      TextButton.icon(
                                        onPressed: () =>
                                            widget.onArchiveBook!(book),
                                        icon: const Icon(
                                          CupertinoIcons.arrow_down_doc,
                                          size: 16,
                                        ),
                                        label: const Text('책 PDF 내보내기'),
                                      ),
                                  ],
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
                          final r =
                              records[i -
                                  (book == null && revisit == null ? 0 : 1)];
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
                              _firstWriting(recordPages, maxLines: 1),
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
              if (!topLevel && keyboard == 0)
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
                          backgroundColor: brandInk,
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
      return PageStorage(
        bucket: scrollStorage,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Stack(
            children: [
              Positioned.fill(
                child: PaperBackdrop(
                  color: book == null
                      ? (shelf ? paper : const Color(0xffe8dbca))
                      : bookPaper,
                  grainOpacity: book == null
                      ? .21
                      : paperGrainOpacity[paperIndex],
                  child: const SizedBox.expand(),
                ),
              ),
              sheet,
            ],
          ),
        ),
      );
    },
  );

  Widget _writingSheets(
    List<WritingRecord> records, {
    Passage? revisit,
    List<Passage>? results,
  }) {
    final count = results?.length ?? records.length + (revisit == null ? 0 : 1);
    if (count == 0) {
      return Center(
        child: Text(
          results == null ? '아직 쓴 글이 없어요.' : '일치하는 기록이 없어요.',
          style: const TextStyle(color: muted),
        ),
      );
    }

    final library = c.library;
    final books = {for (final book in library.books) book.id: book};
    final recordBooks = {
      for (final record in records) record.id: record.bookId,
    };
    final pages = <String, List<WritingPage>>{};
    if (results == null) {
      for (final page in library.pages) {
        (pages[page.recordId] ??= []).add(page);
      }
      for (final recordPages in pages.values) {
        recordPages.sort((a, b) => a.number.compareTo(b.number));
      }
    }

    WritingStyle styleFor(Book? book) {
      final style = library.style;
      return book?.paperIndex == null
          ? style
          : style.copy(paperIndex: book!.paperIndex);
    }

    Widget passageSheet(Passage passage, {String? heading}) {
      final book = books[recordBooks[passage.page.recordId]];
      return WritingSheetPreview(
        excerpt: passage.excerpt,
        notebook: book?.title,
        date: passage.page.writtenOn,
        style: styleFor(book),
        heading: heading,
        onOpen: () => widget.onPassage!(passage),
      );
    }

    return ListView.separated(
      key: results == null
          ? const PageStorageKey('writing')
          : ValueKey(query.trim()),
      controller: results == null ? writingScroll : null,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        if (results != null) return passageSheet(results[index]);
        if (revisit != null && index == 0) {
          return passageSheet(revisit, heading: '다시 만난 문장');
        }
        final record = records[index - (revisit == null ? 0 : 1)];
        final book = books[record.bookId];
        final recordPages = pages[record.id] ?? const [];
        return WritingSheetPreview(
          key: ValueKey('writing-sheet-${record.id}'),
          excerpt: _firstWriting(recordPages),
          notebook: book?.title,
          date: recordPages.firstOrNull?.writtenOn,
          style: styleFor(book),
          onOpen: () => widget.onRecord(record),
        );
      },
    );
  }

  String _firstWriting(List<WritingPage> pages, {int maxLines = 3}) {
    for (final page in pages) {
      final text = page.text.trim();
      if (text.isEmpty) continue;
      final lines = text.split('\n').where((line) => line.trim().isNotEmpty);
      return lines.take(maxLines).join('\n');
    }
    return '아직 비어 있는 종이';
  }

  Widget _results(List<Passage> results) => results.isEmpty
      ? const Center(child: Text('일치하는 기록이 없어요.'))
      : ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(color: line, height: 1),
          itemBuilder: (_, index) => _passageTile(results[index]),
        );

  Widget _passageTile(Passage passage, {bool revisit = false}) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    leading: revisit ? const Icon(CupertinoIcons.bookmark, size: 18) : null,
    title: Text(
      revisit ? '다시 만난 문장' : passage.excerpt,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      [
        if (revisit) passage.excerpt,
        '${passage.label} · ${passage.page.number}쪽',
        ?passage.page.writtenOn,
      ].join('\n'),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: const Icon(CupertinoIcons.chevron_right, size: 13, color: muted),
    onTap: () => widget.onPassage!(passage),
  );
}
