import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/model.dart';
import '../data/original_photo_store.dart';
import '../source/camera_page.dart';
import '../source/ocr_photo_adjustment.dart';
import '../source/photo_lines.dart';
import '../source/source_intake.dart';
import '../source/source_scan.dart';
import 'book_details.dart';
import 'paper.dart';
import 'photo_original_paper.dart';
import 'paper_panel.dart';
import 'original_photo_crop.dart';
import 'original_text_cleanup.dart';
import 'long_source_text.dart';
import 'source_search.dart';
import 'writing_pen.dart';

typedef SourceImportResult = ({
  String text,
  bool isFullPage,
  List<OriginalPhotoLine> photoLines,
  String? photoId,
  List<double>? photoRegion,
  String citation,
  String? bookId,
  bool startWriting,
});

enum _ImportAction { search, share }

enum _PhotoAction { adjust, join, photoOnly, replace }

class SourceImportSheet extends StatefulWidget {
  const SourceImportSheet({
    super.key,
    required this.intake,
    required this.initialText,
    required this.style,
    this.initialPhoto,
    this.existingPhotoId,
    this.onSaveExtraction,
    this.onSaveOriginal,
    this.onSaveTranscription,
    this.initialSearch = false,
    this.initialPhotoRegion,
    this.initialCitation = '',
    this.shared = false,
    this.registration = false,
    this.books = const {},
    this.bookId,
    this.allowUnbound = true,
  });

  final SourceIntake intake;
  final String initialText, initialCitation;
  final WritingStyle style;

  Color get penColor => penColors[style.penIndex];
  final SourcePhoto? initialPhoto;
  final String? existingPhotoId;
  final Future<bool> Function(SourceImportResult)? onSaveExtraction;
  final Future<bool> Function(SourceImportResult)? onSaveOriginal;
  final Future<bool> Function(SourceImportResult)? onSaveTranscription;
  final bool initialSearch;
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
  late final _focus = FocusNode()..addListener(_textFocusChanged);
  final _bodyScroll = ScrollController();
  late final _citation = TextEditingController(text: widget.initialCitation)
    ..addListener(_changed);
  late String? _bookId = widget.bookId;
  TextEditingController? _wholeEditor;
  bool _correctingPhoto = false;
  bool _editingLongText = false;
  ({String text, String citation, bool composing})? _lastDraft;
  String? _normalizedFrom;
  String _normalizedText = '';
  SourceScan? _scan;
  late SourcePhoto? _originalPhoto = widget.initialPhoto;
  late List<double>? _photoRegion = widget.initialPhotoRegion;
  Rect? _scanRegion;
  CameraPage? _cameraPage;
  SourceScan? _photoBeforeAdjustment;
  ({SourceScan scan, CameraPage? page})? _beforeAdjustment;
  bool _savingPhoto = false;
  bool _showPhotoText = false;
  late final OriginalPhotoStore _photos = const OriginalPhotoStore();
  String? _error;
  bool _busy = false, _readingPhoto = false;
  bool _allowClose = false, _askingToClose = false;

  bool get _hasDraft =>
      _confirmedText != widget.initialText ||
      _citation.text != widget.initialCitation ||
      _originalPhoto != widget.initialPhoto ||
      _bookId != widget.bookId ||
      _scan != null;

