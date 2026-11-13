import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
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
import 'tools_screen.dart';
import 'writing_chrome.dart';
import 'page_turn.dart';
import 'paper_swipe.dart';
import 'pages_sheet.dart';
import 'book_details.dart';
import 'book_front_cover.dart';
import 'page_read_preview.dart';
import 'archive_sheet.dart';

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
  final reflectionFocus = FocusNode();
  final _pageTurn = PageTurnController();
  AudioPlayer? _pageAudio;
  String? _coverAnchor;
  bool _coverAtBack = false;
  bool get _showCover => _coverAnchor == page.id;
  int get _coverSide => _showCover ? (_coverAtBack ? 1 : -1) : 0;
  late WritingPage draft = _blank();
  late bool fresh = c.library.pages.isEmpty;
  bool userFresh = false;
  String? draftBookId;
  bool _pageNavigationBusy = false;
  bool _editorComposing = false;
  String? _editingPageId;
  ({String pageId, int offset, int request})? _reveal;
  int _revealRequest = 0;
  late final SourceIntake _intake = widget.sourceIntake ?? createSourceIntake();
  StreamSubscription<void>? _incomingEvents;
  IncomingSource? _incoming;
  SourcePhoto? _recoveredPhoto;
  final _shownShares = <String>{};
  bool _readingSource = false;
  bool _sourceBusy = false, _pollingSources = false, _pollAgain = false;
  bool _checkedPhotoRecovery = false;
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
    final wasCover = _coverSide;
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
      await owner.settled;
      if (paperTurn &&
          mounted &&
          c == owner &&
          !_accountLocked &&
          owner.saveError == null &&
          c.library.style.pageSound &&
          (page.id != origin || wasCover != _coverSide)) {
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

  Future<void> _openPage(String id) => _navigatePage(() async {
    if (page.id == id && _showCover) {
      setState(() => _coverAnchor = null);
      return;
    }
    if (!c.library.pages.any((p) => p.id == id) || page.id == id) return;
    _coverAnchor = null;
    fresh = false;
    userFresh = false;
    c.openPage(id);
  });

  Future<void> _openPassage(Passage passage) => _navigatePage(() async {
    final id = passage.page.id;
    final target = c.library.pages.where((p) => p.id == id).firstOrNull;
    if (target == null) return;
    final offset = passage.offset;
    setState(() {
      _coverAnchor = null;
      fresh = false;
      userFresh = false;
      _reveal = offset != null && target.text == passage.page.text
          ? (pageId: id, offset: offset, request: ++_revealRequest)
          : null;
    });
    if (c.library.activePageId != id) c.openPage(id);
  });

  Future<void> _openCover({bool back = false}) => _navigatePage(() async {
    final target = back ? _volumePages.last : _volumePages.first;
    if (target.id != page.id) c.openPage(target.id);
    setState(() {
      _coverAnchor = target.id;
      _coverAtBack = back;
    });
  });

  Future<void> _stepPage(int step) async {
    if (_showCover) {
      if ((_coverAtBack && step < 0) || (!_coverAtBack && step > 0)) {
        await _openPage(page.id);
      }
      return;
    }
    final pages = _volumePages;
    final index = pages.indexWhere((p) => p.id == page.id);
    if (index < 0) return;
    final target = index + step;
    if (target < 0) {
      await _openCover();
    } else if (target >= pages.length) {
      if (fresh) {
        await _appendPage();
      } else {
        await _openCover(back: true);
      }
    } else {
      await _openPage(pages[target].id);
    }
  }

  Future<bool> _commitTurn(bool forward) async {
    final owner = c, id = page.id, wasCover = _coverSide;
    await _stepPage(forward ? 1 : -1);
    return mounted && c == owner && (page.id != id || wasCover != _coverSide);
  }

  Future<void> _appendPage() => _navigatePage(() async {
    if (fresh) {
      // Explicitly adding a page is intent to keep blank pages as well.
      fresh = false;
      userFresh = false;
      c.saveDraft(draft, bookId: draftBookId, keepBlank: true);
      await c.settled;
      if (!mounted || c.saveError != null) return;
    }
    _coverAnchor = null;
    c.addPage();
  });
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
      reflectionFocus.unfocus();
      _editingPageId = null;
      _coverAnchor = null;
      _reveal = null;
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
      if (_accountLocked || !_showCover) _coverAnchor = null;
      if (_accountLocked || _reveal?.pageId != page.id) _reveal = null;
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
    reflectionFocus.dispose();
    final audio = _pageAudio;
    if (audio != null) unawaited(audio.dispose());
    super.dispose();
  }

  void _blur() {
    _editingPageId = null;
    editorFocus.unfocus();
    reflectionFocus.unfocus();
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
      _coverAnchor = null;
      draft = _blank();
      draftBookId = bookId;
      fresh = true;
      userFresh = true;
    });
  }, paperTurn: false);

  Future<void> _sheet(
    Widget child, {
    bool enableDrag = true,
    bool? showDragHandle,
    Color? backgroundColor,
  }) {
    final route = ModalBottomSheetRoute<void>(
      isScrollControlled: true,
      showDragHandle: showDragHandle ?? enableDrag,
      backgroundColor: backgroundColor,
      clipBehavior: Clip.antiAlias,
      enableDrag: enableDrag,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => child,
    );
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

  void _collection() {
    if (!_canLeaveInput()) return;
    _blur();
    _sheet(
      CollectionSheet(
        controller: c,
        showHandle: true,
        onBook: (book) => _afterSheet(() async {
          if (!c.library.books.any((entry) => entry.id == book.id)) return;
          final target = c.resumePageForBook(book.id);
          if (target == null) {
            await _newSheet(book.id);
          } else {
            await _openPage(target.id);
          }
        }),
        onRecord: (r) {
          final pages = c.library.pages.where((p) => p.recordId == r.id);
          if (pages.isEmpty) return;
          final id =
              pages
                  .where((p) => p.id == c.library.activePageId)
                  .firstOrNull
                  ?.id ??
              pages.last.id;
          _afterSheet(() => _openPage(id));
        },
        onNewSheet: (bookId) {
          _afterSheet(() => _newSheet(bookId));
        },
        onNewBook: () {
          _afterSheet(_createBook);
        },
        onContentsPage: (page) => _afterSheet(() => _openPage(page.id)),
        onBookOriginals: (book) => _showOriginals(bookDetails: book),
        onPassage: (passage) => _afterSheet(() => _openPassage(passage)),
        onArchiveBook: (book) =>
            _afterSheet(() => _archive(selectedBook: book)),
      ),
      showDragHandle: false,
      backgroundColor: Colors.transparent,
    );
  }

  Future<void> _createBook() async {
    _blur();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const NewBookDialog(),
    );
    if (values != null && mounted) {
      _coverAnchor = null;
      fresh = false;
      userFresh = false;
      c.createBook(values.$1, values.$2);
    }
  }

  void _tools() {
    if (_editorComposing && reflectionFocus.hasFocus) return;
    _blur();
    _sheet(
      ToolsScreen(
        controller: c,
        bookId: book?.id,
        onBack: () => Navigator.pop(context),
      ),
      showDragHandle: false,
      backgroundColor: Colors.transparent,
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
    final route = ModalBottomSheetRoute<SourceImportResult>(
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: paperColors[style.paperIndex],
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => _insertedPage(
        SourceImportSheet(
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
        ),
        forBook: targetBook,
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    return result;
  }

  Future<void> _registerOriginal({
    String? bookId,
    WritingPage? selectedPage,
    SourcePhoto? initialPhoto,
  }) async {
    if (_sourceBusy || _accountLocked || !_canLeaveInput()) return;
    final owner = c;
    _sourceBusy = true;
    try {
      await owner.settled;
      if (!mounted || c != owner || _accountLocked || owner.saveError != null) {
        return;
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
        return;
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
      if (!registered) {
        _sourceNotice('원문을 저장하지 못했어요. 다시 시도해 주세요.');
        return;
      }
      await owner.settled;
      if (mounted && c == owner && !_accountLocked && owner.saveError != null) {
        _sourceNotice('원문을 저장하지 못했어요. 다시 저장해 주세요.');
      }
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
      await _registerOriginal(
        bookId: book?.id,
        selectedPage: selectedPage,
        initialPhoto: initialPhoto,
      );
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
        final text = result.text;
        owner.saveDraft(
          WritingPage(id: '$id-page', recordId: id, number: 1),
          source: result.citation.isEmpty ? text : '',
          originals: [
            if (result.citation.isNotEmpty)
              RegisteredOriginal(id, text, citation: result.citation),
          ],
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

  Future<void> _showOriginals({Book? bookDetails}) async {
    if (_readingSource || _sourceBusy || _accountLocked || !_canLeaveInput()) {
      return;
    }
    final owner = c;
    final selectedPage = page;
    final selectedBook = bookDetails ?? book;
    final bookId = selectedBook?.id;
    final volume = bookId == null
        ? _volumePages
        : owner.library.volumePages(bookId: bookId);
    final position = bookDetails == null
        ? volume.indexWhere((p) => p.id == selectedPage.id)
        : -1;
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
    Future<void> register() => _registerOriginal(
      bookId: bookId,
      selectedPage: bookDetails == null ? selectedPage : null,
    );

    try {
      final available = originals();
      if (bookDetails == null && available.isEmpty) {
        await register();
      } else {
        final initial = bookDetails == null
            ? matchOriginal(available, selectedPage.text, selectedPage.extent)
            : null;
        final route = ModalBottomSheetRoute<void>(
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: referencePaperColor(
            paperColors[_paperStyle(selectedBook).paperIndex],
          ),
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          constraints: const BoxConstraints(maxWidth: 600),
          builder: (_) => ListenableBuilder(
            listenable: owner,
            builder: (context, _) => SourceReading(
              originals: originals(),
              match: initial,
              style: _paperStyle(selectedBook),
              coverIndex: selectedBook == null
                  ? null
                  : owner.coverIndexFor(selectedBook),
              pagesBefore: position < 0 ? 0 : position,
              pagesAfter: volume.length - position - 1,
              onRegister: owner.saveError == null ? register : null,
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
              onSaveReflection: (original, reflection) => owner.composing
                  ? Future.value(false)
                  : _saveReflection(
                      owner,
                      bookId,
                      selectedPage.recordId,
                      original,
                      reflection,
                    ),
            ),
          ),
        );
        await Navigator.of(context).push(route);
        await route.completed;
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
    String? id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '책으로 묶기',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
              for (final b in c.library.books)
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
      ),
    );
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
    final selectedId = page.id;
    final owner = c;
    final route = ModalBottomSheetRoute<PageChoice>(
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: paperColors[_paperStyle(book).paperIndex],
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) {
        final pages = _volumePages;
        return _insertedPage(
          PagesSheet(
            pages: pages,
            currentId: selectedId,
            style: _paperStyle(book),
            coverTitle: book?.title ?? record?.title ?? '나의 필사',
            coverVariant: _coverVariant,
          ),
          forBook: book,
          pageCount: pages.length,
        );
      },
    );
    final choice = await Navigator.of(context).push<PageChoice>(route);
    // Let the overview finish closing so the actual paper turn is visible.
    await route.completed;
    if (!mounted ||
        c != owner ||
        _accountLocked ||
        choice == null ||
        page.id != selectedId) {
      return;
    }
    if (choice.append) {
      await _appendPage();
    } else if (choice.cover) {
      await _openCover(back: choice.backCover);
    } else if (choice.pageId != null) {
      await _openPage(choice.pageId!);
    }
  }

  Widget _insertedPage(
    Widget child, {
    Book? forBook,
    int pageCount = 0,
    bool shrinkWrap = false,
  }) {
    final style = _paperStyle(forBook);
    return PaperBackdrop(
      color: paperColors[style.paperIndex],
      grainOpacity: paperGrainOpacity[style.paperIndex],
      binding: style.bookDetails.binding,
      coverIndex: forBook == null ? null : c.coverIndexFor(forBook),
      pagesAfter: pageCount,
      shrinkWrap: shrinkWrap,
      child: child,
    );
  }

  void _more() {
    if (_editorComposing && reflectionFocus.hasFocus) return;
    _blur();
    _sheet(
      _insertedPage(
        SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PaperSheetHandle(),
                  ListTile(
                    leading: const Icon(CupertinoIcons.book, size: 20),
                    title: const Text('책으로 묶기'),
                    subtitle: book == null ? null : Text(book!.title),
                    onTap: () {
                      Navigator.pop(context);
                      _bind();
                    },
                  ),
                  if (record != null)
                    ListTile(
                      leading: const Icon(CupertinoIcons.doc_on_doc, size: 20),
                      title: const Text('페이지'),
                      onTap: () {
                        _afterSheet(_pages);
                      },
                    ),
                  if (page.writtenOn != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            '기록 시작',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          DateStamp(
                            date: page.writtenOn!,
                            choice: c.detailsFor(book).dateStamp,
                          ),
                        ],
                      ),
                    ),
                  ListTile(
                    leading: const Icon(CupertinoIcons.archivebox, size: 20),
                    title: const Text('기록 보관'),
                    onTap: () => _afterSheet(_archive),
                  ),
                  ListTile(
                    leading: const Icon(CupertinoIcons.cloud, size: 20),
                    title: const Text('기기 동기화'),
                    onTap: () => _afterSheet(() async => _syncInfo()),
                  ),
                ],
              ),
            ),
          ),
        ),
        forBook: book,
        pageCount: _volumePages.length,
        shrinkWrap: true,
      ),
      showDragHandle: false,
      backgroundColor: paperColors[_paperStyle(book).paperIndex],
    );
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
    final showingCover = _showCover;
    final navigationEnabled =
        !_pageNavigationBusy &&
        !_editorComposing &&
        !c.composing &&
        c.saveError == null;
    final canSwipe =
        navigationEnabled && !editorFocus.hasFocus && !reflectionFocus.hasFocus;
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
    Widget cover({bool back = false}) => BookFrontCover(
      title: book?.title ?? record?.title ?? '나의 필사',
      author: book?.author ?? '',
      variant: _coverVariant,
      style: _paperStyle(book),
      pageCount: pages.length,
      back: back,
      onOpen: () => _stepPage(back ? -1 : 1),
      onAppend: back ? _appendPage : null,
      onCollection: _collection,
    );
    final nextPage = index + 1 < pages.length
        ? pages[index + 1]
        : WritingPage(
            id: 'preview-next:${current.id}',
            recordId: current.recordId,
            number: current.number + 1,
          );
    return Scaffold(
      backgroundColor: appPaper,
      resizeToAvoidBottomInset: false,
      body: PageTurnView(
        key: ValueKey((c, c.editorEpoch)),
        controller: _pageTurn,
        page: current,
        style: _paperStyle(book),
        scopeId: book?.id ?? current.recordId,
        position: showingCover ? (_coverAtBack ? pages.length : -1) : index,
        isCover: showingCover,
        isBackCover: showingCover && _coverAtBack,
        coverSurface: showingCover ? cover(back: _coverAtBack) : null,
        previousIsCover: !showingCover && index == 0,
        nextIsCover: !showingCover && !fresh && index == pages.length - 1,
        editing: c.editorFocused,
        composing: _editorComposing || c.composing,
        onTurn: _commitTurn,
        previous: showingCover
            ? (_coverAtBack ? paper(current, index) : null)
            : index == 0
            ? cover()
            : paper(pages[index - 1], index - 1),
        next: showingCover
            ? (_coverAtBack ? null : paper(current, index))
            : !fresh && index == pages.length - 1
            ? cover(back: true)
            : paper(nextPage, index + 1),
        child: PaperSwipe(
          key: const ValueKey('paper-swipe'),
          touchOnly: !showingCover,
          onPrevious: canSwipe && (!showingCover || _coverAtBack)
              ? () => _stepPage(-1)
              : null,
          onNext: canSwipe && (!showingCover || !_coverAtBack)
              ? () => _stepPage(1)
              : null,
          onTurnOrigin: (origin) => _pageTurn.start(origin: origin),
          onTurnUpdate: _pageTurn.update,
          onTurnEnd: _pageTurn.end,
          onTurnCancel: _pageTurn.cancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: showingCover,
                child: paper(current, index, preview: false),
              ),
              if (showingCover) cover(back: _coverAtBack),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paperSurface(
    WritingPage currentPage,
    int index,
    int count,
    bool compact, {
    required bool preview,
    required bool navigationEnabled,
  }) {
    final record = c.library.records
        .where((r) => r.id == currentPage.recordId)
        .firstOrNull;
    final bookId = record?.bookId ?? (fresh ? draftBookId : null);
    final book = c.library.books.where((b) => b.id == bookId).firstOrNull;
    final style = _paperStyle(book);
    final safePadding = MediaQuery.paddingOf(context);
    final sideInset = math.max(safePadding.left, safePadding.right);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOverlap = math.max(
      0.0,
      keyboardInset - MediaQuery.viewPaddingOf(context).bottom,
    );
    final originals = preview
        ? const <RegisteredOriginal>[]
        : originalsFor(
            c.library,
            bookId: bookId,
            recordId: currentPage.recordId,
          );
    final owner = c;
    return PaperBackdrop(
      binding: style.bookDetails.binding,
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
                bookmarked: record != null,
                useDevelopmentTypeface: c.library.style.useDevelopmentTypeface,
                compact: compact,
                bookTitle: book?.title,
                onCollection: _collection,
                onNewSheet: () => _newSheet(),
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
                        key: ValueKey(currentPage.id),
                        page: currentPage,
                        style: style,
                      )
                    : PageEditor(
                        key: ValueKey('${currentPage.id}:${c.editorEpoch}'),
                        page: currentPage,
                        style: style,
                        focusNode: editorFocus,
                        originals: originals,
                        keyboardOverlap: keyboardOverlap,
                        reflectionFocus: reflectionFocus,
                        onSaveReflection: (original, reflection) =>
                            _saveReflection(
                              owner,
                              bookId,
                              currentPage.recordId,
                              original,
                              reflection,
                            ),
                        reveal: _reveal?.pageId == currentPage.id
                            ? (
                                offset: _reveal!.offset,
                                request: _reveal!.request,
                              )
                            : null,
                        onChanged: _edit,
                        onPencilMark: c.togglePencilMark,
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
                  onTools: _tools,
                  onSource: navigationEnabled ? _showOriginals : null,
                  onMore: _more,
                  failed: c.saveError != null,
                  pageLabel: '${index + 1}',
                  pageCount: count,
                  onPages: navigationEnabled ? _pages : null,
                  onPrevious: navigationEnabled ? () => _stepPage(-1) : null,
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
  }

  void _syncInfo() {
    if (widget.sync == null || !widget.sync!.available) {
      _archive();
      return;
    }
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: false);
    final sync = widget.sync!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: appPaper,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: sync,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 6, 28, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.cloud, size: 23),
                    SizedBox(width: 12),
                    Text(
                      '다른 기기에서 이어 쓰기',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  sync.message,
                  style: const TextStyle(fontSize: 14, height: 1.8, color: ink),
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
                      backgroundColor: burgundy,
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
    );
  }

  Future<void> _archive({Book? selectedBook}) async {
    if (_accountLocked || !_canLeaveInput()) return;
    _blur();
    final owner = c;
    final targetBook = selectedBook ?? book;
    await _sheet(
      _insertedPage(
        ArchiveSheet(
          controller: owner,
          canAccess: () => mounted && c == owner && !_accountLocked,
          record: selectedBook == null ? record : null,
          book: targetBook,
        ),
        forBook: targetBook,
        pageCount: targetBook == null
            ? 0
            : c.library.volumePages(bookId: targetBook.id).length,
      ),
      enableDrag: false,
    );
  }
}
