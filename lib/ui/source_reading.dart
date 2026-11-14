import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/model.dart';
import '../data/library_search.dart';
import '../data/original_photo_store.dart';
import '../source/originals.dart';
import '../source/source_scan.dart';
import 'book_details.dart';
import 'paper.dart';
import 'original_range_sheet.dart';
import 'pencil_marks.dart';
import 'reading_details.dart';
import 'reflection_ink.dart';
import 'writing_pen.dart';

class SourceReading extends StatefulWidget {
  const SourceReading({
    super.key,
    required this.originals,
    this.match,
    this.initialOriginalId,
    this.onReadOriginal,
    this.style = const WritingStyle(),
    this.coverIndex,
    this.pagesBefore = 0,
    this.pagesAfter = 0,
    this.onRegister,
    this.writingLocations = const {},
    this.onTranscribe,
    this.onOpenWriting,
    this.onRetry,
    this.onSaveReflection,
    this.onSaveRange,
  });

  final List<RegisteredOriginal> originals;
  final OriginalMatch? match;
  final String? initialOriginalId;
  final ValueChanged<String>? onReadOriginal;
  final WritingStyle style;
  final int? coverIndex;
  final int pagesBefore, pagesAfter;
  final Future<RegisteredOriginal?> Function({bool startWithSearch})?
  onRegister;
  final Map<String, ({Passage passage, bool marked})> writingLocations;
  final ValueChanged<RegisteredOriginal>? onTranscribe;
  final ValueChanged<Passage>? onOpenWriting;
  final VoidCallback? onRetry;
  final Future<bool> Function(RegisteredOriginal, PencilMark?)? onSaveRange;
  final Future<bool> Function(RegisteredOriginal, OriginalReflection?)?
  onSaveReflection;

  @override
  State<SourceReading> createState() => _SourceReadingState();
}

class _SourceReadingState extends State<SourceReading> {
  late String? selectedId = widget.initialOriginalId;
  final reflectionField = TextEditingController();
  final reflectionFocus = FocusNode();
  final readingItem = GlobalKey();
  String? _readingId;
  RegisteredOriginal? _editingOriginal;
  Timer? _autosave;
  Future<void>? _inFlight;
  String _saved = '';
  bool _leaveEditor = false;
  bool saving = false, failed = false, markedOnly = false;
  PencilMark? draftMark;

  bool get editing => _editingOriginal != null;
  bool get _composing =>
      reflectionField.value.isComposingRangeValid &&
      !reflectionField.value.composing.isCollapsed;
  String get _draft => reflectionField.text.trim();
  bool get _canLeave =>
      !saving && !_composing && !failed && (!editing || _draft == _saved);

  bool _isMarked(RegisteredOriginal item) =>
      item.reflection?.mark != null ||
      widget.writingLocations[item.id]?.marked == true;

  @override
  void initState() {
    super.initState();
    reflectionField.addListener(_reflectionChanged);
    reflectionFocus.addListener(_focusChanged);
  }

  void _open(String id) {
    setState(() => selectedId = id);
    widget.onReadOriginal?.call(id);
  }

  void _showList() {
    setState(() {
      _readingId = selectedId;
      if (markedOnly &&
          !widget.originals.any(
            (item) => item.id == selectedId && _isMarked(item),
          )) {
        markedOnly = false;
      }
      selectedId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final item = readingItem.currentContext;
      if (item != null) Scrollable.ensureVisible(item, alignment: .35);
    });
  }

  Future<void> _register({bool startWithSearch = false}) async {
    final registered = await widget.onRegister!(
      startWithSearch: startWithSearch,
    );
    if (!mounted || registered == null) return;
    markedOnly = false;
    _open(
      widget.originals
              .where(
                (item) =>
                    item.id == registered.id ||
                    (item.text == registered.text &&
                        item.citation == registered.citation &&
                        item.photoId == registered.photoId),
              )
              .firstOrNull
              ?.id ??
          registered.id,
    );
  }

