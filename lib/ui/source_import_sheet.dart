import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/book_detail_style.dart';
import '../source/scan_passage.dart';
import '../source/source_intake.dart';
import '../source/source_scan.dart';
import 'book_details.dart';
import 'paper.dart';
import 'source_scan_preview.dart';

typedef SourceImportResult = ({
  List<String> passages,
  String citation,
  String? bookId,
});

enum _ScanMode { page, paragraph }

class SourceImportSheet extends StatefulWidget {
  const SourceImportSheet({
    super.key,
    required this.intake,
    required this.initialText,
    required this.choice,
    this.initialPhoto,
    this.initialCitation = '',
    this.shared = false,
    this.registration = false,
    this.books = const {},
    this.bookId,
    this.allowUnbound = true,
  });

  final SourceIntake intake;
  final String initialText, initialCitation;
  final BookDetailChoice choice;
  final SourcePhoto? initialPhoto;
  final bool shared, registration, allowUnbound;
  final Map<String, String> books;
  final String? bookId;

  @override
  State<SourceImportSheet> createState() => _SourceImportSheetState();
}

class _SourceImportSheetState extends State<SourceImportSheet> {
  late final _text = TextEditingController(text: widget.initialText)
    ..addListener(_changed);
  final _focus = FocusNode();
  late final _citation = TextEditingController(text: widget.initialCitation)
    ..addListener(_changed);
  late String? _bookId = widget.bookId;
  final _editors = <TextEditingController>[];
  List<List<ScanLine>> _reviewLines = const [];
  List<(_ScanMode, int, String)> _reviewKeys = const [];
  final _savedReviews = <(_ScanMode, int, String), String>{};
  SourceScan? _scan;
  _ScanMode _mode = _ScanMode.page;
  List<int> _order = [];
  Set<int> _selected = {};
  int? _paragraph;
  int _first = 0, _last = 0;
  String? _reread;
  String? _error;
  bool _busy = false, _readingPhoto = false;

