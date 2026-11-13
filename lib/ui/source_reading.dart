import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/model.dart';
import '../data/original_photo_store.dart';
import '../source/originals.dart';
import 'book_details.dart';
import 'paper.dart';
import 'original_range_sheet.dart';
import 'pencil_marks.dart';
import 'reading_details.dart';
import 'reflection_ink.dart';

class SourceReading extends StatefulWidget {
  const SourceReading({
    super.key,
    required this.originals,
    this.match,
    this.style = const WritingStyle(),
    this.coverIndex,
    this.onRegister,
    this.onRetry,
    this.onSaveReflection,
    this.onSaveRange,
  });

  final List<RegisteredOriginal> originals;
  final OriginalMatch? match;
  final WritingStyle style;
  final int? coverIndex;
  final VoidCallback? onRegister;
  final VoidCallback? onRetry;
  final Future<bool> Function(RegisteredOriginal, PencilMark?)? onSaveRange;
  final Future<bool> Function(RegisteredOriginal, OriginalReflection)?
  onSaveReflection;

  @override
  State<SourceReading> createState() => _SourceReadingState();
}

class _SourceReadingState extends State<SourceReading> {
  late String? selectedId = widget.match?.original.id;
  final reflectionField = TextEditingController();
  bool editing = false, saving = false, failed = false;
  PencilMark? draftMark;

  @override
  void dispose() {
    reflectionField.dispose();
    super.dispose();
  }

  void _loadReflection(RegisteredOriginal original, OriginalMatch? match) {
    reflectionField.text = original.reflection?.text ?? '';
    final opening = original.text.trimLeft();
    final firstLine = opening.split('\n').first;
    final openingLength = firstLine.characters
        .take(18)
        .toString()
        .trimRight()
        .length;
    final openingStart = original.text.length - opening.length;
    draftMark =
        original.reflection?.mark ??
        (match == null
            ? PencilMark(openingStart, openingStart + openingLength)
            : PencilMark(match.start, match.end));
  }

  void _editReflection(RegisteredOriginal original, OriginalMatch? match) {
    _loadReflection(original, match);
    setState(() {
      editing = true;
      failed = false;
    });
  }

  void _cancelEdit() {
    setState(() {
      editing = false;
      failed = false;
    });
  }

  bool _canSave(TextEditingValue value) =>
      !saving &&
      value.text.trim().isNotEmpty &&
      (!value.isComposingRangeValid || value.composing.isCollapsed);

