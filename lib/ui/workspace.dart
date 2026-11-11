import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/library_controller.dart';
import '../data/library_search.dart';
import '../data/model.dart';
import '../sync/coordinator.dart';
import '../source/source_intake.dart';
import '../source/source_platform.dart';
import 'source_import_sheet.dart';
import 'source_reading.dart';
import 'transcription_guide.dart';
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
  final _pageTurn = PageTurnController();
  AudioPlayer? _pageAudio;
  String? _coverAnchor;
  bool _coverAtBack = false;
  bool get _showCover => _coverAnchor == page.id;
  int get _coverSide => _showCover ? (_coverAtBack ? 1 : -1) : 0;
  late WritingPage draft = _blank();
  late bool fresh = c.library.pages.isEmpty;
  bool userFresh = false;
  String draftSource = '';
  String? draftBookId;
  bool _pageNavigationBusy = false;
  bool _editorComposing = false;
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
  ({
    String pageId,
    String? entryId,
    String source,
    int paragraphIndex,
    TranscriptionGuide passage,
    bool visible,
  })?
  _guide;
  Future<void>? _sheetClosed;
  LibraryController? _sheetOwner;
  bool get _accountLocked =>
      (widget.sync?.accountMismatch ?? false) ||
      (widget.sync?.signInRequired == true && c.library.sync.accountId != null);

  List<WritingPage> get _volumePages {
    final current = page;
    if (fresh) return [current];
    final bookId = book?.id;
    final recordIds = bookId == null
        ? [current.recordId]
        : c.library.records.where((r) => r.bookId == bookId).map((r) => r.id);
    final byRecord = {for (final id in recordIds) id: <WritingPage>[]};
    for (final page in c.library.pages) {
      byRecord[page.recordId]?.add(page);
    }
    final pages = [
      for (final group in byRecord.values)
        ...(group..sort((a, b) => a.number.compareTo(b.number))),
    ];
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
      c.saveDraft(
        draft,
        source: draftSource,
        bookId: draftBookId,
        keepBlank: true,
      );
      await c.settled;
      if (!mounted || c.saveError != null) return;
    }
    _coverAnchor = null;
    final recordPages =
        c.library.pages.where((item) => item.recordId == page.recordId).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    c.addPage(continuation: _continuation(recordPages.lastOrNull ?? page));
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

  WritingStyle _paperStyle(Book? book) {
    final style = c.library.style;
    final index = book?.paperIndex;
    return index == null || index == style.paperIndex
        ? style
        : style.copy(paperIndex: index);
  }

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
      _coverAnchor = null;
      _reveal = null;
      fresh = c.library.pages.isEmpty;
      userFresh = false;
      draft = _blank();
      draftSource = '';
      draftBookId = null;
      _guide = null;
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (fresh && !userFresh && c.library.activePage != null) fresh = false;
      if (_accountLocked || !_showCover) _coverAnchor = null;
      if (_accountLocked || _reveal?.pageId != page.id) _reveal = null;
      if (_accountLocked || _guide?.pageId != page.id) {
        _guide = null;
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

  void _blur() {
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: _editorComposing);
  }

  void _edit(String id, String text, int base, int extent, double scroll) {
    if (!c.library.pages.any((p) => p.id == id)) {
      if (text.isEmpty && draftSource.isEmpty) return;
      final next = draft.edited(
        text: text,
        base: base,
        extent: extent,
        scroll: scroll,
      );
      // Same page ID/key on both sides of this first save: keep the live IME.
      fresh = false;
      c.saveDraft(next, source: draftSource, bookId: draftBookId);
    } else {
      if (c.library.activePageId != id || !c.library.writing) c.openPage(id);
      c.editPage(id, text, base, extent, scroll);
    }
  }

  Future<void> _newSheet([String? bookId]) => _navigatePage(() async {
    setState(() {
      _coverAnchor = null;
      draft = _blank();
      draftSource = '';
      draftBookId = bookId;
      fresh = true;
      userFresh = true;
    });
  }, paperTurn: false);

  Future<void> _sheet(Widget child, {bool enableDrag = true}) {
    final route = ModalBottomSheetRoute<void>(
      isScrollControlled: true,
      showDragHandle: enableDrag,
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
        onPassage: (passage) => _afterSheet(() => _openPassage(passage)),
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
      _coverAnchor = null;
      fresh = false;
      userFresh = false;
      c.createBook(values.$1, values.$2);
    }
  }

  void _tools() {
    _blur();
    _sheet(
      ToolsScreen(
        controller: c,
        bookId: book?.id,
        onBack: () => Navigator.pop(context),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _pollSources();
  }

  String _sharedRecordId(IncomingSource share) => 'shared-source-${share.id}';

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
        final imported = c.library.records.any(
          (r) => r.id == _sharedRecordId(share),
        );
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
    final owner = c, selectedPage = page, selectedRecord = record;
    final initial = shared?.text ?? selectedRecord?.source ?? draftSource;
    final choice = c.library.style.bookDetails.sourceSlip;
    _blur();
    _sourceBusy = true;
    try {
      await owner.settled;
      if (!mounted ||
          c != owner ||
          page.id != selectedPage.id ||
          _accountLocked ||
          owner.saveError != null ||
          owner.composing ||
          editorFocus.hasFocus) {
        return;
      }
      if (shared != null &&
          owner.library.records.any((r) => r.id == _sharedRecordId(shared))) {
        await _pollSources();
        return;
      }
      final route = ModalBottomSheetRoute<SourceImportResult>(
        isScrollControlled: true,
        showDragHandle: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        constraints: const BoxConstraints(maxWidth: 600),
        builder: (_) => SourceImportSheet(
          intake: _intake,
          initialText: initial,
          initialPhoto: initialPhoto,
          choice: choice,
          shared: shared != null,
        ),
      );
      final result = await Navigator.of(context).push(route);
      await route.completed;
      if (result == null || !mounted || c != owner || _accountLocked) return;
      final source = result.source;
      if (page.id != selectedPage.id || owner.composing) {
        _sourceNotice('작성 중인 쪽이 바뀌었어요. 원문을 다시 확인해 주세요.');
        return;
      }
      if (owner.saveError != null) return;
      final destination = shared == null
          ? selectedPage.id
          : '${_sharedRecordId(shared)}-page';
      if (shared != null) {
        final id = _sharedRecordId(shared);
        fresh = false;
        userFresh = false;
        owner.saveDraft(
          WritingPage(id: '$id-page', recordId: id, number: 1),
          source: source,
        );
      } else if (selectedRecord != null) {
        owner.setSource(selectedRecord.id, source);
      } else if (source.isNotEmpty) {
        fresh = false;
        userFresh = false;
        owner.saveDraft(selectedPage, source: source, bookId: draftBookId);
      }
      await owner.settled;
      if (!mounted || c != owner || _accountLocked || owner.saveError != null) {
        return;
      }
      if (shared != null) unawaited(_pollSources(openAutomatically: false));
      if (result.follow &&
          page.id == destination &&
          record?.source == source &&
          !owner.composing) {
        final index = record?.sourceParagraph ?? 0;
        setState(() {
          _guide = (
            pageId: destination,
            entryId: null,
            source: source,
            paragraphIndex: index,
            passage: TranscriptionGuide(
              paragraph: sourceFromParagraph(source, index),
              initialText: page.text,
            ),
            visible: true,
          );
        });
        editorFocus.requestFocus();
      }
    } finally {
      _sourceBusy = false;
    }
  }

  String _passageSource(String source, int paragraph, PagePassage? entry) {
    final text = sourceFromParagraph(source, paragraph).trimLeft();
    return text.substring((entry?.sourceOffset ?? 0).clamp(0, text.length));
  }

  TranscriptionGuide _resumeGuide(
    WritingPage page,
    String source,
    PagePassage? entry,
  ) {
    if (entry == null) {
      return TranscriptionGuide.resume(paragraph: source, text: page.text);
    }
    return TranscriptionGuide(
      paragraph: source,
      initialText: page.text.substring(0, entry.start),
    );
  }

  PagePassage? _continuation(WritingPage current) {
    final entry = current.passageAt(current.text.length);
    final source = entry?.source ?? record?.source ?? '';
    if (entry == null && source.isEmpty) return null;
    final paragraph = entry?.paragraph ?? record?.sourceParagraph ?? 0;
    final remainingSource = _passageSource(source, paragraph, entry);
    final active = _guide;
    final guide =
        active?.pageId == current.id &&
            active?.entryId == entry?.id &&
            active?.passage.paragraph.trimLeft() == remainingSource
        ? active!.passage
        : _resumeGuide(current, remainingSource, entry);
    final consumed = guide.consumed(current.text) ?? 0;
    return (entry ??
            PagePassage(
              id: const Uuid().v4(),
              start: 0,
              source: source,
              paragraph: paragraph,
            ))
        .copy(
          sourceOffset: ((entry?.sourceOffset ?? 0) + consumed).clamp(
            0,
            source.length,
          ),
        );
  }

  Future<void> _editPassage([PagePassage? entry]) async {
    if (_sourceBusy || _accountLocked || !_canLeaveInput()) return;
    final owner = c;
    final current = page;
    _sourceBusy = true;
    _blur();
    try {
      await owner.settled;
      if (!mounted ||
          c != owner ||
          _accountLocked ||
          owner.saveError != null ||
          page.id != current.id ||
          page.text != current.text ||
          owner.composing) {
        return;
      }
      final result =
          await showModalBottomSheet<({String source, String citation})>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            constraints: const BoxConstraints(maxWidth: 600),
            builder: (_) => PagePassageSheet(passage: entry),
          );
      if (result == null ||
          !mounted ||
          c != owner ||
          _accountLocked ||
          owner.saveError != null ||
          owner.composing ||
          page.id != current.id ||
          page.text != current.text ||
          (entry != null && !page.passages.any((latest) => latest == entry))) {
        return;
      }
      final changesSource = entry?.source != result.source;
      var lineBreak = '';
      if (entry == null && current.text.isNotEmpty) {
        if (!current.text.endsWith('\n')) lineBreak = '\n';
        if (result.citation.isNotEmpty && !current.text.endsWith('\n\n')) {
          lineBreak += '\n';
        }
      }
      final next =
          (entry ??
                  PagePassage(
                    id: const Uuid().v4(),
                    start: current.text.length + lineBreak.length,
                  ))
              .copy(
                source: result.source,
                citation: result.citation,
                paragraph: changesSource ? 0 : null,
                sourceOffset: changesSource ? 0 : null,
              );
      fresh = false;
      userFresh = false;
      owner.savePagePassage(
        current,
        next,
        lineBreak: lineBreak,
        draftBookId: draftBookId,
      );
      await owner.settled;
      if (mounted &&
          c == owner &&
          !_accountLocked &&
          page.id == current.id &&
          owner.saveError == null) {
        editorFocus.requestFocus();
      }
    } finally {
      _sourceBusy = false;
    }
  }

  Future<void> _showSource() async {
    if (_readingSource || _sourceBusy || _accountLocked || !_canLeaveInput()) {
      return;
    }
    final owner = c, current = page;
    final entry = current.passageAt(current.extent);
    final source = entry?.source ?? record?.source ?? '';
    if (source.isEmpty) return;
    final paragraph = entry?.paragraph ?? record?.sourceParagraph ?? 0;
    final oldGuide = _guide;
    final wasFocused = editorFocus.hasFocus;
    final currentBook = book;
    final style = _paperStyle(currentBook);
    _blur();
    _readingSource = true;
    final route = MaterialPageRoute<SourceReadingResult>(
      builder: (_) => SourceReading(
        title: currentBook?.title ?? record?.title ?? '쓰는 인간',
        source: source,
        paragraphIndex: paragraph,
        style: style,
        coverIndex: currentBook == null ? null : _coverVariant,
      ),
    );
    try {
      final result = await Navigator.of(context).push(route);
      await route.completed;
      if (!mounted ||
          c != owner ||
          _accountLocked ||
          page.id != current.id ||
          page.text != current.text ||
          owner.composing) {
        return;
      }
      final latest = page.passageAt(current.extent);
      if (latest?.id != entry?.id ||
          (latest?.source ?? record?.source) != source) {
        return;
      }
      if (result?.edit == true) {
        if (entry == null) {
          await _source();
        } else {
          await _editPassage(latest);
        }
        return;
      }
      final index = result?.paragraph ?? paragraph;
      final next = latest?.copy(
        paragraph: index,
        sourceOffset: index == paragraph ? null : 0,
      );
      if (index != paragraph) {
        if (next != null) {
          owner.savePagePassage(page, next);
        } else {
          owner.setSourceParagraph(current.recordId, source, index);
        }
      }
      final follow = result?.follow == true;
      final remaining = _passageSource(source, index, next);
      setState(() {
        _guide = (
          pageId: current.id,
          entryId: entry?.id,
          source: source,
          paragraphIndex: index,
          passage: follow
              ? (index == paragraph
                    ? _resumeGuide(current, remaining, next)
                    : TranscriptionGuide(
                        paragraph: remaining,
                        initialText: current.text,
                      ))
              : oldGuide?.passage ?? _resumeGuide(current, remaining, next),
          visible: follow || oldGuide?.visible == true,
        );
      });
      if (follow || wasFocused) editorFocus.requestFocus();
    } finally {
      _readingSource = false;
    }
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
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => PagesSheet(
        pages: _volumePages,
        currentId: selectedId,
        style: _paperStyle(book),
        coverTitle: book?.title ?? record?.title ?? '나의 필사',
        coverVariant: _coverVariant,
      ),
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

  void _more() {
    _blur();
    _sheet(
      SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(CupertinoIcons.quote_bubble, size: 20),
                  title: const Text('원문 메모'),
                  onTap: () => _afterSheet(() => _source()),
                ),
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
                const ListTile(
                  leading: Icon(CupertinoIcons.pencil, size: 20, color: muted),
                  title: Text('연필로 남기는 독서 흔적'),
                  subtitle: Text(
                    '본문에서 구절을 선택한 뒤 ‘연필 표시’를 누르세요.\n표시한 구절을 다시 선택하면 지울 수 있어요.',
                    style: TextStyle(fontSize: 12, height: 1.6, color: muted),
                  ),
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
                          choice: c.library.style.bookDetails.dateStamp,
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
    final canSwipe = navigationEnabled && !editorFocus.hasFocus;
    final compact =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 520;
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
      style: c.library.style,
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
      body: PageTurnView(
        key: ValueKey((c, c.editorEpoch)),
        controller: _pageTurn,
        page: current,
        style: _paperStyle(book),
        scopeId: book?.id ?? current.recordId,
        position: showingCover ? (_coverAtBack ? pages.length : -1) : index,
        isCover: showingCover,
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
    final entry = currentPage.passageAt(currentPage.extent);
    final source =
        entry?.source ??
        record?.source ??
        (fresh && currentPage.recordId == draft.recordId ? draftSource : '');
    final hasSource = source.trim().isNotEmpty;
    final paragraphIndex = entry?.paragraph ?? record?.sourceParagraph ?? 0;
    if (hasSource &&
        !preview &&
        (_guide?.pageId != currentPage.id ||
            _guide?.entryId != entry?.id ||
            _guide?.source != source ||
            _guide?.paragraphIndex != paragraphIndex)) {
      _guide = (
        pageId: currentPage.id,
        entryId: entry?.id,
        source: source,
        paragraphIndex: paragraphIndex,
        passage: _resumeGuide(
          currentPage,
          _passageSource(source, paragraphIndex, entry),
          entry,
        ),
        visible: true,
      );
    }
    final guide =
        !preview &&
            hasSource &&
            _guide?.visible == true &&
            currentPage.passageAt(currentPage.text.length)?.id == entry?.id
        ? _guide?.passage
        : null;
    final bookId = record?.bookId ?? (fresh ? draftBookId : null);
    final book = c.library.books.where((b) => b.id == bookId).firstOrNull;
    final style = _paperStyle(book);
    return PaperBackdrop(
      binding: style.bookDetails.binding,
      color: paperColors[style.paperIndex],
      grainOpacity: paperGrainOpacity[style.paperIndex],
      coverIndex: book == null ? null : c.coverIndexFor(book),
      pagesBefore: index,
      pagesAfter: count - index - 1,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WritingHeader(
                ribbon: c.library.style.bookDetails.ribbon,
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
              if (!preview && currentPage.passages.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: ValueKey(
                      hasSource ? 'toggle-transcription-guide' : 'place-source',
                    ),
                    onPressed: navigationEnabled
                        ? (hasSource ? _showSource : () => _source())
                        : null,
                    icon: const Icon(CupertinoIcons.quote_bubble, size: 15),
                    label: Text(hasSource ? '원문 보기' : '따라 쓰기'),
                  ),
                ),
              Expanded(
                key: const ValueKey('writing-surface'),
                child: preview
                    ? PageReadPreview(
                        key: ValueKey(currentPage.id),
                        page: currentPage,
                        style: style,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          PageEditor(
                            key: ValueKey('${currentPage.id}:${c.editorEpoch}'),
                            page: currentPage,
                            style: style,
                            focusNode: editorFocus,
                            guide: guide,
                            reveal: _reveal?.pageId == currentPage.id
                                ? (
                                    offset: _reveal!.offset,
                                    request: _reveal!.request,
                                  )
                                : null,
                            onChanged: _edit,
                            onAddPassage: navigationEnabled
                                ? () => _editPassage()
                                : null,
                            onNextSheet: navigationEnabled
                                ? (index + 1 < count &&
                                          _volumePages[index + 1].recordId ==
                                              currentPage.recordId
                                      ? () => _stepPage(1)
                                      : _appendPage)
                                : null,
                            onPencilMark: c.togglePencilMark,
                            onEditingState: (focused, composing) {
                              _editorComposing = composing;
                              c.setEditorState(
                                focused: focused,
                                isComposing: composing,
                              );
                            },
                          ),
                          if (hasSource && currentPage.passages.isNotEmpty)
                            Positioned(
                              left: 0,
                              bottom: 0,
                              child: TextButton.icon(
                                onPressed: navigationEnabled
                                    ? _showSource
                                    : null,
                                icon: const Icon(
                                  CupertinoIcons.quote_bubble,
                                  size: 15,
                                ),
                                label: const Text('원문 보기'),
                              ),
                            ),
                        ],
                      ),
              ),
              WritingFooter(
                ornament: c.library.style.bookDetails.ornament,
                onTools: _tools,
                onMore: _more,
                onDone: _blur,
                focused: !preview && editorFocus.hasFocus,
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
    await _sheet(
      ArchiveSheet(
        controller: owner,
        canAccess: () => mounted && c == owner && !_accountLocked,
        record: selectedBook == null ? record : null,
        book: selectedBook ?? book,
      ),
      enableDrag: false,
    );
  }
}
