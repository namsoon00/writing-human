import 'package:flutter/material.dart';

/// Provides the keyboard and IME on the same sheet while correcting text.
class PhotoOriginalCorrection extends StatefulWidget {
  const PhotoOriginalCorrection({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.ink,
    required this.readOnly,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Color ink;
  final bool readOnly;

  @override
  State<PhotoOriginalCorrection> createState() =>
      _PhotoOriginalCorrectionState();
}

class _PhotoOriginalCorrectionState extends State<PhotoOriginalCorrection> {
  final _editable = GlobalKey<EditableTextState>();

  void _placeCursor(TapUpDetails details) {
    final state = _editable.currentState;
    if (state == null || widget.readOnly) return;
    // Keep the IME in charge while Korean text is being composed.
    final value = widget.controller.value;
    if (value.composing.isCollapsed || !value.isComposingRangeValid) {
      final position = state.renderEditable.getPositionForPoint(
        details.globalPosition,
      );
      state.userUpdateTextEditingValue(
        value.copyWith(
          selection: TextSelection.fromPosition(position),
          composing: TextRange.empty,
        ),
        SelectionChangedCause.tap,
      );
    }
    state.requestKeyboard();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Semantics(
      enabled: !widget.readOnly,
      onFocus: widget.readOnly
          ? null
          : () => _editable.currentState?.requestKeyboard(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onTapUp: _placeCursor,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: EditableText(
            key: _editable,
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: widget.style,
            cursorColor: widget.ink,
            backgroundCursorColor: Colors.transparent,
            selectionColor: widget.ink.withValues(alpha: .18),
            readOnly: widget.readOnly,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}
