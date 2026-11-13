import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/library_controller.dart';
import '../data/model.dart';
import 'book_detail_design.dart';
import 'book_detail_tools.dart';
import 'book_details.dart';
import 'paper.dart';

Future<void> showBookAppearance(
  BuildContext context,
  LibraryController controller,
  String bookId,
) {
  final book = controller.library.books
      .where((b) => b.id == bookId)
      .firstOrNull;
  if (book == null) return Future.value();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BookAppearance(controller: controller, book: book),
    ),
  );
}

enum _Section {
  materials('표지·내지'),
  ribbon('책갈피'),
  details('쪽 디테일');

  const _Section(this.label);
  final String label;
}

class BookAppearance extends StatefulWidget {
  const BookAppearance({
    super.key,
    required this.controller,
    required this.book,
  });

  final LibraryController controller;
  final Book book;

  @override
  State<BookAppearance> createState() => _BookAppearanceState();
}

class _BookAppearanceState extends State<BookAppearance> {
  _Section section = _Section.ribbon;
  BookDetailKind detail = BookDetailKind.binding;
  bool showCover = true;
  int? coverIndex;
  int? paperIndex;
  bool paperChanged = false;
  bool saving = false;
  bool saveFailed = false;
  final changes = <BookDetailKind, BookDetailChoice>{};

  LibraryController get controller => widget.controller;
  Book? get current =>
      controller.library.books.where((b) => b.id == widget.book.id).firstOrNull;

