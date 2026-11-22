import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/library_controller.dart';
import '../data/model.dart';
import 'book_detail_design.dart';
import 'book_detail_tools.dart';
import 'book_details.dart';
import 'paper.dart';
import 'paper_choice.dart';

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
  book('책 장식', [
    BookDetailKind.ribbon,
    BookDetailKind.bookplate,
    BookDetailKind.pressedFlower,
  ]),
  page('쪽 장식', [
    BookDetailKind.sourceSlip,
    BookDetailKind.pencil,
    BookDetailKind.ornament,
    BookDetailKind.recordDivider,
    BookDetailKind.dateStamp,
  ]);

  const _Section(this.label, [this.kinds = const []]);
  final String label;
  final List<BookDetailKind> kinds;
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
  _Section section = _Section.materials;
  final _detailsBySection = <_Section, BookDetailKind?>{};
  BookDetailKind? get detail => _detailsBySection[section];
  bool showCover = true;
  LibraryController get controller => widget.controller;

  void _showDetail(BookDetailKind? kind) =>
      setState(() => _detailsBySection[section] = kind);

  Book get current =>
      controller.library.books
          .where((b) => b.id == widget.book.id)
          .firstOrNull ??
      widget.book;

  void _save({
    int? coverIndex,
    int? paperIndex,
    bool useDefaultPaper = false,
    Map<BookDetailKind, BookDetailChoice?> changes = const {},
  }) {
    controller.saveBookAppearance(
      widget.book.id,
      coverIndex: coverIndex,
      paperIndex: paperIndex,
      useDefaultPaper: useDefaultPaper,
      changes: changes,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final book = current;
      final cover = controller.coverIndexFor(book);
      final selectedPaper = book.paperIndex;
      final stock = selectedPaper ?? controller.library.style.paperIndex;
      final details = controller.detailsFor(book);
      final pages = controller.library.volumePages(bookId: book.id);
      final page = controller.resumePageForBook(book.id);
      final sample = page?.text.trim().isNotEmpty == true
          ? page
          : pages.reversed
                .where((entry) => entry.text.trim().isNotEmpty)
                .firstOrNull;
      final excerpt = sample?.text.trim() ?? '';
      final writingStyle = controller.styleFor(book);
      final opened = detail;
      final closed = section == _Section.materials
          ? showCover
          : opened == BookDetailKind.pressedFlower;
      final height = MediaQuery.sizeOf(context).height;
      final pinPreview =
          height >= 520 && MediaQuery.textScalerOf(context).scale(16) <= 24;
      final previewWidth = pinPreview ? math.min(450.0, height * .55) : 450.0;
      final preview = Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: previewWidth),
          child: AspectRatio(
            key: const ValueKey('book-appearance-preview'),
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
                    detail: opened,
                    excerpt: excerpt,
                    writingStyle: writingStyle,
                    pageCount: pages.length,
                    pageNumber: sample == null
                        ? null
                        : pages.indexWhere((p) => p.id == sample.id) + 1,
                  ),
          ),
        ),
      );
      final tabs = Column(
        children: [
          Center(
            child: Wrap(
              spacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final item in _Section.values)
                  Semantics(
                    selected: section == item,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: section == item
                            ? panelSelectedColor(paper)
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                      ),
                      onPressed: () => setState(() => section = item),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            child: section == item
                                ? const Icon(
                                    CupertinoIcons.check_mark,
                                    size: 14,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          Flexible(child: Text(item.label)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: line),
        ],
      );
      final header = Column(
        children: [preview, const SizedBox(height: 16), tabs],
      );
      return PopScope(
        canPop: opened == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && detail != null) _showDetail(null);
        },
        child: Scaffold(
          backgroundColor: paper,
          appBar: AppBar(
            title: const Text('책 꾸미기'),
            centerTitle: true,
            backgroundColor: paper,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.maybePop(context),
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
                    if (opened == null && pinPreview)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: header,
                      ),
                    if (opened == null)
                      Expanded(
                        child: ListView(
                          key: PageStorageKey((section, opened)),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          children: [
                            if (!pinPreview) header,
                            const SizedBox(height: 10),
                            if (section == _Section.materials) ...[
                              Semantics(
                                header: true,
                                child: const Text(
                                  '표지',
                                  style: TextStyle(color: muted),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final (i, name) in coverNames.indexed)
                                    ChoiceChip(
                                      label: Text(name),
                                      selected: cover == i,
                                      onSelected: (selected) {
                                        setState(() => showCover = true);
                                        if (selected) _save(coverIndex: i);
                                      },
                                    ),
                                ],
                              ),
                              const Divider(height: 24, color: line),
                              Semantics(
                                header: true,
                                child: const Text(
                                  '내지',
                                  style: TextStyle(color: muted),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('기본 종이 사용'),
                                    selected: selectedPaper == null,
                                    onSelected: (selected) {
                                      setState(() => showCover = false);
                                      if (selected) {
                                        _save(useDefaultPaper: true);
                                      }
                                    },
                                  ),
                                  for (var i = 0; i < paperNames.length; i++)
                                    PaperChoice(
                                      index: i,
                                      selected: selectedPaper == i,
                                      onSelected: (selected) {
                                        setState(() => showCover = false);
                                        if (selected) _save(paperIndex: i);
                                      },
                                    ),
                                ],
                              ),
                            ] else
                              for (final kind in section.kinds)
                                _detailRow(kind, details.choice(kind), book),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, viewport) {
                            const padding = EdgeInsets.fromLTRB(20, 12, 20, 12);
                            return SingleChildScrollView(
                              key: PageStorageKey((section, opened)),
                              padding: padding,
                              child: _DecorationFit(
                                visibleHeight:
                                    viewport.maxHeight - padding.vertical,
                                preview: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: preview,
                                ),
                                controls: Column(
                                  children: [
                                    tabs,
                                    const SizedBox(height: 4),
                                    _detailEditor(
                                      opened,
                                      details.choice(opened),
                                      book,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (controller.saveError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextButton(
                          onPressed: controller.saving
                              ? null
                              : controller.retrySave,
                          child: const Text('책 꾸밈을 저장하지 못했어요. 다시 저장'),
                        ),
                      )
                    else if (controller.saving)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('저장 중', style: TextStyle(color: muted)),
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

  Widget _detailEditor(
    BookDetailKind kind,
    BookDetailChoice choice,
    Book book,
  ) {
    final design = BookDetailDesign.of(kind);
    final inherited = !book.detailOverrides.containsKey(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookDetailOptions(
          key: ValueKey('book-options-${kind.name}'),
          kind: kind,
          choice: choice,
          heading: Row(
            children: [
              TextButton.icon(
                onPressed: () => _showDetail(null),
                icon: const Icon(CupertinoIcons.chevron_left, size: 14),
                label: const Text('목록'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    design.title,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
          description: switch (kind) {
            BookDetailKind.ribbon || BookDetailKind.pressedFlower => null,
            _ => design.description,
          },
          onChanged: (update) {
            final latest = controller.detailsFor(current).choice(kind);
            _save(changes: {kind: update(latest)});
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: inherited
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '서재 기본값 사용 중',
                    style: TextStyle(fontSize: 14, color: detailMetadataInk),
                  ),
                )
              : TextButton(
                  onPressed: () => _save(changes: {kind: null}),
                  child: const Text('서재 기본값 사용'),
                ),
        ),
      ],
    );
  }

  Widget _detailRow(BookDetailKind kind, BookDetailChoice choice, Book book) {
    final design = BookDetailDesign.of(kind);
    final setting = choice.enabled
        ? '${design.variants[choice.variant]} · ${design.tones[choice.tone]}'
        : '표시 안 함';
    return Column(
      children: [
        ListTile(
          key: ValueKey('book-detail-${kind.name}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          minTileHeight: 64,
          horizontalTitleGap: 12,
          leading: BookDetailSample(kind: kind, choice: choice),
          title: Text(design.title),
          subtitle: Text(
            book.detailOverrides.containsKey(kind)
                ? setting
                : '서재 기본값 · $setting',
            style: const TextStyle(color: detailMetadataInk),
          ),
          trailing: const Icon(
            CupertinoIcons.chevron_right,
            color: brandInk,
            size: 14,
          ),
          onTap: () => _showDetail(kind),
        ),
        const Divider(height: 1, color: line),
      ],
    );
  }
}

/// Measures the controls before fitting the book into the visible height.
/// A short viewport can still scroll the complete editor and preview together.
class _DecorationFit extends MultiChildRenderObjectWidget {
  _DecorationFit({
    required this.visibleHeight,
    required Widget preview,
    required Widget controls,
  }) : super(children: [preview, controls]);

  final double visibleHeight;

  @override
  _RenderDecorationFit createRenderObject(BuildContext context) =>
      _RenderDecorationFit(visibleHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDecorationFit renderObject,
  ) {
    renderObject.visibleHeight = visibleHeight;
  }
}

class _DecorationParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDecorationFit extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DecorationParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DecorationParentData> {
  _RenderDecorationFit(this._visibleHeight);

  double _visibleHeight;
  set visibleHeight(double value) {
    if (_visibleHeight == value) return;
    _visibleHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DecorationParentData) {
      child.parentData = _DecorationParentData();
    }
  }

  @override
  void performLayout() {
    final preview = firstChild!;
    final controls = lastChild!;
    final width = constraints.maxWidth;
    final measure = BoxConstraints.tightFor(width: width);
    controls.layout(measure, parentUsesSize: true);
    preview.layout(
      measure.copyWith(
        maxHeight: math.max(100, _visibleHeight - controls.size.height),
      ),
      parentUsesSize: true,
    );
    (preview.parentData! as _DecorationParentData).offset = Offset.zero;
    (controls.parentData! as _DecorationParentData).offset = Offset(
      0,
      preview.size.height,
    );
    size = constraints.constrain(
      Size(width, preview.size.height + controls.size.height),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

class _OpenBook extends StatelessWidget {
  const _OpenBook({
    required this.book,
    required this.cover,
    required this.stock,
    required this.details,
    required this.detail,
    required this.excerpt,
    required this.writingStyle,
    required this.pageCount,
    required this.pageNumber,
  });

  final Book book;
  final int cover, stock;
  final BookDetailsStyle details;
  final BookDetailKind? detail;
  final String excerpt;
  final WritingStyle writingStyle;
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
                    selected != BookDetailKind.ribbon &&
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
                        maxLines: left ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: left ? TextAlign.center : TextAlign.start,
                        style: left
                            ? TextStyle(
                                color: brandInk,
                                fontSize: math.min(17, box.maxWidth / 8.8),
                                height: 1.65,
                              )
                            : writingTextStyle(
                                writingStyle.fontIndex,
                                color: penColors[writingStyle.penIndex],
                                size: math.min(14, box.maxWidth / 8.8),
                                useDevelopmentTypeface:
                                    writingStyle.useDevelopmentTypeface,
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (!left &&
              (pageNumber != null || detail == BookDetailKind.ornament))
            Positioned(
              bottom: 4,
              left: 24,
              right: 4,
              child: PageOrnament(
                choice: details.ornament,
                child: Text(
                  '${pageNumber ?? 1}',
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
