import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/demo_store.dart';
import '../data/model.dart';
import '../sync/coordinator.dart';
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
  int tab = 0, nav = 0;
  int? tools;
  String? detailId;
  String search = '';
  bool searching = false;
  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    widget.sync?.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      if ((widget.sync?.accountMismatch ?? false) ||
          (widget.sync?.signInRequired ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    widget.sync?.removeListener(_changed);
    editorFocus.dispose();
    super.dispose();
  }

  void _showTools([int initial = 0]) {
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: false);
    setState(() => tools = initial);
  }

  void _shelf([int selected = 0]) {
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: false);
    c.showShelf();
    setState(() {
      detailId = null;
      tools = null;
      nav = selected;
      tab = selected == 4 ? 1 : 0;
    });
  }

  void _detail(Book book) {
    editorFocus.unfocus();
    c.setEditorState(focused: false, isComposing: false);
    c.showShelf();
    setState(() {
      detailId = book.id;
    });
  }

  void _write(Book book) {
    setState(() => detailId = null);
    c.openBook(book.id);
  }

  Future<void> _createBook() async {
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const NewBookDialog(),
    );
    if (values != null && mounted) {
      setState(() => detailId = null);
      c.createBook(values.$1, values.$2);
    }
  }

  void _openRecord(WritingRecord record) {
    setState(() => detailId = null);
    final pages = c.library.pages.where((p) => p.recordId == record.id);
    c.openPage(
      pages.where((p) => p.id == c.library.activePageId).firstOrNull?.id ??
          pages.first.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountLocked =
        (widget.sync?.accountMismatch ?? false) ||
        (widget.sync?.signInRequired == true &&
            c.library.sync.accountId != null);
    if (accountLocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.lock, color: muted),
                const SizedBox(height: 18),
                Text(
                  widget.sync!.signInRequired
                      ? '로그인이 필요합니다.'
                      : '로그인 계정이 바뀌었습니다.',
                  style: const TextStyle(fontSize: 21),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.sync!.signInRequired
                      ? '계정의 기록을 다시 확인하려면\n같은 ChatGPT 계정으로 로그인해 주세요.'
                      : '다른 계정에 기록을 보내지 않도록 동기화를 멈췄습니다.\n이 계정의 책장을 다시 불러와 주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.8),
                ),
                const SizedBox(height: 22),
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
    final detail = c.library.books.where((b) => b.id == detailId).firstOrNull;
    final phone = Material(
      color: appPaper,
      child: PaperBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  if (widget.demo)
                    Container(
                      height: 29,
                      color: const Color(0xffe9d7bf),
                      padding: const EdgeInsets.only(left: 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '예시 책장 · 기록은 저장되지 않아요',
                              style: TextStyle(fontSize: 9, color: muted),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onExitDemo,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            child: const Text(
                              '내 책장',
                              style: TextStyle(fontSize: 10, color: ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (c.saveError != null)
                    Container(
                      color: const Color(0xffffe6d2),
                      padding: const EdgeInsets.only(left: 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '저장 실패 · 앱을 닫지 말고 다시 시도해 주세요.',
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
                  Expanded(
                    child: c.library.writing && c.library.activePage != null
                        ? _writing()
                        : detail != null
                        ? _bookDetail(detail)
                        : _library(),
                  ),
                ],
              ),
              if (tools != null)
                Positioned.fill(
                  child: BlockSemantics(
                    child: ToolsScreen(
                      controller: c,
                      initialTab: tools!,
                      onBack: () => setState(() => tools = null),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, bounds) {
          if (bounds.maxWidth < 700 || bounds.maxHeight < 600) {
            return phone;
          }
          final h = (bounds.maxHeight - 44).clamp(450.0, 846.0);
          final w = (h * .49).clamp(300.0, 414.0);
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xffefe2d0),
              image: DecorationImage(
                image: AssetImage('assets/images/sunlit-desk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x10f5eadb),
                    Color(0x28f9f0e4),
                    Color(0x08e6d3bb),
                  ],
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (bounds.maxWidth >= 1050)
                      Padding(
                        padding: const EdgeInsets.only(right: 110),
                        child: SizedBox(
                          width: 360,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const BotanicalMark(size: 48),
                              const SizedBox(height: 17),
                              const Text(
                                '쓰는 인간',
                                style: TextStyle(
                                  fontFamily: serif,
                                  fontSize: 46,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 6,
                                ),
                              ),
                              const SizedBox(height: 23),
                              const Text(
                                '내 취향으로 쓰고,\n한 권으로 남기는 즐거움.',
                                style: TextStyle(
                                  fontFamily: serif,
                                  fontSize: 19,
                                  height: 1.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 34),
                              Container(width: 40, height: 1, color: muted),
                              const SizedBox(height: 25),
                              const Text(
                                '문장을 고르고, 천천히 옮겨 쓰는 시간.\n일상의 한 켠에 나만의 책장이 생깁니다.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 2,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 52),
                              Row(
                                children: [
                                  for (final color in [
                                    paper,
                                    const Color(0xff5b4636),
                                    green,
                                    const Color(0xff5b6f8e),
                                    burgundy,
                                  ])
                                    Container(
                                      width: 25,
                                      height: 25,
                                      margin: const EdgeInsets.only(right: 13),
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: ink.withValues(alpha: .08),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: const Color(0xff4b4036),
                          width: 5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55513b29),
                            blurRadius: 44,
                            offset: Offset(15, 22),
                          ),
                          BoxShadow(
                            color: Color(0x50513b29),
                            blurRadius: 8,
                            offset: Offset(2, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(27),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: 390,
                            height: (h - 10) / (w - 10) * 390,
                            child: phone,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _library() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(23, 18, 15, 11),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '쓰는 인간',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 27,
                  letterSpacing: .7,
                ),
              ),
            ),
            IconButton(
              tooltip: '책 검색',
              onPressed: () => setState(() {
                searching = !searching;
                search = '';
              }),
              icon: const Icon(CupertinoIcons.search, size: 20),
            ),
            IconButton(
              tooltip: '기기 동기화',
              onPressed: _syncInfo,
              icon: Icon(
                widget.sync?.signedIn == true
                    ? CupertinoIcons.cloud
                    : CupertinoIcons.bell,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      if (searching)
        Padding(
          padding: const EdgeInsets.fromLTRB(23, 0, 23, 10),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '책 이름이나 저자 검색',
              prefixIcon: Icon(CupertinoIcons.search, size: 18),
              isDense: true,
            ),
            onChanged: (v) => setState(() => search = v),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 23),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => tab = i),
                  child: Container(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tab == i ? ink : line,
                          width: tab == i ? 1.3 : .5,
                        ),
                      ),
                    ),
                    child: Text(
                      [
                        '내 책 ${c.library.books.length}',
                        '필사 ${c.library.records.length}',
                        '즐겨찾기',
                      ][i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tab == i ? ink : muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (widget.sync != null &&
          (widget.sync!.hasLegacy || widget.sync!.legacyError))
        InkWell(
          onTap: _syncInfo,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 10),
            color: const Color(0xffeadcc8),
            child: Text(
              widget.sync!.legacyError
                  ? '기존 기기 기록을 읽지 못했습니다 · 확인'
                  : '기기 기록 ${widget.sync!.legacyBooks}권 · 필사 ${widget.sync!.legacyRecords}편 가져오기',
              style: const TextStyle(fontSize: 11, color: ink),
            ),
          ),
        ),
      Expanded(
        child: Stack(
          children: [
            Positioned.fill(
              child: tab == 1 ? _recordList(c.library.records) : _bookList(),
            ),
            Positioned(
              right: 20,
              bottom: 17,
              child: FilledButton.icon(
                onPressed: _createBook,
                icon: const Icon(CupertinoIcons.plus, size: 15),
                label: const Text('새 책 만들기', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: burgundy,
                  foregroundColor: paper,
                  elevation: 3,
                  shadowColor: const Color(0x557a4a4a),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
      _bottomNav(),
    ],
  );

  Widget _bookList() {
    final books = c.library.books
        .where(
          (b) =>
              (tab != 2 || c.library.style.favoriteBookIds.contains(b.id)) &&
              '${b.title} ${b.author}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    if (books.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(35, 48, 35, 100),
        child: Column(
          children: [
            const BotanicalMark(size: 53, color: muted),
            const SizedBox(height: 23),
            Text(
              tab == 2
                  ? '오래 곁에 두고 싶은 책을\n즐겨찾기에 담아 보세요.'
                  : search.isNotEmpty
                  ? '찾는 책이 아직 없어요.'
                  : '첫 책을 펼쳐 볼까요?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                height: 1.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            if (tab == 0 && search.isEmpty) ...[
              OutlinedButton(
                onPressed: _createBook,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: burgundy),
                ),
                child: const Text('첫 책 만들기'),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  setState(() => detailId = null);
                  c.createRecord();
                },
                child: const Text(
                  '책 없이, 먼저 한 문장 쓰기',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const _DemoPreview()),
                ),
                child: const Text(
                  '예시 책장 둘러보기',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              const Text(
                '내 취향으로 쓰고,\n한 권으로 남기는 즐거움.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted, height: 1.9),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(23, 16, 15, 86),
      itemCount: books.length,
      separatorBuilder: (_, _) =>
          const Divider(color: line, thickness: .5, height: 17),
      itemBuilder: (context, i) {
        final book = books[i], index = c.library.books.indexOf(books[i]);
        final ids = c.library.records
            .where((r) => r.bookId == book.id)
            .map((r) => r.id)
            .toSet();
        final pages = c.library.pages
            .where((p) => ids.contains(p.recordId))
            .length;
        return InkWell(
          onTap: () => _detail(book),
          child: SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(title: book.title, width: 86, variant: index),
                const SizedBox(width: 17),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          book.author.isEmpty ? '나의 생각과 문장들' : book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '필사 중 · $pages쪽',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
                _bookMenu(book),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bookMenu(Book book) => PopupMenuButton<String>(
    tooltip: '${book.title} 메뉴',
    padding: EdgeInsets.zero,
    icon: const Icon(CupertinoIcons.ellipsis, size: 20, color: muted),
    onSelected: (value) {
      if (value == 'write') {
        _write(book);
      } else if (value == 'favorite') {
        c.toggleFavorite(book.id);
      } else {
        _bookInfo(book);
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'write', child: Text('이어서 쓰기')),
      PopupMenuItem(
        value: 'favorite',
        child: Text(
          c.library.style.favoriteBookIds.contains(book.id)
              ? '즐겨찾기 해제'
              : '즐겨찾기에 담기',
        ),
      ),
      const PopupMenuItem(value: 'info', child: Text('책 정보')),
    ],
  );

  Widget _recordList(Iterable<WritingRecord> records) => records.isEmpty
      ? const Center(
          child: Text(
            '아직 옮겨 쓴 문장이 없어요.',
            style: TextStyle(color: muted, fontSize: 14),
          ),
        )
      : ListView.separated(
          padding: const EdgeInsets.fromLTRB(23, 15, 23, 90),
          itemCount: records.length,
          separatorBuilder: (_, _) =>
              const Divider(color: line, height: 1, thickness: .5),
          itemBuilder: (context, i) {
            final record = records.elementAt(i),
                pages = c.library.pages
                    .where((p) => p.recordId == records.elementAt(i).id)
                    .toList();
            final title =
                c.library.books
                    .where((b) => b.id == record.bookId)
                    .firstOrNull
                    ?.title ??
                '책 없이 쓴 기록';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              title: Text(
                '$title · ${record.title}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                pages.first.text.isEmpty
                    ? '아직 비어 있는 문장 · ${pages.length}쪽'
                    : pages.first.text.replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: muted, height: 1.8),
              ),
              trailing: const Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: muted,
              ),
              onTap: () => _openRecord(record),
            );
          },
        );

  Widget _bottomNav() => Container(
    height: 69,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: line, width: .6)),
    ),
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
    child: Row(
      children: [
        for (var i = 0; i < 5; i++)
          Expanded(
            child: Semantics(
              selected: nav == i,
              child: InkWell(
                onTap: () {
                  if (i == 3) {
                    _showTools();
                  } else if (i == 2) {
                    setState(() => detailId = null);
                    c.library.activePage == null
                        ? c.createRecord()
                        : c.openPage(c.library.activePageId!);
                  } else {
                    _shelf(i);
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      [
                        nav == 0
                            ? CupertinoIcons.house_fill
                            : CupertinoIcons.house,
                        CupertinoIcons.book,
                        CupertinoIcons.pencil,
                        CupertinoIcons.square_grid_2x2,
                        CupertinoIcons.calendar,
                      ][i],
                      size: 22,
                      color: nav == i ? burgundy : ink,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ['홈', '내 책', '필사', '문구', '내 기록'][i],
                      style: TextStyle(
                        fontSize: 10,
                        color: nav == i ? burgundy : ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _bookDetail(Book book) {
    final records = c.library.records
        .where((r) => r.bookId == book.id)
        .toList();
    final ids = records.map((r) => r.id).toSet(),
        pages = c.library.pages
            .where((p) => records.any((r) => r.id == p.recordId))
            .toList();
    final used = pages.where((p) => p.text.trim().isNotEmpty).length;
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: Row(
            children: [
              IconButton(
                tooltip: '나의 책장',
                onPressed: _shelf,
                icon: const Icon(CupertinoIcons.arrow_left, size: 23),
              ),
              const Spacer(),
              IconButton(
                tooltip: '즐겨찾기',
                onPressed: () => c.toggleFavorite(book.id),
                icon: Icon(
                  c.library.style.favoriteBookIds.contains(book.id)
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.book,
                  size: 22,
                ),
              ),
              _bookMenu(book),
              const SizedBox(width: 7),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, bounds) => BookCover(
                    title: book.title,
                    width: (bounds.maxWidth * .75).clamp(160.0, 238.0),
                    variant: c.library.books.indexOf(book),
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  book.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  book.author.isEmpty ? '나의 생각과 문장들' : book.author,
                  style: const TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 10),
                Text(
                  '필사 중 · ${pages.length}쪽',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 17),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pages.isEmpty ? 0 : used / pages.length,
                    minHeight: 4,
                    color: burgundy,
                    backgroundColor: const Color(0xffe3cdbc),
                    semanticsLabel: '문장을 적은 페이지 $used / ${pages.length}',
                  ),
                ),
                const SizedBox(height: 17),
                _detailRow('목차 (${ids.length})', () => _recordsSheet(records)),
                _detailRow('필사 기록', () => _recordsSheet(records)),
                _detailRow('책 정보', () => _bookInfo(book)),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _write(book),
                    style: FilledButton.styleFrom(
                      backgroundColor: burgundy,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('이어서 쓰기', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String title, VoidCallback action) => InkWell(
    onTap: action,
    child: Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: line, width: .55)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          const Icon(CupertinoIcons.chevron_right, size: 15),
        ],
      ),
    ),
  );

  Widget _writing() {
    final page = c.library.activePage!, record = c.library.activeRecord!;
    final pages = c.library.pages
            .where((p) => p.recordId == page.recordId)
            .toList(),
        index = c.library.pages
            .where((p) => p.recordId == page.recordId)
            .toList()
            .indexWhere((p) => p.id == page.id);
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: Row(
            children: [
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 42,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: '나의 책장',
                onPressed: () {
                  final book = c.library.activeBook;
                  book == null ? _shelf() : _detail(book);
                },
                icon: const Icon(CupertinoIcons.arrow_left, size: 22),
              ),
              Expanded(
                child: Text(
                  '${c.library.activeBook?.title ?? '책 없이 쓰기'} · ${page.number}쪽',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '필사 메뉴',
                icon: const Icon(CupertinoIcons.ellipsis, size: 22),
                onSelected: (value) {
                  if (value == 'sync') {
                    _syncInfo();
                  } else if (value == 'new') {
                    c.createRecord(record.bookId);
                  } else if (value == 'page') {
                    c.addPage();
                  } else if (value == 'records') {
                    _recordsSheet(
                      c.library.records
                          .where((r) => r.bookId == record.bookId)
                          .toList(),
                    );
                  } else if (value == 'bind') {
                    _bind();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'new', child: Text('필사 추가')),
                  if (!widget.demo)
                    const PopupMenuItem(value: 'sync', child: Text('기기 동기화')),
                  const PopupMenuItem(value: 'page', child: Text('새 페이지 추가')),
                  const PopupMenuItem(value: 'records', child: Text('필사 기록')),
                  if (record.bookId == null && c.library.books.isNotEmpty)
                    const PopupMenuItem(value: 'bind', child: Text('책으로 묶기')),
                ],
              ),
              const SizedBox(width: 5),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: InkWell(
            onTap: () => _source(record),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 13),
              decoration: BoxDecoration(
                color: const Color(0xfff2e3cf),
                image: const DecorationImage(
                  image: AssetImage('assets/images/cotton-paper.jpg'),
                  fit: BoxFit.cover,
                  opacity: .4,
                  colorFilter: ColorFilter.mode(
                    Color(0xfff2e3cf),
                    BlendMode.modulate,
                  ),
                ),
                border: Border.all(color: const Color(0xffdfcbb7), width: .5),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0d5b4636),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        '원문',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Spacer(),
                      Icon(CupertinoIcons.chevron_down, size: 12, color: muted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    record.source.isEmpty
                        ? '원문을 메모해 두고 함께 읽어 보세요.'
                        : record.source,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: PageEditor(
              key: ValueKey('${page.id}:${c.editorEpoch}'),
              page: page,
              style: c.library.style,
              focusNode: editorFocus,
              onChanged: c.editPage,
              onEditingState: (focused, composing) =>
                  c.setEditorState(focused: focused, isComposing: composing),
            ),
          ),
        ),
        SizedBox(
          height: 23,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (c.saving)
                const Text('저장 중', style: TextStyle(fontSize: 9, color: muted))
              else
                InkWell(
                  onTap: widget.demo ? null : _syncInfo,
                  child: Text(
                    c.saveError != null
                        ? '저장 실패'
                        : widget.demo
                        ? '예시 화면'
                        : widget.sync?.signedIn == true
                        ? '저장됨 · ${widget.sync!.message}'
                        : '저장됨',
                    style: const TextStyle(fontSize: 9, color: muted),
                  ),
                ),
            ],
          ),
        ),
        Container(
          height: 53,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: line, width: .5)),
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: () => _showTools(2),
                style: TextButton.styleFrom(
                  minimumSize: const Size(36, 42),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: ink,
                ),
                child: const Text(
                  'Aa',
                  style: TextStyle(
                    fontFamily: serif,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 42,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: '펜 선택',
                onPressed: () => _showTools(1),
                icon: const Icon(CupertinoIcons.pencil, size: 22),
              ),
              const Spacer(),
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 42,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: '이전 페이지',
                onPressed: index > 0
                    ? () => c.openPage(pages[index - 1].id)
                    : null,
                icon: const Icon(CupertinoIcons.chevron_left, size: 16),
              ),
              Text(
                '${page.number} / ${pages.length}',
                style: const TextStyle(fontSize: 12),
              ),
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 42,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: index < pages.length - 1 ? '다음 페이지' : '새 페이지',
                onPressed: index < pages.length - 1
                    ? () => c.openPage(pages[index + 1].id)
                    : c.addPage,
                icon: Icon(
                  index < pages.length - 1
                      ? CupertinoIcons.chevron_right
                      : CupertinoIcons.add,
                  size: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 42,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: '키보드',
                onPressed: () {
                  editorFocus.hasFocus
                      ? editorFocus.unfocus()
                      : editorFocus.requestFocus();
                },
                icon: const Icon(CupertinoIcons.keyboard, size: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _source(WritingRecord record) async {
    editorFocus.unfocus();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => SourceDialog(source: record.source),
    );
    if (result != null && mounted) {
      c.setSource(record.id, result);
    }
  }

  Future<void> _bind() async {
    final recordId = c.library.activeRecord!.id;
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('어느 책에 묶을까요?'),
        children: [
          for (final book in c.library.books)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, book.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(book.title),
              ),
            ),
        ],
      ),
    );
    if (id != null && mounted) {
      c.bindRecord(recordId, id);
    }
  }

  void _recordsSheet(List<WritingRecord> records) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: appPaper,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: 380,
      child: Column(
        children: [
          const Text(
            '필사 기록',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (final record in records)
                  ListTile(
                    title: Text(record.title),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openRecord(record);
                    },
                  ),
                ListTile(
                  leading: const Icon(CupertinoIcons.add, size: 19),
                  title: const Text('필사 추가'),
                  onTap: () {
                    Navigator.pop(context);
                    final bookId = records.firstOrNull?.bookId ?? detailId;
                    setState(() => detailId = null);
                    c.createRecord(bookId);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  void _bookInfo(Book book) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: appPaper,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 15),
          Text(
            book.author.isEmpty ? '저자를 남기지 않은 나의 문장집' : book.author,
            style: const TextStyle(fontSize: 15, color: muted),
          ),
          const SizedBox(height: 22),
          const Text('한 문장씩 옮겨 쓰며 완성하는 나의 책.', style: TextStyle(fontSize: 13)),
        ],
      ),
    ),
  );
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
