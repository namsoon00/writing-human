import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/model.dart';
import '../data/original_photo_store.dart';
import '../source/camera_page.dart';
import '../source/ocr_photo_adjustment.dart';
import '../source/photo_lines.dart';
import '../source/scan_passage.dart';
import '../source/source_intake.dart';
import '../source/source_scan.dart';
import 'book_details.dart';
import 'paper.dart';
import 'original_photo_crop.dart';
import 'original_range_sheet.dart';
import 'original_text_cleanup.dart';
import 'source_scan_preview.dart';
import 'source_search.dart';
import 'writing_pen.dart';

typedef SourceImportResult = ({
  String text,
  bool isFullPage,
  PencilMark? writingRange,
  List<OriginalPhotoLine> photoLines,
  String? photoId,
  List<double>? photoRegion,
  String citation,
  String? bookId,
});

enum _ScanMode { page, paragraph }

enum _ImportAction { search, share }

class SourceImportSheet extends StatefulWidget {
  const SourceImportSheet({
    super.key,
    required this.intake,
    required this.initialText,
    required this.choice,
    this.initialPhoto,
    this.existingPhotoId,
    this.onSaveExtraction,
    this.initialPhotoRegion,
    this.paperColor = paper,
    this.penColor = ink,
    this.grainOpacity = .16,
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
  final Color paperColor, penColor;
  final double grainOpacity;
  final SourcePhoto? initialPhoto;
  final String? existingPhotoId;
  final Future<bool> Function(SourceImportResult)? onSaveExtraction;
  final List<double>? initialPhotoRegion;
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
  late SourcePhoto? _originalPhoto = widget.initialPhoto;
  late List<double>? _photoRegion = widget.initialPhotoRegion;
  Rect? _scanRegion;
  CameraPage? _cameraPage;
  SourceScan? _photoBeforeAdjustment;
  ({
    SourceScan? scan,
    CameraPage? page,
    List<int> order,
    Set<int> selected,
    int? paragraph,
    int first,
    int last,
    int? photoAnchor,
    ({String text, PencilMark range})? range,
    String? reread,
  })?
  _beforeAdjustment;
  ({String text, PencilMark range})? _range;
  bool _savingPhoto = false;
  bool _showDetails = false;
  bool _showPhotoText = false;
  late final OriginalPhotoStore _photos = const OriginalPhotoStore();
  _ScanMode _mode = _ScanMode.page;
  List<int> _order = [];
  Set<int> _selected = {};
  int? _paragraph;
  int _first = 0, _last = 0;
  int? _photoAnchor;
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

  bool get _extractionOnly => widget.existingPhotoId != null;
  bool get _photoReady => _originalPhoto != null && _scan == null;
  bool get _offerExtraction => _photoReady && _text.text.trim().isEmpty;

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

  Future<void> _searchSources() async {
    if (!_editable) return;
    FocusScope.of(context).unfocus();
    final choice = await showSourceSearch(context, widget.paperColor);
    if (!mounted || choice == null || !_editable) return;
    final (text: text, citation: citation) = choice;
    final replacesText =
        text != null && _text.text.trim().isNotEmpty && _text.text != text;
    final replacesCitation =
        citation != null &&
        _citation.text.trim().isNotEmpty &&
        _citation.text != citation;
    if (replacesText || replacesCitation) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(replacesText ? '입력한 원문을 바꿀까요?' : '입력한 출처를 바꿀까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('바꾸기'),
            ),
          ],
        ),
      );
      if (!mounted || replace != true || !_editable) return;
    }
    if (text != null) _text.text = text;
    if (citation != null) _citation.text = citation;
  }

  Future<void> _shareHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('다른 앱에서 공유'),
      content: Text(
        !kIsWeb && widget.intake.canUseCamera
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

  Future<void> _choosePhoto({required bool camera}) async {
    if (!_editable) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await widget.intake.pickPhoto(camera: camera);
      if (!mounted || photo == null) return;
      setState(() {
        _originalPhoto = photo;
        _photoRegion = null;
        _scan = null;
        _scanRegion = null;
        _savedReviews.clear();
        _beforeAdjustment = null;
        _photoBeforeAdjustment = null;
      });
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
    Future<SourcePhoto> Function()? preparePhoto,
  }) async {
    setState(() {
      _busy = true;
      _readingPhoto = true;
      _error = null;
    });
    try {
      final input = preparePhoto == null ? photo : await preparePhoto();
      if (!mounted) return null;
      final scan = await widget.intake
          .scan(input, region: region, mask: mask)
          .timeout(const Duration(seconds: 90));
      if (!mounted) return null;
      if (scan.paragraphs.isEmpty) {
        setState(() => _error = '읽힌 글자가 없어요. 글자 영역을 고르거나 선명한 사진으로 다시 시도해 주세요.');
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

  Future<void> _extractPhoto() async {
    final photo = _originalPhoto;
    if (photo == null || !_editable || !_photoReady) return;
    if (_text.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('사진에서 원문 글을 새로 뽑을까요?'),
          content: const Text('추출한 글을 확인하고 담으면 지금 입력한 글을 대신합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('사진에서 글자 읽기'),
            ),
          ],
        ),
      );
      if (!mounted || replace != true || !_editable) return;
    }
    FocusScope.of(context).unfocus();
    final region = _cropRegion;
    final scan = await _recognize(photo, region: region);
    if (scan == null || !mounted) return;
    _scanRegion = region;
    _useScan(scan, _ScanMode.page);
    _reviewSelection();
  }

  Rect? get _cropRegion {
    final region = _photoRegion;
    return region == null
        ? null
        : Rect.fromLTRB(region[0], region[1], region[2], region[3]);
  }

  Rect _onOriginalPhoto(Rect bounds) {
    final box = _cameraPage?.originalBounds(bounds) ?? bounds;
    final region = _scanRegion;
    return region == null
        ? box
        : Rect.fromLTRB(
            region.left + box.left * region.width,
            region.top + box.top * region.height,
            region.left + box.right * region.width,
            region.top + box.bottom * region.height,
          );
  }

  void _useScan(
    SourceScan scan,
    _ScanMode mode, {
    CameraPage? cameraPage,
    bool adjusted = false,
  }) {
    setState(() {
      if (!adjusted) {
        _beforeAdjustment = null;
        _photoBeforeAdjustment = null;
      }
      _scan = scan;
      _cameraPage = cameraPage;
      _error = null;
      _range = null;
      _mode = mode;
      _reread = null;
      _paragraph = null;
      _photoAnchor = null;
      _order = scan.pageReadingOrder;
      _selected = _order.toSet();
    });
  }

  Future<void> _readAdjusted() async {
    final photo = _originalPhoto;
    if (photo == null || !_editable || _beforeAdjustment != null) return;
    final wasReviewing = _reviewing;
    if (wasReviewing) _backToSelection();
    final baseline = (
      scan: _scan,
      page: _cameraPage,
      order: _order,
      selected: _selected,
      paragraph: _paragraph,
      first: _first,
      last: _last,
      photoAnchor: _photoAnchor,
      range: _range,
      reread: _reread,
    );
    CameraPage? projection;
    SourceScan? originalView;
    final adjusted = await _recognize(
      photo,
      preparePhoto: () async {
        final normalized = await ScanImage.decode(
          photo.bytes,
          region: _scanRegion,
          preserveRegionDetail: true,
        );
        originalView = SourceScan(
          normalized.bytes,
          const [],
          width: normalized.width,
          height: normalized.height,
        );
        final result = await compute(adjustOcrPhoto, normalized.bytes);
        projection = result.projection;
        return SourcePhoto(photo.path, result.bytes);
      },
    );
    if (!mounted) return;
    if (adjusted == null) {
      final message = _error;
      if (wasReviewing) _reviewSelection();
      setState(() => _error = message);
      return;
    }
    _beforeAdjustment = baseline;
    _photoBeforeAdjustment = originalView;
    _useScan(adjusted, _mode, cameraPage: projection, adjusted: true);
    if (_mode == _ScanMode.page) _reviewSelection();
  }

  void _restoreUnadjusted() {
    final before = _beforeAdjustment;
    if (before == null || !_editable) return;
    if (_reviewing) _backToSelection();
    setState(() {
      _scan = before.scan;
      _cameraPage = before.page;
      _order = before.order;
      _selected = before.selected;
      _paragraph = before.paragraph;
      _first = before.first;
      _last = before.last;
      _reread = before.reread;
      _photoAnchor = before.photoAnchor;
      _range = before.range;
      _error = null;
      _beforeAdjustment = null;
      _photoBeforeAdjustment = null;
    });
    if (_mode == _ScanMode.page) _reviewSelection();
  }

  Widget _adjustButton() => TextButton(
    onPressed: !_editable
        ? null
        : _beforeAdjustment == null
        ? _readAdjusted
        : _restoreUnadjusted,
    child: Text(_beforeAdjustment == null ? '보정해 다시 읽기' : '보정 전 결과 보기'),
  );

  void _pickParagraph(int index) {
    final passage = ScanPassage(_scan!.paragraphs[index]);
    setState(() {
      _paragraph = index;
      _photoAnchor = null;
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
    if (_paragraph != index) {
      _pickParagraph(index);
      return;
    }
    final terms = _passage!.terms;
    final hitsByWord = [
      for (final (i, term) in terms.indexed)
        if (term.bounds?.inflate(.005).contains(point) ?? false) i,
    ];
    if (hitsByWord.isEmpty) return;
    final anchor = _photoAnchor;
    final word = anchor == null || hitsByWord.last < anchor
        ? hitsByWord.first
        : hitsByWord.last;
    setState(() {
      _photoAnchor = anchor == null ? word : null;
      _first = math.min(anchor ?? word, word);
      _last = anchor == null ? hitsByWord.last : math.max(anchor, word);
      _reread = null;
    });
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
    final photo = _cameraPage == null && _beforeAdjustment == null
        ? _originalPhoto
        : null;
    final result = await _recognize(
      photo ?? SourcePhoto('', _scan!.photo),
      region: photo == null ? region : _onOriginalPhoto(region),
      mask: [
        for (final box in boxes.map((box) => box.inflate(.003)))
          photo == null ? box : _onOriginalPhoto(box),
      ],
    );
    if (!mounted) return;
    if (result != null) {
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

  void _omitParagraph(int index) {
    if (!_editable || !_isPageReview || _editors.length < 2) return;
    final paragraph = _reviewKeys[index].$2;
    _backToSelection();
    _selected.remove(paragraph);
    _reviewSelection();
  }

  String get _confirmedText => _fields
      .map((c) => normalizeSource(c.text))
      .where((text) => text.isNotEmpty)
      .join('\n\n');

  List<OriginalPhotoLine> _photoLines({bool original = false}) =>
      mapPhotoLines([
        for (final (index, editor) in _editors.indexed)
          (normalizeSource(editor.text), _reviewLines[index]),
      ], transformBounds: original ? _onOriginalPhoto : null);

  bool get _isPageReview => _reviewing && _mode == _ScanMode.page;

  Future<void> _pickWritingRange() async {
    final text = _confirmedText;
    if (!_editable || text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final result = await chooseOriginalRange(
      context,
      text,
      current: _range?.text == text ? _range?.range : null,
      photo: _scan,
      photoLines: _photoLines(),
    );
    if (mounted && result != null && text == _confirmedText) {
      setState(() {
        _range = result.range == null
            ? null
            : (text: text, range: result.range!);
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final text = _confirmedText;
    if (!_editable ||
        !_hasContent(text) ||
        text.length > sourceLengthLimit ||
        _citation.text.trim().length > 500) {
      return;
    }
    final isFullPage = _isPageReview;
    if (isFullPage && _range != null && _range!.text != text) {
      setState(() => _error = '원문이 바뀌었어요. 옮겨 쓸 구절을 다시 골라 주세요.');
      return;
    }
    final photo = _originalPhoto;
    final citation = _citation.text.trim(), bookId = _bookId;
    final passage = _reviewing && _mode == _ScanMode.paragraph
        ? _passage
        : null;
    final photoRegion =
        _photoRegion ??
        (passage == null
            ? null
            : photoExcerptRegion(
                passage.lineBoxes(_first, _last).map(_onOriginalPhoto),
              ));
    final range = isFullPage ? _range?.range : null;
    final photoLines = isFullPage
        ? _photoLines(original: true)
        : const <OriginalPhotoLine>[];
    var photoId = widget.existingPhotoId;
    if (photo != null && photoId == null) {
      FocusScope.of(context).unfocus();
      setState(() {
        _busy = true;
        _savingPhoto = true;
        _error = null;
      });
      try {
        photoId = await _photos.save(photo.bytes);
      } catch (_) {
        if (mounted) {
          setState(() => _error = '사진을 보관하지 못했어요. 이 화면에서 다시 저장해 주세요.');
        }
        return;
      } finally {
        if (mounted) {
          setState(() {
            _busy = false;
            _savingPhoto = false;
          });
        }
      }
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final result = (
      text: text,
      citation: citation,
      bookId: bookId,
      isFullPage: isFullPage,
      writingRange: range,
      photoLines: photoLines,
      photoId: photoId,
      photoRegion: photoRegion,
    );
    if (widget.onSaveExtraction case final save?) {
      FocusScope.of(context).unfocus();
      setState(() {
        _busy = true;
        _savingPhoto = true;
        _error = null;
      });
      var saved = false;
      try {
        saved = await save(result);
      } catch (_) {
        // Keep editable text on this screen if the save fails.
      } finally {
        if (mounted) {
          setState(() {
            _busy = false;
            _savingPhoto = false;
            if (!saved) _error = '원문 글을 저장하지 못했어요. 다시 저장해 주세요.';
          });
        }
      }
      if (!saved || !mounted || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
    }
    Navigator.pop<SourceImportResult>(context, result);
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

  Future<void> _import(_ImportAction action) => switch (action) {
    _ImportAction.search => _searchSources(),
    _ImportAction.share => _shareHelp(),
  };

  Widget _otherImports() => PopupMenuButton<_ImportAction>(
    key: const ValueKey('source-import-more'),
    enabled: _editable,
    onSelected: _import,
    tooltip: '가져오기 더 보기',
    icon: const Icon(CupertinoIcons.ellipsis, size: 21),
    color: panelPaperColor(widget.paperColor),
    surfaceTintColor: Colors.transparent,
    itemBuilder: (_) => const [
      PopupMenuItem(value: _ImportAction.search, child: Text('새 원문 찾기')),
      PopupMenuItem(value: _ImportAction.share, child: Text('다른 앱에서 공유')),
    ],
  );

  Widget _importTools() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      if (!widget.shared && !_extractionOnly) ...[
        if (widget.intake.canUseCamera)
          TextButton.icon(
            key: const ValueKey('source-camera-direct'),
            onPressed: _editable ? () => _choosePhoto(camera: true) : null,
            icon: const Icon(CupertinoIcons.camera, size: 19),
            label: const Text('사진 찍기'),
          ),
        TextButton.icon(
          key: const ValueKey('source-photo-direct'),
          onPressed: _editable ? () => _choosePhoto(camera: false) : null,
          icon: const Icon(CupertinoIcons.photo, size: 19),
          label: Text(_originalPhoto == null ? '사진 고르기' : '사진 바꾸기'),
        ),
      ],
      if (!_extractionOnly)
        TextButton.icon(
          key: const ValueKey('source-paste'),
          onPressed: _editable
              ? () {
                  if (_originalPhoto != null) {
                    setState(() => _showPhotoText = true);
                  }
                  _paste();
                }
              : null,
          icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 17),
          label: const Text('붙여넣기'),
        ),
    ],
  );

  Widget _details() {
    final citation = _citation.text.trim();
    final book = widget.books[_bookId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1, color: line),
        InkWell(
          key: const ValueKey('source-details'),
          onTap: !_editable
              ? null
              : () {
                  if (_showDetails) FocusScope.of(context).unfocus();
                  setState(() => _showDetails = !_showDetails);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Row(
              children: [
                const Icon(CupertinoIcons.book, size: 17, color: muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book == null ? '책 없이 담기' : '$book에 담기',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (citation.isNotEmpty && !_showDetails)
                        Text(
                          citation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _showDetails ? '접기' : '담을 책·원문 출처',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showDetails
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 12,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
        if (_showDetails) ...[
          if (widget.books.isNotEmpty)
            _metadataRow(
              '담을 책',
              DropdownButtonFormField<String>(
                initialValue: _bookId ?? '',
                decoration: _recordDecoration,
                icon: const Icon(CupertinoIcons.chevron_down, size: 15),
                dropdownColor: widget.paperColor,
                isExpanded: true,
                items: [
                  if (widget.allowUnbound)
                    const DropdownMenuItem(value: '', child: Text('책 없이 담기')),
                  for (final book in widget.books.entries)
                    DropdownMenuItem(
                      value: book.key,
                      child: Text(book.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _editable
                    ? (id) => setState(() => _bookId = id == '' ? null : id)
                    : null,
              ),
            ),
          _metadataRow(
            '원문 출처 · 선택',
            WritingCaret(
              controller: _citation,
              color: widget.penColor,
              builder: (focus, scroll) => TextField(
                key: const ValueKey('original-citation'),
                controller: _citation,
                focusNode: focus,
                scrollController: scroll,
                showCursor: false,
                decoration: _recordDecoration.copyWith(
                  hintText: '작품명, 쪽수 또는 링크',
                  errorText: citation.length > 500 ? '출처를 조금 줄여 주세요.' : null,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _metadataRow(String label, Widget field) => LayoutBuilder(
    builder: (context, constraints) {
      final caption = Text(
        label,
        style: const TextStyle(color: muted, fontSize: 12),
      );
      final content = Semantics(label: label, child: field);
      return DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: line)),
        ),
        child:
            constraints.maxWidth < 245 ||
                MediaQuery.textScalerOf(context).scale(14) > 24
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const SizedBox(height: 8), caption, content],
              )
            : Row(
                children: [
                  SizedBox(width: constraints.maxWidth * .37, child: caption),
                  Expanded(child: content),
                ],
              ),
      );
    },
  );

  static const _recordDecoration = InputDecoration(
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: brandInk),
    ),
    contentPadding: EdgeInsets.symmetric(vertical: 11),
    filled: false,
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

  Widget _largePhotoButton(
    SourceScan scan, [
    List<Rect> selection = const [],
  ]) => TextButton.icon(
    onPressed: () => _showScanPhoto(scan, selection),
    icon: const Icon(CupertinoIcons.arrow_up_left_arrow_down_right, size: 14),
    label: const Text('사진 크게 보기'),
  );

  Future<void> _showScanPhoto(SourceScan scan, List<Rect> selection) =>
      showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: paper,
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: '큰 사진 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 19),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => InteractiveViewer(
                      maxScale: 5,
                      child: SourceScanPreview(
                        scan: scan,
                        height: box.maxHeight,
                        selection: selection,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  List<Widget> _selectionPanel(double photoHeight) {
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
            onPressed: _editable
                ? () => setState(() {
                    _scan = null;
                    _error = null;
                  })
                : null,
            child: const Text('사진 화면으로'),
          ),
          _largePhotoButton(scan, selectedBoxes),
          if (_originalPhoto != null) _adjustButton(),
        ],
      ),
      Text(
        pageMode
            ? '페이지 전체를 읽습니다. 머리글이나 쪽수를 빼고 읽는 순서를 고칠 수 있어요.'
            : passage == null
            ? '사진에서 저장할 문단을 누르세요.'
            : _photoAnchor == null
            ? '사진에서 시작 단어를 눌러 구절을 좁힐 수 있어요.'
            : '사진에서 끝 단어를 누르세요.',
      ),
      const SizedBox(height: 6),
      InteractiveViewer(
        maxScale: 5,
        child: SourceScanPreview(
          scan: scan,
          height: photoHeight,
          selection: selectedBoxes,
          onTap: _busy || pageMode ? null : _tapPhoto,
        ),
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
                    _photoAnchor = null;
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
    compact: _reviewing,
    showCaption: false,
    child: WritingCaret(
      controller: controller,
      focusNode: index == 0 ? _focus : null,
      color: widget.penColor,
      builder: (focus, scroll) => TextField(
        key: index == 0
            ? const ValueKey('source-text')
            : ValueKey('source-review-text-$index'),
        controller: controller,
        focusNode: focus,
        scrollController: scroll,
        showCursor: false,
        readOnly: _busy,
        minLines: _reviewing ? 2 : 4,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          hintText: '옮겨 쓸 구절을 적어 주세요.',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          filled: false,
        ),
      ),
    ),
  );

  Future<void> _compareLine(ScanLine line, Rect bounds) {
    final original = _photoBeforeAdjustment;
    Rect onPhoto(Rect box) =>
        original != null ? _cameraPage?.originalBounds(box) ?? box : box;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진과 대조'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SourceScanPreview(
                scan: original ?? _scan!,
                focus: onPhoto(bounds),
                selection: [
                  for (final word in line.words)
                    if (word.bounds case final box?
                        when (word.confidence ?? 1) < .65)
                      onPhoto(box),
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
  }

  List<Widget> _reviewPanel() => [
    Wrap(
      spacing: 8,
      children: [
        TextButton(
          onPressed: _editable ? _backToSelection : null,
          child: Text(_isPageReview ? '구절 고르기' : '구절 다시 고르기'),
        ),
        _largePhotoButton(_scan!),
        if (_isPageReview) _adjustButton(),
      ],
    ),
    if (_isPageReview) ...[
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _editable && _confirmedText.isNotEmpty
              ? _pickWritingRange
              : null,
          icon: const Icon(CupertinoIcons.scope, size: 16),
          label: Text(switch (_range) {
            null => '옮겨 쓸 구절 · 원문 전체',
            (text: final text, range: _) when text == _confirmedText =>
              '옮겨 쓸 구절 · 일부 선택됨',
            _ => '옮겨 쓸 구절 · 다시 선택',
          }),
        ),
      ),
    ],
    if (!_extractionOnly) const Text('글을 담으면 원본 사진도 이 기기에 보관돼요.'),
    for (final (index, controller) in _editors.indexed) ...[
      if (_editors.length > 1)
        Row(
          children: [
            Expanded(child: Text('${index + 1}번째 문단')),
            IconButton(
              tooltip: '${index + 1}번째 문단 빼기',
              onPressed: _editable ? () => _omitParagraph(index) : null,
              icon: const Icon(CupertinoIcons.minus_circle, size: 18),
            ),
          ],
        ),
      _field(controller, index),
      OriginalTextCleanup(controller: controller, enabled: _editable),
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

  Future<void> _chooseRegion(SourcePhoto photo) async {
    final chosen = await chooseOriginalPhotoRegion(
      context,
      photo.bytes,
      color: widget.paperColor,
      current: _photoRegion,
    );
    if (!mounted || chosen == null || photo != _originalPhoto) return;
    setState(() {
      _photoRegion = chosen.isEmpty ? null : chosen;
      _error = null;
    });
  }

  bool _hasContent(String text) =>
      text.isNotEmpty ||
      (!_extractionOnly &&
          !_reviewing &&
          (_originalPhoto != null ||
              (widget.shared &&
                  RegisteredOriginal.webLink(_citation.text) != null)));

  @override
  Widget build(BuildContext context) {
    final text = _fields
        .map((c) => normalizeSource(c.text))
        .where((value) => value.isNotEmpty)
        .join('\n\n');
    final canSubmit =
        _editable &&
        _hasContent(text) &&
        text.length <= sourceLengthLimit &&
        _citation.text.trim().length <= 500;
    final selectionReady = _mode == _ScanMode.page
        ? _selected.isNotEmpty
        : _paragraph != null;
    return PopScope(
      canPop: !_savingPhoto,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.paperColor,
          image: paperGrain(widget.paperColor, widget.grainOpacity),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selecting
                              ? _mode == _ScanMode.page
                                    ? '페이지 인식 결과'
                                    : '문단 고르기'
                              : _reviewing
                              ? '원문 확인'
                              : _extractionOnly
                              ? '사진에서 글자 읽기'
                              : widget.shared
                              ? '공유한 원문'
                              : '원문 담기',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      if (!_selecting &&
                          !_reviewing &&
                          !widget.shared &&
                          !_extractionOnly)
                        _otherImports(),
                      IconButton(
                        tooltip: '닫기',
                        onPressed: _savingPhoto
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.xmark, size: 19),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          _readingPhoto ? '사진 속 글자를 읽고 있어요' : '원문을 가져오고 있어요',
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    children: [
                      const SizedBox(height: 12),
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
                        ..._selectionPanel(
                          (constraints.maxHeight * .46).clamp(180.0, 520.0),
                        )
                      else if (_reviewing)
                        ..._reviewPanel()
                      else ...[
                        if (!_extractionOnly) _importTools(),
                        const SizedBox(height: 8),
                        if (_originalPhoto case final photo?) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _editable
                                  ? () => _chooseRegion(photo)
                                  : null,
                              icon: const Icon(CupertinoIcons.crop, size: 16),
                              label: Text(
                                _photoRegion == null
                                    ? '글자 영역 고르기'
                                    : '글자 영역 바꾸기',
                              ),
                            ),
                          ),
                          Image.memory(
                            photo.bytes,
                            key: const ValueKey('original-photo-preview'),
                            height: (constraints.maxHeight * .5).clamp(
                              100,
                              300,
                            ),
                            fit: BoxFit.contain,
                            semanticLabel: '담을 원본 사진',
                            errorBuilder: (_, _, _) =>
                                const Text('이 사진을 표시할 수 없어요.'),
                          ),
                          Wrap(
                            children: [
                              if (!_offerExtraction)
                                TextButton(
                                  onPressed: _editable ? _extractPhoto : null,
                                  child: const Text('사진에서 글자 읽기'),
                                ),
                              if (!_extractionOnly &&
                                  !_showPhotoText &&
                                  _text.text.isEmpty)
                                TextButton(
                                  onPressed: _editable
                                      ? () {
                                          setState(() => _showPhotoText = true);
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (mounted) {
                                                  _focus.requestFocus();
                                                }
                                              });
                                        }
                                      : null,
                                  child: const Text('글 적기'),
                                ),
                              if (!_extractionOnly)
                                TextButton(
                                  onPressed: _editable
                                      ? () => setState(() {
                                          _originalPhoto = null;
                                          _photoRegion = null;
                                          _savedReviews.clear();
                                          _error = null;
                                        })
                                      : null,
                                  child: const Text('사진 빼기'),
                                ),
                            ],
                          ),
                        ],
                        if (_originalPhoto == null ||
                            _showPhotoText ||
                            _text.text.isNotEmpty) ...[
                          _field(_text, 0),
                          OriginalTextCleanup(
                            controller: _text,
                            enabled: _editable,
                          ),
                        ],
                      ],
                      if (text.length > sourceLengthLimit)
                        const Text('원문이 너무 길어요. 옮겨 쓸 구절만 남겨 주세요.'),
                      if (!_selecting &&
                          (widget.registration || widget.shared)) ...[
                        const SizedBox(height: 12),
                        _details(),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          key: const ValueKey('source-confirm'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: _selecting
                              ? selectionReady && !_busy
                                    ? _reviewSelection
                                    : null
                              : _offerExtraction
                              ? (_editable ? _extractPhoto : null)
                              : canSubmit
                              ? _submit
                              : null,
                          child: Text(
                            _offerExtraction
                                ? '사진에서 글자 읽기'
                                : !_selecting
                                ? (_extractionOnly ? '원문에 글 추가' : '담기')
                                : _mode == _ScanMode.page
                                ? '페이지 확인'
                                : '선택한 구절 확인',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_offerExtraction && !_extractionOnly)
                          TextButton(
                            onPressed: canSubmit ? _submit : null,
                            child: const Text('사진만 담기'),
                          ),
                      ],
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
}
