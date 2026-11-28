import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/model.dart';
import '../data/library_search.dart';
import '../source/originals.dart';
import '../source/photo_lines.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'original_edit.dart';
import 'original_list_item.dart';
import 'original_photo.dart';
import 'original_reading_layout.dart';
import 'source_browser.dart';
import 'paper_search_field.dart';
import 'pencil_marks.dart';
import 'reflection_ink.dart';
import 'search_completions.dart';
import 'writing_pen.dart';

class SourceReading extends StatefulWidget {
  const SourceReading({
    super.key,
    required this.originals,
    required this.transcribeLabel,
    this.match,
    this.initialOriginalId,
    this.bookTitle,
    this.previousCitations = const [],
    this.onReadOriginal,
    this.style = const WritingStyle(),
    this.onRegister,
    this.onFind,
    this.writingLocations = const {},
    this.onTranscribe,
    this.onExtractPhoto,
    this.onOpenWriting,
    this.onSetPosition,
    this.onRetry,
    this.onSaveReflection,
    this.onDelete,
    this.onEdit,
  });

  final List<RegisteredOriginal> originals;
  final String transcribeLabel;
  final OriginalMatch? match;
  final String? initialOriginalId, bookTitle;
  final List<String> previousCitations;
  final ValueChanged<String>? onReadOriginal;
  final WritingStyle style;
  final Future<RegisteredOriginal?> Function()? onRegister;
  final Future<RegisteredOriginal?> Function()? onFind;
  final Map<String, ({Passage passage, bool marked})> writingLocations;
  final ValueChanged<RegisteredOriginal>? onTranscribe;
  final Future<RegisteredOriginal?> Function(RegisteredOriginal)?
  onExtractPhoto;
  final ValueChanged<Passage>? onOpenWriting;
  final Future<bool> Function(RegisteredOriginal, int)? onSetPosition;
  final VoidCallback? onRetry;
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
  String query = '';
  final reflectionField = TextEditingController();
  final reflectionFocus = FocusNode();
  final readingItem = GlobalKey();
  String? _readingId;
  bool _openedFromList = false;
  RegisteredOriginal? _editingOriginal;
  Timer? _autosave;
  Future<void>? _inFlight;
  String _saved = '';
  bool _leaveEditor = false;
  bool saving = false, failed = false, markedOnly = false;
  bool _choosingPosition = false, _positionFailed = false;
  int? _sourcePosition;
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

  void _clearSearch() {
    searchField.clear();
    searchFocus.unfocus();
    setState(() => query = '');
  }

  void _open(String id, {bool fromList = false}) {
    searchFocus.unfocus();
    setState(() {
      selectedId = id;
      _openedFromList = fromList;
    });
    widget.onReadOriginal?.call(id);
  }