  @override
  void dispose() {
    _autosave?.cancel();
    reflectionField.dispose();
    reflectionFocus.dispose();
    super.dispose();
  }

  void _editReflection(RegisteredOriginal original, OriginalMatch? match) {
    final text = original.reflection?.text ?? '';
    _saved = text.trim();
    _leaveEditor = false;
    reflectionField.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      _editingOriginal = original;
      failed = false;
      draftMark =
          original.reflection?.mark ??
          (match == null ? null : PencilMark(match.start, match.end));
    });
  }

  void _reflectionChanged() {
    if (!editing) return;
    _autosave?.cancel();
    if (!_composing && (_draft != _saved || _leaveEditor)) {
      _autosave = Timer(
        const Duration(milliseconds: 350),
        () => unawaited(_flush()),
      );
    }
    setState(() {});
  }

  void _focusChanged() {
    if (!editing || reflectionFocus.hasFocus) return;
    _leaveEditor = true;
    unawaited(_flush());
  }

  Future<void> _flush() async {
    _autosave?.cancel();
    while (_inFlight != null) {
      await _inFlight;
    }
    if (!mounted || _composing || !editing) return;
    if (_draft != _saved || failed) {
      final original = _editingOriginal!;
      final draft = _draft;
      setState(() {
        saving = true;
        failed = false;
      });
      final pending = () async {
        var success = false;
        try {
          success = await widget.onSaveReflection!(
            original,
            draft.isEmpty ? null : OriginalReflection(draft, mark: draftMark),
          );
        } catch (_) {
          success = false;
        } finally {
          if (mounted) {
            setState(() {
              saving = false;
              failed = !success;
              if (success) _saved = draft;
            });
          }
        }
      }();
      _inFlight = pending;
      try {
        await pending;
      } finally {
        _inFlight = null;
      }
      if (!mounted || failed || _composing) return;
      if (_draft != _saved && _leaveEditor) {
        await _flush();
        return;
      }
    }
    if (_leaveEditor && _canLeave) setState(() => _editingOriginal = null);
  }

  Future<void> _navigate(VoidCallback action) async {
    if (_composing) return;
    if (editing) {
      _leaveEditor = true;
      reflectionFocus.unfocus();
      await _flush();
    }
    if (mounted && _canLeave && ModalRoute.of(context)?.isCurrent == true) {
      action();
    }
  }

  Future<void> _changeRange(RegisteredOriginal original) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      SourceScan? photo;
      if (original.photoId case final id?) {
        try {
          final bytes = await const OriginalPhotoStore().load(id);
          if (bytes != null) {
            final image = await ScanImage.decode(bytes);
            photo = SourceScan(
              image.bytes,
              const [],
              width: image.width,
              height: image.height,
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('원본 사진을 읽지 못했어요.')));
          }
        }
      }
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final choice = await chooseOriginalRange(
        context,
        original.text,
        current: original.writingRange,
        photo: photo,
        photoLines: original.photoLines,
      );
      if (!mounted || choice == null) return;
      final saved = await widget.onSaveRange!(original, choice.range);
      if (mounted && !saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('필사 범위를 저장하지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _showPhoto(String id) async {
    final bytes = const OriginalPhotoStore().load(id);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('원본 사진')),
          body: FutureBuilder(
            future: bytes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final image = snapshot.data;
              if (image == null) {
                return Center(
                  child: Text(
                    snapshot.hasError ? '사진을 읽지 못했어요.' : '이 기기에 보관된 사진이 없어요.',
                  ),
                );
              }
              return Center(
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Image.memory(
                    image,
                    key: const ValueKey('saved-original-photo'),
                    semanticLabel: '저장한 원본 사진',
                    errorBuilder: (_, _, _) => const Text('이 사진을 표시할 수 없어요.'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.originals
        .where((item) => item.id == selectedId)
        .firstOrNull;
    final match = selectedId == widget.match?.original.id ? widget.match : null;
    final reflection = original?.reflection;
    final visibleOriginals = markedOnly
        ? widget.originals.where(_isMarked).toList()
        : widget.originals;
    final writing = widget.writingLocations[original?.id]?.passage;
    final mark = editing ? draftMark : reflection?.mark;
    final note = original == null || original.text.trim().isEmpty
        ? null
        : _ReflectionNote(
            controller: editing ? reflectionField : null,
            focus: reflectionFocus,
            text: reflection?.text,
            onEdit: widget.onSaveReflection == null
                ? null
                : () => _editReflection(original, match),
          );
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final style = widget.style;
    final details = style.bookDetails;
    final panel = panelPaperColor(paperColors[style.paperIndex]);
    return PopScope(
      canPop: _canLeave && !editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && editing && !_composing && !failed) {
          unawaited(_navigate(() => Navigator.pop(context)));
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: (media.size.height * .68 - keyboard).clamp(
              media.size.height * .38,
              media.size.height,
            ),
            child: PaperBackdrop(
              key: const ValueKey('source-paper'),
              binding: details.binding,
              color: panel,
              outsideColor: panel,
              grainOpacity: panelGrainOpacity,
              coverIndex: widget.coverIndex,
              pagesBefore: widget.pagesBefore,
              pagesAfter: widget.pagesAfter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (original != null)
                          IconButton(
                            tooltip: '원문 목록',
                            onPressed: () => _navigate(_showList),
                            icon: const Icon(
                              CupertinoIcons.chevron_left,
                              size: 19,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            original?.citation.trim().isNotEmpty == true
                                ? original!.citation
                                : '원문',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (widget.onRegister != null && !editing) ...[
                          IconButton(
                            tooltip: '시·문장 검색',
                            onPressed: () => _register(startWithSearch: true),
                            icon: const Icon(CupertinoIcons.search, size: 19),
                          ),
                          Flexible(
                            flex: 2,
                            child: TextButton(
                              onPressed: _register,
                              child: const Text(
                                '원문 등록',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () =>
                              _navigate(() => Navigator.pop(context)),
                          icon: const Icon(CupertinoIcons.xmark, size: 18),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (original == null && widget.originals.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilterChip(
                          label: const Text('밑칠한 구절만 보기'),
                          backgroundColor: panelChipColor(panel),
                          selectedColor: panelSelectedColor(panel),
                          checkmarkColor: brandInk,
                          side: BorderSide(color: markedOnly ? brandInk : line),
                          selected: markedOnly,
                          onSelected: (value) =>
                              setState(() => markedOnly = value),
                        ),
                      ),
                    if (original != null &&
                        !editing &&
                        (original.photoId != null || original.isFullPage))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (original.photoId case final id?)
                              TextButton.icon(
                                onPressed: saving ? null : () => _showPhoto(id),
                                icon: const Icon(
                                  CupertinoIcons.photo,
                                  size: 16,
                                ),
                                label: const Text('원본 사진'),
                              ),
                            if (original.isFullPage &&
                                widget.onSaveRange != null)
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () => _changeRange(original),
                                child: Text(
                                  original.writingRange == null
                                      ? '필사 범위 · 전체 페이지'
                                      : '필사 범위 · 구간 선택됨',
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (widget.onRetry != null && !editing)
                      TextButton(
                        onPressed: widget.onRetry,
                        child: const Text('저장 실패 · 다시 저장'),
                      ),
                    Expanded(
                      child: original != null
                          ? _OriginalText(
                              key: ValueKey(original.id),
                              original: original,
                              style: style,
                              match: match,
                              mark: mark,
                              note: note,
                              editing: editing,
                            )
                          : visibleOriginals.isEmpty
                          ? Center(
                              child: Text(
                                markedOnly ? '밑칠한 구절이 없어요.' : '등록한 원문이 없습니다.',
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  for (final (index, item)
                                      in visibleOriginals.indexed) ...[
                                    if (index > 0)
                                      details.recordDivider.enabled
                                          ? RecordDivider(
                                              choice: details.recordDivider,
                                              compact: true,
                                            )
                                          : const SizedBox(height: 8),
                                    InkWell(
                                      key: item.id == _readingId
                                          ? readingItem
                                          : ValueKey(item.id),
                                      onTap: () => _open(item.id),
                                      child: SourceSlip(
                                        compact: true,
                                        panelColor: panel,
                                        choice: details.sourceSlip,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            item.text.isEmpty
                                                ? item.citation
                                                : item.text
                                                      .replaceAll(
                                                        _previewWhitespace,
                                                        ' ',
                                                      )
                                                      .trim(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: writingTextStyle(
                                              style.fontIndex,
                                              size: 17,
                                              useDevelopmentTypeface:
                                                  style.useDevelopmentTypeface,
                                              color: ink,
                                            ),
                                          ),
                                          subtitle:
                                              item.citation.isEmpty ||
                                                  item.text.isEmpty
                                              ? null
                                              : Text(
                                                  item.citation,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    if (original != null && !editing)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (widget.onTranscribe != null &&
                                original.text.trim().isNotEmpty)
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () => widget.onTranscribe!(original),
                                child: const Text('이 구절 필사하기'),
                              ),
                            if (writing != null && widget.onOpenWriting != null)
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () => widget.onOpenWriting!(writing),
                                child: const Text('필사한 쪽 열기'),
                              ),
                          ],
                        ),
                      ),
                    if (failed && editing)
                      TextButton(
                        onPressed: _composing ? null : _flush,
                        child: const Text('느낀 점 저장 실패 · 다시 시도'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OriginalText extends StatefulWidget {
  const _OriginalText({
    super.key,
    required this.original,
    required this.style,
    this.match,
    this.mark,
    this.note,
    required this.editing,
  });

  final RegisteredOriginal original;
  final WritingStyle style;
  final OriginalMatch? match;
  final PencilMark? mark;
  final Widget? note;
  final bool editing;

  @override
  State<_OriginalText> createState() => _OriginalTextState();
}

final _sentenceEnd = RegExp(r'[.!?。！？]+|\n');
final _previewWhitespace = RegExp(r'\s+');

class _OriginalTextState extends State<_OriginalText> {
  final scroll = ScrollController();
  final beforeNote = GlobalKey();
  final afterNote = GlobalKey();
  final noteKey = GlobalKey();

  @override
  void didUpdateWidget(_OriginalText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing && !oldWidget.editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final field = noteKey.currentContext;
        if (field != null) Scrollable.ensureVisible(field, alignment: .7);
      });
    }
  }

  bool positioned = false;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  TextSpan _span(int from, int to) {
    final text = widget.original.text;
    final style = widget.style;
    final pencil = style.bookDetails.pencil;
    final mark = pencil.enabled ? widget.mark : null;
    final current = widget.match;
    final match =
        current != null &&
            (mark == null ||
                current.end <= mark.start ||
                current.start >= mark.end)
        ? current
        : null;
    final range = widget.original.writingRange;
    final boundaries = {
      from,
      to,
      if (range != null) ...[
        range.start.clamp(from, to),
        range.end.clamp(from, to),
      ],
      if (mark != null) ...[
        mark.start.clamp(from, to),
        mark.end.clamp(from, to),
      ],
      if (match != null) ...[
        match.start.clamp(from, to),
        match.end.clamp(from, to),
      ],
    }.toList()..sort();
    return TextSpan(
      style: writingTextStyle(
        style.fontIndex,
        size: 20,
        color: penColors[style.penIndex],
        useDevelopmentTypeface: style.useDevelopmentTypeface,
      ).copyWith(height: 1.65, letterSpacing: 0),
      children: [
        for (var i = 0; i + 1 < boundaries.length; i++)
          TextSpan(
            text: text.substring(boundaries[i], boundaries[i + 1]),
            style:
                mark != null &&
                    boundaries[i] >= mark.start &&
                    boundaries[i] < mark.end
                ? passageWashStyle(pencil)
                : match != null &&
                      boundaries[i] >= match.start &&
                      boundaries[i] < match.end
                ? const TextStyle(backgroundColor: Color(0x30a78356))
                : range != null &&
                      boundaries[i] >= range.start &&
                      boundaries[i] < range.end
                ? const TextStyle(backgroundColor: Color(0x20a78356))
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.original.text;
    if (text.trim().isEmpty) return const Center(child: Text('출처를 남긴 기록입니다.'));
    final mark = widget.mark;
    final noteStart =
        (mark ?? widget.original.reflection?.mark)?.end ??
        widget.match?.end ??
        text.length;
    final sentenceEnd = _sentenceEnd.firstMatch(text.substring(noteStart));
    final split = sentenceEnd == null
        ? text.length
        : noteStart + sentenceEnd.end;
    const from = 0;
    final before = _span(from, split);
    final after = _span(split, text.length);
    return LayoutBuilder(
      builder: (context, box) {
        final focus = widget.editing
            ? null
            : widget.match?.start ?? mark?.start;
        if (!positioned && focus != null) {
          positioned = true;
          final inAfter = focus >= split;
          final painter = TextPainter(
            text: inAfter ? after : before,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: box.maxWidth);
          final offset = painter
              .getOffsetForCaret(
                TextPosition(offset: focus - (inAfter ? split : from)),
                Rect.zero,
              )
              .dy;
          painter.dispose();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !scroll.hasClients) return;
            final target = (inAfter ? afterNote : beforeNote).currentContext
                ?.findRenderObject();
            final start = target == null
                ? 0.0
                : RenderAbstractViewport.of(
                    target,
                  ).getOffsetToReveal(target, 0).offset;
            scroll.jumpTo(
              (start + offset - box.maxHeight * .22).clamp(
                0,
                scroll.position.maxScrollExtent,
              ),
            );
          });
        }
        return SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: beforeNote,
                child: Text.rich(
                  before,
                  key: const ValueKey('source-reading-text'),
                ),
              ),
              if (widget.note case final note?)
                KeyedSubtree(key: noteKey, child: note),
              if (split < text.length)
                Padding(
                  key: afterNote,
                  padding: const EdgeInsets.only(top: 10),
                  child: Text.rich(after),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReflectionNote extends StatelessWidget {
  const _ReflectionNote({
    this.controller,
    required this.focus,
    this.text,
    this.onEdit,
  });

  final TextEditingController? controller;
  final FocusNode focus;
  final String? text;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final field = controller;
    if (field == null && text == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: onEdit, child: const Text('느낀 점 남기기')),
      );
    }
    final lineHeight = MediaQuery.textScalerOf(context).scale(27) * 1.24;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: CustomPaint(size: Size(24, 22), painter: ReflectionArrow()),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: CustomPaint(
              painter: _NotebookLines(lineHeight),
              child: field == null
                  ? Semantics(
                      button: onEdit != null,
                      hint: '느낀 점 고치기',
                      child: InkWell(
                        onTap: onEdit,
                        child: Transform.rotate(
                          angle: -.014,
                          alignment: Alignment.topLeft,
                          child: Text(text ?? '', style: reflectionHandwriting),
                        ),
                      ),
                    )
                  : Semantics(
                      label: '느낀 점 입력',
                      child: WritingCaret(
                        controller: field,
                        focusNode: focus,
                        color: reflectionGraphite,
                        builder: (focus, scroll) => TextField(
                          key: const ValueKey('original-reflection-input'),
                          controller: field,
                          focusNode: focus,
                          scrollController: scroll,
                          showCursor: false,
                          autofocus: true,
                          onTapOutside: (_) => focus.unfocus(),
                          minLines: 2,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          style: reflectionHandwriting,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: '이 문장이 남긴 생각',
                            hintStyle: reflectionHandwriting.copyWith(
                              color: reflectionGraphite.withValues(alpha: .62),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotebookLines extends CustomPainter {
  const _NotebookLines(this.lineHeight);
  final double lineHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = const Color(0x287a593c)
      ..strokeWidth = .75;
    for (var y = lineHeight - 1; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
  }

  @override
  bool shouldRepaint(_NotebookLines oldDelegate) =>
      oldDelegate.lineHeight != lineHeight;
}
