import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/library_controller.dart';
import '../data/demo_store.dart';
import '../data/model.dart';
import '../sync/coordinator.dart';
import 'collection_sheet.dart';
import 'editor.dart';
import 'new_book_dialog.dart';
import 'paper.dart';
import 'tools_screen.dart';

class Workspace extends StatefulWidget {
  const Workspace({
    super.key,
    required this.controller,
    this.demo = false,
    this.onExitDemo,
    this.sync,
  });
  final LibraryController controller;
  final bool demo;
  final VoidCallback? onExitDemo;
  final SyncCoordinator? sync;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  LibraryController get c => widget.controller;
  final editorFocus = FocusNode();
  late WritingPage draft = _blank();
  late bool fresh = c.library.pages.isEmpty;
  bool userFresh = false;
  String draftSource = '';
  String? draftBookId;
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

  @override
  void initState() {
    super.initState();
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
      fresh = c.library.pages.isEmpty;
      userFresh = false;
      draft = _blank();
      draftSource = '';
      draftBookId = null;
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (fresh && !userFresh && c.library.activePage != null) fresh = false;
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
    c.removeListener(_changed);
    widget.sync?.removeListener(_changed);
    editorFocus.dispose();
    super.dispose();
  }

  void _blur() {
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: false);
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

  void _newSheet([String? bookId]) {
    _blur();
    setState(() {
      draft = _blank();
      draftSource = '';
      draftBookId = bookId;
      fresh = true;
      userFresh = true;
    });
  }

