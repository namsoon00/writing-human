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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 400;
        final horizontal = constraints.maxWidth < 500 ? 30.0 : 64.0;
        final padding = EdgeInsets.fromLTRB(
          horizontal,
          compact ? 24 : 54,
          horizontal,
          44,
        );
        return Stack(
          children: [
            if (style.guides)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: scroll,
                      builder: (context, _) => CustomPaint(
                        painter: WritingGuides(
                          enabled: style.guides,
                          top: padding.top,
                          left: padding.left,
                          right: padding.right,
                          lineHeight:
                              MediaQuery.textScalerOf(context).scale(23) * 1.8,
                          scroll: scroll.hasClients ? scroll.offset : 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
                cursorColor: brandInk,
                cursorWidth: 1.2,
                decoration: InputDecoration(
                  hintText: '마음에 남은 문장을\n천천히 옮겨 적어보세요.',
                  hintStyle: writingTextStyle(
                    style.fontIndex,
                    size: 21,
                    color: muted,
                  ),
                  contentPadding: padding,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
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
        );
      },
    );
  }
}
