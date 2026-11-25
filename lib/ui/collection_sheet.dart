import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/library_search.dart';
import '../data/model.dart';
import '../data/writing_title.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'paper_search_field.dart';
import 'search_completions.dart';
import 'book_details.dart';
import 'book_appearance.dart';
import 'bookshelf.dart';
import 'reading_details.dart';
import 'read_aloud_screen.dart';
import 'new_book_dialog.dart';
import 'writing_sheet_preview.dart';

class CollectionSheet extends StatefulWidget {
  const CollectionSheet({
    super.key,
    required this.controller,
    required this.onRecord,
    required this.onResumeBook,
    this.initialBookId,
    required this.onNewWriting,
    required this.onNewBook,
    this.onPassage,
    this.onContentsPage,
    this.onArchiveBook,
    this.onBookOriginals,
    this.onSettings,
    this.onCafe,
  });
  final LibraryController controller;
  final String? initialBookId;
  final ValueChanged<WritingRecord> onRecord;
  final ValueChanged<Book> onResumeBook;
  final ValueChanged<String?> onNewWriting;
  final VoidCallback onNewBook;
  final VoidCallback? onSettings;
  final VoidCallback? onCafe;
  final ValueChanged<Passage>? onPassage;
  final ValueChanged<WritingPage>? onContentsPage;
  final ValueChanged<Book>? onArchiveBook, onBookOriginals;
  @override
  State<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends State<CollectionSheet> {
  late bool books = widget.initialBookId == null;
  bool showSearch = false;
  bool returnToShelfOnBack = false;
  ({bool books, bool search, String query})? _shelfState;
  late String? bookId = widget.initialBookId;
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

  Future<void> _renameWriting(WritingRecord record, String title) async {
    final owner = c;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => BookTitleDialog(title: title, isWriting: true),
    );
    if (name != null && mounted && c == owner) {
      owner.setRecordTitle(record.id, name);
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

  Future<void> _showBookplate(Book book, String summary) =>
      Navigator.of(context).push<void>(
        paperPanelRoute(
          (_) => AnimatedBuilder(
            animation: c,
            builder: (_, _) {
              final current =
                  c.library.books
                      .where((item) => item.id == book.id)
                      .firstOrNull ??
                  book;
              final details = c.detailsFor(current);
              final stockColor =
                  paperColors[current.paperIndex ?? c.library.style.paperIndex];
              return PaperPanel(
                color: stockColor,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 12, 0),
                      child: PaperPanelHeader('장서표'),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Bookplate(
                          choice: details.bookplate,
                          stockColor: stockColor,
                          flower: details.pressedFlower,
                          title: current.title,
                          owner: current.owner,
                          summary: summary,
                          onOwner: () => _owner(current),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

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
          value: () => c.toggleFavorite(book.id),
          child: Text(favorite ? '즐겨찾기 해제' : '즐겨찾기'),
        ),
        if (widget.onArchiveBook != null)
          PopupMenuItem(
            value: () => widget.onArchiveBook!(book),
            child: const Text('책 PDF 내보내기'),
          ),
      ],
    );
  }

  Widget _bookActions(Book book) => Wrap(
    alignment: WrapAlignment.start,
    spacing: 8,
    children: [
      TextButton.icon(
        onPressed: () => showReadAloud(
          context,
          library: c.library,
          book: book,
          color: panelPaperColor(paperColors[c.styleFor(book).paperIndex]),
        ),
        icon: const Icon(CupertinoIcons.speaker_2, size: 17),
        label: const Text('책 낭독'),
      ),
      TextButton.icon(
        onPressed: () => showBookAppearance(context, c, book.id),
        icon: const Icon(CupertinoIcons.paintbrush, size: 17),
        label: const Text('책 꾸미기'),
      ),
    ],
  );

  Widget _contentsHeader(Book book, String summary, int pageCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InkMark(size: 10),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.4,
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: muted,
                      ),
                    ),
                    if (book.author.isNotEmpty)
                      Text(
                        '지은이 ${book.author}',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (MediaQuery.textScalerOf(context).scale(20) < 32) ...[
                const SizedBox(width: 18),
                ExcludeSemantics(
                  child: BookCover(
                    key: const ValueKey('contents-cover-preview'),
                    title: '',
                    width: 84,
                    variant: c.coverIndexFor(book),
                    details: c.detailsFor(book),
                    pageCount: pageCount,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _bookActions(book),
        ],
      ),
    );
  }

  Widget _resumeWriting(Book book, int number) => Padding(
    key: const ValueKey('contents-resume-footer'),
    padding: const EdgeInsets.fromLTRB(26, 8, 26, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 20),
        FilledButton.icon(
          key: const ValueKey('contents-resume-writing'),
          onPressed: () => widget.onResumeBook(book),
          icon: const Icon(CupertinoIcons.book, size: 19),
          label: Text('이어서 쓰기 · $number쪽', textAlign: TextAlign.center),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
        ),
      ],
    ),
  );