  Future<void> _sheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (_) => child,
  );

  void _collection() {
    _blur();
    _sheet(
      CollectionSheet(
        controller: c,
        onRecord: (r) {
          Navigator.pop(context);
          final pages = c.library.pages.where((p) => p.recordId == r.id);
          if (pages.isEmpty) return;
          fresh = false;
          userFresh = false;
          c.openPage(
            pages
                    .where((p) => p.id == c.library.activePageId)
                    .firstOrNull
                    ?.id ??
                pages.last.id,
          );
        },
        onNewSheet: (bookId) {
          Navigator.pop(context);
          _newSheet(bookId);
        },
        onNewBook: () {
          Navigator.pop(context);
          _createBook();
        },
        onDemo: widget.demo
            ? null
            : () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const _DemoPreview()),
                );
              },
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
      fresh = false;
      userFresh = false;
      c.createBook(values.$1, values.$2);
    }
  }

  void _tools() {
    _blur();
    _sheet(ToolsScreen(controller: c, onBack: () => Navigator.pop(context)));
  }

  Future<void> _source() async {
    _blur();
    final selectedPage = page, selectedRecord = record;
    userFresh = fresh;
    final source = await showDialog<String>(
      context: context,
      builder: (_) =>
          SourceDialog(source: selectedRecord?.source ?? draftSource),
    );
    if (source == null || !mounted) return;
    if (selectedRecord != null) {
      c.setSource(selectedRecord.id, source);
    } else if (source.isNotEmpty) {
      fresh = false;
      c.saveDraft(selectedPage, source: source, bookId: draftBookId);
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

  void _pages() {
    _blur();
    final selectedPage = page;
    final pages = c.library.pages
        .where((p) => p.recordId == selectedPage.recordId)
        .toList();
    if (pages.isEmpty) return;
    _sheet(
      SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  '페이지',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final p in pages)
                      ListTile(
                        title: Text('${p.number}쪽'),
                        subtitle: Text(
                          p.text.isEmpty
                              ? '빈 종이'
                              : p.text.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: p.id == selectedPage.id
                            ? const Icon(CupertinoIcons.checkmark, size: 16)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          c.openPage(p.id);
                        },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    c.openPage(selectedPage.id);
                    c.addPage();
                  },
                  icon: const Icon(CupertinoIcons.plus, size: 16),
                  label: const Text('한 쪽 더'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _more() {
    _blur();
    _sheet(
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(CupertinoIcons.quote_bubble, size: 20),
                title: const Text('원문 메모'),
                onTap: () {
                  Navigator.pop(context);
                  _source();
                },
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
                    Navigator.pop(context);
                    _pages();
                  },
                ),
              if (!widget.demo)
                ListTile(
                  leading: const Icon(CupertinoIcons.cloud, size: 20),
                  title: const Text('기기 동기화'),
                  onTap: () {
                    Navigator.pop(context);
                    _syncInfo();
                  },
                ),
            ],
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
    final currentPage = page;
    final source = record?.source ?? (fresh ? draftSource : '');
    final count = c.library.pages
        .where((p) => p.recordId == currentPage.recordId)
        .length;
    return Scaffold(
      backgroundColor: appPaper,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.demo)
                    SizedBox(
                      height: 30,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '예시 · 기록은 저장되지 않아요',
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onExitDemo,
                            child: const Text(
                              '내 종이',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    height: 60,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _collection,
                          icon: const Icon(
                            CupertinoIcons.square_stack,
                            size: 17,
                          ),
                          label: const Text(
                            '보관함',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: muted,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            book?.title ?? '쓰는 인간',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _newSheet(),
                          icon: const Icon(CupertinoIcons.plus, size: 16),
                          label: const Text(
                            '새 종이',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: muted,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
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
                      color: const Color(0xffffeee5),
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
                            onPressed: c.retrySave,
                            child: const Text(
                              '저장 재시도',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (source.isNotEmpty)
                    TextButton.icon(
                      onPressed: _source,
                      icon: const Icon(
                        CupertinoIcons.quote_bubble,
                        size: 14,
                        color: muted,
                      ),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          source.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: serif,
                            fontSize: 13,
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    key: const ValueKey('writing-surface'),
                    child: PageEditor(
                      key: ValueKey('${currentPage.id}:${c.editorEpoch}'),
                      page: currentPage,
                      style: c.library.style,
                      focusNode: editorFocus,
                      onChanged: _edit,
                      onEditingState: (focused, composing) => c.setEditorState(
                        focused: focused,
                        isComposing: composing,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _tools,
                          icon: const Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 17,
                          ),
                          label: const Text(
                            '쓰기 도구',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: muted,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _syncInfo,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              c.saveError != null
                                  ? '저장 실패'
                                  : record == null
                                  ? '자동 저장'
                                  : c.saving
                                  ? '저장 중'
                                  : widget.demo
                                  ? '예시'
                                  : '저장됨',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (count > 1)
                          TextButton(
                            onPressed: _pages,
                            child: Text(
                              '${currentPage.number} / $count',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (editorFocus.hasFocus)
                          TextButton(
                            onPressed: _blur,
                            child: const Text(
                              '완료',
                              style: TextStyle(fontSize: 12),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: '더 보기',
                            onPressed: _more,
                            icon: const Icon(
                              CupertinoIcons.ellipsis,
                              size: 21,
                              color: muted,
                            ),
                          ),
                      ],
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

  void _syncInfo() {
    if (widget.sync == null || !widget.sync!.available) {
      _storageInfo();
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

  void _storageInfo() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: appPaper,
    showDragHandle: true,
    builder: (context) => const Padding(
      padding: EdgeInsets.fromLTRB(30, 10, 30, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '나의 문장은 이곳에',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 20),
          Text(
            kIsWeb
                ? '쓰는 동안 이 브라우저에 자동으로 보관합니다.\n브라우저 데이터를 지우면 기록도 지워집니다.'
                : '쓰는 동안 이 기기에 자동으로 보관합니다.\n앱을 삭제하면 기록도 지워질 수 있습니다.',
            style: TextStyle(fontSize: 14, height: 1.9),
          ),
          SizedBox(height: 18),
          Text('백업·복원은 준비 중입니다.', style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    ),
  );
}

class _DemoPreview extends StatefulWidget {
  const _DemoPreview();
  @override
  State<_DemoPreview> createState() => _DemoPreviewState();
}

class _DemoPreviewState extends State<_DemoPreview> {
  late final c = LibraryController(DemoStore(), referenceLibrary());
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Workspace(
    controller: c,
    demo: true,
    onExitDemo: () => Navigator.pop(context),
  );
}
