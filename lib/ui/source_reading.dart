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
import 'paper_panel.dart';
import 'original_edit.dart';
import 'original_photo.dart';
import 'source_browser.dart';
import 'paper_search_field.dart';
import 'original_range_sheet.dart';
import 'pencil_marks.dart';
import 'reading_details.dart';
import 'reflection_ink.dart';
import 'search_completions.dart';
import 'writing_pen.dart';

class SourceReading extends StatefulWidget {
  const SourceReading({
    super.key,
    required this.originals,
    this.match,
    this.initialOriginalId,
    this.previousCitations = const [],
    this.onReadOriginal,
    this.style = const WritingStyle(),
    this.onRegister,
    this.writingLocations = const {},
    this.onTranscribe,
    this.onOpenWriting,
    this.onRetry,
    this.onSaveReflection,
    this.onSaveRange,
    this.onDelete,
    this.onEdit,
  });

  final List<RegisteredOriginal> originals;
  final OriginalMatch? match;
  final String? initialOriginalId;
  final List<String> previousCitations;
  final ValueChanged<String>? onReadOriginal;
  final WritingStyle style;
  final Future<RegisteredOriginal?> Function()? onRegister;
  final Map<String, ({Passage passage, bool marked})> writingLocations;
  final ValueChanged<RegisteredOriginal>? onTranscribe;
  final ValueChanged<Passage>? onOpenWriting;
  final VoidCallback? onRetry;
  final Future<bool> Function(RegisteredOriginal, PencilMark?)? onSaveRange;
  final Future<bool> Function(RegisteredOriginal)? onDelete;
  final Future<RegisteredOriginal?> Function(
    RegisteredOriginal,
    String,
    String,
  )?
  onEdit;
  final Future<bool> Function(RegisteredOriginal, OriginalReflection?)?
  onSaveReflection;

  @override
  State<SourceReading> createState() => _SourceReadingState();
}

class _SourceReadingState extends State<SourceReading> {
  late String? selectedId = widget.initialOriginalId;
  final searchField = TextEditingController();
  final searchFocus = FocusNode(debugLabel: 'saved original search');
  bool showSearch = false;
  String query = '';
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

  Iterable<String> _searchFields(Iterable<RegisteredOriginal> originals) sync* {
    for (final item in originals) {
      yield* item.citation.split(' · ');
      yield item.text.replaceAll(_previewWhitespace, ' ');
    }
  }

