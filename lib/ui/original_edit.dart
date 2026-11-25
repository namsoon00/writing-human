import 'package:flutter/material.dart';

import '../data/model.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'original_text_cleanup.dart';

class OriginalEdit extends StatefulWidget {
  const OriginalEdit({
    super.key,
    required this.original,
    required this.style,
    required this.color,
    required this.onSave,
  });

  final RegisteredOriginal original;
  final WritingStyle style;
  final Color color;
  final Future<RegisteredOriginal?> Function(String text, String citation)
  onSave;

  @override
  State<OriginalEdit> createState() => _OriginalEditState();
}

class _OriginalEditState extends State<OriginalEdit> {
  late final text = TextEditingController(text: widget.original.text);
  late final citation = TextEditingController(text: widget.original.citation);
  bool saving = false;
  bool _allowLeave = false, _askingLeave = false;
  bool get _dirty =>
      text.text != widget.original.text ||
      citation.text != widget.original.citation;

  Future<void> _close() async {
    if (saving || composing || _askingLeave) return;
    if (_dirty) {
      _askingLeave = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('원문 수정을 취소할까요?'),
          content: const Text('저장하지 않은 변경 내용이 사라져요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 수정'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('수정 취소'),
            ),
          ],
        ),
      );
      _askingLeave = false;
      if (!mounted || discard != true) return;
    }
    if (!mounted) return;
    setState(() => _allowLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  bool failed = false;

  bool get composing => [
    text.value,
    citation.value,
  ].any((value) => value.isComposingRangeValid && !value.composing.isCollapsed);
  bool get textTooLong => text.text.length > 50000;
  bool get citationTooLong => citation.text.trim().length > 500;
  bool get canSave =>
      !saving &&
      !composing &&
      (text.text.trim().isNotEmpty ||
          widget.original.photoId != null ||
          RegisteredOriginal.webLink(citation.text) != null) &&
      !textTooLong &&
      !citationTooLong;

  Future<void> _save() async {
    if (!canSave) return;
    final body = text.text;
    final source = citation.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      failed = false;
    });
    final saved = await widget.onSave(body, source);
    if (!mounted) return;
    if (saved != null) {
      Navigator.pop(context, saved);
    } else {
      setState(() {
        saving = false;
        failed = true;
      });
    }
  }

  @override
  void dispose() {
    text.dispose();
    citation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([text, citation]),
    builder: (context, _) => PopScope(
      canPop: !saving && !composing && (_allowLeave || !_dirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: PaperPanel(
        color: widget.color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaperPanelHeader(
                '원문 수정',
                allowWritingReturn: false,
                canClose: !saving && !composing,
                onBack: _close,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 14, bottom: 12),
                  children: [
                    TextField(
                      key: const ValueKey('edit-original-text'),
                      controller: text,
                      readOnly: saving,
                      minLines: 5,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: writingTextStyle(
                        widget.style.fontIndex,
                        size: 16,
                        useDevelopmentTypeface:
                            widget.style.useDevelopmentTypeface,
                        color: ink,
                      ),
                      decoration: InputDecoration(
                        labelText: '원문 본문',
                        alignLabelWithHint: true,
                        errorText: textTooLong
                            ? '원문은 50,000자까지 저장할 수 있어요.'
                            : null,
                      ),
                    ),
                    OriginalTextCleanup(
                      controller: text,
                      enabled: !saving && !composing,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('edit-original-citation'),
                      controller: citation,
                      readOnly: saving,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '원문 출처 · 선택',
                        errorText: citationTooLong
                            ? '출처는 500자까지 저장할 수 있어요.'
                            : null,
                      ),
                    ),
                    if (failed)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: const Text(
                            '수정 내용을 저장하지 못했어요. 입력한 내용은 남아 있어요.',
                            style: TextStyle(color: burgundy),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    child: Text(saving ? '저장 중…' : '저장'),
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
