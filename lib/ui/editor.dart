import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';
import 'writing_pen.dart';
import 'pencil_marks.dart';
import 'transcription_guide.dart';
import 'editable_geometry.dart';
import 'guide_scroll.dart';

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
    this.reveal,
  });
  final FocusNode? focusNode;
  final void Function(bool focused, bool composing)? onEditingState;
  final WritingPage page;
  final WritingStyle style;
  final void Function(String, String, int, int, double) onChanged;
  final void Function(String, int, int)? onPencilMark;
  final TranscriptionGuide? guide;
  final ({int offset, int request})? reveal;
  @override
  State<PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<PageEditor> {
  late final PencilTextController text;
  late final GuideScrollController scroll;
  final _guideLayout = TextPainter();
  double _pendingGuideExtent = 0;
  bool _extentQueued = false;
  Drag? _guideDrag;
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
    scroll = GuideScrollController(initialScrollOffset: p.scroll);
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
    if (oldWidget.guide != null && widget.guide == null) _updateGuideExtent(0);
    if (widget.reveal != null && widget.reveal != oldWidget.reveal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal();
      });
    }
  }

  void _updateGuideExtent(double extent) {
    _pendingGuideExtent = extent;
    if (_extentQueued) return;
    _extentQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extentQueued = false;
      if (!mounted ||
          !scroll.setGuideExtent(
            widget.guide == null ? 0 : _pendingGuideExtent,
          )) {
        return;
      }
      // Scrollable updates its gesture recognizers during editable layout.
      findEditable(
        fieldRenderKey.currentContext?.findRenderObject(),
      )?.markNeedsLayout();
    });
  }

  void _scrollGuide(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !scroll.hasClients) return;
    final position = scroll.position;
    final delta = event.scrollDelta.dy;
    if (delta == 0 ||
        (delta > 0 && position.pixels >= position.maxScrollExtent) ||
        (delta < 0 && position.pixels <= position.minScrollExtent)) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (mounted && scroll.hasClients) scroll.position.pointerScroll(delta);
    });
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
      scroll.hasClients ? scroll.offset.clamp(0.0, scroll.textExtent) : 0,
    );
  }

  @override
  void dispose() {
    text.removeListener(_save);
    scroll.removeListener(_save);
    text.dispose();
    _guideDrag?.cancel();
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
        final guide = widget.guide;
        final paper = Stack(
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
                      layout: _guideLayout,
                      onExtent: _updateGuideExtent,
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
        return Listener(
          onPointerSignal: guide == null ? null : _scrollGuide,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            supportedDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
              PointerDeviceKind.trackpad,
            },
            onVerticalDragStart: guide == null
                ? null
                : (details) {
                    if (scroll.hasClients) {
                      _guideDrag = scroll.position.drag(
                        details,
                        () => _guideDrag = null,
                      );
                    }
                  },
            onVerticalDragUpdate: guide == null
                ? null
                : (details) => _guideDrag?.update(details),
            onVerticalDragEnd: guide == null
                ? null
                : (details) => _guideDrag?.end(details),
            onVerticalDragCancel: guide == null
                ? null
                : () => _guideDrag?.cancel(),
            child: paper,
          ),
        );
      },
    );
  }
}