  Widget _contents(
    List<WritingRecord> records,
    List<WritingPage> pages,
    Book book,
    String summary,
  ) {
    final first = <String, ({WritingPage page, int number})>{};
    final byRecord = <String, List<WritingPage>>{};
    for (final (i, page) in pages.indexed) {
      first.putIfAbsent(page.recordId, () => (page: page, number: i + 1));
      (byRecord[page.recordId] ??= []).add(page);
    }
    final resumePage = c.resumePageForBook(book.id);
    final resumeIndex = pages.indexWhere((page) => page.id == resumePage?.id);
    final details = c.detailsFor(book);
    return LayoutBuilder(
      builder: (context, box) {
        final pinResume =
            box.maxHeight >= 360 &&
            !(MediaQuery.textScalerOf(context).scale(20) >= 40 &&
                box.maxHeight < 700);
        final hasResume = resumeIndex >= 0;
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                key: ValueKey('book-contents-${book.id}'),
                padding: const EdgeInsets.fromLTRB(26, 4, 26, 24),
                itemCount:
                    records.length + 1 + (!pinResume && hasResume ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!showSearch)
                          _contentsHeader(book, summary, pages.length),
                        const Divider(height: 1, color: line),
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: const Text(
                                  '목차',
                                  style: TextStyle(fontSize: 19),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => widget.onNewWriting(book.id),
                              icon: const Icon(CupertinoIcons.plus, size: 16),
                              label: const Text('새 글'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                            ),
                          ],
                        ),
                        if (records.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 22),
                            child: Text(
                              '아직 쓴 글이 없어요.',
                              style: TextStyle(color: muted),
                            ),
                          ),
                      ],
                    );
                  }
                  if (index > records.length) {
                    return _resumeWriting(book, resumeIndex + 1);
                  }
                  final record = records[index - 1];
                  final entry = first[record.id];
                  final resumed = record.id == resumePage?.recordId;
                  final title = writingTitle(
                    record,
                    byRecord[record.id] ?? const [],
                  );
                  return Column(
                    children: [
                      if (index > 1)
                        if (details.recordDivider.enabled)
                          RecordDivider(choice: details.recordDivider)
                        else
                          const Divider(height: 1, color: line),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Semantics(
                              selected: resumed,
                              label: resumed ? '이어서 쓰는 글' : null,
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
                                          details.ribbon.enabled ? 26 : 4,
                                          14,
                                          4,
                                          14,
                                        ),
                                        child: LayoutBuilder(
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    height: 1.55,
                                                  ),
                                                ),
                                              ),
                                              if (entry != null) ...[
                                                const Expanded(
                                                  child: _ContentsLeader(),
                                                ),
                                                Text(
                                                  '${entry.number}',
                                                  key: ValueKey(
                                                    'contents-page-${record.id}',
                                                  ),
                                                  semanticsLabel:
                                                      '${entry.number}쪽',
                                                  style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (resumed && details.ribbon.enabled)
                                        Positioned(
                                          left: 0,
                                          top: 8,
                                          child: RibbonBookmark(
                                            width: 13,
                                            height: 32,
                                            choice: details.ribbon.copy(
                                              variant: 1,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          PopupMenuButton<VoidCallback>(
                            key: ValueKey('contents-writing-menu-${record.id}'),
                            enabled: c.saveError == null,
                            tooltip: '글 더 보기',
                            icon: const Icon(CupertinoIcons.ellipsis, size: 18),
                            onSelected: (action) => action(),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: () => _renameWriting(record, title),
                                child: const Text('글 이름 변경'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            if (pinResume && hasResume) _resumeWriting(book, resumeIndex + 1),
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

  Future<void> _openPractice() async {
    final controller = c;
    if (!await controller.openPracticeBook() || !mounted || controller != c) {
      return;
    }
    _openBook(controller.practiceBook);
  }

  void _showShelf() {
    setState(() {
      bookId = null;
      books = _shelfState?.books ?? true;
      returnToShelfOnBack = false;
      searchFocus.unfocus();
      showSearch = _shelfState?.search ?? false;
      query = _shelfState?.query ?? '';
      searchField.text = query;
    });
  }

  void _openBook(Book book) {
    if (bookId == null) {
      _shelfState = (books: books, search: showSearch, query: query);
    }
    setState(() {
      books = false;
      bookId = book.id;
      returnToShelfOnBack = true;
      _clearSearch();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final book = c.library.books.where((b) => b.id == bookId).firstOrNull;
      final paperIndex = book?.paperIndex ?? c.library.style.paperIndex;
      final bookPaper = paperColors[paperIndex];
      final topLevel = bookId == null;
      PaperNavigationScope.maybeOf(
        context,
      )?.name(context, topLevel ? (books ? '책장' : '내 글') : '목차');
      final showingPractice =
          book?.id == LibraryController.defaultPracticeBook.id;
      final records =
          (topLevel || showingPractice
                  ? c.library.records.reversed
                  : c.library.records)
              .where((r) => topLevel || r.bookId == bookId)
              .toList();
      final passages = !books && widget.onPassage != null
          ? LibraryPassages(c.library)
          : null;
      final shelf = books && topLevel;
      final searching = passages != null && query.trim().isNotEmpty;
      final canSearch = shelf || (records.isNotEmpty && passages != null);
      final searchLabel = shelf ? '책 검색' : '내 글 검색';
      final volume = book == null
          ? const <WritingPage>[]
          : c.library.volumePages(bookId: book.id);
      final summary = '${records.length}편 · ${volume.length}쪽';
      final sheet = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
            child: PaperHeaderRow(
              children: [
                PaperBackButton(
                  label: returnToShelfOnBack
                      ? (_shelfState?.books == false ? '내 글' : '책장')
                      : null,
                  onPressed: returnToShelfOnBack ? _showShelf : null,
                ),
                if (topLevel) ...[
                  Expanded(child: PaperPanelTitle(shelf ? '책장' : '내 글')),
                  if (shelf && !showSearch && widget.onSettings != null)
                    TextButton.icon(
                      onPressed: widget.onSettings,
                      icon: const Icon(CupertinoIcons.gear, size: 17),
                      label: const Text('설정'),
                    ),
                ] else if (book != null) ...[
                  if (showingPractice)
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (showSearch)
                    IconButton(
                      tooltip: '이 책에서 찾기 닫기',
                      onPressed: _toggleSearch,
                      icon: const Icon(CupertinoIcons.xmark_circle, size: 19),
                    )
                  else ...[
                    if (widget.onBookOriginals != null)
                      TextButton.icon(
                        onPressed: () => widget.onBookOriginals!(book),
                        icon: const Icon(CupertinoIcons.quote_bubble, size: 16),
                        label: const Text('원문'),
                      ),
                    _bookMenu(book, summary, canSearch),
                  ],
                ],
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
                if (!volume.any((p) => p.id == c.library.activePageId))
                  PaperWritingReturn(force: returnToShelfOnBack),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(height: 1),
          ),
          if (topLevel && !showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: _switchView,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          shelf ? CupertinoIcons.doc_text : CupertinoIcons.book,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(shelf ? '내 글' : '책장'),
                      ],
                    ),
                  ),
                  if (widget.onCafe != null)
                    TextButton.icon(
                      key: const ValueKey('open-cafe'),
                      onPressed: widget.onCafe,
                      icon: const Icon(Icons.local_cafe_outlined, size: 17),
                      label: const Text('필사 카페'),
                    ),
                  TextButton.icon(
                    onPressed: shelf
                        ? widget.onNewBook
                        : () => widget.onNewWriting(null),
                    icon: const Icon(CupertinoIcons.plus, size: 15),
                    label: Text(shelf ? '새 책' : '새 글'),
                  ),
                ],
              ),
            ),
          if (showingPractice && !showSearch) ...[
            _bookActions(book!),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => widget.onNewWriting(book.id),
                  icon: const Icon(CupertinoIcons.plus, size: 15),
                  label: const Text('새 글'),
                ),
              ),
            ),
          ],
          if (canSearch && showSearch)
            Padding(
              key: shelf ? null : const ValueKey('collection-search'),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: PaperSearchField(
                fieldKey: shelf ? const ValueKey('shelf-title-search') : null,
                controller: searchField,
                focusNode: searchFocus,
                autofocus: true,
                hint: shelf ? '책 이름 찾기' : '문장, 책, 날짜 찾기',
                onSubmitted: (_) => searchFocus.unfocus(),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
          if (canSearch && showSearch)
            Flexible(
              child: SearchCompletions(
                controller: searchField,
                focusNode: searchFocus,
                options: (query) => shelf
                    ? searchCompletions(query, [
                        for (final book in c.library.books) book.title,
                        LibraryController.defaultPracticeBook.title,
                      ])
                    : passages!.completions(query, bookId: bookId),
                onSelected: (value) => setState(() => query = value),
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
                    scrollController: query.trim().isEmpty ? shelfScroll : null,
                    query: query,
                    onOpen: _openBook,
                    onWrite: () => widget.onNewWriting(null),
                    onPractice: _openPractice,
                  )
                : topLevel || showingPractice
                ? _writingSheets(
                    records,
                    results: searching
                        ? passages.search(query, bookId: bookId).toList()
                        : null,
                  )
                : searching
                ? _results(passages.search(query, bookId: bookId).toList())
                : book == null
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
      );
      return PopScope<void>(
        canPop: !returnToShelfOnBack,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && returnToShelfOnBack) _showShelf();
        },
        child: PaperInternalBack(
          enabled: returnToShelfOnBack,
          onBack: _showShelf,
          child: PageStorage(
            bucket: scrollStorage,
            child: PaperPanel(
              color: book == null
                  ? shelf
                        ? const Color(0xffeee0cd)
                        : const Color(0xffe8dbca)
                  : bookPaper,
              grainOpacity: book == null
                  ? panelGrainOpacity
                  : paperGrainOpacity[paperIndex],
              child: book == null
                  ? sheet
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        BookBinding(choice: c.detailsFor(book).binding),
                        sheet,
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );

  Widget _writingSheets(List<WritingRecord> records, {List<Passage>? results}) {
    final count = results?.length ?? records.length;
    if (count == 0) {
      return Center(
        child: Text(
          results == null ? '아직 쓴 글이 없어요.' : '일치하는 글이 없어요.',
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
        bookTitle: bookId == null ? book?.title : null,
        date: passage.page.writtenOn,
        style: c.styleFor(book),
        onOpen: () => widget.onPassage!(passage),
      );
    }

    return ListView.separated(
      key: results == null
          ? PageStorageKey(bookId == null ? 'writing' : 'practice-writing')
          : ValueKey(query.trim()),
      controller: results == null && bookId == null ? writingScroll : null,
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
          bookTitle: bookId == null ? book?.title : null,
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
      ? const Center(child: Text('일치하는 글이 없어요.'))
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