  void _open(String id) {
    searchFocus.unfocus();
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

  void _toggleSearch(bool searching) {
    if (searching) {
      searchFocus.unfocus();
      searchField.clear();
      setState(() {
        showSearch = false;
        query = '';
      });
    } else {
      setState(() {
        selectedId = null;
        showSearch = true;
      });
      searchFocus.requestFocus();
    }
  }

  Future<void> _register() async {
    searchFocus.unfocus();
    final registered = await widget.onRegister!();
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
    searchField.dispose();
    searchFocus.dispose();
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

  Future<void> _editOriginal(RegisteredOriginal original, Color color) async {
    if (!_canLeave) return;
    final saved = await Navigator.of(context).push(
      paperPanelRoute<RegisteredOriginal>(
        (_) => OriginalEdit(
          original: original,
          color: color,
          style: widget.style,
          onSave: (text, citation) => widget.onEdit!(original, text, citation),
        ),
        color: color,
      ),
    );
    if (mounted && saved != null) _open(saved.id);
  }

  Future<void> _delete(RegisteredOriginal original) async {
    if (!_canLeave || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('원문을 삭제할까요?'),
        content: const Text('이 원문과 원문에 남긴 느낀 점이 삭제돼요. 이미 작성한 필사는 남아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('삭제', style: TextStyle(color: burgundy)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_canLeave) return;
    setState(() => saving = true);
    var deleted = false;
    try {
      deleted = await widget.onDelete!(original);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          if (deleted) selectedId = null;
        });
      }
    }
    if (mounted && !deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원문을 삭제하지 못했어요. 다시 시도해 주세요.')),
      );
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

  Future<void> _showPhoto(String id) => showOriginalPhoto(
    context,
    id,
    color: panelPaperColor(paperColors[widget.style.paperIndex]),
  );

  Future<void> _showCitations() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('이 쪽에 남긴 출처'),
      content: SingleChildScrollView(
        child: SelectableText(widget.previousCitations.join('\n\n')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final original = widget.originals
        .where((item) => item.id == selectedId)
        .firstOrNull;
    final previousMatch = widget.match;
    final match =
        previousMatch != null &&
            original?.id == previousMatch.original.id &&
            original?.text == previousMatch.original.text
        ? previousMatch
        : null;
    final reflection = original?.reflection;
    final searching = original == null && showSearch;
    final pattern = searching ? originalSearchPattern(query) : null;
    final scopedOriginals = markedOnly
        ? widget.originals.where(_isMarked)
        : widget.originals;
    final visibleOriginals =
        scopedOriginals
            .where(
              (item) =>
                  pattern == null ||
                  pattern.hasMatch(item.citation) ||
                  pattern.hasMatch(item.text),
            )
            .indexed
            .toList()
          ..sort((a, b) {
            final byDate = (b.$2.registeredAt ?? 0).compareTo(
              a.$2.registeredAt ?? 0,
            );
            return byDate == 0 ? b.$1.compareTo(a.$1) : byDate;
          });
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
      child: PaperPanel(
        key: const ValueKey('source-paper'),
        color: panel,
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
                      icon: const Icon(CupertinoIcons.chevron_left, size: 19),
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .42,
                      ),
                      child: TextButton.icon(
                        onPressed: saving ? null : _register,
                        icon: const Icon(CupertinoIcons.plus, size: 16),
                        label: const Text('원문 등록', textAlign: TextAlign.center),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => _navigate(() => Navigator.pop(context)),
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
              const Divider(),
              if (original == null && widget.originals.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () => _toggleSearch(searching),
                        icon: Icon(
                          searching
                              ? CupertinoIcons.xmark
                              : CupertinoIcons.search,
                          size: 16,
                        ),
                        label: Text(searching ? '검색 닫기' : '원문 검색'),
                      ),
                      FilterChip(
                        label: const Text('밑칠만 보기'),
                        avatar: markedOnly
                            ? null
                            : const Icon(
                                CupertinoIcons.line_horizontal_3_decrease,
                                size: 15,
                              ),
                        backgroundColor: Colors.transparent,
                        selectedColor: panelSelectedColor(panel),
                        selected: markedOnly,
                        onSelected: (value) =>
                            setState(() => markedOnly = value),
                      ),
                    ],
                  ),
                ),
              if (searching)
                PaperSearchField(
                  fieldKey: const ValueKey('saved-original-search'),
                  controller: searchField,
                  focusNode: searchFocus,
                  hint: '원문 내용이나 출처 찾기',
                  onSubmitted: (_) => searchFocus.unfocus(),
                  onChanged: (value) => setState(() => query = value),
                ),
              if (searching)
                Flexible(
                  child: SearchCompletions(
                    controller: searchField,
                    focusNode: searchFocus,
                    options: (query) => searchCompletions(
                      query.replaceAll(_previewWhitespace, ' '),
                      _searchFields(scopedOriginals),
                    ),
                    onSelected: (value) => setState(() => query = value),
                  ),
                ),
              if (original == null && widget.originals.isNotEmpty)
                const SizedBox(height: 4),
              if (original != null &&
                  !editing &&
                  (original.photoId != null ||
                      original.isFullPage ||
                      widget.onDelete != null ||
                      widget.onEdit != null))
                Row(
                  children: [
                    Expanded(
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
                    if (widget.onEdit != null || widget.onDelete != null)
                      PopupMenuButton<_OriginalAction>(
                        tooltip: '원문 더 보기',
                        icon: const Icon(CupertinoIcons.ellipsis, size: 19),
                        enabled: !saving,
                        itemBuilder: (_) => [
                          if (widget.onEdit != null)
                            const PopupMenuItem(
                              value: _OriginalAction.edit,
                              child: Text('원문 수정'),
                            ),
                          if (widget.onDelete != null)
                            const PopupMenuItem(
                              value: _OriginalAction.delete,
                              child: Text(
                                '원문 삭제',
                                style: TextStyle(color: burgundy),
                              ),
                            ),
                        ],
                        onSelected: (action) => switch (action) {
                          _OriginalAction.edit => _editOriginal(
                            original,
                            panel,
                          ),
                          _OriginalAction.delete => _delete(original),
                        },
                      ),
                  ],
                ),
              if (widget.onRetry != null && !editing)
                TextButton(
                  onPressed: widget.onRetry,
                  child: const Text('저장 실패 · 다시 저장'),
                ),
              if (original == null && widget.previousCitations.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _showCitations,
                    child: const Text('이 쪽에 남긴 출처'),
                  ),
                ),
              Expanded(
                child: original != null
                    ? original.text.trim().isEmpty && original.photoId != null
                          ? Semantics(
                              button: true,
                              label: '원본 사진 크게 보기',
                              child: InkWell(
                                onTap: saving
                                    ? null
                                    : () => _showPhoto(original.photoId!),
                                child: OriginalPhoto(
                                  id: original.photoId!,
                                  region: original.photoRegion,
                                ),
                              ),
                            )
                          : _OriginalText(
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
                          pattern != null
                              ? '일치하는 원문이 없어요.'
                              : markedOnly
                              ? '밑칠한 구절이 없어요.'
                              : '등록한 원문이 없습니다.',
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final (index, (_, item))
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
                                      _originalPreview(item, pattern),
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
                                            (!item.canTranscribe &&
                                                item.text.isEmpty)
                                        ? null
                                        : Text(
                                            item.citation,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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
                      if (RegisteredOriginal.webLink(original.citation)
                          case final Uri link when original.text.trim().isEmpty)
                        TextButton(
                          onPressed: () => openSourceBrowser(
                            context,
                            url: link,
                            title: '원문 링크',
                            launchLabel: '링크 열기',
                            hasCitation: true,
                          ),
                          child: const Text('링크 열기'),
                        ),
                      if (widget.onTranscribe != null && original.canTranscribe)
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
    );
  }
}

enum _OriginalAction { edit, delete }

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

String _originalPreview(RegisteredOriginal item, RegExp? pattern) {
  if (item.text.trim().isEmpty) {
    if (item.photoId != null) return '원본 사진';
    return item.citation;
  }
  final text = item.text.replaceAll(_previewWhitespace, ' ').trim();
  final match = pattern?.firstMatch(text);
  return match == null ? text : searchExcerpt(text, match.start, match.end);
}

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