  Future<void> _close() async {
    if (_savingPhoto || _askingToClose || _composing) return;
    if (_hasDraft) {
      _askingToClose = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('담지 않은 원문을 닫을까요?'),
          content: const Text('입력하거나 고친 내용이 사라져요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 편집'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
      _askingToClose = false;
      if (!mounted || discard != true) return;
    }
    if (!mounted) return;
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  bool get _reviewing => _wholeEditor != null;
  bool get _composing => [
    _wholeEditor ?? _text,
    _citation,
  ].any((c) => c.value.isComposingRangeValid && !c.value.composing.isCollapsed);
  bool get _editable => !_busy && !_composing;

  bool get _extractionOnly => widget.existingPhotoId != null;
  bool get _photoReady => _originalPhoto != null && _scan == null;
  bool get _offerExtraction => _photoReady && _text.text.trim().isEmpty;

  void _changed() {
    final draft = (
      text: (_wholeEditor ?? _text).text,
      citation: _citation.text,
      composing: _composing,
    );
    if (draft == _lastDraft) return;
    _lastDraft = draft;
    setState(() {});
  }

  bool get _longText => _text.text.length >= LongSourceText.threshold;
  bool get _readingLongText =>
      _longText && !_editingLongText && !_focus.hasFocus;

  void _textFocusChanged() {
    if (!_reviewing && _longText && !_editingLongText) setState(() {});
  }

  void _toggleLongTextEditing() {
    if (!_editable) return;
    final edit = _readingLongText;
    _focus.unfocus();
    setState(() => _editingLongText = edit);
    if (edit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editingLongText && !_reviewing) _focus.requestFocus();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchSources(closeOnCancel: true);
      });
    }
    if (widget.initialPhoto != null && widget.initialText.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _extractPhoto();
      });
    }
  }

  @override
  void dispose() {
    if (_readingPhoto) widget.intake.cancelRecognition();
    for (final controller in [_text, _citation, ?_wholeEditor]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    _focus.dispose();
    _bodyScroll.dispose();
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
        setState(() => _error = '원문이 너무 길어요. 글을 줄인 뒤 붙여넣어 주세요.');
      } else if (_text.text != beforePaste) {
        setState(() => _error = '입력한 원문을 유지했어요. 다시 붙여넣어 주세요.');
      } else if (!_composing) {
        if (text.length >= LongSourceText.threshold) {
          _editingLongText = false;
          _focus.unfocus();
        }
        _text.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(
            offset: text.length >= LongSourceText.threshold ? 0 : text.length,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '붙여넣지 못했어요. 입력칸을 눌러 키보드로 붙여넣어 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchSources({bool closeOnCancel = false}) async {
    if (!_editable) return;
    FocusScope.of(context).unfocus();
    SourceImportResult? catalogResult;
    (String, String)? confirmedCatalog;
    final saveTranscription = widget.onSaveTranscription;
    final choice = await showSourceSearch(
      context,
      widget.style,
      widget.intake,
      onCatalogTranscription: saveTranscription == null
          ? null
          : (text, citation) async {
              if (!mounted || !_editable) return null;
              final work = (text, citation);
              if (confirmedCatalog != work) {
                if (!await _confirmSourceReplacement(
                      text: text,
                      citation: citation,
                      replacePhoto: _originalPhoto != null,
                      startWriting: true,
                    ) ||
                    !mounted ||
                    !_editable) {
                  return null;
                }
                confirmedCatalog = work;
              }
              final SourceImportResult result = (
                text: text,
                citation: citation,
                bookId: _bookId,
                isFullPage: false,
                photoLines: const [],
                photoId: null,
                photoRegion: null,
                startWriting: true,
              );
              if (!await saveTranscription(result)) return false;
              catalogResult = result;
              return true;
            },
    );
    if (!mounted) return;
    if (catalogResult case final result?) {
      _finish(result);
      return;
    }
    if (!_editable) return;
    if (choice == null) {
      if (closeOnCancel) await _close();
      return;
    }
    final SourceSearchChoice(:text, :citation, :photo) = choice;
    if (!await _confirmSourceReplacement(
          text: photo == null ? text : '',
          citation: citation,
          replacePhoto:
              (text != null || photo != null) && _originalPhoto != null,
        ) ||
        !mounted ||
        !_editable) {
      return;
    }
    if (photo != null) {
      await _importScreenshot(photo, citation);
      return;
    }
    if (text != null) {
      if (_originalPhoto != null) {
        setState(() {
          _originalPhoto = null;
          _photoRegion = null;
        });
      }
      _editingLongText = false;
      if (text.length >= LongSourceText.threshold) {
        _text.value = TextEditingValue(
          text: text,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _text.text = text;
      }
    }
    if (citation != null) _citation.text = citation;
  }

  Future<void> _importScreenshot(SourcePhoto photo, String? citation) async {
    final hasDraft = _text.text.trim().isNotEmpty || _originalPhoto != null;
    final scan = hasDraft ? await _recognize(photo) : null;
    if (!mounted || (hasDraft && scan == null)) return;
    setState(() => _setPickedPhoto(photo));
    if (citation != null) _citation.text = citation;
    if (scan == null) {
      await _extractPhoto();
    } else {
      _text.clear();
      _reviewScan(scan);
    }
  }

  Future<bool> _confirmSourceReplacement({
    String? text,
    String? citation,
    bool replacePhoto = false,
    bool startWriting = false,
  }) async {
    final replacesText =
        text != null && _text.text.trim().isNotEmpty && _text.text != text;
    final replacesCitation =
        citation != null &&
        _citation.text.trim().isNotEmpty &&
        _citation.text != citation;
    if (replacePhoto || replacesText || replacesCitation) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            startWriting
                ? '작성 중인 원문을 바꾸고 필사할까요?'
                : replacePhoto
                ? '담을 사진을 이 원문으로 바꿀까요?'
                : replacesText
                ? '입력한 원문을 바꿀까요?'
                : '입력한 출처를 바꿀까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(startWriting ? '필사하기' : '바꾸기'),
            ),
          ],
        ),
      );
      return replace == true;
    }
    return true;
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
    final replacing = _wholeEditor != null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await widget.intake.pickPhoto(camera: camera);
      if (!mounted || photo == null) return;
      SourceScan? replacement;
      if (replacing) {
        replacement = await _recognize(photo);
        if (!mounted || replacement == null) return;
      }
      setState(() => _setPickedPhoto(photo));
      if (replacement != null) {
        _reviewScan(replacement);
        return;
      }
    } on SourceIntakeException catch (error) {
      if (mounted) setState(() => _error = error.message);
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _error = '사진을 가져오지 못했어요. 권한을 확인하거나 다른 사진을 골라 주세요.');
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _text.text.trim().isEmpty) await _extractPhoto();
  }

  void _setPickedPhoto(SourcePhoto photo) {
    _clearWholeEditor();
    _originalPhoto = photo;
    _photoRegion = null;
    _scan = null;
    _scanRegion = null;
    _beforeAdjustment = null;
    _photoBeforeAdjustment = null;
  }

  Future<SourceScan?> _recognize(
    SourcePhoto photo, {
    Rect? region,
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
          .scan(input, region: region)
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
          title: const Text('사진에서 글자를 읽을까요?'),
          content: const Text('읽은 글을 담으면 지금 입력한 글이 바뀌어요.'),
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
    _reviewScan(scan);
  }

  Iterable<ScanParagraph> get _wholeParagraphs =>
      _scan!.pageReadingOrder.map((index) => _scan!.paragraphs[index]);

  String get _wholeText => _wholeParagraphs
      .map((paragraph) => normalizeSource(paragraph.text))
      .where((text) => text.isNotEmpty)
      .join('\n\n');

  void _clearWholeEditor() {
    final editor = _wholeEditor;
    if (editor == null) return;
    _wholeEditor = null;
    _correctingPhoto = false;
    editor.removeListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => editor.dispose());
  }

  Future<bool> _confirmWholeReplacement(String title) async {
    final editor = _wholeEditor;
    if (!_editable) return false;
    if (editor == null || editor.text == _wholeText) return true;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('지금 고친 글이 사진에서 읽은 글로 바뀔 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 편집'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('계속하기'),
          ),
        ],
      ),
    );
    return mounted && replace == true && _editable;
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

  void _reviewScan(SourceScan scan, {CameraPage? cameraPage}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _clearWholeEditor();
      _scan = scan;
      _cameraPage = cameraPage;
      _error = null;
      _wholeEditor = TextEditingController(text: _wholeText)
        ..addListener(_changed);
    });
  }

  Future<void> _readAdjusted() async {
    final photo = _originalPhoto;
    final scan = _scan;
    if (photo == null ||
        scan == null ||
        !_editable ||
        _beforeAdjustment != null) {
      return;
    }
    final baseline = (scan: scan, page: _cameraPage);
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
    if (!mounted || adjusted == null) return;
    _beforeAdjustment = baseline;
    _photoBeforeAdjustment = originalView;
    _reviewScan(adjusted, cameraPage: projection);
  }

  void _restoreUnadjusted() {
    final before = _beforeAdjustment;
    if (before == null || !_editable) return;
    _beforeAdjustment = null;
    _photoBeforeAdjustment = null;
    _reviewScan(before.scan, cameraPage: before.page);
  }

  String get _confirmedText {
    final current = (_wholeEditor ?? _text).text;
    if (_normalizedFrom != current) {
      _normalizedFrom = current;
      _normalizedText = normalizeSource(current);
    }
    return _normalizedText;
  }

  List<OriginalPhotoLine> _photoLines(String text) {
    if (text == _wholeText) {
      return mapPhotoLines([
        for (final paragraph in _wholeParagraphs)
          (normalizeSource(paragraph.text), paragraph.lines),
      ], transformBounds: _onOriginalPhoto);
    }
    return mapPhotoLines(
      [
        (text, [for (final paragraph in _wholeParagraphs) ...paragraph.lines]),
      ],
      transformBounds: _onOriginalPhoto,
      matchByPosition: false,
    );
  }

  Future<void> _submit({
    bool startWriting = false,
    bool photoOnly = false,
  }) async {
    if (photoOnly && (_extractionOnly || _originalPhoto == null)) return;
    final text = photoOnly ? '' : _confirmedText;
    final citation = _citation.text.trim();
    if (!_editable ||
        (!photoOnly && !_hasContent(text)) ||
        text.length > sourceLengthLimit ||
        citation.length > 500) {
      return;
    }
    final isFullPage = !photoOnly && _reviewing;
    final photo = _originalPhoto;
    final bookId = _bookId;
    final photoRegion = _photoRegion;
    final photoLines = isFullPage
        ? _photoLines(text)
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
      photoLines: photoLines,
      photoId: photoId,
      photoRegion: photo == null ? null : photoRegion,
      startWriting: startWriting,
    );
    if ((widget.onSaveExtraction ?? widget.onSaveOriginal) case final save?) {
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
            if (!saved) {
              _error = _extractionOnly
                  ? '원문 글을 저장하지 못했어요. 다시 저장해 주세요.'
                  : '원문을 저장하지 못했어요. 이 화면에서 다시 담아 주세요.';
            }
          });
        }
      }
      if (!saved || !mounted || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
    }
    _finish(result);
  }

  void _finish(SourceImportResult result) {
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.isCurrentOf(context) == true) {
        Navigator.pop<SourceImportResult>(context, result);
      }
    });
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
    color: originalPanelColor,
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
      if (!widget.shared && !_extractionOnly)
        TextButton.icon(
          key: const ValueKey('source-search-direct'),
          onPressed: _editable ? _searchSources : null,
          icon: const Icon(CupertinoIcons.search, size: 18),
          label: const Text('새 원문 찾기'),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1, color: line),
        if (widget.books.isNotEmpty)
          _metadataRow(
            '담을 책',
            DropdownButtonFormField<String>(
              initialValue: _bookId ?? '',
              decoration: _recordDecoration,
              icon: const Icon(CupertinoIcons.chevron_down, size: 15),
              dropdownColor: originalPanelColor,
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
              readOnly: _busy,
              decoration: _recordDecoration.copyWith(
                hintText: '작품명, 쪽수 또는 링크',
                errorText: citation.length > 500 ? '출처를 조금 줄여 주세요.' : null,
              ),
            ),
          ),
        ),
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
                  const SizedBox(width: 8),
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

  Future<void> _showScanPhoto(SourceScan scan) => showDialog<void>(
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
                  child: Image.memory(
                    scan.photo,
                    key: const ValueKey('source-scan-preview'),
                    width: box.maxWidth,
                    height: box.maxHeight,
                    fit: BoxFit.contain,
                    semanticLabel: '인식한 책 사진',
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('이 사진을 표시할 수 없어요.')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field() {
    final longPreview = _readingLongText;
    return SourceSlip(
      choice: widget.style.bookDetails.sourceSlip,
      showCaption: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (longPreview)
            LongSourceText(text: _confirmedText)
          else
            WritingCaret(
              controller: _text,
              focusNode: _focus,
              color: widget.penColor,
              builder: (focus, scroll) => TextField(
                key: const ValueKey('source-text'),
                controller: _text,
                focusNode: focus,
                scrollController: scroll,
                showCursor: false,
                readOnly: _busy,
                minLines: _longText ? 8 : 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: '옮겨 쓸 글을 적어 주세요.',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
              ),
            ),
          if (_longText || _editingLongText)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _editable ? _toggleLongTextEditing : null,
                child: Text(longPreview ? '글 고치기' : '고치기 마치기'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseReviewedPhotoRegion() async {
    final editor = _wholeEditor;
    final photo = _originalPhoto;
    if (editor == null || photo == null || !_editable) return;
    _focus.unfocus();
    final chosen = await chooseOriginalPhotoRegion(
      context,
      photo.bytes,
      color: originalPanelColor,
      current: _photoRegion,
    );
    if (!mounted || chosen == null || _wholeEditor != editor || !_editable) {
      return;
    }
    if (!await _confirmWholeReplacement('사진에서 글자를 다시 읽을까요?') ||
        !mounted ||
        _wholeEditor != editor ||
        !_editable) {
      return;
    }
    final region = chosen.isEmpty ? null : chosen;
    final box = region == null
        ? null
        : Rect.fromLTRB(region[0], region[1], region[2], region[3]);
    final scan = await _recognize(photo, region: box);
    if (scan == null || !mounted || _wholeEditor != editor) return;
    _photoRegion = region;
    _scanRegion = box;
    _beforeAdjustment = null;
    _photoBeforeAdjustment = null;
    _reviewScan(scan);
  }

  Future<void> _photoAction(_PhotoAction action) async {
    final editor = _wholeEditor;
    if (editor == null || !_editable) return;
    switch (action) {
      case _PhotoAction.adjust:
        if (!await _confirmWholeReplacement('사진을 다시 읽을까요?')) return;
        if (_beforeAdjustment == null) {
          await _readAdjusted();
        } else {
          _restoreUnadjusted();
        }
      case _PhotoAction.join:
        await _joinLines(editor);
      case _PhotoAction.photoOnly:
        if (!await _confirmWholeReplacement('사진만 담을까요?')) return;
        await _submit(photoOnly: true);
      case _PhotoAction.replace:
        if (!await _confirmWholeReplacement('다른 사진을 고를까요?')) return;
        await _choosePhoto(camera: false);
    }
  }

  Widget _photoEditingMenu() => PopupMenuButton<_PhotoAction>(
    tooltip: '사진 편집 더 보기',
    enabled: _editable,
    onSelected: _photoAction,
    icon: const Icon(CupertinoIcons.ellipsis, size: 21),
    color: originalPanelColor,
    surfaceTintColor: Colors.transparent,
    itemBuilder: (_) => [
      PopupMenuItem(
        value: _PhotoAction.adjust,
        child: Text(_beforeAdjustment == null ? '보정해 다시 읽기' : '보정 전 결과 보기'),
      ),
      const PopupMenuItem(value: _PhotoAction.join, child: Text('줄바꿈 정리')),
      if (!widget.shared && !_extractionOnly)
        const PopupMenuItem(value: _PhotoAction.replace, child: Text('사진 바꾸기')),
      if (!_extractionOnly)
        const PopupMenuItem(
          value: _PhotoAction.photoOnly,
          child: Text('사진만 담기'),
        ),
    ],
  );

  void _togglePhotoCorrection() {
    final editor = _wholeEditor;
    if (editor == null || !_editable) return;
    if (_correctingPhoto) {
      _focus.unfocus();
    } else if (!editor.selection.isValid) {
      editor.selection = TextSelection.collapsed(offset: editor.text.length);
    }
    setState(() => _correctingPhoto = !_correctingPhoto);
    if (_correctingPhoto) {
      // The footer action may already own focus when the editor is mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _correctingPhoto && _wholeEditor == editor) {
          _focus.requestFocus();
        }
      });
    }
  }

  List<Widget> _wholeReviewPanel(TextEditingController editor) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge!.copyWith(
      inherit: false,
      color: theme.colorScheme.onSurface,
      height: 1.65,
    );
    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _editable ? _chooseReviewedPhotoRegion : null,
          icon: const Icon(CupertinoIcons.crop, size: 17),
          label: Text(_photoRegion == null ? '글자 영역 고르기' : '글자 영역 바꾸기'),
        ),
      ),
      SourceSlip(
        choice: widget.style.bookDetails.sourceSlip,
        compact: true,
        showCaption: false,
        panelColor: originalPanelColor,
        child: _correctingPhoto
            ? PhotoOriginalCorrection(
                key: const ValueKey('photo-original-correction'),
                controller: editor,
                focusNode: _focus,
                style: style,
                ink: theme.colorScheme.primary,
                readOnly: _busy,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: editor.text.length >= LongSourceText.threshold
                    ? LongSourceText(text: editor.text, style: style)
                    : Text(
                        editor.text,
                        key: const ValueKey('photo-original-paper'),
                        style: style,
                      ),
              ),
      ),
      OriginalTextCleanup(controller: editor, enabled: _editable),
    ];
  }

  Widget _photoCorrectionButton() => TextButton(
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    onPressed: _editable ? _togglePhotoCorrection : null,
    child: Text(_correctingPhoto ? '고치기 마치기' : '글 고치기'),
  );

  Future<void> _chooseRegion(SourcePhoto photo) async {
    final chosen = await chooseOriginalPhotoRegion(
      context,
      photo.bytes,
      color: originalPanelColor,
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

  static final _confirmStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );

  Widget _completionActions(
    Widget confirm, {
    required bool showWriting,
    required bool canWrite,
  }) {
    if (!showWriting) return confirm;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: confirm),
        const SizedBox(width: 8),
        Expanded(
          child: TextButton(
            key: const ValueKey('source-save-and-write'),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: canWrite ? () => _submit(startWriting: true) : null,
            child: const Text('필사하기', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = _confirmedText;
    final canSubmit =
        _editable &&
        _hasContent(text) &&
        text.length <= sourceLengthLimit &&
        _citation.text.trim().length <= 500;
    final photoWriting =
        _originalPhoto != null &&
        !_offerExtraction &&
        !_extractionOnly &&
        text.isNotEmpty;
    final confirm = FilledButton(
      key: const ValueKey('source-confirm'),
      style: _confirmStyle,
      onPressed: _offerExtraction
          ? (_editable ? _extractPhoto : null)
          : canSubmit
          ? () => _submit(startWriting: photoWriting)
          : null,
      child: Text(
        _offerExtraction
            ? '사진에서 글자 읽기'
            : photoWriting
            ? '필사하기'
            : _extractionOnly
            ? '원문에 글 추가'
            : '담기',
        textAlign: TextAlign.center,
      ),
    );
    PaperNavigationScope.maybeOf(
      context,
    )?.name(context, _reviewing ? '원문 확인' : '원문 담기');
    return PopScope(
      canPop: !_composing && (_allowClose || (!_savingPhoto && !_hasDraft)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: originalPanelColor,
          image: paperGrain(originalPanelColor, panelGrainOpacity),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: PaperHeaderRow(
                    children: [
                      PaperBackButton(
                        enabled: !_savingPhoto && !_composing,
                        onPressed: _close,
                      ),
                      Expanded(
                        child: PaperPanelTitle(
                          _reviewing
                              ? '원문 확인'
                              : _extractionOnly
                              ? '사진에서 글자 읽기'
                              : widget.shared
                              ? '공유한 원문'
                              : '원문 담기',
                          fontSize:
                              constraints.maxWidth < 360 &&
                                  MediaQuery.textScalerOf(context).scale(22) >
                                      30
                              ? 18
                              : 22,
                        ),
                      ),
                      if (_wholeEditor != null) ...[
                        IconButton(
                          tooltip: '사진 크게 보기',
                          onPressed: _editable
                              ? () => _showScanPhoto(
                                  _photoBeforeAdjustment ?? _scan!,
                                )
                              : null,
                          icon: const Icon(CupertinoIcons.photo, size: 20),
                        ),
                        _photoEditingMenu(),
                      ],
                      if (!_reviewing && !widget.shared && !_extractionOnly)
                        _otherImports(),
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
                    controller: _bodyScroll,
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
                      if (_wholeEditor case final editor?)
                        ..._wholeReviewPanel(editor)
                      else if (!_readingPhoto) ...[
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
                          _field(),
                          OriginalTextCleanup(
                            controller: _text,
                            enabled: _editable,
                          ),
                        ],
                      ],
                      if (text.length > sourceLengthLimit)
                        const Text('원문이 너무 길어요. 글을 줄여 주세요.'),
                      if (widget.registration || widget.shared) ...[
                        const SizedBox(height: 12),
                        _details(),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: TextFieldTapRegion(
                    enabled: _wholeEditor != null,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_wholeEditor != null)
                            Row(
                              children: [
                                _photoCorrectionButton(),
                                const SizedBox(width: 8),
                                Expanded(child: confirm),
                              ],
                            )
                          else
                            _completionActions(
                              confirm,
                              showWriting:
                                  !photoWriting &&
                                  !_offerExtraction &&
                                  !_extractionOnly,
                              canWrite: canSubmit && text.isNotEmpty,
                            ),
                          if (photoWriting)
                            TextButton(
                              onPressed: canSubmit ? _submit : null,
                              child: const Text('원문만 담기'),
                            ),
                          if (_offerExtraction &&
                              !_readingPhoto &&
                              !_extractionOnly)
                            TextButton(
                              onPressed: canSubmit ? _submit : null,
                              child: const Text('사진만 담기'),
                            ),
                        ],
                      ),
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
