import 'package:flutter/material.dart';

import 'paper_selection_menu.dart';

/// Edits the transcribed text without adding a border to the paper slip.
class PhotoOriginalCorrection extends StatelessWidget {
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

  bool get _canSelect {
    final value = controller.value;
    return !readOnly &&
        (!value.isComposingRangeValid || value.composing.isCollapsed);
  }

  Widget _selectionMenu(BuildContext context, EditableTextState state) {
    if (!_canSelect) return const SizedBox.shrink();
    final actions = state.contextMenuButtonItems
        .where(
          (item) => switch (item.type) {
            ContextMenuButtonType.copy ||
            ContextMenuButtonType.cut ||
            ContextMenuButtonType.paste ||
            ContextMenuButtonType.selectAll => true,
            _ => false,
          },
        )
        .toList();
    if (actions.isEmpty) return const SizedBox.shrink();
    return PaperSelectionMenu(
      anchors: state.contextMenuAnchors,
      editActions: actions,
      writingActions: const [],
      otherActions: const [],
      onTapOutside: (_) => state.hideToolbar(false),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: TextSelectionTheme(
      data: TextSelectionTheme.of(context).copyWith(
        selectionColor: ink.withValues(alpha: .18),
        selectionHandleColor: ink,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: style,
          cursorColor: ink,
          readOnly: readOnly,
          enableInteractiveSelection: _canSelect,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: null,
          contextMenuBuilder: _selectionMenu,
        ),
      ),
    ),
  );
}
