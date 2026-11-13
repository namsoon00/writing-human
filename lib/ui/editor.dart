import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/model.dart';
import '../source/originals.dart';
import 'notebook_reflection.dart';
import 'paper.dart';
import 'paper_selection_menu.dart';
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
    this.onSaveReflection,
    this.reflectionFocus,
    this.keyboardOverlap = 0,
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
  final Future<bool> Function(RegisteredOriginal, OriginalReflection?)?
  onSaveReflection;
  final FocusNode? reflectionFocus;
  final double keyboardOverlap;
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
  final _reflectionKey = GlobalKey<NotebookReflectionState>();
  bool _reflectionFocused = false, _reflectionComposing = false;

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
        focus.hasFocus || _reflectionFocused,
        _reflectionComposing ||
            (text.value.isComposingRangeValid &&
                !text.value.composing.isCollapsed),
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

  Widget _selectionMenu(BuildContext context, EditableTextState state) {
    final value = text.value;
    final selection = value.selection;
    if (!selection.isValid ||
        selection.end > value.text.length ||
        (value.isComposingRangeValid && !value.composing.isCollapsed)) {
      return const SizedBox.shrink();
    }
    final native = {
      for (final item in state.contextMenuButtonItems) item.type: item,
    };
    final paste = native[ContextMenuButtonType.paste];
    final selectAll = native[ContextMenuButtonType.selectAll];
    final editActions = <ContextMenuButtonItem>[];
    final writingActions = <ContextMenuButtonItem>[];
    final otherActions = <ContextMenuButtonItem>[];
    if (selection.isCollapsed) {
      final caret = selection.extentOffset;
      final start = caret == 0
          ? 0
          : value.text.lastIndexOf('\n', caret - 1) + 1;
      final end = value.text.indexOf('\n', caret);
      final blankLine = value.text
          .substring(start, end < 0 ? value.text.length : end)
          .trim()
          .isEmpty;
      if (paste != null) editActions.add(paste);
      if (!blankLine && selectAll != null) editActions.add(selectAll);
    } else {
      for (final type in [
        ContextMenuButtonType.copy,
        ContextMenuButtonType.cut,
      ]) {
        final item = native[type];
        if (item != null) editActions.add(item);
      }
      if (paste != null) otherActions.add(paste);
      if (selectAll != null) otherActions.add(selectAll);
      if (widget.onPencilMark case final mark?) {
        final marked = widget.page.pencilMarks.any(
          (m) => m.start <= selection.start && m.end >= selection.end,
        );
        writingActions.add(
          ContextMenuButtonItem(
            label: marked ? '연필 표시 지우기' : '연필 표시',
            onPressed: () {
              if (text.value != value) return;
              state.hideToolbar(false);
              mark(widget.page.id, selection.start, selection.end);
            },
          ),
        );
      }
      if (widget.onSaveReflection != null) {
        final passage = selection.textInside(value.text);
        final match = matchSelectedOriginal(widget.originals, passage);
        if (match != null) {
          writingActions.add(
            ContextMenuButtonItem(
              label: '느낀 점',
              onPressed: () {
                if (text.value != value) return;
                state.hideToolbar();
                _reflectionKey.currentState?.edit((
                  match: match,
                  offset: selection.start + passage.trimRight().length,
                ));
              },
            ),
          );
        }
      }
    }
    if (editActions.isEmpty && writingActions.isEmpty && otherActions.isEmpty) {
      return const SizedBox.shrink();
    }
    return PaperSelectionMenu(
      anchors: state.contextMenuAnchors,
      editActions: editActions,
      writingActions: writingActions,
      otherActions: otherActions,
    );
  }

  Widget _dismissGutter() => TextFieldTapRegion(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () {
        if (_reflectionComposing) return;
        widget.reflectionFocus?.unfocus();
        focus.unfocus();
      },
    ),
  );

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
        final overlap = widget.keyboardOverlap;
        final visiblePadding = padding.copyWith(
          bottom: overlap > 0 ? 12 : padding.bottom,
        );
        return Padding(
          padding: EdgeInsets.only(
            bottom: math.min(overlap, constraints.maxHeight),
          ),
          child: Stack(
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
                                MediaQuery.textScalerOf(context).scale(23) *
                                1.8,
                            scroll: scroll.hasClients ? scroll.offset : 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              RepaintBoundary(
                key: fieldRenderKey,
                child: TextSelectionTheme(
                  data: TextSelectionThemeData(
                    selectionColor: const Color(
                      0xffaa833c,
                    ).withValues(alpha: .25),
                    selectionHandleColor: penColors[style.penIndex],
                  ),
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
                    contextMenuBuilder: _selectionMenu,
                    style: writingTextStyle(
                      style.fontIndex,
                      size: 23,
                      color: penColors[style.penIndex],
                      useDevelopmentTypeface: style.useDevelopmentTypeface,
                    ),
                    cursorColor: brandInk,
                    cursorWidth: 1.2,
                    decoration: InputDecoration(
                      contentPadding: visiblePadding,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),
              if (focus.hasFocus || _reflectionFocused) ...[
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: padding.left,
                  child: _dismissGutter(),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: padding.right,
                  child: _dismissGutter(),
                ),
              ],
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
                        bottomPadding: visiblePadding.bottom,
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
                    key: _reflectionKey,
                    originals: widget.originals,
                    controller: text,
                    scroll: scroll,
                    fieldKey: fieldRenderKey,
                    padding: visiblePadding,
                    paperColor: paperColors[style.paperIndex],
                    focus: widget.reflectionFocus,
                    onSave: widget.onSaveReflection,
                    onEditingState: (focused, composing) {
                      if (_reflectionFocused == focused &&
                          _reflectionComposing == composing) {
                        return;
                      }
                      setState(() {
                        _reflectionFocused = focused;
                        _reflectionComposing = composing;
                      });
                      _emitEditingState();
                    },
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
          ),
        );
      },
    );
  }
}