  void _showList() {
    final restoreScrollOffset = _openedFromList;
    setState(() {
      _readingId = selectedId;
      _openedFromList = false;
      if (markedOnly &&
          !widget.originals.any(
            (item) => item.id == selectedId && _isMarked(item),
          )) {
        markedOnly = false;
      }
      selectedId = null;
    });
    if (restoreScrollOffset) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final item = readingItem.currentContext;
      if (item != null) Scrollable.ensureVisible(item, alignment: .35);
    });
  }

  Future<void> _register({bool find = false}) async {
    searchFocus.unfocus();
    final registered = await (find ? widget.onFind! : widget.onRegister!)();
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
          (match != null && match.end > match.start
              ? PencilMark(match.start, match.end)
              : null);
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

  Future<void> _extractPhoto(RegisteredOriginal original) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final updated = await widget.onExtractPhoto!(original);
      if (mounted && updated != null) _open(updated.id);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _showPhoto(RegisteredOriginal original) =>
      showOriginalPhoto(context, original.photoId!, color: originalPanelColor);

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

  Widget _saveNotice(String message, VoidCallback? onRetry) => Row(
    children: [
      Expanded(child: Semantics(liveRegion: true, child: Text(message))),
      TextButton(onPressed: onRetry, child: const Text('다시 저장')),
    ],
  );

  void _stopChoosingPosition() => setState(() {
    _choosingPosition = false;
    _positionFailed = false;
    _sourcePosition = null;
  });

  Future<void> _setPosition(RegisteredOriginal original) async {
    final offset = _sourcePosition;
    if (offset == null || saving) return;
    setState(() {
      saving = true;
      _positionFailed = false;
    });
    var saved = false;
    try {
      saved = await widget.onSetPosition!(original, offset);
    } on Exception {
      saved = false;
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          _positionFailed = !saved;
        });
      }
    }
  }

  Widget _originalMenu(RegisteredOriginal original) =>
      PopupMenuButton<_OriginalAction>(
        tooltip: '원문 더 보기',
        icon: const Icon(CupertinoIcons.ellipsis, size: 19),
        enabled: !saving,
        itemBuilder: (_) => [
          if (widget.onSetPosition != null &&
              original.id == widget.match?.original.id &&
              original.text == widget.match?.original.text)
            const PopupMenuItem(
              value: _OriginalAction.position,
              child: Text('필사 위치 고르기'),
            ),
          if (widget.onRegister != null)
            const PopupMenuItem(
              value: _OriginalAction.register,
              child: Text('원문 담기'),
            ),
          if (widget.onEdit != null)
            const PopupMenuItem(
              value: _OriginalAction.edit,
              child: Text('원문 수정'),
            ),
          if (widget.onDelete != null)
            const PopupMenuItem(
              value: _OriginalAction.delete,
              child: Text('원문 삭제', style: TextStyle(color: burgundy)),
            ),
        ],
        onSelected: (action) => switch (action) {
          _OriginalAction.position => setState(() => _choosingPosition = true),
          _OriginalAction.register => _register(),
          _OriginalAction.edit => _editOriginal(original, originalPanelColor),
          _OriginalAction.delete => _delete(original),
        },
      );

  Widget _findNewOriginal() => TextButton.icon(
    key: const ValueKey('originals-find-new'),
    onPressed: saving ? null : () => _register(find: true),
    icon: const Icon(CupertinoIcons.search, size: 17),
    label: const Text('새 원문 찾기'),
  );

  Widget _emptyLibrary() => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('담은 원문이 없어요.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (widget.onRegister != null)
            FilledButton.icon(
              onPressed: saving ? null : _register,
              icon: const Icon(CupertinoIcons.plus, size: 16),
              label: const Text('원문 담기'),
            ),
          if (widget.onFind != null) _findNewOriginal(),
        ],
      ),
    ),
  );

  Widget _writingPreview(RegisteredOriginal original, Passage resume) =>
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '쓴 글 · ${resume.excerpt.replaceAll(_previewWhitespace, ' ')}',
                key: ValueKey('original-writing-preview-${original.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.5, color: muted),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: TextButton(
                key: ValueKey('original-resume-${original.id}'),
                onPressed: saving || widget.onRetry != null
                    ? null
                    : () => widget.onOpenWriting!(resume),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('이어서 쓰기', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      );

  Widget _readingActions(RegisteredOriginal original) {
    final transcribe = widget.onTranscribe;
    final writing = widget.writingLocations[original.id]?.passage;
    final resume = original.canTranscribe && widget.onOpenWriting != null
        ? writing
        : null;
    final link = original.canTranscribe
        ? null
        : RegisteredOriginal.webLink(original.citation);
    void startTranscription() => transcribe!(original);

    final actions = <Widget>[
      if (resume != null)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('source-open-writing'),
            onPressed: saving ? null : () => widget.onOpenWriting!(resume),
            icon: const Icon(CupertinoIcons.book, size: 18),
            label: const Text('이어서 쓰기'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
          ),
        ),
      if (link != null)
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
      if (transcribe != null)
        original.canTranscribe && resume == null
            ? SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('source-start-transcription'),
                  onPressed: saving ? null : startTranscription,
                  icon: const Icon(CupertinoIcons.pencil, size: 18),
                  label: Text(
                    widget.transcribeLabel,
                    textAlign: TextAlign.center,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 56),
                  ),
                ),
              )
            : TextButton(
                onPressed: saving ? null : startTranscription,
                key: const ValueKey('source-start-transcription'),
                child: Text(
                  resume != null ? '새로 필사하기' : widget.transcribeLabel,
                ),
              ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        if (original.canTranscribe && transcribe != null && resume == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '새 글의 첫 쪽에서 시작해요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: muted),
            ),
          ),
        ...actions,
      ],
    );
  }

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
    final searching = original == null && widget.originals.isNotEmpty;
    final pattern = searching ? originalSearchPattern(query) : null;
    final bookTitle = widget.bookTitle?.trim() ?? '';
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
    final mark = editing ? draftMark : reflection?.mark;
    final note =
        original == null ||
            original.text.trim().isEmpty ||
            (!editing && reflection == null)
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
    final inlineNote = editing || reflection != null;
    final originalText = original == null
        ? null
        : _OriginalText(
            key: ValueKey(original.id),
            original: original,
            style: style,
            match: match,
            mark: mark,
            note: inlineNote && !_choosingPosition ? note : null,
            onPosition: !_choosingPosition || saving
                ? null
                : (offset) {
                    final range = match?.useWritingRange == true
                        ? original.writingRange
                        : null;
                    final start = range?.start ?? 0;
                    final end = range?.end ?? original.text.length;
                    final slice = original.text.substring(start, end);
                    final first = end - slice.trimLeft().length;
                    final next = offset >= first && offset < end
                        ? offset
                        : null;
                    if (next != _sourcePosition || _positionFailed) {
                      setState(() {
                        _sourcePosition = next;
                        _positionFailed = false;
                      });
                    }
                  },
            selecting: _choosingPosition,
            footer: !original.canTranscribe || editing || _choosingPosition
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SourceAttribution(
                        original: original,
                        onOpenPhoto: original.photoId == null || saving
                            ? null
                            : () => _showPhoto(original),
                        onAddCitation: widget.onEdit == null || saving
                            ? null
                            : () => _editOriginal(original, originalPanelColor),
                      ),
                    ],
                  ),
            editing: editing,
          );
    const panel = originalPanelColor;
    final internalBack = original != null && _openedFromList;
    final localBack = internalBack || _choosingPosition;
    void back() {
      if (_choosingPosition) {
        if (!saving) _stopChoosingPosition();
      } else if (internalBack) {
        _showList();
      } else {
        Navigator.pop(context);
      }
    }

    final resume = original == null
        ? null
        : widget.writingLocations[original.id]?.passage;
    final resumesOrigin =
        resume != null &&
        resume.page.id ==
            PaperNavigationScope.maybeOf(context)?.currentWritingPageId?.call();
    PaperNavigationScope.maybeOf(context)?.name(
      context,
      _choosingPosition
          ? '필사 위치'
          : original == null
          ? '원문 목록'
          : '원문',
    );
    return PopScope(
      canPop: _canLeave && !editing && !localBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !saving && !_composing && !failed) {
          unawaited(_navigate(back));
        }
      },
      child: PaperInternalBack(
        enabled: localBack && _canLeave && !editing,
        onBack: () => _navigate(back),
        child: PaperPanel(
          key: const ValueKey('source-paper'),
          color: panel,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, original == null ? 12 : 2, 24, 12),
            child: Column(
              children: [
                PaperHeaderRow(
                  children: [
                    PaperBackButton(
                      label: _choosingPosition
                          ? '원문'
                          : internalBack
                          ? '원문 목록'
                          : null,
                      enabled: !saving,
                      onPressed: () => _navigate(back),
                    ),
                    Expanded(
                      child: PaperPanelTitle(
                        _choosingPosition
                            ? '필사 위치'
                            : original != null &&
                                  !original.canTranscribe &&
                                  original.citation.trim().isNotEmpty
                            ? original.citation
                            : '원문',
                        fontSize: original == null ? 27 : 22,
                      ),
                    ),
                    if (original == null &&
                        widget.originals.isNotEmpty &&
                        widget.onRegister != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .42,
                        ),
                        child: TextButton.icon(
                          onPressed: saving ? null : _register,
                          icon: const Icon(CupertinoIcons.plus, size: 16),
                          label: const Text(
                            '원문 담기',
                            textAlign: TextAlign.center,
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    if (original != null &&
                        !editing &&
                        !_choosingPosition &&
                        (widget.onSetPosition != null ||
                            widget.onRegister != null ||
                            widget.onEdit != null ||
                            widget.onDelete != null))
                      _originalMenu(original),
                    if (!editing && !resumesOrigin && !_choosingPosition)
                      PaperWritingReturn(force: internalBack),
                  ],
                ),
                if (_choosingPosition)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('이어 쓸 글자의 앞을 눌러 주세요.'),
                  ),
                if (original != null && !internalBack && !_choosingPosition)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: '원문 목록',
                      child: TextButton(
                        onPressed: () => _navigate(_showList),
                        child: const Text('원문 목록'),
                      ),
                    ),
                  ),
                if (searching) ...[
                  const SizedBox(height: 10),
                  if (bookTitle.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        bookTitle,
                        style: const TextStyle(color: muted, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Divider(color: Color(0xffa58e70), height: 1),
                  const Divider(color: Color(0xffd1bda1), height: 5),
                  const SizedBox(height: 7),
                  LayoutBuilder(
                    builder: (context, box) {
                      final scale = MediaQuery.textScalerOf(context).scale(14);
                      final search = Row(
                        children: [
                          Expanded(
                            child: PaperSearchField(
                              fieldKey: const ValueKey('saved-original-search'),
                              controller: searchField,
                              focusNode: searchFocus,
                              hint: '담은 원문 찾기',
                              onSubmitted: (_) => searchFocus.unfocus(),
                              onChanged: (value) =>
                                  setState(() => query = value),
                            ),
                          ),
                          if (query.isNotEmpty)
                            IconButton(
                              tooltip: '검색 지우기',
                              onPressed: _clearSearch,
                              icon: const Icon(
                                CupertinoIcons.xmark_circle,
                                size: 17,
                              ),
                            ),
                        ],
                      );
                      final marks = FilterChip(
                        label: const Text('밑칠만 보기'),
                        avatar: markedOnly
                            ? null
                            : const Icon(CupertinoIcons.pencil, size: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        side: BorderSide(
                          color: markedOnly
                              ? brandInk
                              : const Color(0xffcab89f),
                        ),
                        backgroundColor: Colors.transparent,
                        selectedColor: panelSelectedColor(panel),
                        selected: markedOnly,
                        onSelected: (value) =>
                            setState(() => markedOnly = value),
                      );
                      if (box.maxWidth < 242 || scale > 20) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [search, marks],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 10),
                          marks,
                        ],
                      );
                    },
                  ),
                ] else
                  const Divider(),
                if (original == null && widget.originals.isNotEmpty)
                  const SizedBox(height: 14),
                if (widget.onRetry != null && !editing && !_choosingPosition)
                  _saveNotice('원문을 저장하지 못했어요.', widget.onRetry),
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
                      ? Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: original.canTranscribe
                              ? originalText!
                              : OriginalReadingLayout(
                                  original: original,
                                  onOpenPhoto:
                                      original.photoId == null || saving
                                      ? null
                                      : () => _showPhoto(original),
                                  child: originalText!,
                                ),
                        )
                      : widget.originals.isEmpty
                      ? _emptyLibrary()
                      : CustomScrollView(
                          key: const PageStorageKey('saved-original-list'),
                          slivers: [
                            SliverToBoxAdapter(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 48,
                                ),
                                child: SearchCompletions(
                                  controller: searchField,
                                  focusNode: searchFocus,
                                  options: (query) => searchCompletions(
                                    query.replaceAll(_previewWhitespace, ' '),
                                    _searchFields(scopedOriginals),
                                  ),
                                  onSelected: (value) =>
                                      setState(() => query = value),
                                ),
                              ),
                            ),
                            if (visibleOriginals.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    pattern != null
                                        ? '일치하는 원문이 없어요.'
                                        : '밑칠한 구절이 없어요.',
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(0, 2, 2, 16),
                                sliver: SliverList.builder(
                                  itemCount: visibleOriginals.length,
                                  itemBuilder: (context, index) {
                                    final item = visibleOriginals[index].$2;
                                    final resume =
                                        widget.onOpenWriting == null ||
                                            !item.canTranscribe
                                        ? null
                                        : widget
                                              .writingLocations[item.id]
                                              ?.passage;
                                    final card = OriginalListItem(
                                      key: item.id == _readingId
                                          ? readingItem
                                          : ValueKey(item.id),
                                      style: style,
                                      title: _originalPreview(item, pattern),
                                      subtitle:
                                          item.citation.isEmpty ||
                                              (!item.canTranscribe &&
                                                  item.photoId == null)
                                          ? null
                                          : item.citation,
                                      indexCard: true,
                                      photoId: item.photoId,
                                      showDivider: index > 0,
                                      onTap: () =>
                                          _open(item.id, fromList: true),
                                    );
                                    if (resume == null ||
                                        resume.excerpt.trim().isEmpty) {
                                      return card;
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        card,
                                        _writingPreview(item, resume),
                                      ],
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                ),
                if (original != null &&
                    original.photoId != null &&
                    !original.canTranscribe &&
                    widget.onExtractPhoto != null &&
                    !editing)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () => _extractPhoto(original),
                        icon: const Icon(
                          CupertinoIcons.doc_text_viewfinder,
                          size: 17,
                        ),
                        label: const Text(
                          '사진에서 글자 읽기',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                if (original != null && _choosingPosition) ...[
                  const Divider(height: 24),
                  if (_positionFailed)
                    Semantics(
                      liveRegion: true,
                      child: const Text('필사 위치를 저장하지 못했어요.'),
                    ),
                  FilledButton(
                    onPressed: saving || _sourcePosition == null
                        ? null
                        : () => _setPosition(original),
                    child: Text(_positionFailed ? '다시 저장' : '이 위치에서 이어 쓰기'),
                  ),
                ] else if (original != null && !editing)
                  _readingActions(original),
                if (failed && editing)
                  _saveNotice('느낀 점을 저장하지 못했어요.', _composing ? null : _flush),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _OriginalAction { position, register, edit, delete }

class _OriginalText extends StatefulWidget {
  const _OriginalText({
    super.key,
    required this.original,
    required this.style,
    this.match,
    this.mark,
    this.note,
    this.footer,
    required this.editing,
    this.selecting = false,
    this.onPosition,
  });

  final RegisteredOriginal original;
  final WritingStyle style;
  final OriginalMatch? match;
  final PencilMark? mark;
  final Widget? note, footer;
  final bool editing, selecting;
  final ValueChanged<int>? onPosition;

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
  return match == null
      ? searchExcerpt(text, 0, 50)
      : searchExcerpt(text, match.start, match.end);
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
    final boundaries = {
      from,
      to,
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
        size: style.fontSize,
        color: penColors[style.penIndex],
        useDevelopmentTypeface: style.useDevelopmentTypeface,
      ).copyWith(height: 1.8, letterSpacing: 0),
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
                : null,
          ),
      ],
    );
  }

  Widget _body(TextSpan span, int start, {Key? key}) {
    if (!widget.selecting) return Text.rich(span, key: key);
    return SelectableText.rich(
      span,
      key: key,
      showCursor: true,
      cursorWidth: 1.5,
      cursorColor: brandInk,
      contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      onSelectionChanged: (selection, cause) {
        if (selection.isValid && cause != null) {
          widget.onPosition?.call(start + selection.start);
        }
      },
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
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: beforeNote,
                child: _body(
                  before,
                  from,
                  key: const ValueKey('source-reading-text'),
                ),
              ),
              if (widget.note case final note?)
                KeyedSubtree(key: noteKey, child: note),
              if (split < text.length)
                Padding(
                  key: afterNote,
                  padding: const EdgeInsets.only(top: 10),
                  child: _body(after, split),
                ),
              if (widget.footer case final footer?)
                Padding(padding: const EdgeInsets.only(top: 24), child: footer),
            ],
          ),
        );
      },
    );
  }
}