  bool get _reviewing => _editors.isNotEmpty;
  bool get _selecting => _scan != null && !_reviewing;
  List<TextEditingController> get _fields => _reviewing ? _editors : [_text];
  bool get _composing => [
    ..._fields,
    _citation,
  ].any((c) => c.value.isComposingRangeValid && !c.value.composing.isCollapsed);
  bool get _editable => !_busy && !_composing;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoto case final photo?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _read(photo, _ScanMode.page);
      });
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    if (_readingPhoto) widget.intake.cancelRecognition();
    for (final controller in [_text, _citation, ..._editors]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    if (!_editable) return;
    final beforePaste = _text.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final text = normalizeSource(data?.text ?? '');
      if (text.isEmpty) {
        setState(() => _error = '복사한 문장이 없어요. 문장을 복사한 뒤 붙여넣어 주세요.');
      } else if (text.length > sourceLengthLimit) {
        setState(() => _error = '원문이 너무 길어요. 옮겨 쓸 구절만 골라 주세요.');
      } else if (_text.text != beforePaste) {
        setState(() => _error = '입력한 원문을 유지했어요. 다시 붙여넣어 주세요.');
      } else if (!_composing) {
        _text.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '붙여넣지 못했어요. 입력칸을 눌러 키보드로 붙여넣어 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('다른 앱에서 공유'),
      content: Text(
        widget.intake.canUseCamera
            ? '다른 앱에서 문장을 고르고 공유 메뉴의 ‘쓰는 인간’을 누르세요. 앱으로 돌아오면 받은 문장을 확인할 수 있어요.'
            : '다른 앱에서 문장을 복사한 뒤 이 화면에서 붙여넣으세요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  Future<void> _choosePhoto(_ScanMode mode) async {
    if (!_editable) return;
    FocusScope.of(context).unfocus();
    final camera = widget.intake.canUseCamera
        ? await showDialog<bool>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(mode == _ScanMode.page ? '책 한 페이지 인식' : '문단 인식'),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('사진 찍기'),
                ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('사진 고르기'),
                ),
              ],
            ),
          )
        : false;
    if (!mounted || camera == null || !_editable) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await widget.intake.pickPhoto(camera: camera);
      if (photo != null && mounted) await _read(photo, mode);
    } on SourceIntakeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '사진을 가져오지 못했어요. 권한을 확인하거나 다른 사진을 골라 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<SourceScan?> _recognize(
    SourcePhoto photo, {
    Rect? region,
    List<Rect> mask = const [],
  }) async {
    setState(() {
      _busy = true;
      _readingPhoto = true;
      _error = null;
    });
    try {
      final scan = await widget.intake
          .scan(photo, region: region, mask: mask)
          .timeout(const Duration(seconds: 90));
      if (!mounted) return null;
      if (scan.paragraphs.isEmpty) {
        setState(() => _error = '읽을 수 있는 글자가 없어요. 구절이 선명한 사진을 골라 주세요.');
        return null;
      }
      return scan;
    } on SourceIntakeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      widget.intake.cancelRecognition();
      if (mounted) {
        setState(() => _error = '글자를 읽지 못했어요. 다시 시도하거나 원문을 붙여넣어 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _readingPhoto = false;
          _busy = false;
        });
      }
    }
    return null;
  }

  Future<void> _read(SourcePhoto photo, _ScanMode mode) async {
    final scan = await _recognize(photo);
    if (scan == null || !mounted) return;
    setState(() {
      _scan = scan;
      _savedReviews.clear();
      _mode = mode;
      _reread = null;
      _paragraph = null;
      _order = scan.pageReadingOrder;
      _selected = _order.toSet();
    });
  }

  void _pickParagraph(int index) {
    final passage = ScanPassage(_scan!.paragraphs[index]);
    setState(() {
      _paragraph = index;
      _first = 0;
      _last = passage.terms.length - 1;
      _reread = null;
    });
  }

  void _toggle(int index, bool selected) => setState(() {
    if (selected) {
      _selected.add(index);
    } else {
      _selected.remove(index);
    }
  });

  void _tapPhoto(Offset point) {
    final scan = _scan!;
    final hits = _order.where(
      (index) => scan.paragraphs[index].lines.any(
        (line) => line.bounds?.inflate(.012).contains(point) ?? false,
      ),
    );
    final index =
        hits.firstOrNull ??
        _order
            .where(
              (index) =>
                  scan.paragraphs[index].bounds?.contains(point) ?? false,
            )
            .firstOrNull;
    if (index == null) return;
    if (_mode == _ScanMode.paragraph) {
      _pickParagraph(index);
    } else {
      _toggle(index, !_selected.contains(index));
    }
  }

  void _move(int index, int delta) => setState(() {
    final from = _order.indexOf(index);
    _order.insert(from + delta, _order.removeAt(from));
  });

  ScanPassage? get _passage =>
      _paragraph == null ? null : ScanPassage(_scan!.paragraphs[_paragraph!]);

  Future<void> _readRegion(ScanPassage passage) async {
    final boxes = passage.lineBoxes(_first, _last);
    if (boxes.isEmpty || _busy) return;
    final bounds = boxes.reduce((a, b) => a.expandToInclude(b));
    final region = bounds.inflate(.007).intersect(scanPageBounds);
    final scan = _scan!;
    final result = await _recognize(
      SourcePhoto('', scan.photo),
      region: region,
      mask: boxes.map((box) => box.inflate(.003)).toList(),
    );
    if (mounted && result != null) {
      setState(
        () => _reread = result.paragraphs.map((p) => p.text).join('\n\n'),
      );
    }
  }

  void _reviewSelection() {
    if (_busy) return;
    final paragraphs = _scan!.paragraphs;
    final passage = _passage;
    final texts = _mode == _ScanMode.page
        ? [
            for (final index in _order.where(_selected.contains))
              paragraphs[index].text,
          ]
        : [if (passage != null) _reread ?? passage.select(_first, _last)];
    if (texts.isEmpty) return;
    if (texts.join('\n\n').length > sourceLengthLimit) {
      setState(() => _error = '옮겨 쓸 문단을 조금 더 좁혀 주세요.');
      return;
    }
    final indices = _mode == _ScanMode.page
        ? _order.where(_selected.contains).toList()
        : [_paragraph!];
    setState(() {
      _reviewKeys = [
        for (final (i, text) in texts.indexed) (_mode, indices[i], text),
      ];
      _editors.addAll(
        _reviewKeys.map(
          (key) =>
              TextEditingController(text: _savedReviews[key] ?? key.$3)
                ..addListener(_changed),
        ),
      );
      _reviewLines = [for (final index in indices) paragraphs[index].lines];
      _error = null;
    });
  }

  void _backToSelection() {
    if (!_editable) return;
    FocusScope.of(context).unfocus();
    final previous = List.of(_editors);
    setState(() {
      for (final (i, editor) in previous.indexed) {
        _savedReviews[_reviewKeys[i]] = editor.text;
        editor.removeListener(_changed);
      }
      _editors.clear();
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final editor in previous) {
        editor.dispose();
      }
    });
  }

  void _submit() {
    final passages = _fields
        .map((c) => normalizeSource(c.text))
        .where((text) => text.isNotEmpty)
        .toList();
    if (!_editable ||
        passages.isEmpty ||
        passages.join('\n\n').length > sourceLengthLimit) {
      return;
    }
    Navigator.pop<SourceImportResult>(context, (
      passages: passages,
      citation: _citation.text.trim(),
      bookId: _bookId,
    ));
  }

  Future<void> _joinLines(TextEditingController field) async {
    if (!_editable) return;
    final original = field.text;
    final joined = original.replaceAll(
      RegExp(r'[^\S\n]*\n(?!\n)[^\S\n]*(?=\S)'),
      ' ',
    );
    if (joined == original) return;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('줄바꿈 정리'),
        content: SingleChildScrollView(child: Text(joined)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );
    if (apply == true && mounted && _editable && field.text == original) {
      field.text = joined;
    }
  }

  Widget _methodButtons() => Wrap(
    spacing: 8,
    children: [
      TextButton.icon(
        onPressed: _editable ? _focus.requestFocus : null,
        icon: const Icon(CupertinoIcons.pencil),
        label: const Text('텍스트 넣기'),
      ),
      TextButton.icon(
        onPressed: _editable ? _shareHelp : null,
        icon: const Icon(CupertinoIcons.share),
        label: const Text('다른 앱에서 공유'),
      ),
      TextButton.icon(
        key: const ValueKey('source-photo'),
        onPressed: _editable ? () => _choosePhoto(_ScanMode.page) : null,
        icon: const Icon(CupertinoIcons.doc_text_viewfinder),
        label: const Text('책 한 페이지 인식'),
      ),
      TextButton.icon(
        key: const ValueKey('source-paragraph-photo'),
        onPressed: _editable ? () => _choosePhoto(_ScanMode.paragraph) : null,
        icon: const Icon(CupertinoIcons.viewfinder),
        label: const Text('문단 인식'),
      ),
    ],
  );

  String? _blockLabel(ScanParagraph block) {
    final bounds = block.bounds;
    if (bounds == null) return null;
    if ((bounds.top > .84 || bounds.bottom < .16) &&
        RegExp(r'^[\s\d–—-]+$').hasMatch(block.text)) {
      return '쪽 번호 후보';
    }
    if (bounds.top > .78 &&
        block.lines.every((line) => (line.bounds?.height ?? 1) < .025)) {
      return '각주 후보';
    }
    if (bounds.top < .18 && block.lines.length == 1 && bounds.height > .05) {
      return '제목 후보';
    }
    return null;
  }

  List<Widget> _selectionPanel() {
    final scan = _scan!;
    final pageMode = _mode == _ScanMode.page;
    final passage = _passage;
    final selectedBoxes = pageMode
        ? [
            for (final i in _selected)
              for (final line in scan.paragraphs[i].lines) ?line.bounds,
          ]
        : passage?.boxes(_first, _last) ?? [];
    return [
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('한 페이지'),
            selected: pageMode,
            onSelected: _busy
                ? null
                : (_) => setState(() => _mode = _ScanMode.page),
          ),
          ChoiceChip(
            label: const Text('문단'),
            selected: !pageMode,
            onSelected: _busy
                ? null
                : (_) => setState(() => _mode = _ScanMode.paragraph),
          ),
          TextButton(
            onPressed: _editable ? () => _choosePhoto(_mode) : null,
            child: const Text('다른 사진'),
          ),
        ],
      ),
      Text(pageMode ? '남길 문단을 고르고 읽는 순서를 확인하세요.' : '사진이나 목록에서 원하는 문단을 고르세요.'),
      const SizedBox(height: 6),
      SourceScanPreview(
        scan: scan,
        selection: selectedBoxes,
        onTap: _busy ? null : _tapPhoto,
      ),
      if (pageMode)
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(
                  () => _selected = _selected.length == _order.length
                      ? {}
                      : _order.toSet(),
                ),
          child: Text(_selected.length == _order.length ? '모두 해제' : '모두 선택'),
        ),
      if (!pageMode && passage != null) ...[
        if (passage.terms.length > 1)
          RangeSlider(
            key: const ValueKey('source-word-range'),
            values: RangeValues(_first.toDouble(), _last.toDouble()),
            max: (passage.terms.length - 1).toDouble(),
            divisions: passage.terms.length - 1,
            semanticFormatterCallback: (value) => '${value.round() + 1}번째 단어',
            onChanged: _busy
                ? null
                : (range) => setState(() {
                    _first = range.start.round();
                    _last = range.end.round();
                    _reread = null;
                  }),
          ),
        Text(
          _reread ?? passage.select(_first, _last),
          key: const ValueKey('source-selected-passage'),
        ),
        if (_reread != null)
          TextButton(
            onPressed: _busy ? null : () => setState(() => _reread = null),
            child: const Text('처음 인식 결과 보기'),
          ),
        if (selectedBoxes.isNotEmpty)
          TextButton(
            onPressed: _busy ? null : () => _readRegion(passage),
            child: const Text('선택 영역 다시 읽기'),
          ),
      ],
      for (final (position, index) in _order.indexed)
        if (pageMode)
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  key: ValueKey('source-paragraph-$index'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    scan.paragraphs[index].text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: switch (_blockLabel(scan.paragraphs[index])) {
                    final label? => Text(label),
                    null => null,
                  },
                  value: _selected.contains(index),
                  onChanged: _busy
                      ? null
                      : (checked) => _toggle(index, checked == true),
                ),
              ),
              if (_order.length > 1)
                Column(
                  children: [
                    IconButton(
                      tooltip: '${position + 1}번째 문단을 위로',
                      icon: const Icon(CupertinoIcons.chevron_up, size: 15),
                      onPressed: position == 0 || _busy
                          ? null
                          : () => _move(index, -1),
                    ),
                    IconButton(
                      tooltip: '${position + 1}번째 문단을 아래로',
                      icon: const Icon(CupertinoIcons.chevron_down, size: 15),
                      onPressed: position == _order.length - 1 || _busy
                          ? null
                          : () => _move(index, 1),
                    ),
                  ],
                ),
            ],
          )
        else
          ListTile(
            key: ValueKey('source-pick-paragraph-$index'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _paragraph == index
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
            ),
            selected: _paragraph == index,
            title: Text(
              scan.paragraphs[index].text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: _busy ? null : () => _pickParagraph(index),
          ),
    ];
  }

  Widget _field(TextEditingController controller, int index) => SourceSlip(
    choice: widget.choice,
    compact: true,
    child: TextField(
      key: index == 0
          ? const ValueKey('source-text')
          : ValueKey('source-review-text-$index'),
      controller: controller,
      focusNode: index == 0 ? _focus : null,
      minLines: _reviewing ? 2 : 4,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        hintText: '옮겨 쓸 구절을 붙여넣거나 적어 주세요.',
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        filled: false,
      ),
    ),
  );

  Future<void> _compareLine(ScanLine line, Rect bounds) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('사진과 대조'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SourceScanPreview(
              scan: _scan!,
              focus: bounds,
              selection: [
                for (final word in line.words)
                  if ((word.confidence ?? 1) < .65) ?word.bounds,
              ],
            ),
            const SizedBox(height: 12),
            Text(line.text),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );

  List<Widget> _reviewPanel() => [
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: _editable ? _backToSelection : null,
        child: const Text('문단 다시 고르기'),
      ),
    ),
    if (_editors.length > 1) Text('${_editors.length}개 문단을 각각 원문으로 저장합니다.'),
    for (final (index, controller) in _editors.indexed) ...[
      if (_editors.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('${index + 1}번째 원문'),
        ),
      _field(controller, index),
      Wrap(
        spacing: 6,
        children: [
          for (final (lineIndex, line) in _reviewLines[index].indexed)
            if (line.bounds case final bounds?)
              ActionChip(
                key: ValueKey('source-review-line-$index-$lineIndex'),
                avatar: Icon(
                  line.needsReview
                      ? CupertinoIcons.exclamationmark_circle
                      : CupertinoIcons.photo,
                  size: 16,
                ),
                label: Text(
                  '${lineIndex + 1}줄${line.needsReview ? ' 확인 필요' : ''}',
                ),
                tooltip: line.text,
                onPressed: _editable ? () => _compareLine(line, bounds) : null,
              ),
          TextButton(
            onPressed: _editable ? () => _joinLines(controller) : null,
            child: const Text('줄바꿈 정리'),
          ),
        ],
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final available = math.max(
      0.0,
      media.size.height - inset - media.padding.top,
    );
    final text = _fields
        .map((c) => normalizeSource(c.text))
        .where((value) => value.isNotEmpty)
        .join('\n\n');
    final canSubmit =
        _editable &&
        text.isNotEmpty &&
        text.length <= sourceLengthLimit &&
        _citation.text.trim().length <= 500;
    final selectionReady = _mode == _ScanMode.page
        ? _selected.isNotEmpty
        : _paragraph != null;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: math.min(680, available * .88),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selecting
                                ? '문단 고르기'
                                : _reviewing
                                ? '원문 확인'
                                : widget.shared
                                ? '공유한 원문'
                                : '원문 등록',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(CupertinoIcons.xmark, size: 19),
                        ),
                      ],
                    ),
                    if (!_selecting && !_reviewing && !widget.shared)
                      _methodButtons(),
                    if (_busy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 10),
                      Text(_readingPhoto ? '사진 속 글자를 읽고 있어요' : '원문을 가져오고 있어요'),
                    ],
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: const TextStyle(color: burgundy),
                          ),
                        ),
                      ),
                    if (_selecting)
                      ..._selectionPanel()
                    else if (_reviewing)
                      ..._reviewPanel()
                    else ...[
                      _field(_text, 0),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('source-paste'),
                          onPressed: _editable ? _paste : null,
                          icon: const Icon(
                            CupertinoIcons.doc_on_clipboard,
                            size: 17,
                          ),
                          label: const Text('붙여넣기'),
                        ),
                      ),
                    ],
                    if (text.length > sourceLengthLimit)
                      const Text('원문이 너무 길어요. 옮겨 쓸 구절만 남겨 주세요.'),
                    if (!_selecting &&
                        (widget.registration || widget.shared)) ...[
                      if (widget.books.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _bookId ?? '',
                          decoration: const InputDecoration(labelText: '보관할 책'),
                          isExpanded: true,
                          items: [
                            if (widget.allowUnbound)
                              const DropdownMenuItem(
                                value: '',
                                child: Text('책 없이 보관'),
                              ),
                            for (final book in widget.books.entries)
                              DropdownMenuItem(
                                value: book.key,
                                child: Text(
                                  book.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _editable
                              ? (id) => setState(
                                  () => _bookId = id == '' ? null : id,
                                )
                              : null,
                        ),
                      TextField(
                        key: const ValueKey('original-citation'),
                        controller: _citation,
                        decoration: InputDecoration(
                          labelText: _reviewing ? '쪽수 또는 출처 (선택)' : '출처 (선택)',
                          errorText: _citation.text.trim().length > 500
                              ? '출처를 조금 줄여 주세요.'
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('source-confirm'),
                    onPressed: _selecting
                        ? selectionReady && !_busy
                              ? _reviewSelection
                              : null
                        : canSubmit
                        ? _submit
                        : null,
                    child: Text(_selecting ? '선택한 문단 확인' : '저장'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
