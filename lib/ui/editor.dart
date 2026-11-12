import 'package:flutter/material.dart';
import '../data/model.dart';
import '../source/originals.dart';
import 'notebook_reflection.dart';
import 'paper.dart';
import 'writing_pen.dart';
import 'pencil_marks.dart';
import 'transcription_guide.dart';
import 'editable_geometry.dart';

class PageEditor extends StatefulWidget {
  const PageEditor({
    super.key,
    required this.page,
    required this.onChanged,
    this.style = const WritingStyle(),
    this.focusNode,
    this.onEditingState,
    this.onPencilMark,
    this.onReflection,
    this.originals = const [],
    this.reveal,
  });
  final FocusNode? focusNode;
  final void Function(bool focused, bool composing)? onEditingState;
  final WritingPage page;
  final WritingStyle style;
  final void Function(String, String, int, int, double) onChanged;
  final void Function(String, int, int)? onPencilMark;
  final List<RegisteredOriginal> originals;
  final ValueChanged<OriginalMatch>? onReflection;
  final ({int offset, int request})? reveal;
  @override
  State<PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<PageEditor> {
  late final PencilTextController text;
  late final ScrollController scroll;
  final _guideLayout = TextPainter();
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
      _reveal();
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
    if (widget.reveal != null && widget.reveal != oldWidget.reveal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal();
      });
    }
  }

  void _reveal() {
    final reveal = widget.reveal;
    if (reveal == null || !scroll.hasClients || focus.hasFocus) return;
    final editable = findEditable(
      fieldRenderKey.currentContext?.findRenderObject(),
    );
    if (editable == null || !editable.hasSize) return;
    final caret = editable.getLocalRectForCaret(
      TextPosition(offset: reveal.offset.clamp(0, text.text.length)),
    );
    final target = (scroll.offset + caret.top - 16).clamp(
      0.0,
      scroll.position.maxScrollExtent,
    );
    // Scroll to the result without changing selection, focus, or composition.
    scroll.jumpTo(target);
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
      scroll.hasClients
          ? scroll.offset.clamp(0.0, scroll.position.maxScrollExtent)
          : 0,
    );
  }

  @override
  void dispose() {
    text.removeListener(_save);
    scroll.removeListener(_save);
    text.dispose();
    scroll.dispose();
    _guideLayout.dispose();
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
                  contentPadding: padding,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            if (widget.originals.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('transcription-guide'),
                    painter: TranscriptionGuidePainter(
                      originals: widget.originals,
                      focus: focus,
                      controller: text,
                      scroll: scroll,
                      fieldKey: fieldRenderKey,
                      bottomPadding: padding.bottom,
                      layout: _guideLayout,
                      style: writingTextStyle(
                        style.fontIndex,
                        color: const Color(0xff8b8273).withValues(alpha: .58),
                        useDevelopmentTypeface: style.useDevelopmentTypeface,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.originals.isNotEmpty)
              Positioned.fill(
                child: NotebookReflection(
                  originals: widget.originals,
                  controller: text,
                  scroll: scroll,
                  fieldKey: fieldRenderKey,
                  padding: padding,
                  onEdit: widget.onReflection,
                ),
              ),
            Positioned.fill(
              child: WritingPen(
                controller: text,
                scroll: scroll,
                focus: focus,
                fieldKey: fieldRenderKey,
                animateInk: style.penMotion,
                color: penColors[style.penIndex],
              ),
            ),
          ],
        );
      },
    );
  }
}
