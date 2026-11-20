import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../source/original_text_cleanup.dart';

/// Edits the draft on request and allows undo while it is still unchanged.
class OriginalTextCleanup extends StatefulWidget {
  const OriginalTextCleanup({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  State<OriginalTextCleanup> createState() => _OriginalTextCleanupState();
}

class _OriginalTextCleanupState extends State<OriginalTextCleanup> {
  ({TextEditingValue before, String after})? _undo;

  bool get _editable =>
      widget.enabled &&
      !(widget.controller.value.isComposingRangeValid &&
          !widget.controller.value.composing.isCollapsed);

  @override
  void didUpdateWidget(OriginalTextCleanup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _undo = null;
  }

  void _clean() {
    if (!_editable) return;
    final controller = widget.controller;
    final before = controller.value;
    final cleaned = cleanOriginalText(before.text);
    if (cleaned == before.text) return;
    FocusScope.of(context).unfocus();
    setState(() => _undo = (before: before, after: cleaned));
    controller.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }

  void _restore() {
    final undo = _undo;
    if (!_editable || undo == null || widget.controller.text != undo.after) {
      return;
    }
    setState(() => _undo = null);
    widget.controller.value = undo.before;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final value = widget.controller.value;
      final canUndo = _undo?.after == value.text;
      final canClean = needsOriginalTextCleanup(value.text);
      if (!canClean && !canUndo) return const SizedBox.shrink();
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          TextButton.icon(
            onPressed: _editable && canClean ? _clean : null,
            icon: const Icon(CupertinoIcons.textformat, size: 16),
            label: const Text('특수문자 정리'),
          ),
          if (canUndo)
            TextButton(
              onPressed: _editable ? _restore : null,
              child: const Text('정리 되돌리기'),
            ),
        ],
      );
    },
  );
}
