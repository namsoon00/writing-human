import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';
import 'writing_pen.dart';

class PageEditor extends StatefulWidget {
  const PageEditor({
    super.key,
    required this.page,
    required this.onChanged,
    this.style = const WritingStyle(),
    this.focusNode,
    this.onEditingState,
  });
  final FocusNode? focusNode;
  final void Function(bool focused, bool composing)? onEditingState;
  final WritingPage page;
  final WritingStyle style;
  final void Function(String, String, int, int, double) onChanged;
  @override
  State<PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<PageEditor> {
  late final TextEditingController text;
  late final ScrollController scroll;
  late final focus = widget.focusNode ?? FocusNode();
  bool restoring = true;
  final fieldRenderKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    focus.addListener(_focusChanged);
    final p = widget.page;
    text = TextEditingController.fromValue(
      TextEditingValue(
        text: p.text,
        selection: TextSelection(
          baseOffset: p.base.clamp(0, p.text.length),
          extentOffset: p.extent.clamp(0, p.text.length),
        ),
      ),
    );
    scroll = ScrollController(initialScrollOffset: p.scroll);
    text.addListener(_save);
    scroll.addListener(_save);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (scroll.hasClients) {
        scroll.jumpTo(p.scroll.clamp(0, scroll.position.maxScrollExtent));
      }
      restoring = false;
      _emitEditingState();
    });
  }

  void _emitEditingState() {
    if (!restoring) {
      widget.onEditingState?.call(
        focus.hasFocus,
        text.value.composing.isValid && !text.value.composing.isCollapsed,
      );
    }
  }

  void _focusChanged() {
    _emitEditingState();
    if (mounted) {
      setState(() {});
    }
  }

  void _save() {
    if (restoring) {
      return;
    }
    _emitEditingState();
    // Observe IME text, selection and scroll without rewriting the controller.
    final value = text.value;
    widget.onChanged(
      widget.page.id,
      value.text,
      value.selection.baseOffset,
      value.selection.extentOffset,
      scroll.hasClients ? scroll.offset.clamp(0, double.infinity) : 0,
    );
  }

  @override
  void dispose() {
    text.removeListener(_save);
    scroll.removeListener(_save);
    text.dispose();
    scroll.dispose();
    focus.removeListener(_focusChanged);
    if (widget.focusNode == null) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return PaperSurface(
      color: paperColors[style.paperIndex],
      torn: false,
      guides: style.guides,
      child: Stack(
        children: [
          RepaintBoundary(
            key: fieldRenderKey,
            child: TextField(
              key: const ValueKey('page-text'),
              controller: text,
              scrollController: scroll,
              focusNode: focus,
              maxLines: null,
              minLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              autocorrect: false,
              enableSuggestions: false,
              style: writingTextStyle(
                style.fontIndex,
                size: 23,
                color: penColors[style.penIndex],
              ),
              cursorColor: burgundy,
              cursorWidth: 1.2,
              decoration: InputDecoration(
                hintText: '여기를 눌러 써보세요.',
                hintStyle: writingTextStyle(
                  style.fontIndex,
                  size: 23,
                  color: const Color(0xffa7ada3),
                ),
                contentPadding: const EdgeInsets.fromLTRB(26, 38, 25, 42),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Positioned.fill(
            child: WritingPen(
              controller: text,
              scroll: scroll,
              focus: focus,
              fieldKey: fieldRenderKey,
              enabled: style.penMotion,
            ),
          ),
        ],
      ),
    );
  }
}
