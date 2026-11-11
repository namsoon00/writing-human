import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';
import 'writing_pen.dart';
import 'pencil_marks.dart';
import 'transcription_guide.dart';

class PageEditor extends StatefulWidget {
  const PageEditor({
    super.key,
    required this.page,
    required this.onChanged,
    this.style = const WritingStyle(),
    this.focusNode,
    this.onEditingState,
    this.onPencilMark,
    this.guide,
  });
  final FocusNode? focusNode;
  final void Function(bool focused, bool composing)? onEditingState;
  final WritingPage page;
  final WritingStyle style;
  final void Function(String, String, int, int, double) onChanged;
  final void Function(String, int, int)? onPencilMark;
  final TranscriptionGuide? guide;
  @override
  State<PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<PageEditor> {
  late final PencilTextController text;
  late final ScrollController scroll;
  late final focus = widget.focusNode ?? FocusNode();
  bool restoring = true;
  final fieldRenderKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    focus.addListener(_focusChanged);
    final p = widget.page;
    text = PencilTextController(
      annotatedText: p.text,
      marks: p.pencilMarks,
      choice: widget.style.bookDetails.pencil,
      value: TextEditingValue(
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

  @override
  void didUpdateWidget(PageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    text.annotatedText = widget.page.text;
    text.marks = widget.page.pencilMarks;
    text.choice = widget.style.bookDetails.pencil;
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
        final padding = writingPagePadding(constraints.biggest);
        final guide = widget.guide;
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
                // Keep native input/selection, with a separate ink indicator.
                showCursor: false,
                maxLines: null,
                minLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                autocorrect: false,
                enableSuggestions: false,
                contextMenuBuilder: (context, state) {
                  final selection = text.selection;
                  final canMark =
                      widget.onPencilMark != null &&
                      selection.isValid &&
                      !selection.isCollapsed &&
                      (!text.value.composing.isValid ||
                          text.value.composing.isCollapsed);
                  final marked = widget.page.pencilMarks.any(
                    (m) => m.start <= selection.start && m.end >= selection.end,
                  );
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: state.contextMenuAnchors,
                    buttonItems: [
                      if (canMark)
                        ContextMenuButtonItem(
                          label: marked ? '연필 표시 지우기' : '연필 표시',
                          onPressed: () {
                            // The selection is read only, including during toolbar actions.
                            state.hideToolbar();
                            widget.onPencilMark!(
                              widget.page.id,
                              selection.start,
                              selection.end,
                            );
                          },
                        ),
                      ...state.contextMenuButtonItems,
                    ],
                  );
                },
                style: writingTextStyle(
                  style.fontIndex,
                  size: 23,
                  color: penColors[style.penIndex],
                  useDevelopmentTypeface: style.useDevelopmentTypeface,
                ),
                cursorColor: brandInk,
                cursorWidth: 1.2,
                decoration: InputDecoration(
                  hintText: guide == null ? '마음에 남은 문장을\n천천히 옮겨 적어보세요.' : null,
                  hintStyle: writingTextStyle(
                    style.fontIndex,
                    size: 21,
                    color: muted,
                    useDevelopmentTypeface: style.useDevelopmentTypeface,
                  ),
                  contentPadding: padding,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            if (guide != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('transcription-guide'),
                    painter: TranscriptionGuidePainter(
                      guide: guide,
                      controller: text,
                      scroll: scroll,
                      fieldKey: fieldRenderKey,
                      bottomPadding: padding.bottom,
                      style: writingTextStyle(
                        style.fontIndex,
                        color: const Color(0xff8b8273).withValues(alpha: .58),
                        useDevelopmentTypeface: style.useDevelopmentTypeface,
                      ),
                    ),
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
                color: penColors[style.penIndex],
              ),
            ),
          ],
        );
      },
    );
  }
}