  Future<void> _save(RegisteredOriginal original) async {
    final draft = reflectionField.value;
    if (!_canSave(draft)) return;
    setState(() {
      saving = true;
      failed = false;
    });
    final success = await widget.onSaveReflection!(
      original,
      OriginalReflection(draft.text.trim(), mark: draftMark),
    );
    if (!mounted) return;
    if (success &&
        reflectionField.text == draft.text &&
        reflectionField.value.composing == draft.composing &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = false;
      failed = !success;
    });
  }

  Future<void> _changeRange(RegisteredOriginal original) async {
    final choice = await chooseOriginalRange(
      context,
      original.text,
      current: original.writingRange,
    );
    if (!mounted || choice == null || saving) return;
    setState(() => saving = true);
    try {
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
    final mark = editing ? draftMark : reflection?.mark;
    final note = editing || reflection != null
        ? _ReflectionNote(
            controller: editing ? reflectionField : null,
            text: reflection?.text,
          )
        : null;
    final keyboard = editing ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    final style = widget.style;
    final details = style.bookDetails;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: keyboard > 0 ? .92 : .54,
          child: PaperBackdrop(
            key: const ValueKey('source-paper'),
            binding: details.binding,
            color: paperColors[style.paperIndex],
            grainOpacity: paperGrainOpacity[style.paperIndex],
            coverIndex: widget.coverIndex,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (original != null && !editing)
                        IconButton(
                          tooltip: '원문 목록',
                          onPressed: () => setState(() => selectedId = null),
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
                      if (widget.onRegister != null && !editing)
                        TextButton(
                          onPressed: widget.onRegister,
                          child: const Text('원문 등록'),
                        ),
                      IconButton(
                        tooltip: '닫기',
                        onPressed: saving ? null : () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.xmark, size: 18),
                      ),
                    ],
                  ),
                  const Divider(),
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
                              icon: const Icon(CupertinoIcons.photo, size: 16),
                              label: const Text('원본 사진'),
                            ),
                          if (original.isFullPage && widget.onSaveRange != null)
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
                            key: ValueKey((original.id, editing)),
                            original: original,
                            style: style,
                            match: match,
                            mark: mark,
                            note: note,
                            editing: editing,
                          )
                        : widget.originals.isEmpty
                        ? const Center(child: Text('등록한 원문이 없습니다.'))
                        : ListView.separated(
                            itemCount: widget.originals.length,
                            separatorBuilder: (_, _) =>
                                details.recordDivider.enabled
                                ? RecordDivider(
                                    choice: details.recordDivider,
                                    compact: true,
                                  )
                                : const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = widget.originals[index];
                              return InkWell(
                                onTap: () =>
                                    setState(() => selectedId = item.id),
                                child: SourceSlip(
                                  compact: true,
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
                                        color: penColors[style.penIndex],
                                      ),
                                    ),
                                    subtitle:
                                        item.citation.isEmpty ||
                                            item.text.isEmpty
                                        ? null
                                        : Text(
                                            item.citation,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (failed && editing)
                    Semantics(
                      liveRegion: true,
                      child: const Text('느낀 점을 저장하지 못했어요. 다시 저장해 주세요.'),
                    ),
                  if (original != null &&
                      original.text.trim().isNotEmpty &&
                      widget.onSaveReflection != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: editing
                          ? ValueListenableBuilder<TextEditingValue>(
                              valueListenable: reflectionField,
                              builder: (context, value, _) => Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: saving ? null : _cancelEdit,
                                    child: const Text('취소'),
                                  ),
                                  FilledButton(
                                    onPressed: _canSave(value)
                                        ? () => _save(original)
                                        : null,
                                    child: Text(saving ? '저장 중' : '저장'),
                                  ),
                                ],
                              ),
                            )
                          : TextButton.icon(
                              icon: const Icon(CupertinoIcons.pencil, size: 16),
                              onPressed: () => _editReflection(original, match),
                              label: Text(
                                reflection == null ? '느낀 점 남기기' : '느낀 점 고치기',
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
      ),
      children: [
        for (var i = 0; i + 1 < boundaries.length; i++)
          TextSpan(
            text: text.substring(boundaries[i], boundaries[i + 1]),
            style:
                mark != null &&
                    boundaries[i] >= mark.start &&
                    boundaries[i] < mark.end
                ? pencilUnderlineStyle(pencil)
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
    final noteStart = mark?.end ?? 0;
    final sentenceEnd = widget.note == null
        ? null
        : _sentenceEnd.firstMatch(text.substring(noteStart));
    final split = sentenceEnd == null
        ? text.length
        : noteStart + sentenceEnd.end;
    final from = widget.editing && mark != null
        ? _sentenceEnd
                  .allMatches(text.substring(0, mark.start))
                  .lastOrNull
                  ?.end ??
              0
        : 0;
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
              ?widget.note,
              if (!widget.editing && split < text.length)
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
  const _ReflectionNote({this.controller, this.text});

  final TextEditingController? controller;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final field = controller;
    final lineHeight = MediaQuery.textScalerOf(context).scale(27) * 1.24;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CustomPaint(size: Size(24, 22), painter: ReflectionArrow()),
              const Icon(
                CupertinoIcons.pencil,
                color: reflectionGraphite,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text('느낀 점', style: reflectionHandwriting.copyWith(fontSize: 21)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: CustomPaint(
              painter: _NotebookLines(lineHeight),
              child: field == null
                  ? Transform.rotate(
                      angle: -.014,
                      alignment: Alignment.topLeft,
                      child: Text(text ?? '', style: reflectionHandwriting),
                    )
                  : Semantics(
                      label: '느낀 점 입력',
                      child: TextField(
                        key: const ValueKey('original-reflection-input'),
                        controller: field,
                        autofocus: true,
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
