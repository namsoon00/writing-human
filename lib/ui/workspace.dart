import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/library_controller.dart';
import '../data/library_search.dart';
import '../data/model.dart';
import '../sync/coordinator.dart';
import '../source/source_intake.dart';
import '../source/originals.dart';
import '../source/source_platform.dart';
import 'source_import_sheet.dart';
import 'source_reading.dart';
import 'collection_sheet.dart';
import 'editor.dart';
import 'new_book_dialog.dart';
import 'paper.dart';
import 'paper_panel.dart';
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

typedef _SavedOriginal = ({
  String? bookId,
  RegisteredOriginal original,
  bool startTranscription,
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
  AudioPlayer? _pageAudio;
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
  String? draftBookId;
  bool _pageNavigationBusy = false;
  int _directPageChange = 0;
  bool _openingFromPanel = false;
  bool _editorComposing = false;
  String? _editingPageId;
  ({String pageId, int offset, int request})? _reveal;
  int _revealRequest = 0;
  ({String pageId, int request})? _firstPageView;
  int _firstPageRequest = 0;
  ({String pageId, String? bookId, RegisteredOriginal original})? _savedSource;
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
  MaterialPageRoute<void>? _activePanel;
  Future<void>? _sheetClosed;
  LibraryController? _sheetOwner;
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
    ).showSnackBar(const SnackBar(content: Text('입력을 마친 뒤 페이지를 넘겨 주세요.')));
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
        unawaited(_playPageSound());
      }
    } finally {
      if (mounted) setState(() => _pageNavigationBusy = false);
    }
  }

  Future<void> _playPageSound() async {
    try {
      final player = _pageAudio ??= AudioPlayer();
      await player.play(
        AssetSource('audio/page-turn.mp3'),
        volume: .42,
        ctx: AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.assistanceSonification,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
    } catch (error) {
      debugPrint('Page sound unavailable: $error');
    }
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
      await _newSheet(book.id);
    } else {
      await _openPage(first.id, startAtTop: true);
    }
  }

  Future<void> _resumeBook(Book book, {bool paperTurn = true}) async {
    if (!c.library.books.any((entry) => entry.id == book.id)) return;
    final target = c.resumePageForBook(book.id);
    if (target == null) {
      await _newSheet(book.id);
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
      _editingPageId = null;
      _originalByPage.clear();
      _originalByVolume.clear();
      _bookLeaf = null;
      _reveal = null;
      _firstPageView = null;
      fresh = c.library.pages.isEmpty;
      userFresh = false;
      draft = _blank();
      draftBookId = null;
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (fresh && !userFresh && c.library.activePage != null) fresh = false;
      if (_accountLocked) {
        _originalByPage.clear();
        _originalByVolume.clear();
      }
      if (_accountLocked || _leafBook == null) _bookLeaf = null;
      if (_accountLocked || _reveal?.pageId != page.id) _reveal = null;
      if (_accountLocked || _firstPageView?.pageId != page.id) {
        _firstPageView = null;
      }
      if (_accountLocked ||
          _savedSource?.pageId != page.id ||
          c.library.originalRemovals.any(
            (item) => item.originalId == _savedSource?.original.id,
          )) {
        _savedSource = null;
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
    WidgetsBinding.instance.removeObserver(this);
    _incomingEvents?.cancel();
    if (widget.sourceIntake == null) _intake.dispose();
    c.removeListener(_changed);
    widget.sync?.removeListener(_changed);
    editorFocus.dispose();
    final audio = _pageAudio;
    if (audio != null) unawaited(audio.dispose());
    super.dispose();
  }

  void _dismissWritingKeyboard() {
    if (!_editorComposing && !c.composing) _blur();
  }

  void _blur() {
    _editingPageId = null;
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: _editorComposing);
  }

  void _edit(String id, String text, int base, int extent, double scroll) {
    if (!c.library.pages.any((p) => p.id == id)) {
      if (text.isEmpty) return;
      final next = draft.edited(
        text: text,
        base: base,
        extent: extent,
        scroll: scroll,
      );
      // Same page ID/key on both sides of this first save: keep the live IME.
      fresh = false;
      c.saveDraft(next, bookId: draftBookId);
    } else {
      if (c.library.activePageId != id || !c.library.writing) c.openPage(id);
      c.editPage(id, text, base, extent, scroll);
    }
  }

  Future<void> _newSheet([String? bookId]) => _navigatePage(() async {
    setState(() {
      _bookLeaf = null;
      draft = _blank();
      draftBookId = bookId;
      fresh = true;
      userFresh = true;
    });
  }, paperTurn: false);

  Future<void> _openPanel(Widget child, {Color color = paper}) {
    final route = paperPanelRoute<void>((_) => child, color: color);
    _activePanel = route;
    _sheetClosed = route.completed.then((_) {});
    _sheetOwner = c;
    return Navigator.of(context).push<void>(route);
  }

  Future<void> _afterSheet(Future<void> Function() action) async {
    final closed = _sheetClosed;
    final owner = _sheetOwner;
    Navigator.pop(context);
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
      }
    } finally {
      _openingFromPanel = false;
    }
  }

  Future<void> _openFromCollection(Future<void> Function() open) =>
      _openPageFromPanel(_activePanel, _sheetOwner, open);

  void _collection() {
    if (!_canLeaveInput()) return;
    _blur();
    _openPanel(
      CollectionSheet(
        controller: c,
        onBook: (book) => _openFromCollection(
          () => _navigatePage(() async {
            if (c.library.books.any((entry) => entry.id == book.id)) {
              _showBookLeaf(book, _BookLeaf.frontCover);
            }
          }, paperTurn: false),
        ),
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
        onNewSheet: (bookId) {
          _openFromCollection(() => _newSheet(bookId));
        },
        onNewBook: () {
          _afterSheet(_createBook);
        },
        onContentsPage: (page) =>
            _openFromCollection(() => _openPage(page.id, paperTurn: false)),
        onBookOriginals: (book) => _showOriginals(bookDetails: book),
        onPassage: (passage) =>
            _openFromCollection(() => _openPassage(passage, paperTurn: false)),
        onArchiveBook: (book) =>
            _afterSheet(() => _archive(selectedBook: book)),
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
    }
  }

  void _menu() {
    _blur();
    _openPanel(
      ToolsScreen(
        controller: c,
        bookId: book?.id,
        onReadAloud: (context) {
          if (!_canLeaveInput()) return;
          showReadAloud(
            context,
            library: c.library,
            book: book,
            page: page,
            color: panelPaperColor(paperColors[_paperStyle(book).paperIndex]),
          );
        },
        onBind: () => _afterSheet(_bind),
        onArchive: () => _afterSheet(_archive),
        onSync: widget.sync?.available == true
            ? () => _afterSheet(() async => _syncInfo())
            : null,
      ),
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
    String? bookId,
    bool allowUnbound = true,
  }) async {
    final books = {for (final book in c.library.books) book.id: book.title};
    final targetBook = c.library.books
        .where((item) => item.id == bookId)
        .firstOrNull;
    final style = _paperStyle(targetBook);
    final sharedText = shared?.text.trim() ?? '';
    final link = Uri.tryParse(sharedText);
    final linkOnly =
        link != null &&
        (link.scheme == 'http' || link.scheme == 'https') &&
        link.host.isNotEmpty &&
        !RegExp(r'\s').hasMatch(sharedText);
    final route = MaterialPageRoute<SourceImportResult>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: paperColors[style.paperIndex],
        body: Center(
          child: SizedBox(
            width: writingSurfaceMaxWidth,
            child: SourceImportSheet(
              intake: _intake,
              initialText: linkOnly ? '' : sharedText,
              initialCitation: linkOnly ? sharedText : '',
              initialPhoto: initialPhoto,
              choice: style.bookDetails.sourceSlip,
              penColor: penColors[style.penIndex],
              paperColor: paperColors[style.paperIndex],
              grainOpacity: paperGrainOpacity[style.paperIndex],
              shared: shared != null,
              registration: shared == null,
              books: books,
              bookId: bookId,
              allowUnbound: allowUnbound,
              allowTranscription: shared == null,
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
  }) async {
    if (_sourceBusy || _accountLocked || !_canLeaveInput()) return null;
    final owner = c;
    _sourceBusy = true;
    try {
      await owner.settled;
      if (!mounted || c != owner || _accountLocked || owner.saveError != null) {
        return null;
      }
      final result = await _reviewOriginal(
        initialPhoto: initialPhoto,
        bookId: bookId,
        allowUnbound: selectedPage != null,
      );
      if (result == null ||
          !mounted ||
          c != owner ||
          _accountLocked ||
          owner.saveError != null ||
          owner.composing ||
          (selectedPage != null && page.id != selectedPage.id) ||
          (result.bookId != null &&
              !owner.library.books.any((book) => book.id == result.bookId))) {
        return null;
      }
      if (result.bookId == null && selectedPage != null && fresh) {
        fresh = false;
        userFresh = false;
      }
      final registered = owner.registerOriginal(
        bookId: result.bookId,
        page: selectedPage,
        text: result.text,
        citation: result.citation,
        photoId: result.photoId,
        isFullPage: result.isFullPage,
        writingRange: result.writingRange,
        photoLines: result.photoLines,
      );
      if (registered == null) {
        _sourceNotice('원문을 저장하지 못했어요. 다시 시도해 주세요.');
        return null;
      }
      await owner.settled;
      if (!mounted || c != owner || _accountLocked) return null;
      if (owner.saveError != null) {
        _sourceNotice('원문을 저장하지 못했어요. 다시 저장해 주세요.');
        return null;
      }
      return (
        bookId: result.bookId,
        original: registered,
        startTranscription: result.startTranscription,
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
      final result = await _reviewOriginal(shared: shared);
      if (result == null ||
          !mounted ||
          c != owner ||
          _accountLocked ||
          owner.saveError != null ||
          page.id != selectedPage.id ||
          owner.composing) {
        return;
      }
      if (_isShareRegistered(shared)) {
        await _pollSources();
        return;
      }
      if (result.bookId case final destination?) {
        if (!owner.library.books.any((book) => book.id == destination)) return;
        owner.registerOriginals(
          bookId: destination,
          passages: [result.text],
          citation: result.citation,
          deliveryId: id,
        );
      } else {
        fresh = false;
        userFresh = false;
        owner.registerOriginals(
          page: WritingPage(id: '$id-page', recordId: id, number: 1),
          passages: [result.text],
          citation: result.citation,
          deliveryId: id,
        );
      }
      await owner.settled;
      if (mounted && c == owner && !_accountLocked && owner.saveError == null) {
        unawaited(_pollSources(openAutomatically: false));
      }
    } finally {
      _sourceBusy = false;
    }
  }

  Future<void> _afterOriginalSave(
    WritingPage origin,
    _SavedOriginal saved, {
    bool fromContents = false,
  }) async {
    if (saved.startTranscription) {
      Future<void> start() =>
          _startTranscription(saved.original, saved.bookId, origin);
      if (fromContents) {
        await _afterSheet(start);
      } else {
        await start();
      }
      return;
    }
    if (page.id != origin.id) return;
    setState(
      () => _savedSource = (
        pageId: origin.id,
        bookId: saved.bookId,
        original: saved.original,
      ),
    );
  }

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
      final source =
          originalsFor(owner.library, bookId: bookId, recordId: origin.recordId)
              .where(
                (item) =>
                    item.id == original.id ||
                    (item.text == original.text &&
                        item.citation == original.citation &&
                        item.photoId == original.photoId),
              )
              .firstOrNull;
      if (source == null || source.text.trim().isEmpty) return;
      if ((page.text.isEmpty || page.guidedOriginalId == source.id) &&
          (bookId != null
              ? book?.id == bookId
              : page.recordId == origin.recordId)) {
        _bookLeaf = null;
        if (fresh) {
          fresh = false;
          userFresh = false;
          c.saveDraft(
            draft.withDetails(guidedOriginalId: source.id),
            bookId: bookId,
            keepBlank: true,
          );
        } else {
          c.guidePage(page.id, source.id);
        }
      } else if (bookId == null) {
        fresh = false;
        userFresh = false;
        _bookLeaf = null;
        c.addPage(recordId: origin.recordId, guidedOriginalId: source.id);
      } else {
        _bookLeaf = null;
        fresh = false;
        userFresh = false;
        c.saveDraft(
          _blank().withDetails(guidedOriginalId: source.id),
          bookId: bookId,
          keepBlank: true,
        );
      }
      target = page.id;
    }, paperTurn: false);
    if (target == null ||
        !mounted ||
        page.id != target ||
        c != owner ||
        _accountLocked ||
        c.saveError != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && c == owner && !_accountLocked && page.id == target) {
        editorFocus.requestFocus();
      }
    });
  }

  Future<void> _showOriginals({Book? bookDetails}) async {
    if (_readingSource || _sourceBusy || _accountLocked || !_canLeaveInput()) {
      return;
    }
    final owner = c;
    final selectedPage = page;
    final selectedBook = bookDetails ?? book;
    final bookId = selectedBook?.id;
    // Web accessibility can move focus to the button before its handler.
    final wasEditing =
        bookDetails == null &&
        (editorFocus.hasFocus || _editingPageId == selectedPage.id);
    _blur();
    _readingSource = true;
    List<RegisteredOriginal> originals() => originalsFor(
      owner.library,
      bookId: bookId,
      recordId: selectedPage.recordId,
    );
    Future<_SavedOriginal?> register() => _registerOriginal(
      bookId: bookId,
      selectedPage: bookDetails == null ? selectedPage : null,
    );

    try {
      final available = originals();
      if (bookDetails == null && available.isEmpty) {
        final saved = await register();
        if (saved != null) {
          await _afterOriginalSave(selectedPage, saved);
          if (saved.startTranscription) return;
        }
      } else {
        final match = bookDetails == null
            ? matchOriginal(available, selectedPage.text, selectedPage.extent)
            : null;
        final scope = (
          bookId: bookId,
          recordId: bookId == null ? selectedPage.recordId : null,
        );
        String? availableId(String? id) =>
            available.any((item) => item.id == id) ? id : null;
        final pageChoice = bookDetails == null
            ? _originalByPage[selectedPage.id]
            : null;
        final guided = bookDetails == null
            ? selectedPage.guidedOriginalId
            : null;
        final initialId =
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
              onRegister: owner.saveError != null
                  ? null
                  : () async {
                      final saved = await register();
                      if (saved == null) return null;
                      if (saved.bookId != bookId || saved.startTranscription) {
                        if (context.mounted &&
                            ModalRoute.of(context)?.isCurrent == true) {
                          savedAfterPanel = saved;
                          Navigator.of(context).pop();
                        }
                        return null;
                      }
                      return saved.original;
                    },
              writingLocations: originalWritingLocations(
                originals(),
                owner.library.volumePages(
                  bookId: bookId,
                  recordId: selectedPage.recordId,
                ),
              ),
              onTranscribe: owner.saveError == null
                  ? (original) => Navigator.of(context).pop(original)
                  : null,
              onOpenWriting: (passage) =>
                  _openPageFromPanel(route, owner, () async {
                    await _openPassage(passage, paperTurn: false);
                    openedWriting = true;
                  }),
              onRetry: owner.saveError == null ? null : _retrySave,
              onSaveRange: (original, range) async {
                if (!mounted ||
                    c != owner ||
                    _accountLocked ||
                    owner.composing) {
                  return false;
                }
                final latest = originals()
                    .where((item) => item.id == original.id)
                    .firstOrNull;
                if (latest == null || latest.text != original.text) {
                  return false;
                }
                return owner.saveOriginalRange(
                  bookId: bookId,
                  recordId: selectedPage.recordId,
                  original: latest,
                  range: range,
                );
              },
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
          color: panelPaperColor(
            paperColors[_paperStyle(selectedBook).paperIndex],
          ),
        );
        final action = await Navigator.of(context).push(route);
        await route.completed;
        if (savedAfterPanel case final saved?) {
          if (mounted && c == owner && !_accountLocked) {
            await _afterOriginalSave(
              selectedPage,
              saved,
              fromContents: bookDetails != null,
            );
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
      }
      if (wasEditing &&
          mounted &&
          c == owner &&
          !_accountLocked &&
          selectedPage.id == page.id) {
        final editable = editorFocus.context
            ?.findAncestorStateOfType<EditableTextState>();
        if (editable == null) {
          editorFocus.requestFocus();
        } else {
          editable.requestKeyboard();
        }
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

  Future<void> _bind() async {
    _blur();
    final selectedRecord = record;
    userFresh = fresh;
    final route = paperPanelRoute<String>(
      (context) => PaperPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              PaperPanelHeader(book == null ? '책에 넣기' : '다른 책으로 옮기기'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    for (final b in c.library.books.where(
                      (b) => b.id != book?.id,
                    ))
                      ListTile(
                        leading: BookCover(
                          title: '',
                          width: 29,
                          variant: c.coverIndexFor(b),
                          details: c.detailsFor(b),
                        ),
                        title: Text(b.title),
                        onTap: () => Navigator.pop(context, b.id),
                      ),
                    ListTile(
                      leading: const Icon(CupertinoIcons.plus, size: 18),
                      title: const Text('새 책 만들기'),
                      onTap: () => Navigator.pop(context, 'new'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    String? id = await Navigator.of(context).push(route);
    await route.completed;
    if (id == null || !mounted) return;
    if (id == 'new') {
      final values = await showDialog<(String, String)>(
        context: context,
        builder: (_) => const NewBookDialog(),
      );
      if (values == null || !mounted) return;
      id = c.addBook(values.$1, values.$2).id;
    }
    if (selectedRecord != null) {
      c.bindRecord(selectedRecord.id, id);
    } else {
      setState(() => draftBookId = id);
    }
  }

  Future<void> _pages() async {
    if (_pageNavigationBusy || !_canLeaveInput()) return;
    _blur();
    final owner = c;
    late final MaterialPageRoute<void> route;
    route = paperPanelRoute<void>(
      (_) => AnimatedBuilder(
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
          return PaperPanel(
            color: panelPaperColor(paperColors[style.paperIndex]),
            child: PagesSheet(
              pages: pages,
              currentId: page.id,
              style: style,
              coverTitle: book?.title,
              coverVariant: _coverVariant,
              onChoose: (choice) => _openPageFromPanel(route, owner, () async {
                if (choice.append) {
                  await _appendPage(paperTurn: false);
                } else if (choice.cover) {
                  await _openCover(back: choice.backCover, paperTurn: false);
                } else if (choice.pageId case final id?) {
                  await _openPage(id, paperTurn: false);
                }
              }),
              canTrash: (page) => (pageCounts[page.recordId] ?? 0) > 1,
              onTrash: (target) async {
                if (!mounted ||
                    c != owner ||
                    _accountLocked ||
                    !_canLeaveInput()) {
                  return false;
                }
                final previous = page.id;
                final saved = await owner.trashPage(target);
                if (saved && mounted && c == owner && page.id != previous) {
                  setState(() => _directPageChange++);
                }
                return saved;
              },
            ),
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
    final canSwipe = navigationEnabled && !editorFocus.hasFocus;
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
    final showKeyboardDismiss =
        !preview && (keyboardInset > 0 || (mobileWeb && editorFocus.hasFocus));
    final originals = preview
        ? const <RegisteredOriginal>[]
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
                bookTitle: book?.title,
                loosePage: book == null && record != null,
                onCollection: _collection,
                onNewSheet: book == null
                    ? () => _newSheet()
                    : () => _appendPage(addAfterDraft: false),
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
              if ((preview ? null : _savedSource) case final saved?)
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: navigationEnabled && c.saveError == null
                              ? () {
                                  if (!_canLeaveInput()) return;
                                  setState(() => _savedSource = null);
                                  unawaited(
                                    _startTranscription(
                                      saved.original,
                                      saved.bookId,
                                      currentPage,
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('이 구절 필사하기'),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '필사 안내 닫기',
                      onPressed: () => setState(() => _savedSource = null),
                      icon: const Icon(CupertinoIcons.xmark, size: 16),
                    ),
                  ],
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
                      const Expanded(
                        child: Text(
                          '저장 실패 · 앱을 닫지 말아 주세요.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: _retrySave,
                        child: const Text(
                          '저장 재시도',
                          style: TextStyle(fontSize: 11),
                        ),
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
              Expanded(
                key: const ValueKey('writing-surface'),
                child: preview
                    ? PageReadPreview(
                        key: ValueKey((currentPage.id, previewFromTop)),
                        page: currentPage,
                        fromTop: previewFromTop,
                        style: style,
                      )
                    : PageEditor(
                        key: ValueKey('${currentPage.id}:${c.editorEpoch}'),
                        page: currentPage,
                        style: style,
                        focusNode: editorFocus,
                        originals: originals,
                        guidedOriginal: originals
                            .where(
                              (item) => item.id == currentPage.guidedOriginalId,
                            )
                            .firstOrNull,
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
                        onEraseHighlight: c.erasePencilMark,
                        onHighlight: c.addPencilMark,
                        onEditingState: (focused, composing) {
                          if (focused) _editingPageId = currentPage.id;
                          _editorComposing = composing;
                          c.setEditorState(
                            focused: focused,
                            isComposing: composing,
                          );
                        },
                      ),
              ),
              Transform.translate(
                offset: Offset(0, preview ? 0 : -keyboardOverlap),
                child: WritingFooter(
                  ornament: style.bookDetails.ornament,
                  onMenu: _menu,
                  showKeyboardDismiss: showKeyboardDismiss,
                  onKeyboardDismiss: _editorComposing || c.composing
                      ? null
                      : _dismissWritingKeyboard,
                  onSource: navigationEnabled ? _showOriginals : null,
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
    await _openPanel(
      PaperPanel(
        color: panel,
        child: ArchiveSheet(
          controller: owner,
          canAccess: () => mounted && c == owner && !_accountLocked,
          record: selectedBook == null ? record : null,
          book: targetBook,
        ),
      ),
      color: panel,
    );
  }
}
