import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/library_search.dart';
import '../data/model.dart';
import 'paper.dart';
import 'book_details.dart';
import 'book_appearance.dart';
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
    this.onContentsPage,
    this.onArchiveBook,
    this.onBookOriginals,
    this.showHandle = false,
  });
  final LibraryController controller;
  final ValueChanged<WritingRecord> onRecord;
  final ValueChanged<Book> onBook;
  final ValueChanged<String?> onNewSheet;
  final VoidCallback onNewBook;
  final ValueChanged<Passage>? onPassage;
  final ValueChanged<WritingPage>? onContentsPage;
  final ValueChanged<Book>? onArchiveBook, onBookOriginals;
  final bool showHandle;
  @override
  State<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends State<CollectionSheet> {
  bool books = true;
  bool showSearch = false;
  String? bookId;
  bool showingLoosePages = false;
  String query = '';
  final searchField = TextEditingController();
  final searchFocus = FocusNode(debugLabel: 'collection search');
  final shelfScroll = ScrollController();
  final writingScroll = ScrollController();
  final scrollStorage = PageStorageBucket();
  LibraryController get c => widget.controller;

  void _clearSearch() {
    searchFocus.unfocus();
    searchField.clear();
    query = '';
    showSearch = false;
  }

  @override
  void dispose() {
    searchFocus.dispose();
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

  Future<void> _showBookplate(Book book, String summary) => showDialog<void>(
    context: context,
    builder: (dialog) => Dialog(
      child: AnimatedBuilder(
        animation: c,
        builder: (_, _) {
          final current =
              c.library.books.where((item) => item.id == book.id).firstOrNull ??
              book;
          final details = c.detailsFor(current);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Bookplate(
                  choice: details.bookplate,
                  stockColor:
                      paperColors[current.paperIndex ??
                          c.library.style.paperIndex],
                  flower: details.pressedFlower,
                  title: current.title,
                  owner: current.owner,
                  summary: summary,
                  onOwner: () => _owner(current),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('닫기'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Future<void> _chooseBook(Book book) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('다른 책의 목차'),
        children: [
          for (final entry in c.library.books)
            if (c.detailsFor(entry).indexTab.enabled)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialog, entry.id),
                child: BookIndexTab(
                  key: ValueKey('book-index-${entry.id}'),
                  label: entry.indexLabel.isEmpty
                      ? entry.title
                      : entry.indexLabel,
                  choice: c.detailsFor(entry).indexTab,
                  selected: entry.id == book.id,
                ),
              ),
        ],
      ),
    );
    if (mounted && chosen != null) {
      setState(() {
        bookId = chosen;
        _clearSearch();
      });
    }
  }

  Widget _bookMenu(Book book, String summary, bool canSearch) {
    final favorite = c.library.style.favoriteBookIds.contains(book.id);
    return PopupMenuButton<VoidCallback>(
      tooltip: '책 더 보기',
      icon: const Icon(CupertinoIcons.ellipsis),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        if (canSearch)
          PopupMenuItem(value: _toggleSearch, child: const Text('이 책에서 찾기')),
        PopupMenuItem(value: () => _rename(book), child: const Text('책 이름 변경')),
        PopupMenuItem(
          value: () => _showBookplate(book, summary),
          child: const Text('장서표'),
        ),
        PopupMenuItem(
          value: () => showBookAppearance(context, c, book.id),
          child: const Text('책 꾸미기'),
        ),
        PopupMenuItem(
          value: () => c.toggleFavorite(book.id),
          child: Text(favorite ? '즐겨찾기 해제' : '즐겨찾기'),
        ),
        if (c.library.books.any(
          (entry) =>
              entry.id != book.id && c.detailsFor(entry).indexTab.enabled,
        ))
          PopupMenuItem(
            value: () => _chooseBook(book),
            child: const Text('다른 책의 목차'),
          ),
        PopupMenuItem(
          key: const ValueKey('edit-book-index'),
          value: () => _indexName(book),
          child: const Text('색인 이름 고치기'),
        ),
        if (widget.onArchiveBook != null)
          PopupMenuItem(
            value: () => widget.onArchiveBook!(book),
            child: const Text('책 PDF 내보내기'),
          ),
      ],
    );
  }

  Widget _contentsHeader(Book? book, String summary, WritingPage? resumePage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 24),
      child: Column(
        children: [
          const InkMark(size: 12),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              book?.title ?? loosePagesTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, height: 1.3, color: ink),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.5, color: muted),
          ),
          if (book != null && resumePage != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => widget.onBook(book),
              icon: const Icon(CupertinoIcons.book, size: 16),
              label: const Text('이어서 쓰기'),
              style: FilledButton.styleFrom(
                backgroundColor: brandInk,
                foregroundColor: paper,
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
          if (book != null)
            TextButton(
              onPressed: () => showBookAppearance(context, c, book.id),
              style: TextButton.styleFrom(
                foregroundColor: brandInk,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('책 꾸미기'),
            ),
        ],
      ),
    );
  }

  Widget _contents(
    List<WritingRecord> records,
    List<WritingPage> pages,
    Book? book,
    String summary,
  ) {
    final first = <String, ({WritingPage page, int number})>{};
    final firstWrittenLine = <String, String>{};
    for (final (i, page) in pages.indexed) {
      first.putIfAbsent(page.recordId, () => (page: page, number: i + 1));
      final text = page.text.trim();
      if (text.isNotEmpty) {
        firstWrittenLine.putIfAbsent(
          page.recordId,
          () => text.split('\n').first,
        );
      }
    }
    final resumePage = book == null ? null : c.resumePageForBook(book.id);
    final details = c.detailsFor(book);
    return ListView.builder(
      key: book == null
          ? const ValueKey('loose-pages-contents')
          : ValueKey('book-contents-${book.id}'),
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 24),
      itemCount: records.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!showSearch) _contentsHeader(book, summary, resumePage),
              const Divider(height: 1, color: line),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text('목차', style: TextStyle(fontSize: 19)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => widget.onNewSheet(book?.id),
                    icon: const Icon(CupertinoIcons.plus, size: 16),
                    label: const Text('새 종이'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  ),
                ],
              ),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Text('아직 필사 기록이 없어요.', style: TextStyle(color: muted)),
                ),
            ],
          );
        }
        final record = records[index - 1];
        final entry = first[record.id];
        final resumed = record.id == resumePage?.recordId;
        final excerpt = firstWrittenLine[record.id];
        final title =
            RegExp(r'^필사 [0-9]+$').hasMatch(record.title) && excerpt != null
            ? excerpt
            : record.title;
        return Column(
          children: [
            if (index > 1)
              if (details.recordDivider.enabled)
                RecordDivider(choice: details.recordDivider)
              else
                const Divider(height: 1, color: line),
            Semantics(
              selected: resumed,
              label: resumed ? '이어서 쓰는 기록' : null,
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  key: ValueKey('contents-record-${record.id}'),
                  borderRadius: BorderRadius.circular(4),
                  onTap: entry == null
                      ? null
                      : () {
                          final open = widget.onContentsPage;
                          if (open == null) {
                            widget.onRecord(record);
                          } else {
                            open(entry.page);
                          }
                        },
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          book != null && details.ribbon.enabled ? 26 : 4,
                          14,
                          4,
                          14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (_, box) => Row(
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: entry == null
                                          ? box.maxWidth
                                          : box.maxWidth * .72,
                                    ),
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        height: 1.55,
                                      ),
                                    ),
                                  ),
                                  if (entry != null) ...[
                                    const Expanded(child: _ContentsLeader()),
                                    Text(
                                      '${entry.number}',
                                      key: ValueKey(
                                        'contents-page-${record.id}',
                                      ),
                                      semanticsLabel: '${entry.number}쪽',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (excerpt != null && excerpt != title)
                              Text(
                                excerpt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  height: 1.55,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (resumed && details.ribbon.enabled)
                        PositionedDirectional(
                          top: 0,
                          start: 4,
                          child: RibbonBookmark(
                            choice: details.ribbon.copy(variant: 1),
                            width: 13,
                            height: 32,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _switchView() {
    setState(() {
      books = !books;
      _clearSearch();
    });
  }

  void _toggleSearch() {
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
      final topLevel = bookId == null && !showingLoosePages;
      final records =
          (topLevel ? c.library.records.reversed : c.library.records)
              .where((r) => topLevel || r.bookId == bookId)
              .toList();
      final passages = !books && !showingLoosePages && widget.onPassage != null
          ? LibraryPassages(c.library)
          : null;
      final shelf = books && topLevel;
      final searching = passages != null && query.trim().isNotEmpty;
      final canSearch = shelf || (records.isNotEmpty && passages != null);
      final searchLabel = shelf ? '노트 검색' : '내 글 검색';
      final volume = showingLoosePages
          ? _loosePages(records)
          : book == null
          ? const <WritingPage>[]
          : c.library.volumePages(bookId: book.id);
      final summary =
          '${records.length}편 · ${volume.length}쪽'
          '${book == null || book.author.isEmpty ? '' : ' · ${book.author}'}';
      final media = MediaQuery.of(context);
      final keyboard = media.viewInsets.bottom;
      final handleHeight = widget.showHandle ? kMinInteractiveDimension : 0.0;
      final restingHeight = math.min(
        media.size.height * .88 + handleHeight,
        media.size.height,
      );
      final sheet = SizedBox(
        height: math.max(
          0.0,
          showSearch
              ? restingHeight - keyboard
              : math.min(restingHeight, media.size.height - keyboard),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (widget.showHandle) const PaperSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
                child: Row(
                  children: [
                    if (!topLevel)
                      IconButton(
                        tooltip: '모든 책',
                        onPressed: () => setState(() {
                          bookId = null;
                          showingLoosePages = false;
                          books = true;
                          _clearSearch();
                        }),
                        icon: const Icon(CupertinoIcons.chevron_left, size: 18),
                      ),
                    if (topLevel)
                      Expanded(
                        child: Row(
                          children: [
                            if (topLevel) ...[
                              const InkMark(size: 20),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                shelf ? '책장' : '내 글',
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
                      )
                    else if (book != null) ...[
                      const Spacer(),
                      if (showSearch)
                        IconButton(
                          tooltip: '이 책에서 찾기 닫기',
                          onPressed: _toggleSearch,
                          icon: const Icon(
                            CupertinoIcons.xmark_circle,
                            size: 19,
                          ),
                        )
                      else ...[
                        if (widget.onBookOriginals != null)
                          TextButton.icon(
                            onPressed: () => widget.onBookOriginals!(book),
                            icon: const Icon(
                              CupertinoIcons.quote_bubble,
                              size: 16,
                            ),
                            label: const Text('원문'),
                          ),
                        _bookMenu(book, summary, canSearch),
                      ],
                    ],
                    if (showingLoosePages) const Spacer(),
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
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark, size: 18),
                    ),
                  ],
                ),
              ),
              if (topLevel && !showSearch)
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
                    focusNode: searchFocus,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '노트 제목 찾기',
                      prefixIcon: Icon(CupertinoIcons.search, size: 17),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
              if (!shelf && canSearch && showSearch)
                Padding(
                  key: const ValueKey('collection-search'),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: TextField(
                    controller: searchField,
                    focusNode: searchFocus,
                    autofocus: true,
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
                        onLoosePages: () => setState(() {
                          books = false;
                          showingLoosePages = true;
                          _clearSearch();
                        }),
                        onDetails: (book) => setState(() {
                          books = false;
                          bookId = book.id;
                          _clearSearch();
                        }),
                      )
                    : topLevel
                    ? _writingSheets(
                        records,
                        results: searching
                            ? passages.search(query).toList()
                            : null,
                      )
                    : searching
                    ? _results(passages.search(query, bookId: bookId).toList())
                    : book == null && !showingLoosePages
                    ? const SizedBox.shrink()
                    : _contents(records, volume, book, summary),
              ),
              if (c.saveError != null)
                TextButton(
                  onPressed: c.retrySave,
                  child: const Text(
                    '저장 실패 · 다시 시도',
                    style: TextStyle(color: burgundy),
                  ),
                ),
            ],
          ),
        ),
      );
      return PageStorage(
        bucket: scrollStorage,
        child: BlockSemantics(
          blocking: widget.showHandle,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: book == null && !showingLoosePages
                ? shelf
                      ? DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xffeee0cd), Color(0xffe2c9ac)],
                            ),
                          ),
                          child: sheet,
                        )
                      : ColoredBox(color: const Color(0xffe8dbca), child: sheet)
                : PaperBackdrop(
                    color: bookPaper,
                    grainOpacity: paperGrainOpacity[paperIndex],
                    binding: c.detailsFor(book).binding,
                    coverIndex: book == null ? null : c.coverIndexFor(book),
                    pagesAfter: volume.length,
                    outsideColor: bookPaper,
                    child: sheet,
                  ),
          ),
        ),
      );
    },
  );

  List<WritingPage> _loosePages(List<WritingRecord> records) {
    final pagesByRecord = {
      for (final record in records) record.id: <WritingPage>[],
    };
    for (final page in c.library.pages) {
      pagesByRecord[page.recordId]?.add(page);
    }
    return [
      for (final pages in pagesByRecord.values)
        ...(pages..sort((a, b) => a.number.compareTo(b.number))),
    ];
  }

  Widget _writingSheets(List<WritingRecord> records, {List<Passage>? results}) {
    final count = results?.length ?? records.length;
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

    Widget passageSheet(Passage passage) {
      final book = books[recordBooks[passage.page.recordId]];
      return WritingSheetPreview(
        excerpt: passage.excerpt,
        notebook: book?.title,
        date: passage.page.writtenOn,
        style: c.styleFor(book),
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
        final record = records[index];
        final book = books[record.bookId];
        final recordPages = pages[record.id] ?? const [];
        return WritingSheetPreview(
          key: ValueKey('writing-sheet-${record.id}'),
          excerpt: _firstWriting(recordPages),
          notebook: book?.title,
          date: recordPages.firstOrNull?.writtenOn,
          style: c.styleFor(book),
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

  Widget _passageTile(Passage passage) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    title: Text(passage.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      [
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

class _ContentsLeader extends StatelessWidget {
  const _ContentsLeader();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 6),
    child: ExcludeSemantics(
      child: SizedBox(height: 6, child: CustomPaint(painter: _LeaderDots())),
    ),
  );
}

class _LeaderDots extends CustomPainter {
  const _LeaderDots();

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = muted.withValues(alpha: .64);
    for (var x = 3.0; x < size.width - 2; x += 5) {
      canvas.drawCircle(Offset(x, size.height / 2), .75, dot);
    }
  }

  @override
  bool shouldRepaint(_LeaderDots oldDelegate) => false;
}
