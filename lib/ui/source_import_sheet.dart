import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/book_detail_style.dart';
import '../source/source_intake.dart';
import 'book_details.dart';
import 'paper.dart';

typedef SourceImportResult = ({String source, String citation});

class SourceImportSheet extends StatefulWidget {
  const SourceImportSheet({
    super.key,
    required this.intake,
    required this.initialText,
    required this.choice,
    this.initialPhoto,
    this.shared = false,
    this.registration = false,
  });

  final SourceIntake intake;
  final String initialText;
  final BookDetailChoice choice;
  final SourcePhoto? initialPhoto;
  final bool shared, registration;

  @override
  State<SourceImportSheet> createState() => _SourceImportSheetState();
}

class _SourceImportSheetState extends State<SourceImportSheet> {
  late final _text = TextEditingController(text: widget.initialText);
  final _focus = FocusNode();
  final _citation = TextEditingController();
  List<String>? _paragraphs;
  SourcePhoto? _photo;
  Set<int> _selected = {};
  String? _error;
  bool _busy = false;
  bool _readingPhoto = false;

  bool get _composing => [
    _text.value,
    _citation.value,
  ].any((value) => value.isComposingRangeValid && !value.composing.isCollapsed);
  bool get _editable => !_busy && !_composing;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    _citation.addListener(_changed);
    if (widget.initialPhoto case final photo?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _read(photo);
      });
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    if (_readingPhoto) widget.intake.cancelRecognition();
    _text.removeListener(_changed);
    _text.dispose();
    _focus.dispose();
    _citation.removeListener(_changed);
    _citation.dispose();
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
        // This is an explicit Paste action, never an input listener.
        _text.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '붙여넣지 못했어요. 입력칸을 눌러 키보드로 붙여넣어 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePhoto() async {
    if (!_editable) return;
    _focus.unfocus();
    final camera = widget.intake.canUseCamera
        ? await showDialog<bool>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('책 사진'),
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
      if (photo != null && mounted) await _read(photo);
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

  Future<void> _read(SourcePhoto photo) async {
    setState(() {
      _busy = true;
      _readingPhoto = true;
      _error = null;
    });
    try {
      final blocks =
          (await widget.intake
                  .recognize(photo)
                  .timeout(const Duration(seconds: 90)))
              .map(normalizeSource)
              .where((text) => text.isNotEmpty)
              .toList();
      if (!mounted) return;
      if (blocks.isEmpty) {
        setState(() => _error = '읽을 수 있는 글자가 없어요. 구절이 선명한 사진을 골라 주세요.');
        return;
      }
      setState(() {
        _photo = photo;
        _paragraphs = blocks;
        _selected = {for (var i = 0; i < blocks.length; i++) i};
      });
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
  }

  void _submit() {
    final text = normalizeSource(_text.text);
    final citation = _citation.text.trim();
    if (_editable &&
        text.isNotEmpty &&
        text.length <= sourceLengthLimit &&
        citation.length <= 500) {
      Navigator.pop<SourceImportResult>(context, (
        source: text,
        citation: citation,
      ));
    }
  }

  void _reviewSelection() {
    final blocks = _paragraphs;
    if (blocks == null || _busy || _selected.isEmpty) return;
    final text = [
      for (var i = 0; i < blocks.length; i++)
        if (_selected.contains(i)) blocks[i],
    ].join('\n\n');
    if (text.length > sourceLengthLimit) {
      setState(() => _error = '옮겨 쓸 문단을 조금 더 좁혀 주세요.');
      return;
    }
    _text.text = text;
    setState(() {
      _paragraphs = null;
      _photo = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final available = math.max(
      0.0,
      media.size.height - inset - media.padding.top,
    );
    final blocks = _paragraphs;
    final text = normalizeSource(_text.text);
    final canSubmit =
        _editable &&
        text.isNotEmpty &&
        text.length <= sourceLengthLimit &&
        _citation.text.trim().length <= 500;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: math.min(640, available * .85),
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
                            blocks != null
                                ? '문단 고르기'
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
                    if (blocks == null)
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton.icon(
                            key: const ValueKey('source-paste'),
                            onPressed: _editable ? _paste : null,
                            icon: const Icon(
                              CupertinoIcons.doc_on_clipboard,
                              size: 17,
                            ),
                            label: const Text('붙여넣기'),
                          ),
                          TextButton.icon(
                            key: const ValueKey('source-photo'),
                            onPressed: _editable ? _choosePhoto : null,
                            icon: const Icon(CupertinoIcons.camera, size: 19),
                            label: const Text('책 사진'),
                          ),
                        ],
                      ),
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
                    if (blocks == null)
                      SourceSlip(
                        choice: widget.choice,
                        compact: true,
                        child: TextField(
                          key: const ValueKey('source-text'),
                          controller: _text,
                          focusNode: _focus,
                          minLines: 4,
                          maxLines: 10,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            hintText: '옮겨 쓸 구절을 붙여넣거나 적어 주세요.',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                          ),
                        ),
                      )
                    else ...[
                      const Text('옮겨 쓸 문단을 고르세요. 다음 화면에서 글자를 고칠 수 있어요.'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _editable ? _choosePhoto : null,
                          child: const Text('다른 사진'),
                        ),
                      ),
                      Image.memory(
                        _photo!.bytes,
                        height: 116,
                        fit: BoxFit.contain,
                        cacheWidth: 640,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _selected = _selected.length == blocks.length
                                ? {}
                                : {for (var i = 0; i < blocks.length; i++) i};
                          }),
                          child: Text(
                            _selected.length == blocks.length
                                ? '모두 해제'
                                : '모두 선택',
                          ),
                        ),
                      ),
                      for (var i = 0; i < blocks.length; i++)
                        CheckboxListTile(
                          key: ValueKey('source-paragraph-$i'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            blocks[i],
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                          value: _selected.contains(i),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _selected.add(i);
                            } else {
                              _selected.remove(i);
                            }
                          }),
                        ),
                    ],
                    if (text.length > sourceLengthLimit)
                      const Text('원문이 너무 길어요. 옮겨 쓸 구절만 남겨 주세요.'),
                    if (widget.registration && blocks == null)
                      TextField(
                        key: const ValueKey('original-citation'),
                        controller: _citation,
                        decoration: InputDecoration(
                          labelText: '출처 (선택)',
                          errorText: _citation.text.trim().length > 500
                              ? '출처를 조금 줄여 주세요.'
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('source-confirm'),
                    onPressed: blocks != null
                        ? _selected.isEmpty
                              ? null
                              : _reviewSelection
                        : canSubmit
                        ? _submit
                        : null,
                    child: Text(blocks == null ? '저장' : '선택한 문단 확인'),
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
