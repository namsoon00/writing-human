import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/library_controller.dart';
import '../data/writing_title.dart';
import '../data/library_search.dart';
import '../data/model.dart';
import '../data/original_photo_store.dart';
import '../sync/coordinator.dart';
import '../source/source_intake.dart';
import '../source/originals.dart';
import '../source/source_platform.dart';
import 'source_import_sheet.dart';
import 'source_reading.dart';
import '../source/page_originals.dart';
import 'collection_sheet.dart';
import 'editor.dart';
import 'writing_sound.dart';
import 'new_book_dialog.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'paper_tool.dart';
import 'read_aloud_screen.dart';
import 'tools_screen.dart';
import 'writing_chrome.dart';
import 'page_turn.dart';
import 'paper_swipe.dart';
import 'pages_sheet.dart';
import 'book_front_cover.dart';
import 'book_details.dart';
import 'page_read_preview.dart';
import 'archive_sheet.dart';
import '../cafe/cafe_visit.dart';
import '../cafe/cafe_space.dart';
import 'cafe_screen.dart';
import 'cafe_ritual.dart';

const _firstWritingExampleLine = '창가에 앉아 저녁빛을 바라보았다.';
const _firstWritingExampleSource = '마지막 빛이 종이 위에 천천히 내려앉았다.';

typedef _SavedOriginal = ({
  String? bookId,
  RegisteredOriginal original,
  bool startWriting,
  String? transcriptionPageId,
});

enum _BookLeaf { frontCover, bookplate, backCover }

class Workspace extends StatefulWidget {
  const Workspace({
    super.key,
    required this.controller,
    this.sync,
    this.sourceIntake,
  });
  final LibraryController controller;
  final SyncCoordinator? sync;
  final SourceIntake? sourceIntake;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with WidgetsBindingObserver {
  LibraryController get c => widget.controller;
  final editorFocus = FocusNode();
  final _pageTurn = PageTurnController();
  PaperSound? _pageAudio;
  ({String bookId, String anchor, _BookLeaf leaf})? _bookLeaf;
  Book? get _leafBook {
    final target = _bookLeaf;
    if (target == null || target.anchor != page.id) return null;
    return c.library.books
        .where((book) => book.id == target.bookId)
        .firstOrNull;
  }

  _BookLeaf? get _visibleLeaf => _leafBook == null ? null : _bookLeaf?.leaf;
  late WritingPage draft = _blank();
  late bool fresh = c.library.pages.isEmpty;
  bool userFresh = false;
  ({WritingPage page, RegisteredOriginal original})? _firstWritingExample;
  String? _dismissedExamplePage;

  String? draftBookId;
  bool _pageNavigationBusy = false;
  int _directPageChange = 0;
  bool _openingFromPanel = false;
  bool _editorComposing = false;
  CafeSeat? _cafeSeat;
  bool _openingCafe = false;
  PaperTool _paperTool = PaperTool.writing;
  ({String pageId, int offset, int request})? _reveal;
  int _revealRequest = 0;
  ({String pageId, int request})? _firstPageView;
  int _firstPageRequest = 0;
  final _originalByPage = <String, String>{};
  final _originalByVolume = <({String? bookId, String? recordId}), String>{};

  late final SourceIntake _intake = widget.sourceIntake ?? createSourceIntake();
  StreamSubscription<void>? _incomingEvents;
  IncomingSource? _incoming;
  SourcePhoto? _recoveredPhoto;
  final _shownShares = <String>{};
  bool _readingSource = false;
  bool _sourceBusy = false, _pollingSources = false, _pollAgain = false;
  bool _checkedPhotoRecovery = false;
  PageRoute<void>? _activePanel;
  Route<dynamic>? _sourceRoute;
  Future<void>? _sheetClosed;
  LibraryController? _sheetOwner;
  PaperNavigation? _navigation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PaperNavigationScope.maybeOf(context);
    if (_navigation != next) {
      _navigation?.canReturnToWriting = null;
      _navigation = next;
      next?.canReturnToWriting = _canReturnToWriting;
      next?.currentWritingPageId = () => page.id;
    }
  }

  Future<bool> _canReturnToWriting() async {
    final owner = c;
    if (_accountLocked || !_canLeaveInput()) return false;
    await owner.settled;
    return mounted &&
        c == owner &&
        !_accountLocked &&
        !_editorComposing &&
        !c.composing &&
        owner.saveError == null;
  }

  Future<void> _finishWritingNavigation() async {
    final navigation = _navigation;
    if (navigation != null) {
      await navigation.returnToWriting();
      return;
    }
    // Embedded Workspace tests/hosts may not install the app-wide observer.
    // Only dismiss this owner's known exploration route, respecting its guard.
    final panel = _activePanel;
    if (await _canReturnToWriting() &&
        panel?.isCurrent == true &&
        _sheetOwner == c) {
      await panel!.navigator?.maybePop();
    }
  }

  bool get _accountLocked =>
      (widget.sync?.accountMismatch ?? false) ||
      (widget.sync?.signInRequired == true && c.library.sync.accountId != null);

  List<WritingPage> get _volumePages {
    final current = page;
    if (fresh) return [current];
    final pages = c.library.volumePages(
      bookId: book?.id,
      recordId: current.recordId,
    );
    return pages.any((p) => p.id == current.id) ? pages : [current];
  }