  Future<void> _finish() async {
    if (saving) return;
    if (coverIndex == null && !paperChanged && changes.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => saving = true);
    final saved = await controller.saveBookAppearance(
      widget.book.id,
      coverIndex: coverIndex,
      paperIndex: paperIndex,
      useDefaultPaper: paperChanged && paperIndex == null,
      changes: changes,
    );
    if (!mounted) return;
    setState(() {
      saving = false;
      saveFailed = !saved;
    });
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final book = current ?? widget.book;
      final cover = coverIndex ?? controller.coverIndexFor(book);
      final selectedPaper = paperChanged ? paperIndex : book.paperIndex;
      final stock = selectedPaper ?? controller.library.style.paperIndex;
      var details = controller.detailsFor(book);
      for (final entry in changes.entries) {
        details = details.withChoice(entry.key, entry.value);
      }
      final pages = controller.library.volumePages(bookId: book.id);
      final page = controller.resumePageForBook(book.id);
      final excerpt = page?.text.trim() ?? '';
      final kind = section == _Section.ribbon ? BookDetailKind.ribbon : detail;
      final closed = switch (section) {
        _Section.materials => showCover,
        _Section.ribbon => false,
        _Section.details =>
          detail == BookDetailKind.pressedFlower ||
              detail == BookDetailKind.indexTab,
      };
      return PopScope(
        canPop: !saving,
        child: Scaffold(
          backgroundColor: paper,
          appBar: AppBar(
            title: const Text('책 꾸미기'),
            centerTitle: true,
            backgroundColor: paper,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: '뒤로',
              onPressed: saving ? null : () => Navigator.pop(context),
              icon: const Icon(CupertinoIcons.chevron_left, size: 20),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        children: [
                          Center(
                            child: SizedBox(
                              width: 450,
                              child: AspectRatio(
                                aspectRatio: 1.53,
                                child: closed
                                    ? Center(
                                        child: LayoutBuilder(
                                          builder: (_, box) => BookCover(
                                            title: book.title,
                                            width: box.maxHeight / 1.36,
                                            variant: cover,
                                            materialPreview: true,
                                            pageCount: pages.length,
                                            details: details,
                                          ),
                                        ),
                                      )
                                    : _OpenBook(
                                        book: book,
                                        cover: cover,
                                        stock: stock,
                                        details: details,
                                        detail: section == _Section.details
                                            ? detail
                                            : null,
                                        excerpt: excerpt,
                                        pageCount: pages.length,
                                        pageNumber: page == null
                                            ? null
                                            : pages.indexWhere(
                                                    (p) => p.id == page.id,
                                                  ) +
                                                  1,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Wrap(
                              spacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final item in _Section.values)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: section == item
                                          ? burgundy
                                          : muted,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                      ),
                                      minimumSize: const Size(48, 48),
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
                                    ),
                                    onPressed: saving
                                        ? null
                                        : () => setState(() => section = item),
                                    child: Semantics(
                                      selected: section == item,
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          decoration: section == item
                                              ? TextDecoration.underline
                                              : null,
                                          decorationColor: burgundy,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: line),
                          const SizedBox(height: 10),
                          if (section == _Section.materials) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: saving
                                      ? null
                                      : () => setState(() => showCover = true),
                                  child: Semantics(
                                    selected: showCover,
                                    child: const Text('표지'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: saving
                                      ? null
                                      : () => setState(() => showCover = false),
                                  child: Semantics(
                                    selected: !showCover,
                                    child: const Text('내지'),
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              children: showCover
                                  ? [
                                      for (final (i, name)
                                          in coverNames.indexed)
                                        ChoiceChip(
                                          label: Text(name),
                                          selected: cover == i,
                                          onSelected: saving
                                              ? null
                                              : (_) => setState(
                                                  () => coverIndex = i,
                                                ),
                                        ),
                                    ]
                                  : [
                                      ChoiceChip(
                                        label: const Text('기본 종이 사용'),
                                        selected: selectedPaper == null,
                                        onSelected: saving
                                            ? null
                                            : (_) => _selectPaper(null),
                                      ),
                                      for (final (i, name)
                                          in paperNames.indexed)
                                        ChoiceChip(
                                          avatar: CircleAvatar(
                                            backgroundColor: paperColors[i],
                                          ),
                                          label: Text(name),
                                          selected: selectedPaper == i,
                                          onSelected: saving
                                              ? null
                                              : (_) => _selectPaper(i),
                                        ),
                                    ],
                            ),
                          ] else ...[
                            if (section == _Section.details)
                              DropdownButton<BookDetailKind>(
                                isExpanded: true,
                                value: detail,
                                onChanged: saving
                                    ? null
                                    : (kind) {
                                        if (kind != null) {
                                          setState(() => detail = kind);
                                        }
                                      },
                                items: [
                                  for (final kind in BookDetailKind.values)
                                    if (kind != BookDetailKind.ribbon)
                                      DropdownMenuItem(
                                        value: kind,
                                        child: Text(
                                          BookDetailDesign.of(kind).title,
                                        ),
                                      ),
                                ],
                              ),
                            ExcludeFocus(
                              excluding: saving,
                              child: IgnorePointer(
                                ignoring: saving,
                                child: BookDetailOptions(
                                  kind: kind,
                                  choice: details.choice(kind),
                                  showSpecimen: false,
                                  onChanged: (value) =>
                                      setState(() => changes[kind] = value),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (saveFailed)
                            const Text(
                              '책 꾸밈을 저장하지 못했어요.',
                              style: TextStyle(color: burgundy),
                            ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: burgundy,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: saving ? null : _finish,
                            child: Text(
                              saving
                                  ? '저장 중'
                                  : saveFailed
                                  ? '다시 저장'
                                  : '완료',
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
    },
  );

  void _selectPaper(int? index) => setState(() {
    paperIndex = index;
    paperChanged = true;
  });
}

class _OpenBook extends StatelessWidget {
  const _OpenBook({
    required this.book,
    required this.cover,
    required this.stock,
    required this.details,
    required this.detail,
    required this.excerpt,
    required this.pageCount,
    required this.pageNumber,
  });

  final Book book;
  final int cover, stock;
  final BookDetailsStyle details;
  final BookDetailKind? detail;
  final String excerpt;
  final int pageCount;
  final int? pageNumber;

  @override
  Widget build(BuildContext context) {
    final color = paperColors[stock];
    return Semantics(
      label: '${book.title} · 펼친 책 미리보기',
      child: ExcludeSemantics(
        child: ExcludeFocus(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth;
                final height = box.maxHeight;
                final ribbonWidth = (width * .038).clamp(8.0, 17.0);
                final edge = (5 + math.sqrt(pageCount) * .65).clamp(5.0, 11.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      top: 3,
                      bottom: 2,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x28604937),
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Color(0x30524232),
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(6),
                          ),
                          child: BookCoverMaterial(
                            variant: cover,
                            back: false,
                            binding: const BookDetailChoice(enabled: false),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: 7,
                      bottom: 6,
                      left: 5,
                      right: 5,
                      child: Row(
                        children: [
                          for (final left in [true, false])
                            Expanded(
                              child: CustomPaint(
                                painter: _LeafEdges(
                                  color: color,
                                  depth: edge,
                                  left: left,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: edge,
                                    left: left ? 3 : 0,
                                    right: left ? 0 : 3,
                                  ),
                                  child: ClipPath(
                                    clipper: _LeafClip(left),
                                    child: _leaf(
                                      color,
                                      left: left,
                                      ribbonWidth: ribbonWidth,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (details.ribbon.enabled)
                      Positioned(
                        top: 2,
                        left: width / 2 + 2,
                        child: Transform.rotate(
                          angle: -.026,
                          alignment: Alignment.topCenter,
                          child: RibbonBookmark(
                            key: const ValueKey('book-preview-ribbon'),
                            choice: details.ribbon,
                            width: ribbonWidth,
                            height: height * .58,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _leaf(
    Color color, {
    required bool left,
    required double ribbonWidth,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      image: paperGrain(color, paperGrainOpacity[stock] + .15),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: left ? Alignment.centerRight : Alignment.centerLeft,
          end: left ? Alignment.centerLeft : Alignment.centerRight,
          colors: const [
            Color(0x55524232),
            Color(0x1f524232),
            Color(0x17ffffff),
            Colors.transparent,
            Color(0x12524232),
          ],
          stops: const [0, .052, .17, .40, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!left) BookBinding(choice: details.binding),
          Padding(
            padding: EdgeInsets.fromLTRB(
              left ? 14 : ribbonWidth + 12,
              19,
              13,
              21,
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final selected = detail;
                if (left &&
                    selected != null &&
                    selected != BookDetailKind.binding &&
                    selected != BookDetailKind.ornament) {
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 240,
                        child: selected == BookDetailKind.bookplate
                            ? Bookplate(
                                title: book.title,
                                owner: book.owner,
                                summary: '',
                                choice: details.bookplate,
                                stockColor: color,
                                flower: details.pressedFlower,
                                onOwner: () {},
                                margin: EdgeInsets.zero,
                              )
                            : BookDetailPreview(
                                kind: selected,
                                choice: details.choice(selected),
                              ),
                      ),
                    ),
                  );
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        left ? book.title : excerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: left ? TextAlign.center : TextAlign.start,
                        style: TextStyle(
                          color: brandInk,
                          fontSize: math.min(
                            left ? 17 : 14,
                            box.maxWidth / 8.8,
                          ),
                          height: 1.65,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (!left && pageNumber != null)
            Positioned(
              bottom: 4,
              left: 24,
              right: 4,
              child: PageOrnament(
                choice: details.ornament,
                child: Text(
                  '$pageNumber',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The leaves bend into the gutter. Their fore-edges stay nearly straight.
Path _leafOutline(Size size, bool left) {
  final w = size.width, h = size.height;
  final path = Path()
    ..moveTo(w, 6)
    ..quadraticBezierTo(w * .70, 0, 7, 1)
    ..quadraticBezierTo(1, 1, 1, 7)
    ..lineTo(1, h - 6)
    ..quadraticBezierTo(1, h - 1, 6, h - 1)
    ..quadraticBezierTo(w * .72, h + 1, w, h - 6)
    ..close();
  if (left) return path;
  return path.transform(
    (Matrix4.identity()
          ..translateByDouble(w, 0, 0, 1)
          ..scaleByDouble(-1, 1, 1, 1))
        .storage,
  );
}

class _LeafClip extends CustomClipper<Path> {
  const _LeafClip(this.left);

  final bool left;

  @override
  Path getClip(Size size) => _leafOutline(size, left);

  @override
  bool shouldReclip(_LeafClip oldClipper) => oldClipper.left != left;
}

class _LeafEdges extends CustomPainter {
  const _LeafEdges({
    required this.color,
    required this.depth,
    required this.left,
  });

  final Color color;
  final double depth;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final face = _leafOutline(Size(size.width, size.height - depth), left);
    final paint = Paint();
    for (var i = 0; i < 6; i++) {
      final fraction = i / 5;
      final sheet = face.shift(
        Offset(left ? fraction * 2 : -fraction * 2, depth * (1 - fraction)),
      );
      paint.color = Color.lerp(color, brandInk, i.isEven ? .30 : .13)!;
      canvas.drawPath(sheet, paint);
    }
  }

  @override
  bool shouldRepaint(_LeafEdges oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.depth != depth ||
      oldDelegate.left != left;
}