/// Attribution stays with the passage; the small photograph opens its full original.
class _SourceAttribution extends StatelessWidget {
  const _SourceAttribution({
    required this.original,
    this.onOpenPhoto,
    this.onAddCitation,
  });
  final RegisteredOriginal original;
  final VoidCallback? onOpenPhoto, onAddCitation;

  Widget _photograph({required bool compact}) => Semantics(
    button: true,
    label: '원본 사진 보기',
    child: InkWell(
      key: const ValueKey('source-photo-preview'),
      onTap: onOpenPhoto,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: compact
            ? Row(
                children: [
                  SizedBox(width: 64, height: 72, child: _photo),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '원본 사진 보기',
                      style: TextStyle(fontSize: 14, color: brandInk),
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.arrow_up_left_arrow_down_right,
                    size: 14,
                    color: muted,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 80, child: _photo),
                  const SizedBox(height: 6),
                  const Text(
                    '원본 사진 보기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: brandInk,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget get _photo => DecoratedBox(
    decoration: BoxDecoration(
      color: paper,
      border: Border.all(color: line),
      boxShadow: [
        BoxShadow(
          color: brandInk.withValues(alpha: .10),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: OriginalPhoto(
        id: original.photoId!,
        region: originalPhotoPreviewRegion(original),
        compact: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final citation = original.citation.trim();
      final credit = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('출처', style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 6),
          if (citation.isNotEmpty)
            Text(
              citation,
              key: const ValueKey('source-attribution'),
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: brandInk,
              ),
            )
          else if (onAddCitation != null)
            TextButton(onPressed: onAddCitation, child: const Text('출처 남기기'))
          else
            const Text(
              '아직 남긴 출처가 없어요.',
              style: TextStyle(fontSize: 14, height: 1.6, color: muted),
            ),
        ],
      );
      final photo = original.photoId != null;
      final sideBySide =
          box.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18;
      return Padding(
        key: const ValueKey('source-details'),
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (photo && sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: credit),
                  const SizedBox(width: 16),
                  SizedBox(width: 112, child: _photograph(compact: false)),
                ],
              )
            else ...[
              credit,
              if (photo) ...[
                const SizedBox(height: 12),
                _photograph(compact: true),
              ],
            ],
          ],
        ),
      );
    },
  );
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
    if (field == null && text == null) return const SizedBox.shrink();
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