  bool _canLeaveInput() {
    if (!_editorComposing && !c.composing) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('입력을 마친 뒤 쪽을 넘겨 주세요.')));
    return false;
  }

  Future<void> _navigatePage(
    Future<void> Function() action, {
    bool paperTurn = true,
  }) async {
    if (_pageNavigationBusy || _accountLocked || !_canLeaveInput()) return;
    final owner = c, origin = page.id;
    final previousLeaf = _visibleLeaf;
    _blur();
    setState(() => _pageNavigationBusy = true);
    try {
      await owner.settled;
      if (!mounted ||
          c != owner ||
          page.id != origin ||
          _accountLocked ||
          editorFocus.hasFocus ||
          c.composing) {
        return;
      }
      if (c.saveError != null) return;
      await action();
      if (!paperTurn &&
          mounted &&
          c == owner &&
          (page.id != origin || previousLeaf != _visibleLeaf)) {
        setState(() => _directPageChange++);
      }
      await owner.settled;
      if (paperTurn &&
          mounted &&
          c == owner &&
          !_accountLocked &&
          owner.saveError == null &&
          c.library.style.pageSound &&
          (page.id != origin || previousLeaf != _visibleLeaf)) {
        _pageAudio?.play(
          () =>
              mounted &&
              c == owner &&
              !_accountLocked &&
              c.library.style.pageSound,
        );
      }
    } finally {
      if (mounted) setState(() => _pageNavigationBusy = false);
    }
  }

  void _updatePageSound() {
    if (c.library.style.pageSound && !_accountLocked) {
      _pageAudio ??= PaperSound.pageTurn();
    } else {
      _closePageSound();
    }
  }

  void _closePageSound() {
    final audio = _pageAudio;
    _pageAudio = null;
    if (audio != null) unawaited(audio.dispose());
  }

  Future<void> _openPage(
    String id, {
    bool paperTurn = true,
    bool startAtTop = false,
  }) => _navigatePage(() async {
    if (!c.library.pages.any((p) => p.id == id)) return;
    final samePage = page.id == id;
    if (samePage &&
        _visibleLeaf == null &&
        _firstPageView == null &&
        !startAtTop) {
      return;
    }
    setState(() {
      _bookLeaf = null;
      fresh = false;
      userFresh = false;
      _firstPageView = startAtTop
          ? (pageId: id, request: ++_firstPageRequest)
          : null;
      if (startAtTop) _reveal = null;
    });
    if (!samePage) c.openPage(id);
  }, paperTurn: paperTurn);

  Future<void> _openPassage(Passage passage, {bool paperTurn = true}) =>
      _navigatePage(() async {
        final id = passage.page.id;
        final target = c.library.pages.where((p) => p.id == id).firstOrNull;
        if (target == null) return;
        final offset = passage.offset;
        setState(() {
          _bookLeaf = null;
          fresh = false;
          userFresh = false;
          _firstPageView = null;
          _reveal = offset != null && target.text == passage.page.text
              ? (pageId: id, offset: offset, request: ++_revealRequest)
              : null;
        });
        if (c.library.activePageId != id) c.openPage(id);
      }, paperTurn: paperTurn);

  Future<void> _openCover({bool back = false, bool paperTurn = true}) =>
      _navigatePage(() async {
        final currentBook = book;
        if (currentBook == null) return;
        if (back && _volumePages.last.id != page.id) {
          c.openPage(_volumePages.last.id);
        }
        _showBookLeaf(
          currentBook,
          back ? _BookLeaf.backCover : _BookLeaf.frontCover,
        );
      }, paperTurn: paperTurn);

  void _showBookLeaf(Book book, _BookLeaf leaf) {
    setState(() => _bookLeaf = (bookId: book.id, anchor: page.id, leaf: leaf));
  }

  Future<void> _openBookFromStart(Book book) async {
    final first = c.library.volumePages(bookId: book.id).firstOrNull;
    if (first == null) {
      await _newWriting(book.id);
    } else {
      await _openPage(first.id, startAtTop: true);
    }
  }

  Future<void> _resumeBook(Book book, {bool paperTurn = true}) async {
    if (!c.library.books.any((entry) => entry.id == book.id)) return;
    final target = c.resumePageForBook(book.id);
    if (target == null) {
      await _newWriting(book.id);
    } else {
      await _openPage(target.id, paperTurn: paperTurn);
    }
  }

  Future<void> _stepPage(int step) async {
    final leafBook = _leafBook;
    if (leafBook != null) {
      switch (_visibleLeaf) {
        case _BookLeaf.frontCover:
          if (step < 0) return;
          if (c.detailsFor(leafBook).bookplate.enabled) {
            await _navigatePage(() async {
              _showBookLeaf(leafBook, _BookLeaf.bookplate);
            });
          } else {
            await _openBookFromStart(leafBook);
          }
        case _BookLeaf.bookplate:
          if (step < 0) {
            await _navigatePage(() async {
              _showBookLeaf(leafBook, _BookLeaf.frontCover);
            });
          } else {
            await _openBookFromStart(leafBook);
          }
        case _BookLeaf.backCover:
          if (step < 0) await _openPage(page.id);
        case null:
          break;
      }
      return;
    }
    final pages = _volumePages;
    final index = pages.indexWhere((p) => p.id == page.id);
    if (index < 0) return;
    final target = index + step;
    if (target < 0) {
      final currentBook = book;
      if (currentBook != null) {
        if (c.detailsFor(currentBook).bookplate.enabled) {
          await _navigatePage(() async {
            _showBookLeaf(currentBook, _BookLeaf.bookplate);
          });
        } else {
          await _openCover();
        }
      }
    } else if (target >= pages.length) {
      if (fresh || book == null) {
        await _appendPage();
      } else {
        await _openCover(back: true);
      }
    } else {
      await _openPage(pages[target].id);
    }
  }

  Future<bool> _commitTurn(bool forward) async {
    final owner = c, id = page.id, previousLeaf = _visibleLeaf;
    await _stepPage(forward ? 1 : -1);
    return mounted &&
        c == owner &&
        (page.id != id || previousLeaf != _visibleLeaf);
  }

  Future<void> _appendPage({
    bool addAfterDraft = true,
    bool paperTurn = true,
  }) => _navigatePage(() async {
    if (fresh) {
      // Explicitly adding a page is intent to keep blank pages as well.
      fresh = false;
      userFresh = false;
      _bookLeaf = null;
      c.saveDraft(draft, bookId: draftBookId, keepBlank: true);
      if (!addAfterDraft) return;
      await c.settled;
      if (!mounted || c.saveError != null) return;
    }
    _bookLeaf = null;
    c.addPage();
  }, paperTurn: paperTurn);
  WritingPage _blank() => WritingPage(
    id: const Uuid().v4(),
    recordId: const Uuid().v4(),
    number: 1,
  );
  WritingPage get page => fresh
      ? draft
      : c.library.activePage ?? c.library.pages.lastOrNull ?? draft;
  WritingRecord? get record =>
      c.library.records.where((r) => r.id == page.recordId).firstOrNull;
  Book? get book => c.library.books
      .where((b) => b.id == (record?.bookId ?? (fresh ? draftBookId : null)))
      .firstOrNull;

  int get _coverVariant => c.coverIndexFor(book);

  WritingStyle _paperStyle(Book? book) => c.styleFor(book);

  PaperTool _toolFor(WritingStyle style) =>
      style.bookDetails.pencil.enabled ? _paperTool : PaperTool.writing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _incomingEvents = _intake.incomingChanges.listen((_) => _pollSources());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pollSources();
    });
    c.addListener(_changed);
    widget.sync?.addListener(_changed);
    _updatePageSound();
  }

  @override
  void didUpdateWidget(Workspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      oldWidget.sync?.removeListener(_changed);
      c.addListener(_changed);
      widget.sync?.addListener(_changed);
      editorFocus.unfocus();
      _paperTool = PaperTool.writing;
      _cafeSeat = null;
      _originalByPage.clear();
      _originalByVolume.clear();
      _bookLeaf = null;
      _reveal = null;
      _firstPageView = null;
      fresh = c.library.pages.isEmpty;
      userFresh = false;
      draft = _blank();
      _firstWritingExample = null;
      _dismissedExamplePage = null;
      draftBookId = null;
      _closePageSound();
      _updatePageSound();
    }
  }

  void _changed() {
    if (!mounted) return;
    _updatePageSound();
    setState(() {
      if (fresh && !userFresh && c.library.activePage != null) fresh = false;
      if (_accountLocked) {
        _cafeSeat = null;
        _originalByPage.clear();
        _originalByVolume.clear();
      }
      if (_accountLocked || _leafBook == null) _bookLeaf = null;
      if (_accountLocked || _reveal?.pageId != page.id) _reveal = null;
      if (_accountLocked || _firstPageView?.pageId != page.id) {
        _firstPageView = null;
      }
    });
    if ((widget.sync?.accountMismatch ?? false) ||
        (widget.sync?.signInRequired ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void dispose() {
    if (_navigation?.canReturnToWriting == _canReturnToWriting) {
      _navigation?.canReturnToWriting = null;
      _navigation?.currentWritingPageId = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _incomingEvents?.cancel();
    if (widget.sourceIntake == null) _intake.dispose();
    c.removeListener(_changed);
    widget.sync?.removeListener(_changed);
    editorFocus.dispose();
    _closePageSound();
    super.dispose();
  }

  void _dismissWritingKeyboard() {
    if (!_editorComposing && !c.composing) _blur();
  }

  void _blur() {
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: _editorComposing);
  }

  bool get _canShowFirstWritingExample =>
      fresh &&
      !userFresh &&
      c.library.pages.isEmpty &&
      c.library.trashedPages.isEmpty &&
      c.library.records.isEmpty &&
      c.library.books.isEmpty;

  void _startFirstWritingExample() {
    if (!_canShowFirstWritingExample ||
        !_canLeaveInput() ||
        c.saveError != null) {
      return;
    }
    final original = RegisteredOriginal(
      const Uuid().v4(),
      _firstWritingExampleSource,
      citation: '쓰는 인간 · 필사 예시',
    );
    setState(() {
      _firstWritingExample = (
        page: c.attachedPage(draft, original),
        original: original,
      );
    });
    editorFocus.requestFocus();
  }

  bool _leaveFirstWritingExample(String pageId) {
    if (_firstWritingExample?.page.id != pageId) return false;
    setState(() {
      _firstWritingExample = null;
      _dismissedExamplePage = pageId;
    });
    return true;
  }

  Widget _firstWritingExamplePreview(WritingStyle style) {
    final handwriting = writingTextStyle(
      style.fontIndex,
      size: 18,
      useDevelopmentTypeface: style.useDevelopmentTypeface,
      color: penColors[style.penIndex],
    ).copyWith(height: 1.65);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .38,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
        child: Column(
          key: const ValueKey('first-writing-example'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('필사 예시', style: TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: 8),
            Text(_firstWritingExampleLine, style: handwriting),
            Text(
              _firstWritingExampleSource,
              style: handwriting.copyWith(color: muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  key: const ValueKey('try-first-transcription'),
                  onPressed: _startFirstWritingExample,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('이어서 필사하기'),
                ),
                TextButton(
                  key: const ValueKey('skip-first-transcription'),
                  onPressed: () {
                    setState(() => _dismissedExamplePage = page.id);
                    editorFocus.requestFocus();
                  },
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('빈 종이 쓰기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _edit(String id, String text, int base, int extent, double scroll) {
    if (!c.library.pages.any((p) => p.id == id)) {
      if (text.isEmpty) return;
      final example = _firstWritingExample?.page.id == id
          ? _firstWritingExample
          : null;
      final next = (example?.page ?? draft).edited(
        text: text,
        base: base,
        extent: extent,
        scroll: scroll,
      );
      // Same page ID/key on both sides of this first save: keep the live IME.
      fresh = false;
      _firstWritingExample = null;
      c.saveDraft(
        next,
        bookId: draftBookId,
        originals: example == null ? const [] : [example.original],
      );
    } else {
      if (c.library.activePageId != id || !c.library.writing) c.openPage(id);
      c.editPage(id, text, base, extent, scroll);
    }
  }

  Future<void> _newWriting([String? bookId]) => _navigatePage(() async {
    setState(() {
      _bookLeaf = null;
      draft = _blank();
      _firstWritingExample = null;
      _dismissedExamplePage = null;
      draftBookId = bookId;
      fresh = true;
      userFresh = true;
    });
  }, paperTurn: false);

  Future<void> _openPanel(
    Widget child, {
    Color color = paper,
    bool sheet = false,
  }) {
    final route = sheet
        ? paperSheetRoute<void>((_) => child)
        : paperPanelRoute<void>((_) => child, color: color);
    _activePanel = route;
    _sheetClosed = route.completed.then((_) {});
    _sheetOwner = c;
    return Navigator.of(context).push<void>(route);
  }

  Future<void> _afterSheet(Future<void> Function() action) async {
    final closed = _sheetClosed;
    final owner = _sheetOwner;
    final panel = _activePanel;
    if (owner != c || panel?.isCurrent != true || _accountLocked) return;
    panel!.navigator!.pop();
    await closed;
    if (mounted && c == owner && !_accountLocked) await action();
  }

  Future<void> _openPageFromPanel(
    ModalRoute<dynamic>? route,
    LibraryController? owner,
    Future<void> Function() open,
  ) async {
    if (_openingFromPanel ||
        _pageNavigationBusy ||
        owner != c ||
        _accountLocked ||
        route?.isCurrent != true) {
      return;
    }
    _openingFromPanel = true;
    try {
      // Update the hidden editor before the outgoing panel reveals it.
      await open();
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && c == owner && !_accountLocked && route!.isCurrent) {
        route.navigator!.pop();
        if (route != _sourceRoute) await _finishWritingNavigation();
      }
    } finally {
      _openingFromPanel = false;
    }
  }

  Future<void> _openFromCollection(Future<void> Function() open) =>
      _openPageFromPanel(_activePanel, _sheetOwner, open);

  void _collection({String? initialBookId}) {
    if (!_canLeaveInput()) return;
    _blur();
    _openPanel(
      CollectionSheet(
        initialBookId: initialBookId,
        controller: c,
        onResumeBook: (book) =>
            _openFromCollection(() => _resumeBook(book, paperTurn: false)),
        onRecord: (r) {
          final pages = c.library.pages.where((p) => p.recordId == r.id);
          if (pages.isEmpty) return;
          final id =
              pages
                  .where((p) => p.id == c.library.activePageId)
                  .firstOrNull
                  ?.id ??
              pages.last.id;
          _openFromCollection(() => _openPage(id, paperTurn: false));
        },
        onNewWriting: (bookId) {
          _openFromCollection(() => _newWriting(bookId));
        },
        onNewBook: _createBook,
        onContentsPage: (page) =>
            _openFromCollection(() => _openPage(page.id, paperTurn: false)),
        onBookOriginals: (book) => _showOriginals(bookDetails: book),
        onPassage: (passage) =>
            _openFromCollection(() => _openPassage(passage, paperTurn: false)),
        onArchiveBook: (book) =>
            _afterSheet(() => _archive(selectedBook: book)),
        onSettings: _settings,
        onCafe: _cafe,
      ),
    );
  }

  CafePastWriting? _pastCafeWriting(Library library) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    WritingPage? past;
    WritingPage? earlierToday;
    for (final page in library.pages.reversed) {
      if (page.text.trim().isEmpty ||
          (page.guidedOriginalId == null &&
              !page.passages.any(
                (link) => link.attached && !link.referenceOnly,
              ))) {
        continue;
      }
      final date = page.writtenOn ?? '';
      if (date == today && page.id != library.activePageId) {
        earlierToday ??= page;
      } else if (date.compareTo(today) < 0 &&
          (past == null || date.compareTo(past.writtenOn ?? '') > 0)) {
        past = page;
      }
    }
    final chosen = past ?? earlierToday;
    if (chosen == null) return null;
    final record = library.records
        .where((record) => record.id == chosen.recordId)
        .firstOrNull;
    if (record == null) return null;
    final originals = originalsFor(
      library,
      bookId: record.bookId,
      recordId: record.id,
    );
    final links = pageOriginals(
      chosen,
      originals,
    ).where((link) => link.attached && !link.referenceOnly);
    final source = links.map(passageOriginal).nonNulls.firstOrNull;
    if (source?.canTranscribe != true) return null;
    final line = chosen.text.trim().split('\n').first.trimRight();
    final letters = line.characters.take(120).toString();
    return (
      pageId: chosen.id,
      date: chosen.writtenOn,
      text: line == letters ? letters : '$letters…',
      photoId: source?.photoId,
    );
  }

  Future<void> _cafe() async {
    if (_openingCafe || _pageNavigationBusy || _accountLocked) return;
    if (_editorComposing || c.composing) {
      _sourceNotice('입력을 마친 뒤 카페를 열어 주세요.');
      return;
    }
    final owner = c;
    _openingCafe = true;
    try {
      await owner.settled;
      if (!mounted || c != owner || _accountLocked) return;
      if (_editorComposing || c.composing) {
        _sourceNotice('입력을 마친 뒤 카페를 열어 주세요.');
        return;
      }
      if (owner.saveError != null) {
        _sourceNotice('글을 저장하지 못했어요. ‘다시 저장’을 눌러 주세요.');
        return;
      }
      _blur();
      final store = owner.store;
      final roomStore = store is CafeSpaceStoreProvider
          ? await (store as CafeSpaceStoreProvider).openSpaceStore(
              widget.sync?.context.account?.userId ??
                  owner.library.sync.accountId ??
                  'local',
            )
          : MemoryCafeSpaceStore();
      if (!mounted || c != owner || _accountLocked) return;
      final pastWriting = _pastCafeWriting(owner.library);
      final sentenceDrafts =
          <String, ({WritingPage page, RegisteredOriginal original})>{};
      final route = paperPanelRoute<void>(
        (context) => AnimatedBuilder(
          animation: owner,
          builder: (context, _) => CafeScreen(
            books: owner.library.books,
            spaceStore: roomStore,
            currentWritingLabel: book?.title == null
                ? (page.text.isEmpty ? '지금 펼친 빈 쪽' : '지금 쓰던 글')
                : '${book!.title} · 지금 펼친 쪽',
            initialSeat: _cafeSeat,
            lastSentence: page.text.trim().characters.take(120).toString(),
            pastWriting: pastWriting,
            onOpenPastWriting: (pageId) async {
              final route = ModalRoute.of(context);
              if (route?.isCurrent != true ||
                  !mounted ||
                  c != owner ||
                  _accountLocked ||
                  _pageNavigationBusy ||
                  !_canLeaveInput() ||
                  owner.saveError != null ||
                  !owner.library.pages.any((page) => page.id == pageId)) {
                return false;
              }
              await _openPage(pageId, paperTurn: false);
              await owner.settled;
              if (!mounted ||
                  c != owner ||
                  _accountLocked ||
                  route?.isCurrent != true ||
                  owner.saveError != null ||
                  owner.library.activePageId != pageId) {
                return false;
              }
              route!.navigator!.pop();
              await _finishWritingNavigation();
              return true;
            },
            onTranscribe: (seat, selectedBookId, sentence) async {
              final route = ModalRoute.of(context);
              if (route?.isCurrent != true ||
                  c != owner ||
                  _accountLocked ||
                  _pageNavigationBusy ||
                  _editorComposing ||
                  c.composing) {
                return false;
              }
              await owner.settled;
              if (!mounted ||
                  c != owner ||
                  _accountLocked ||
                  owner.saveError != null ||
                  route?.isCurrent != true) {
                return false;
              }
              final targetBookId = selectedBookId ?? book?.id;
              final key = '${targetBookId ?? ''}|${sentence.id}';
              final candidate = sentenceDrafts.putIfAbsent(
                key,
                () => (
                  page: _blank(),
                  original: RegisteredOriginal(
                    const Uuid().v4(),
                    sentence.text,
                    citation: sentence.citation,
                    registeredAt: DateTime.now().millisecondsSinceEpoch,
                  ),
                ),
              );
              final origin = page;
              var saved = false;
              await _navigatePage(() async {
                // Retrying a failed atomic save reuses its candidate. A completed
                // retry must not create a second record or replace existing text.
                if (owner.library.pages.any((p) => p.id == candidate.page.id)) {
                  saved = owner.library.activePageId == candidate.page.id;
                } else {
                  saved = await owner.saveImportedTranscription(
                    draft: candidate.page,
                    bookId: targetBookId,
                    looseRecordId: origin.recordId,
                    original: candidate.original,
                  );
                }
                if (saved && mounted) {
                  setState(() {
                    _bookLeaf = null;
                    fresh = false;
                    userFresh = false;
                    draft = candidate.page;
                    _cafeSeat = seat;
                  });
                }
              }, paperTurn: false);
              await owner.settled;
              if (!saved ||
                  !mounted ||
                  c != owner ||
                  _accountLocked ||
                  owner.saveError != null ||
                  route?.isCurrent != true) {
                return false;
              }
              route!.navigator!.pop();
              await _finishWritingNavigation();
              _focusTranscription(owner, candidate.page.id);
              return true;
            },
            saveFailed: owner.saveError != null,
            onRetry: _retrySave,
            onTools: (selectedBookId) async {
              if (!mounted || c != owner || _accountLocked) return;
              final toolBookId = selectedBookId ?? book?.id;
              final toolBook = owner.library.books
                  .where((item) => item.id == toolBookId)
                  .firstOrNull;
              late final PageRoute<void> toolsRoute;
              toolsRoute = paperSheetRoute<void>(
                (_) => ToolsScreen(
                  controller: owner,
                  bookId: toolBookId,
                  paperTool: _toolFor(_paperStyle(toolBook)),
                  onToolSelected: (tool) {
                    if (!mounted ||
                        !toolsRoute.isCurrent ||
                        c != owner ||
                        _accountLocked) {
                      return;
                    }
                    setState(() => _paperTool = tool);
                  },
                ),
              );
              await Navigator.of(context).push(toolsRoute);
            },
            onLeave: () {
              if (c != owner || _accountLocked) return;
              setState(() => _cafeSeat = null);
              Navigator.pop(context);
            },
            onWrite: (seat, bookId) async {
              final route = ModalRoute.of(context);
              if (route?.isCurrent != true ||
                  c != owner ||
                  _accountLocked ||
                  _pageNavigationBusy ||
                  _editorComposing ||
                  c.composing) {
                return false;
              }
              await owner.settled;
              if (!mounted ||
                  c != owner ||
                  _accountLocked ||
                  route?.isCurrent != true ||
                  owner.saveError != null) {
                return false;
              }
              if (bookId == null) {
                await _navigatePage(() async {
                  setState(() => _bookLeaf = null);
                }, paperTurn: false);
              } else {
                final target = owner.library.books
                    .where((book) => book.id == bookId)
                    .firstOrNull;
                if (target == null) return false;
                await _resumeBook(target, paperTurn: false);
              }
              await owner.settled;
              if (!mounted ||
                  c != owner ||
                  _accountLocked ||
                  route?.isCurrent != true ||
                  owner.saveError != null) {
                return false;
              }
              setState(() => _cafeSeat = seat);
              if (route!.isCurrent) route.navigator!.pop();
              await _finishWritingNavigation();
              return true;
            },
          ),
        ),
      );
      await Navigator.of(context).push(route);
    } finally {
      _openingCafe = false;
    }
  }

  void _settings() {
    if (_activePanel?.isCurrent != true || _accountLocked) return;
    Navigator.of(context).push(
      paperPanelRoute<void>(
        (_) => LibrarySettings(
          controller: c,
          onArchive: _archive,
          onSync: widget.sync?.available == true ? _syncInfo : null,
        ),
      ),
    );
  }

  Future<void> _createBook() async {
    _blur();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const NewBookDialog(),
    );
    if (values != null && mounted) {
      _bookLeaf = null;
      fresh = false;
      userFresh = false;
      c.createBook(values.$1, values.$2);
      await _finishWritingNavigation();
    }
  }

  void _menu() {
    if (_editorComposing || c.composing) return;
    _blur();
    _openPanel(
      ToolsScreen(
        controller: c,
        bookId: book?.id,
        paperTool: _toolFor(_paperStyle(book)),
        onToolSelected: (tool) {
          if (_activePanel?.isCurrent != true || _accountLocked) return;
          setState(() => _paperTool = tool);
        },
      ),
      sheet: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _pollSources();
  }

  String _sharedRecordId(IncomingSource share) => 'shared-source-${share.id}';

  bool _isShareRegistered(IncomingSource share) {
    final id = _sharedRecordId(share);
    return c.library.records.any((record) => record.id == id) ||
        c.library.originalRemovals.any((entry) => entry.originalId == id) ||
        c.library.books.any(
          (book) => book.originals.any((original) => original.id == id),
        );
  }

  Future<void> _pollSources({bool openAutomatically = true}) async {
    if (!mounted || _accountLocked) return;
    if (_pollingSources) {
      _pollAgain = true;
      return;
    }
    _pollingSources = true;
    try {
      if (!_checkedPhotoRecovery) {
        _checkedPhotoRecovery = true;
        try {
          final photo = await _intake.recoverPhoto();
          if (mounted && photo != null) setState(() => _recoveredPhoto = photo);
        } on SourceIntakeException catch (error) {
          if (mounted) _sourceNotice(error.message);
        }
      }
      final shares = await _intake.pendingShares();
      if (!mounted || _accountLocked) return;
      IncomingSource? pending;
      for (final share in shares) {
        final imported = _isShareRegistered(share);
        if (imported && !c.saving && c.saveError == null) {
          // A crash after a successful save and before acknowledgement must
          // not import the same OS delivery twice.
          await _intake.acknowledgeShare(share.id);
          if (!mounted || _accountLocked) return;
        } else {
          pending ??= share;
        }
      }
      if (_incoming?.id != pending?.id) setState(() => _incoming = pending);
      if (openAutomatically &&
          !_sourceBusy &&
          !_pageNavigationBusy &&
          !editorFocus.hasFocus &&
          !_editorComposing &&
          !c.composing &&
          c.saveError == null &&
          ModalRoute.of(context)?.isCurrent == true &&
          (_recoveredPhoto != null ||
              (pending != null && !_shownShares.contains(pending.id)))) {
        unawaited(_openPendingSource());
      }
    } catch (_) {
      if (mounted && !_accountLocked) {
        _sourceNotice('가져온 원문을 열지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      _pollingSources = false;
      if (_pollAgain && mounted) {
        _pollAgain = false;
        unawaited(_pollSources());
      }
    }
  }

  void _sourceNotice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openPendingSource() async {
    if (_sourceBusy ||
        _accountLocked ||
        !_canLeaveInput() ||
        c.saveError != null) {
      return;
    }
    if (_recoveredPhoto case final photo?) {
      setState(() => _recoveredPhoto = null);
      await _source(initialPhoto: photo);
    } else if (_incoming case final share?) {
      _shownShares.add(share.id);
      await _source(shared: share);
    }
  }

  Future<void> _discardPendingSource() async {
    if (_recoveredPhoto != null) {
      setState(() => _recoveredPhoto = null);
      return;
    }
    final share = _incoming;
    if (share == null) return;
    try {
      await _intake.acknowledgeShare(share.id);
      if (mounted) await _pollSources();
    } catch (_) {
      if (mounted) _sourceNotice('받은 원문을 지우지 못했어요. 다시 시도해 주세요.');
    }
  }

  void _retrySave() {
    c.retrySave();
    c.settled.then((_) {
      if (mounted && c.saveError == null && _incoming != null) _pollSources();
    });
  }

  Future<SourceImportResult?> _reviewOriginal({
    IncomingSource? shared,
    SourcePhoto? initialPhoto,
    RegisteredOriginal? extractFrom,
    Future<bool> Function(SourceImportResult)? onSaveExtraction,
    Future<bool> Function(SourceImportResult)? onSaveOriginal,
    Future<bool> Function(SourceImportResult)? onSaveTranscription,
    bool initialSearch = false,
    String? bookId,
    bool allowUnbound = true,
  }) async {
    final books = {for (final book in c.library.books) book.id: book.title};
    final targetBook = c.library.books
        .where((item) => item.id == bookId)
        .firstOrNull;
    final style = _paperStyle(targetBook);
    final sharedText = shared?.text.trim() ?? '';
    final linkOnly = RegisteredOriginal.webLink(sharedText) != null;
    final photo = shared?.hasPhoto == true
        ? await _intake.readSharedPhoto(shared!.id)
        : initialPhoto;
    if (!mounted) return null;
    final route = MaterialPageRoute<SourceImportResult>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: originalPanelColor,
        body: Center(
          child: SizedBox(
            width: writingSurfaceMaxWidth,
            child: SourceImportSheet(
              intake: _intake,
              initialText: linkOnly ? '' : sharedText,
              initialCitation:
                  extractFrom?.citation ?? (linkOnly ? sharedText : ''),
              initialPhoto: photo,
              existingPhotoId: extractFrom?.photoId,
              onSaveExtraction: onSaveExtraction,
              onSaveOriginal: onSaveOriginal,
              onSaveTranscription: onSaveTranscription,
              initialSearch: initialSearch,
              initialPhotoRegion: extractFrom?.photoRegion,
              style: style,
              shared: shared != null,
              registration: shared == null && extractFrom == null,
              books: books,
              bookId: bookId,
              allowUnbound: allowUnbound,
            ),
          ),
        ),
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    return result;
  }

  Future<_SavedOriginal?> _registerOriginal({
    String? bookId,
    WritingPage? selectedPage,
    SourcePhoto? initialPhoto,
    bool initialSearch = false,
  }) async {
    if (_sourceBusy || _accountLocked || !_canLeaveInput()) return null;
    final owner = c;
    _sourceBusy = true;
    try {
      await owner.settled;
      if (!mounted || c != owner || _accountLocked || owner.saveError != null) {
        return null;
      }
      RegisteredOriginal? registered;
      String? transcriptionPageId;
      final origin = page;
      final originalId = const Uuid().v4();
      final registeredAt = DateTime.now().millisecondsSinceEpoch;
      bool canSave() =>
          mounted &&
          c == owner &&
          !_accountLocked &&
          !owner.composing &&
          page.id == origin.id;
      RegisteredOriginal originalFor(SourceImportResult result) =>
          RegisteredOriginal(
            originalId,
            result.text,
            citation: result.citation,
            registeredAt: registeredAt,
            photoId: result.photoId,
            photoRegion: result.photoRegion,
            isFullPage: result.isFullPage,
            photoLines: result.photoLines,
          );

      final result = await _reviewOriginal(
        initialPhoto: initialPhoto,
        initialSearch: initialSearch,
        bookId: bookId,
        allowUnbound: selectedPage != null,
        onSaveOriginal: (result) async {
          if (!canSave()) return false;
          registered = await owner.saveNewOriginal(
            bookId: result.bookId,
            page: selectedPage,
            original: originalFor(result),
          );
          return registered != null;
        },
        onSaveTranscription: (result) async {
          if (!canSave()) return false;
          final original = originalFor(result);
          final next = fresh ? draft : _blank();
          final saved = await owner.saveImportedTranscription(
            draft: next,
            bookId: result.bookId,
            looseRecordId: origin.recordId,
            original: original,
          );
          if (!saved || !mounted || c != owner || _accountLocked) return false;
          setState(() {
            _bookLeaf = null;
            fresh = false;
            userFresh = false;
            _directPageChange++;
          });
          registered = original;
          transcriptionPageId = next.id;
          return true;
        },
      );
      if (result == null ||
          registered == null ||
          !mounted ||
          c != owner ||
          _accountLocked) {
        return null;
      }
      if (result.bookId == null && selectedPage != null && fresh) {
        fresh = false;
        userFresh = false;
      }
      return (
        bookId: result.bookId,
        original: registered!,
        startWriting: result.startWriting,
        transcriptionPageId: transcriptionPageId,
      );
    } finally {
      _sourceBusy = false;
    }
  }

  Future<void> _source({
    IncomingSource? shared,
    SourcePhoto? initialPhoto,
  }) async {
    if (_sourceBusy ||
        _pageNavigationBusy ||
        _accountLocked ||
        !_canLeaveInput()) {
      return;
    }
    final owner = c, selectedPage = page;
    _blur();
    if (shared == null) {
      final saved = await _registerOriginal(
        bookId: book?.id,
        selectedPage: selectedPage,
        initialPhoto: initialPhoto,
      );
      if (saved != null) await _afterOriginalSave(selectedPage, saved);
      return;
    }
    _sourceBusy = true;
    try {
      await owner.settled;
      if (!mounted ||
          c != owner ||
          _accountLocked ||
          owner.saveError != null ||
          page.id != selectedPage.id ||
          owner.composing ||
          editorFocus.hasFocus) {
        return;
      }
      final id = _sharedRecordId(shared);
      if (_isShareRegistered(shared)) {
        await _pollSources();
        return;
      }
      final SourceImportResult? result;
      RegisteredOriginal? registered;
      try {
        result = await _reviewOriginal(
          shared: shared,
          bookId: book?.id,
          onSaveOriginal: (result) async {
            if (!mounted ||
                c != owner ||
                _accountLocked ||
                owner.composing ||
                page.id != selectedPage.id ||
                _isShareRegistered(shared)) {
              return false;
            }
            registered = await owner.saveNewOriginal(
              bookId: result.bookId,
              page: result.bookId == null
                  ? WritingPage(id: '$id-page', recordId: id, number: 1)
                  : selectedPage,
              original: RegisteredOriginal(
                id,
                result.text,
                citation: result.citation,
                registeredAt: DateTime.now().millisecondsSinceEpoch,
                photoId: result.photoId,
                photoRegion: result.photoRegion,
                isFullPage: result.isFullPage,
                photoLines: result.photoLines,
              ),
            );
            return registered != null;
          },
        );
      } on SourceIntakeException catch (error) {
        if (mounted) _sourceNotice(error.message);
        return;
      }
      if (result == null ||
          registered == null ||
          !mounted ||
          c != owner ||
          _accountLocked) {
        return;
      }
      if (result.bookId == null) {
        fresh = false;
        userFresh = false;
      }
      await _pollSources(openAutomatically: false);
      if (!mounted || c != owner || _accountLocked) return;
      _sourceBusy = false;
      await _afterOriginalSave(page, (
        bookId: result.bookId,
        original: registered!,
        startWriting: result.startWriting,
        transcriptionPageId: null,
      ));
    } finally {
      _sourceBusy = false;
    }
  }

  Future<RegisteredOriginal?> _extractArchivedPhoto(
    LibraryController owner,
    String? bookId,
    String recordId,
    RegisteredOriginal original,
  ) async {
    final photoId = original.photoId;
    if (_sourceBusy ||
        _accountLocked ||
        original.canTranscribe ||
        photoId == null) {
      return null;
    }
    _sourceBusy = true;
    try {
      final bytes = await const OriginalPhotoStore().load(photoId);
      if (!mounted || c != owner || _accountLocked || owner.saveError != null) {
        return null;
      }
      if (bytes == null) {
        _sourceNotice('이 기기에 보관된 사진이 없어요.');
        return null;
      }
      RegisteredOriginal? saved;
      await _reviewOriginal(
        initialPhoto: SourcePhoto(photoId, bytes),
        bookId: bookId,
        extractFrom: original,
        onSaveExtraction: (result) async {
          if (!mounted || c != owner || _accountLocked) return false;
          saved = await owner.saveOriginalEdit(
            bookId: bookId,
            recordId: recordId,
            original: original,
            text: result.text,
            citation: result.citation,
            extraction: (
              isFullPage: result.isFullPage,
              photoLines: result.photoLines,
              photoRegion: result.photoRegion,
            ),
          );
          return saved != null;
        },
      );
      return saved;
    } catch (_) {
      if (mounted) _sourceNotice('사진에서 원문을 가져오지 못했어요.');
      return null;
    } finally {
      _sourceBusy = false;
    }
  }

  Future<void> _afterOriginalSave(
    WritingPage origin,
    _SavedOriginal saved,
  ) async {
    if (saved.transcriptionPageId case final target?) {
      _focusTranscription(c, target);
      return;
    }
    if (page.id != origin.id) return;
    if (saved.startWriting) {
      await _startTranscription(saved.original, saved.bookId, origin);
      return;
    }
    final destination = c.library.books
        .where((item) => item.id == saved.bookId)
        .firstOrNull;
    await _showOriginals(
      originalBook: destination,
      openOriginalId: saved.original.id,
      unbound: saved.bookId == null,
    );
  }

  String _transcribeLabel(String? bookId, WritingPage page) => '필사하기';

  Future<void> _startTranscription(
    RegisteredOriginal original,
    String? bookId,
    WritingPage origin,
  ) async {
    if (page.id != origin.id) return;
    String? target;
    final owner = c;
    await _navigatePage(() async {
      if (bookId != null && !c.library.books.any((item) => item.id == bookId)) {
        return;
      }
      if (bookId == null &&
          !c.library.records.any((item) => item.id == origin.recordId)) {
        return;
      }
      final originals = originalsFor(
        owner.library,
        bookId: bookId,
        recordId: origin.recordId,
      );
      final source =
          originals.where((item) => item.id == original.id).firstOrNull ??
          originals
              .where(
                (item) =>
                    item.text == original.text &&
                    item.citation == original.citation &&
                    item.photoId == original.photoId &&
                    listEquals(item.photoRegion, original.photoRegion),
              )
              .firstOrNull;
      if (source == null) return;
      // Each new transcription is its own writing; continuation uses addPage.
      final next = fresh ? draft : _blank();
      _bookLeaf = null;
      fresh = false;
      userFresh = false;
      c.saveDraft(
        c.attachedPage(next, source),
        bookId: bookId,
        title: originalWritingTitle(source),
        // Loose originals belong to a record. Keep the catalog available when
        // starting another writing without a book.
        originals: bookId == null ? originals : const [],
        keepBlank: true,
      );
      target = page.id;
    }, paperTurn: false);
    final opened = target;
    if (opened == null ||
        !mounted ||
        page.id != opened ||
        c != owner ||
        _accountLocked ||
        c.saveError != null) {
      return;
    }
    _focusTranscription(owner, opened);
  }

  void _focusTranscription(LibraryController owner, String target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && c == owner && !_accountLocked && page.id == target) {
        editorFocus.requestFocus();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _showOriginals({
    Book? bookDetails,
    Book? originalBook,
    String? openOriginalId,
    bool unbound = false,
  }) async {
    if (_readingSource || _sourceBusy || _accountLocked || !_canLeaveInput()) {
      return;
    }
    final owner = c;
    final selectedPage = page;
    final selectedBook = unbound ? null : bookDetails ?? originalBook ?? book;
    final bookId = selectedBook?.id;
    _blur();
    _readingSource = true;
    List<RegisteredOriginal> originals() => originalsFor(
      owner.library,
      bookId: bookId,
      recordId: selectedPage.recordId,
    );
    Map<String, ({Passage passage, bool marked})> writingLocations() {
      final sources = originals();
      final locations = originalWritingLocations(
        sources,
        owner.library.volumePages(
          bookId: bookId,
          recordId: selectedPage.recordId,
        ),
      );
      if (bookDetails == null) {
        for (final entry in originalWritingLocations(sources, [
          selectedPage,
        ]).entries) {
          locations[entry.key] = (
            passage: entry.value.passage,
            marked: entry.value.marked || locations[entry.key]?.marked == true,
          );
        }
      }
      return locations;
    }

    Future<_SavedOriginal?> register({bool find = false}) => _registerOriginal(
      initialSearch: find,
      bookId: bookId,
      selectedPage: bookDetails == null ? selectedPage : null,
    );

    try {
      final available = originals();
      final scope = (
        bookId: bookId,
        recordId: bookId == null ? selectedPage.recordId : null,
      );
      String? availableId(String? id) =>
          available.any((item) => item.id == id) ? id : null;
      final pageChoice = bookDetails == null
          ? _originalByPage[selectedPage.id]
          : null;
      final activeLink = bookDetails == null
          ? passageAt(
              pageOriginals(selectedPage, available),
              selectedPage.extent,
            )
          : null;
      final guideMatch = matchTranscriptionPosition(
        selectedPage,
        activeLink,
        available,
      );
      final match = bookDetails == null
          ? guideMatch ??
                matchOriginal(available, selectedPage.text, selectedPage.extent)
          : null;
      final guided =
          activeLink?.original?.id ??
          (bookDetails == null ? selectedPage.guidedOriginalId : null);
      final initialId =
          availableId(openOriginalId) ??
          availableId(guided) ??
          availableId(pageChoice) ??
          match?.original.id ??
          availableId(_originalByVolume[scope]);
      if (initialId != null) _originalByVolume[scope] = initialId;
      _SavedOriginal? savedAfterPanel;
      bool openedWriting = false;
      late final MaterialPageRoute<RegisteredOriginal> route;
      route = paperPanelRoute<RegisteredOriginal>(
        (_) => ListenableBuilder(
          listenable: owner,
          builder: (context, _) => SourceReading(
            originals: originals(),
            bookTitle: selectedBook?.title,
            transcribeLabel: _transcribeLabel(bookId, selectedPage),
            previousCitations: bookDetails == null
                ? selectedPage.originalCitations
                : const [],
            initialOriginalId: initialId,
            match: match,
            onReadOriginal: (id) {
              if (!mounted || c != owner || _accountLocked) return;
              _originalByVolume[scope] = id;
              if (bookDetails == null) {
                _originalByPage[selectedPage.id] = id;
              }
            },
            style: _paperStyle(selectedBook),
            onFind: owner.saveError != null
                ? null
                : () async {
                    final saved = await register(find: true);
                    if (saved == null) return null;
                    if (saved.bookId != bookId || saved.startWriting) {
                      if (context.mounted &&
                          ModalRoute.of(context)?.isCurrent == true) {
                        savedAfterPanel = saved;
                        Navigator.of(context).pop();
                      }
                      return null;
                    }
                    return saved.original;
                  },
            onRegister: owner.saveError != null
                ? null
                : () async {
                    final saved = await register();
                    if (saved == null) return null;
                    if (saved.bookId != bookId || saved.startWriting) {
                      if (context.mounted &&
                          ModalRoute.of(context)?.isCurrent == true) {
                        savedAfterPanel = saved;
                        Navigator.of(context).pop();
                      }
                      return null;
                    }
                    return saved.original;
                  },
            writingLocations: writingLocations(),
            onExtractPhoto: owner.saveError == null
                ? (original) => _extractArchivedPhoto(
                    owner,
                    bookId,
                    selectedPage.recordId,
                    original,
                  )
                : null,
            onTranscribe: owner.saveError == null
                ? (original) {
                    if (!context.mounted ||
                        c != owner ||
                        _accountLocked ||
                        ModalRoute.of(context)?.isCurrent != true) {
                      return;
                    }
                    Navigator.of(context).pop(original);
                  }
                : null,
            onOpenWriting: (passage) =>
                _openPageFromPanel(route, owner, () async {
                  await _openPassage(passage, paperTurn: false);
                  openedWriting = true;
                }),
            onSetPosition:
                activeLink == null ||
                    activeLink.referenceOnly ||
                    guideMatch == null
                ? null
                : (original, offset) async {
                    if (!mounted ||
                        c != owner ||
                        _accountLocked ||
                        !route.isCurrent ||
                        !_canLeaveInput()) {
                      return false;
                    }
                    final saved = await owner.saveOriginalPosition(
                      pageId: selectedPage.id,
                      passageId: activeLink.id,
                      original: original,
                      offset: offset,
                    );
                    if (!saved ||
                        !mounted ||
                        c != owner ||
                        _accountLocked ||
                        !route.isCurrent) {
                      return false;
                    }
                    openedWriting = true;
                    route.navigator!.pop();
                    return true;
                  },
            onRetry: owner.saveError == null ? null : _retrySave,
            onEdit: (original, text, citation) async {
              if (!mounted || c != owner || _accountLocked) return null;
              return owner.saveOriginalEdit(
                bookId: bookId,
                recordId: selectedPage.recordId,
                original: original,
                text: text,
                citation: citation,
              );
            },
            onDelete: (original) async {
              if (!mounted || c != owner || _accountLocked) return false;
              return owner.deleteOriginal(
                bookId: bookId,
                recordId: selectedPage.recordId,
                original: original,
              );
            },
            onSaveReflection: (original, reflection) => _saveReflection(
              owner,
              bookId,
              selectedPage.recordId,
              original,
              reflection,
            ),
          ),
        ),
        color: originalPanelColor,
      );
      _sourceRoute = route;
      final action = await Navigator.of(context).push(route);
      await route.completed;
      if (_sourceRoute == route) _sourceRoute = null;
      if (savedAfterPanel case final saved?) {
        _readingSource = false;
        if (mounted && c == owner && !_accountLocked) {
          if (bookDetails != null && saved.startWriting) {
            await _afterSheet(() => _afterOriginalSave(selectedPage, saved));
          } else {
            await _afterOriginalSave(selectedPage, saved);
          }
        }
        return;
      }
      if (openedWriting && mounted && c == owner && !_accountLocked) {
        if (bookDetails != null) await _afterSheet(() async {});
        return;
      }
      if (action != null && mounted && c == owner && !_accountLocked) {
        if (bookDetails != null) {
          await _afterSheet(
            () => _startTranscription(action, bookId, selectedPage),
          );
        } else {
          await _startTranscription(action, bookId, selectedPage);
        }
        return;
      }
    } finally {
      _readingSource = false;
    }
  }

  Future<bool> _saveReflection(
    LibraryController owner,
    String? bookId,
    String recordId,
    RegisteredOriginal original,
    OriginalReflection? reflection,
  ) async {
    if (!mounted || c != owner || _accountLocked) return false;
    final latest = originalsFor(
      owner.library,
      bookId: bookId,
      recordId: recordId,
    ).where((item) => item.id == original.id).firstOrNull;
    if (latest == null ||
        latest.text != original.text ||
        latest.citation != original.citation) {
      return false;
    }
    return owner.saveOriginalReflection(
      bookId: bookId,
      recordId: recordId,
      original: latest,
      reflection: reflection,
    );
  }

  Future<void> _pages() async {
    if (_pageNavigationBusy || !_canLeaveInput()) return;
    _blur();
    final owner = c;
    final selectedRecord = record;
    bool choosingBook = false, binding = false;
    late final PageRoute<void> route;
    late StateSetter updatePanel;
    Future<void> chooseBook(String id) async {
      if (binding ||
          !mounted ||
          c != owner ||
          _accountLocked ||
          !route.isCurrent) {
        return;
      }
      updatePanel(() => binding = true);
      try {
        String target = id;
        if (target == 'new') {
          final values = await showDialog<(String, String)>(
            context: context,
            builder: (_) => const NewBookDialog(),
          );
          if (values == null ||
              !mounted ||
              c != owner ||
              _accountLocked ||
              !route.isCurrent) {
            return;
          }
          target = owner.addBook(values.$1, values.$2).id;
        }
        if (selectedRecord != null) {
          owner.bindRecord(selectedRecord.id, target);
        } else {
          setState(() => draftBookId = target);
        }
        await owner.settled;
        if (mounted &&
            c == owner &&
            !_accountLocked &&
            owner.saveError == null &&
            route.isCurrent) {
          route.navigator!.pop();
          await _finishWritingNavigation();
        }
      } finally {
        if (mounted && route.isActive) updatePanel(() => binding = false);
      }
    }

    route = paperSheetRoute<void>(
      (_) => StatefulBuilder(
        builder: (context, setPanelState) {
          updatePanel = setPanelState;
          return AnimatedBuilder(
            animation: owner,
            builder: (_, _) {
              final pages = _volumePages;
              final pageCounts = <String, int>{};
              for (final page in owner.library.pages) {
                pageCounts.update(
                  page.recordId,
                  (count) => count + 1,
                  ifAbsent: () => 1,
                );
              }
              final style = _paperStyle(book);
              return PopScope(
                canPop: !choosingBook && !binding && owner.saveError == null,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop &&
                      choosingBook &&
                      !binding &&
                      owner.saveError == null) {
                    updatePanel(() => choosingBook = false);
                  }
                },
                child: PaperPanel(
                  color: panelPaperColor(paperColors[style.paperIndex]),
                  child: choosingBook
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              PaperPanelHeader(
                                book == null ? '책에 넣기' : '다른 책으로 옮기기',
                                backLabel: '쪽 목록',
                                allowWritingReturn: false,
                                canClose: !binding && owner.saveError == null,
                                onBack: () =>
                                    updatePanel(() => choosingBook = false),
                              ),
                              Expanded(
                                child: ListView(
                                  children: [
                                    for (final target
                                        in owner.library.books.where(
                                          (b) => b.id != book?.id,
                                        ))
                                      ListTile(
                                        title: Text(target.title),
                                        leading: BookCover(
                                          title: '',
                                          width: 29,
                                          variant: owner.coverIndexFor(target),
                                          details: owner.detailsFor(target),
                                        ),
                                        enabled:
                                            !binding && owner.saveError == null,
                                        onTap: () => chooseBook(target.id),
                                      ),
                                    ListTile(
                                      title: const Text('새 책 만들기'),
                                      leading: const Icon(CupertinoIcons.plus),
                                      enabled:
                                          !binding && owner.saveError == null,
                                      onTap: () => chooseBook('new'),
                                    ),
                                  ],
                                ),
                              ),
                              if (owner.saveError != null)
                                PaperSettingsSaveNotice(
                                  onRetry: () async {
                                    owner.retrySave();
                                    await owner.settled;
                                    if (mounted &&
                                        c == owner &&
                                        !_accountLocked &&
                                        owner.saveError == null &&
                                        route.isCurrent) {
                                      route.navigator!.pop();
                                    }
                                  },
                                ),
                            ],
                          ),
                        )
                      : PagesSheet(
                          pages: pages,
                          currentId: page.id,
                          style: style,
                          coverTitle: book?.title,
                          coverVariant: _coverVariant,
                          onChoose: (choice) =>
                              _openPageFromPanel(route, owner, () async {
                                if (choice.append) {
                                  await _appendPage(paperTurn: false);
                                } else if (choice.cover) {
                                  await _openCover(
                                    back: choice.backCover,
                                    paperTurn: false,
                                  );
                                } else if (choice.pageId case final id?) {
                                  await _openPage(id, paperTurn: false);
                                }
                              }),
                          onReadAloud: () {
                            if (route.isCurrent != true ||
                                c != owner ||
                                _accountLocked ||
                                !_canLeaveInput()) {
                              return;
                            }
                            showReadAloud(
                              context,
                              library: owner.library,
                              book: book,
                              page: page,
                              color: panelPaperColor(
                                paperColors[style.paperIndex],
                              ),
                            );
                          },
                          onBind: () {
                            if (route.isCurrent &&
                                c == owner &&
                                !_accountLocked) {
                              updatePanel(() => choosingBook = true);
                            }
                          },
                          canTrash: (page) =>
                              (pageCounts[page.recordId] ?? 0) > 1,
                          onTrash: (target) async {
                            if (!mounted ||
                                c != owner ||
                                _accountLocked ||
                                !_canLeaveInput()) {
                              return false;
                            }
                            final previous = page.id;
                            final saved = await owner.trashPage(target);
                            if (saved &&
                                mounted &&
                                c == owner &&
                                page.id != previous) {
                              setState(() => _directPageChange++);
                            }
                            return saved;
                          },
                        ),
                ),
              );
            },
          );
        },
      ),
    );
    await Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final locked =
        (widget.sync?.accountMismatch ?? false) ||
        (widget.sync?.signInRequired == true &&
            c.library.sync.accountId != null);
    if (locked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.lock, color: muted),
                const SizedBox(height: 20),
                Text(
                  widget.sync!.signInRequired
                      ? '로그인이 필요합니다.'
                      : '로그인 계정이 바뀌었습니다.',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                const Text(
                  '계정의 기록을 보호하고 있습니다.\n같은 계정으로 다시 연결해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.8, color: muted),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: widget.sync!.signInRequired
                      ? widget.sync!.context.signIn
                      : widget.sync!.context.reload,
                  child: Text(
                    widget.sync!.signInRequired
                        ? 'ChatGPT로 로그인'
                        : '계정 책장 다시 불러오기',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final current = page;
    final pages = _volumePages;
    final index = pages.indexWhere((p) => p.id == current.id);
    final leaf = _visibleLeaf;
    final showingLeaf = leaf != null;
    final showingCover = showingLeaf && leaf != _BookLeaf.bookplate;
    final showingBack = leaf == _BookLeaf.backCover;
    final displayBook = _leafBook ?? book;
    final hasBook = displayBook != null;
    final hasBookplate =
        displayBook != null && c.detailsFor(displayBook).bookplate.enabled;
    final displayPages = displayBook?.id == book?.id && !fresh
        ? pages
        : (hasBook ? c.library.volumePages(bookId: displayBook.id) : pages);
    final navigationEnabled =
        !_pageNavigationBusy &&
        !_editorComposing &&
        !c.composing &&
        c.saveError == null;
    final canSwipe =
        navigationEnabled &&
        !editorFocus.hasFocus &&
        (showingLeaf || _toolFor(_paperStyle(book)) == PaperTool.writing);
    final compact = MediaQuery.sizeOf(context).height < 520;
    Widget paper(WritingPage target, int index, {bool preview = true}) =>
        _paperSurface(
          target,
          index,
          pages.length,
          compact,
          preview: preview,
          navigationEnabled: !preview && navigationEnabled,
        );
    Widget firstPaper() => _paperSurface(
      displayPages.firstOrNull ??
          const WritingPage(
            id: 'first-paper-preview',
            recordId: 'first-paper-preview',
            number: 1,
          ),
      0,
      math.max(displayPages.length, 1),
      compact,
      preview: true,
      navigationEnabled: false,
      previewBook: displayBook,
      previewFromTop: true,
    );
    Widget cover({bool back = false}) => BookFrontCover(
      title: displayBook!.title,
      author: displayBook.author,
      variant: c.coverIndexFor(displayBook),
      style: _paperStyle(displayBook),
      pageCount: displayPages.length,
      back: back,
      onOpen: () => _stepPage(back ? -1 : 1),
      onResume: !back && displayPages.isNotEmpty
          ? () => _resumeBook(displayBook)
          : null,
      onAppend: back ? _appendPage : null,
      onContents: back
          ? null
          : () => _collection(initialBookId: displayBook.id),
      onCollection: _collection,
    );
    Widget bookplate() => _insideBookplate(displayBook!, displayPages);
    final previous = switch (leaf) {
      _BookLeaf.frontCover => null,
      _BookLeaf.bookplate => cover(),
      _BookLeaf.backCover => paper(current, index),
      null =>
        index != 0
            ? paper(pages[index - 1], index - 1)
            : hasBookplate
            ? bookplate()
            : hasBook
            ? cover()
            : null,
    };
    final nextPage = index + 1 < pages.length
        ? pages[index + 1]
        : WritingPage(
            id: 'preview-next:${current.id}',
            recordId: current.recordId,
            number: current.number + 1,
          );
    // A scrolled or guided destination needs the real editor's viewport.
    // A read-only neighbour lacks the guide and can wrap or clamp differently.
    bool needsLivePage(WritingPage target) =>
        target.scroll > 0 || target.guidedOriginalId != null;
    final firstPage = displayPages.firstOrNull;
    return Scaffold(
      backgroundColor: appPaper,
      resizeToAvoidBottomInset: false,
      body: PageTurnView(
        key: ValueKey((c, c.editorEpoch)),
        controller: _pageTurn,
        directPageChange: _directPageChange,
        page: current,
        style: _paperStyle(book),
        scopeId: displayBook?.id ?? current.recordId,
        position: switch (leaf) {
          _BookLeaf.frontCover => -2,
          _BookLeaf.bookplate => -1,
          _BookLeaf.backCover => pages.length,
          null => index,
        },
        isCover: showingCover,
        isBackCover: showingBack,
        coverSurface: showingCover ? cover(back: showingBack) : null,
        previousIsCover:
            leaf == _BookLeaf.bookplate ||
            (leaf == null && hasBook && !hasBookplate && index == 0),
        nextIsCover:
            hasBook && !showingLeaf && !fresh && index == pages.length - 1,
        previousDirect: switch (leaf) {
          _BookLeaf.backCover => needsLivePage(current),
          null => index > 0 && needsLivePage(pages[index - 1]),
          _ => false,
        },
        nextDirect: switch (leaf) {
          _BookLeaf.bookplate => firstPage?.guidedOriginalId != null,
          _BookLeaf.frontCover =>
            !hasBookplate && firstPage?.guidedOriginalId != null,
          null => index + 1 < pages.length && needsLivePage(nextPage),
          _ => false,
        },
        directIncoming:
            !showingLeaf &&
            (current.guidedOriginalId != null ||
                (current.scroll > 0 && _firstPageView?.pageId != current.id)),
        editing: c.editorFocused,
        composing: _editorComposing || c.composing,
        onTurn: _commitTurn,
        previous: previous,
        next: switch (leaf) {
          _BookLeaf.frontCover => hasBookplate ? bookplate() : firstPaper(),
          _BookLeaf.bookplate => firstPaper(),
          _BookLeaf.backCover => null,
          null =>
            hasBook && !fresh && index == pages.length - 1
                ? cover(back: true)
                : paper(nextPage, index + 1),
        },
        child: PaperSwipe(
          key: const ValueKey('paper-swipe'),
          touchOnly: !showingLeaf,
          onPrevious:
              canSwipe &&
                  (showingLeaf
                      ? leaf != _BookLeaf.frontCover
                      : hasBook || index > 0)
              ? () => _stepPage(-1)
              : null,
          onNext: canSwipe && !showingBack ? () => _stepPage(1) : null,
          onTurnOrigin: (origin) => _pageTurn.start(origin: origin),
          onTurnUpdate: _pageTurn.update,
          onTurnEnd: _pageTurn.end,
          onTurnCancel: _pageTurn.cancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: showingLeaf,
                child: paper(current, index, preview: false),
              ),
              if (showingCover) cover(back: showingBack),
              if (leaf == _BookLeaf.bookplate) bookplate(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insideBookplate(Book book, List<WritingPage> pages) {
    final style = _paperStyle(book);
    final recordCount = pages.map((page) => page.recordId).toSet().length;
    return PaperBackdrop(
      key: const ValueKey('inside-bookplate'),
      color: paperColors[style.paperIndex],
      grainOpacity: paperGrainOpacity[style.paperIndex],
      binding: style.bookDetails.binding,
      coverIndex: c.coverIndexFor(book),
      pagesAfter: pages.length,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextButton(
                  key: const ValueKey('open-bookshelf'),
                  onPressed: _collection,
                  child: const Text('책장'),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  Bookplate(
                    title: book.title,
                    owner: book.owner,
                    summary: '$recordCount편 · ${pages.length}쪽',
                    stockColor: paperColors[style.paperIndex],
                    choice: style.bookDetails.bookplate,
                    flower: style.bookDetails.pressedFlower,
                    onOwner: () => _editBookOwner(book),
                  ),
                ],
              ),
            ),
            OverflowBar(
              alignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _stepPage(-1),
                  child: const Text('앞표지'),
                ),
                TextButton(
                  onPressed: () => _stepPage(1),
                  child: Text(pages.isEmpty ? '첫 쪽 쓰기' : '첫 쪽 펼치기'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editBookOwner(Book book) async {
    final controller = c;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => BookOwnerDialog(owner: book.owner),
    );
    if (name != null && mounted && c == controller && !_accountLocked) {
      c.setBookOwner(book.id, name);
    }
  }

  Widget _paperSurface(
    WritingPage currentPage,
    int index,
    int count,
    bool compact, {
    required bool preview,
    required bool navigationEnabled,
    Book? previewBook,
    bool previewFromTop = false,
  }) {
    final record = c.library.records
        .where((r) => r.id == currentPage.recordId)
        .firstOrNull;
    final bookId = record?.bookId ?? (fresh ? draftBookId : null);
    final book =
        previewBook ?? c.library.books.where((b) => b.id == bookId).firstOrNull;
    final style = _paperStyle(book);
    final safePadding = MediaQuery.paddingOf(context);
    final sideInset = math.max(safePadding.left, safePadding.right);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOverlap = math.max(
      0.0,
      keyboardInset - MediaQuery.viewPaddingOf(context).bottom,
    );
    // Mobile browsers may shrink the viewport instead of reporting an inset.
    final mobileWeb =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final tool = preview ? PaperTool.writing : _toolFor(style);
    final showKeyboardDismiss =
        !preview &&
        tool == PaperTool.writing &&
        (keyboardInset > 0 || (mobileWeb && editorFocus.hasFocus));
    final example =
        !preview && fresh && _firstWritingExample?.page.id == currentPage.id
        ? _firstWritingExample
        : null;
    final showExample =
        !preview &&
        _canShowFirstWritingExample &&
        example == null &&
        _dismissedExamplePage != currentPage.id &&
        !editorFocus.hasFocus &&
        keyboardInset == 0 &&
        navigationEnabled &&
        tool == PaperTool.writing;
    final originals = preview
        ? const <RegisteredOriginal>[]
        : example != null
        ? [example.original]
        : originalsFor(
            c.library,
            bookId: bookId,
            recordId: currentPage.recordId,
          );
    final surface = PaperBackdrop(
      binding: book == null
          ? const BookDetailChoice(enabled: false)
          : style.bookDetails.binding,
      color: paperColors[style.paperIndex],
      grainOpacity: paperGrainOpacity[style.paperIndex],
      coverIndex: book == null ? null : c.coverIndexFor(book),
      pagesBefore: index,
      pagesAfter: count - index - 1,
      child: SafeArea(
        minimum: EdgeInsets.symmetric(horizontal: sideInset),
        maintainBottomViewPadding: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WritingHeader(
                ribbon: style.bookDetails.ribbon,
                bookmarked: book != null && record != null,
                useDevelopmentTypeface: c.library.style.useDevelopmentTypeface,
                compact: compact,
                showInkMark: keyboardInset == 0,
                bookTitle: book?.title,
                loosePage: book == null && record != null,
                onCollection: _collection,
                onAdd: book == null
                    ? () => _newWriting()
                    : () => _appendPage(addAfterDraft: false),
              ),
              if (!preview && _cafeSeat != null)
                Padding(
                  key: const ValueKey('cafe-writing-session'),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_cafe_outlined,
                        size: 16,
                        color: muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _cafeSeat!.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: muted),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('return-to-cafe'),
                        onPressed: _cafe,
                        child: const Text('카페로'),
                      ),
                    ],
                  ),
                ),
              if (widget.sync != null &&
                  (widget.sync!.hasLegacy || widget.sync!.legacyError))
                TextButton(
                  onPressed: _syncInfo,
                  child: Text(
                    widget.sync!.legacyError
                        ? '이전 글을 읽지 못했어요 · 확인'
                        : '이 기기의 이전 글 가져오기',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (c.saveError != null)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffffeee5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '글을 저장하지 못했어요.\n앱을 닫기 전에 ‘다시 저장’을 눌러 주세요.',
                              style: TextStyle(fontSize: 13, height: 1.35),
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _retrySave,
                        child: const Text('다시 저장'),
                      ),
                    ],
                  ),
                ),
              if (_incoming != null || _recoveredPhoto != null)
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _openPendingSource,
                        child: Text(
                          _recoveredPhoto != null ? '가져오던 사진 확인' : '공유한 원문 확인',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '받은 원문 지우기',
                      onPressed: _discardPendingSource,
                      icon: const Icon(CupertinoIcons.xmark, size: 16),
                    ),
                  ],
                ),
              if (showExample) _firstWritingExamplePreview(style),
              Expanded(
                key: const ValueKey('writing-surface'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (preview)
                      PageReadPreview(
                        key: ValueKey((currentPage.id, previewFromTop)),
                        page: currentPage,
                        fromTop: previewFromTop,
                        style: style,
                      )
                    else
                      PageEditor(
                        key: ValueKey('${currentPage.id}:${c.editorEpoch}'),
                        page: example?.page ?? currentPage,
                        style: style,
                        focusNode: editorFocus,
                        showFirstWritingHint:
                            !showExample &&
                            fresh &&
                            c.library.pages.isEmpty &&
                            c.library.trashedPages.isEmpty &&
                            originals.isEmpty,
                        originals: originals,
                        guidedOriginal: originals
                            .where(
                              (item) =>
                                  item.id ==
                                  (example?.page ?? currentPage)
                                      .guidedOriginalId,
                            )
                            .firstOrNull,
                        onAddOriginal: navigationEnabled
                            ? () => _showOriginals()
                            : null,
                        onRemoveOriginal: (id) {
                          if (navigationEnabled &&
                              !_editorComposing &&
                              !c.composing &&
                              page.id == currentPage.id) {
                            if (!_leaveFirstWritingExample(currentPage.id)) {
                              c.detachOriginal(currentPage.id, id);
                            }
                          }
                        },
                        onWriteWithoutOriginal: () {
                          if (navigationEnabled &&
                              !_editorComposing &&
                              !c.composing &&
                              page.id == currentPage.id) {
                            if (!_leaveFirstWritingExample(currentPage.id)) {
                              c.writeWithoutOriginal(currentPage.id);
                            }
                          }
                        },
                        keyboardOverlap: keyboardOverlap,
                        startAtTopRequest:
                            _firstPageView?.pageId == currentPage.id
                            ? _firstPageView?.request
                            : null,
                        reveal: _reveal?.pageId == currentPage.id
                            ? (
                                offset: _reveal!.offset,
                                request: _reveal!.request,
                              )
                            : null,
                        onChanged: _edit,
                        onFontSizeChanged: (value) {
                          if (!_editorComposing && !c.composing) {
                            c.setStyle(c.library.style.copy(fontSize: value));
                          }
                        },
                        onEraseHighlight: c.erasePencilMark,
                        onHighlight: c.addPencilMark,
                        paperTool: tool,
                        onEditingState: (focused, composing) {
                          _editorComposing = composing;
                          c.setEditorState(
                            focused: focused,
                            isComposing: composing,
                          );
                        },
                      ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(0, preview ? 0 : -keyboardOverlap),
                child: WritingFooter(
                  offerSourceImport:
                      !preview &&
                      (example != null || originals.isEmpty) &&
                      currentPage.originalCitations.isEmpty,
                  ornament: style.bookDetails.ornament,
                  onMenu: _menu,
                  paperTool: tool,
                  onResumeWriting: () =>
                      setState(() => _paperTool = PaperTool.writing),
                  showKeyboardDismiss: showKeyboardDismiss,
                  onKeyboardDismiss: _editorComposing || c.composing
                      ? null
                      : _dismissWritingKeyboard,
                  onSource: navigationEnabled ? () => _showOriginals() : null,
                  failed: c.saveError != null,
                  pageLabel: '${index + 1}',
                  pageCount: count,
                  onPages: navigationEnabled ? _pages : null,
                  onPrevious: navigationEnabled && (book != null || index > 0)
                      ? () => _stepPage(-1)
                      : null,
                  onNext: navigationEnabled ? () => _stepPage(1) : null,
                  onTurnStart: _pageTurn.start,
                  onTurnUpdate: _pageTurn.update,
                  onTurnEnd: _pageTurn.end,
                  onTurnCancel: _pageTurn.cancel,
                  status: c.saveError != null
                      ? '저장 실패'
                      : record == null
                      ? '자동 저장'
                      : c.saving
                      ? '저장 중'
                      : '저장됨',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (preview) return surface;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: () {
        if (editorFocus.hasFocus) _dismissWritingKeyboard();
      },
      child: surface,
    );
  }

  void _syncInfo() {
    if (widget.sync == null || !widget.sync!.available) {
      _archive();
      return;
    }
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: false);
    final sync = widget.sync!;
    Navigator.of(context).push(
      paperPanelRoute<void>(
        (_) => AnimatedBuilder(
          animation: sync,
          builder: (context, _) => PaperPanel(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 6, 28, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PaperPanelHeader('다른 기기에서 이어 쓰기'),
                  const SizedBox(height: 20),
                  Text(
                    sync.message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.8,
                      color: ink,
                    ),
                  ),
                  if (sync.signedIn) ...[
                    const SizedBox(height: 8),
                    Text(
                      sync.context.account!.email.isEmpty
                          ? '같은 ChatGPT 계정의 PC·모바일 책장'
                          : sync.context.account!.email,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '기기에 먼저 저장하고, 연결되면 계정에 보관합니다.\n서로 다르게 고친 문장은 ‘충돌 보관’ 필사로 남깁니다.',
                    style: TextStyle(fontSize: 12, height: 1.9, color: muted),
                  ),
                  if (sync.conflictCopies > 0) ...[
                    const SizedBox(height: 14),
                    Text(
                      '겹쳐 수정한 기록 ${sync.conflictCopies}편을 따로 보관했습니다.',
                      style: const TextStyle(fontSize: 12, color: burgundy),
                    ),
                  ],
                  if (sync.legacyError) ...[
                    const SizedBox(height: 14),
                    const Text(
                      '기존 기기 기록을 읽지 못했습니다. 원본은 그대로 보관하며, 빈 기록으로 덮어쓰지 않습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: burgundy,
                        height: 1.8,
                      ),
                    ),
                  ],
                  if (sync.hasLegacy) ...[
                    const SizedBox(height: 22),
                    const Divider(color: line),
                    const SizedBox(height: 8),
                    Text(
                      '이 기기의 기존 기록 ${sync.legacyBooks}권 · 필사 ${sync.legacyRecords}편',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '계정 책장에 합쳐 가져옵니다. 기존 기기 기록도 그대로 보관합니다.',
                      style: TextStyle(fontSize: 12, color: muted, height: 1.8),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: sync.busy ? null : sync.importLegacy,
                        child: const Text('이 기기 기록 가져오기'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: sync.busy
                          ? null
                          : sync.signedIn && sync.phase != 'sign_in_required'
                          ? sync.syncNow
                          : sync.context.signIn,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        sync.busy
                            ? '동기화 중'
                            : sync.signedIn && sync.phase != 'sign_in_required'
                            ? '지금 동기화'
                            : 'ChatGPT로 로그인',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _archive({Book? selectedBook}) async {
    if (_accountLocked || !_canLeaveInput()) return;
    _blur();
    final owner = c;
    final targetBook = selectedBook ?? book;
    final panel = panelPaperColor(
      paperColors[_paperStyle(targetBook).paperIndex],
    );
    await Navigator.of(context).push(
      paperPanelRoute<void>(
        (_) => PaperPanel(
          color: panel,
          child: ArchiveSheet(
            controller: owner,
            canAccess: () => mounted && c == owner && !_accountLocked,
            record: selectedBook == null ? record : null,
            book: targetBook,
          ),
        ),
        color: panel,
      ),
    );
  }
}
