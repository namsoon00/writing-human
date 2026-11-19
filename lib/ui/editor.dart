import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../data/model.dart';
import '../source/transcription_comparison.dart';
import 'notebook_reflection.dart';
import 'paper.dart';
import 'ink_reveal.dart';
import 'paper_highlighter.dart';
import 'paper_tool.dart';
import 'paper_selection_menu.dart';
import 'writing_pen.dart';
import 'writing_sound.dart';
import 'pencil_marks.dart';
import 'transcription_reference.dart';
import 'transcription_marks.dart';
import 'editable_geometry.dart';

class PageEditor extends StatefulWidget {
  const PageEditor({
    super.key,
    required this.page,
    required this.onChanged,
    this.style = const WritingStyle(),
    this.focusNode,
    this.onEditingState,
    this.onEraseHighlight,
    this.onHighlight,
    this.paperTool = PaperTool.writing,
    this.keyboardOverlap = 0,
    this.originals = const [],
    this.guidedOriginal,
    this.reveal,
    this.startAtTopRequest,
  });
  final FocusNode? focusNode;
  final void Function(bool focused, bool composing)? onEditingState;
  final WritingPage page;
  final WritingStyle style;
  final void Function(String, String, int, int, double) onChanged;
  final void Function(String, int, int)? onEraseHighlight, onHighlight;
  final PaperTool paperTool;
  final List<RegisteredOriginal> originals;
  final RegisteredOriginal? guidedOriginal;
  final double keyboardOverlap;
  final ({int offset, int request})? reveal;
  final int? startAtTopRequest;
  @override
  State<PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<PageEditor> {
  late final PencilTextController text;
  late final _WritingScrollController scroll;
  late TextEditingValue _observedText;
  WritingSound? _sound;
  late TranscriptionComparison? _comparison = _compareChosen();

  TranscriptionComparison? _compareChosen() {
    final source = widget.guidedOriginal;
    return source == null ||
            widget.page.referenceOnly ||
            source.text.trim().isEmpty
        ? null
        : TranscriptionComparison(source);
  }

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
    final initialOffset = widget.startAtTopRequest == null ? p.scroll : 0.0;
    scroll = _WritingScrollController(
      initialScrollOffset: initialOffset,
      lastLineExtent: _lastLineExtent,
    );
    _prepareReveal();
    if (widget.style.writingSound) _sound = WritingSound();
    _observedText = text.value;
    text.addListener(_textChanged);
    scroll.addListener(_save);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
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
    if (oldWidget.guidedOriginal != widget.guidedOriginal ||
        oldWidget.page.referenceOnly != widget.page.referenceOnly) {
      _comparison = _compareChosen();
      findEditable(
        fieldRenderKey.currentContext?.findRenderObject(),
      )?.markNeedsLayout();
    }
    if (oldWidget.style.writingSound != widget.style.writingSound) {
      if (widget.style.writingSound) {
        _sound = WritingSound();
      } else {
        _closeSound();
      }
    }
    if (widget.reveal != null && widget.reveal != oldWidget.reveal) {
      _prepareReveal();
    } else if (widget.startAtTopRequest != oldWidget.startAtTopRequest &&
        !focus.hasFocus) {
      final offset = widget.startAtTopRequest == null
          ? widget.page.scroll
          : 0.0;
      scroll.layoutOffset = (_) => offset;
      _markEditableForLayout();
    }
  }

  void _markEditableForLayout() {
    findEditable(
      fieldRenderKey.currentContext?.findRenderObject(),
    )?.markNeedsLayout();
  }

  void _prepareReveal() {
    final reveal = widget.reveal;
    if (reveal == null || focus.hasFocus) return;
    scroll.layoutOffset = (pixels) {
      final editable = findEditable(
        fieldRenderKey.currentContext?.findRenderObject(),
      );
      if (editable == null || !editable.hasSize) return pixels;
      final endpoint = editable
          .getEndpointsForSelection(
            TextSelection.collapsed(
              offset: reveal.offset.clamp(0, text.text.length),
            ),
          )
          .single
          .point;
      return pixels + endpoint.dy - editable.preferredLineHeight - 16;
    };
    _markEditableForLayout();
  }

  void _emitEditingState() {
    if (!restoring) {
      widget.onEditingState?.call(
        focus.hasFocus,
        (text.value.isComposingRangeValid && !text.value.composing.isCollapsed),
      );
    }
  }

  double? _centeredLine;
  bool _centerQueued = false;

  void _followWritingLine() {
    if (_centerQueued || widget.guidedOriginal == null) return;
    _centerQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerQueued = false;
      if (!mounted || !scroll.hasClients) return;
      final anchor = scroll.writingCenter;
      final position = scroll.position;
      if (anchor == null || !focus.hasFocus) {
        _centeredLine = null;
        final bounded = scroll.offset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if (bounded != scroll.offset) scroll.jumpTo(bounded);
        return;
      }
      final selection = text.selection;
      if (_composing || !selection.isValid || !selection.isCollapsed) return;
      final editable = findEditable(
        fieldRenderKey.currentContext?.findRenderObject(),
      );
      if (editable == null || !editable.hasSize) return;
      final caret = editable.getLocalRectForCaret(selection.extent);
      final line = scroll.offset + caret.center.dy;
      if (_centeredLine != null && (line - _centeredLine!).abs() < 1) return;
      _centeredLine = line;
      final target = (line - anchor).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((target - scroll.offset).abs() >= 1) scroll.jumpTo(target);
    });
  }

  double _lastLineExtent(double pixels, double anchor) {
    final editable = findEditable(
      fieldRenderKey.currentContext?.findRenderObject(),
    );
    if (editable == null || !editable.hasSize) return 0;
    final lineEnd = editable
        .getEndpointsForSelection(
          TextSelection.collapsed(offset: text.text.length),
        )
        .single
        .point
        .dy;
    // The line endpoint is available while parent transforms are still in layout.
    return pixels + lineEnd - editable.preferredLineHeight / 2 - anchor + 2;
  }

  void _focusChanged() {
    _emitEditingState();
    if (mounted) {
      setState(() {});
    }
  }

  void _closeSound() {
    final sound = _sound;
    _sound = null;
    if (sound != null) unawaited(sound.dispose());
  }

  void _textChanged() {
    final previous = _observedText;
    final next = _observedText = text.value;
    if (widget.guidedOriginal != null &&
        previous.text == next.text &&
        previous.composing != next.composing) {
      findEditable(
        fieldRenderKey.currentContext?.findRenderObject(),
      )?.markNeedsLayout();
    }
    if (previous.text != next.text || previous.composing != next.composing) {
      _followWritingLine();
    }
    _save();
    final sound = _sound;
    if (sound != null &&
        !restoring &&
        focus.hasFocus &&
        hasNewWrittenCharacter(previous, next)) {
      unawaited(sound.stroke(() => mounted && focus.hasFocus));
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
      final marked = widget.page.pencilMarks.any(
        (m) => m.start < selection.end && selection.start < m.end,
      );
      final change = marked ? widget.onEraseHighlight : widget.onHighlight;
      if (change != null) {
        writingActions.add(
          ContextMenuButtonItem(
            label: marked ? '밑칠 지우기' : '밑칠하기',
            onPressed: () {
              if (text.value != value) return;
              state.hideToolbar(false);
              change(widget.page.id, selection.start, selection.end);
            },
          ),
        );
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

  void _dismissKeyboard() {
    if (_composing) return;
    focus.unfocus();
  }

  Widget _dismissGutter() => TextFieldTapRegion(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: _dismissKeyboard,
    ),
  );

  bool get _composing =>
      (text.value.isComposingRangeValid && !text.value.composing.isCollapsed);

  EditableTextState? get _editable {
    EditableTextState? result;
    void visit(Element child) {
      if (result != null) return;
      if (child is StatefulElement && child.state is EditableTextState) {
        result = child.state as EditableTextState;
      } else {
        child.visitChildren(visit);
      }
    }

    fieldRenderKey.currentContext?.visitChildElements(visit);
    return result;
  }

  void _placeCaret(TapUpDetails details) {
    final editor = _editable;
    if (editor == null || _composing) return;
    final render = editor.renderEditable;
    final lastLine = render.getLocalRectForCaret(
      TextPosition(offset: text.text.length),
    );
    final belowLastLine =
        render.globalToLocal(details.globalPosition).dy >
        lastLine.bottom +
            math.max(4.0, (render.preferredLineHeight - lastLine.height) / 2);
    if (belowLastLine && focus.hasFocus) {
      _dismissKeyboard();
      return;
    }
    editor.hideToolbar();
    editor.renderEditable.selectPositionAt(
      from: details.globalPosition,
      cause: SelectionChangedCause.tap,
    );
    // A tap at the same caret can leave selection unchanged while the
    // software keyboard is hidden.
    editor.requestKeyboard();
  }

  @override
  void dispose() {
    _closeSound();
    text.removeListener(_textChanged);
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
    final tool = widget.paperTool;
    final marking = tool != PaperTool.writing;
    final stroke = tool == PaperTool.eraser
        ? widget.onEraseHighlight
        : widget.onHighlight;
    final preciseSelection = defaultTargetPlatform == TargetPlatform.iOS;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = writingPagePadding(constraints.biggest);
        final writingMargins = EdgeInsets.only(
          left: padding.left,
          right: padding.right,
        );
        final overlap = widget.keyboardOverlap;
        final visiblePadding = padding.copyWith(
          bottom: overlap > 0 ? 12 : padding.bottom,
        );
        final source = widget.guidedOriginal;
        final hasChosenGuide = source != null;
        final paperHeight = math.max(0.0, constraints.maxHeight - overlap);
        final scaler = MediaQuery.textScalerOf(context);
        final referenceHeight = source?.photoId == null
            ? math.min(scaler.scale(16) * 4 + 12, paperHeight * .34)
            : math.min(232.0, paperHeight * .40);
        final lineHeight = scaler.scale(23) * 1.8;
        final canCenter =
            hasChosenGuide &&
            focus.hasFocus &&
            paperHeight / 2 >=
                referenceHeight + lineHeight + visiblePadding.bottom;
        final writingCenter = canCenter
            ? paperHeight / 2 - visiblePadding.top
            : null;
        if (scroll.writingCenter != writingCenter) {
          scroll.writingCenter = writingCenter;
          _centeredLine = null;
          _followWritingLine();
        }
        final writing = Stack(
          fit: hasChosenGuide ? StackFit.expand : StackFit.loose,
          children: [
            if (style.guides)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: WritingGuides(
                        enabled: style.guides,
                        top: padding.top,
                        left: padding.left,
                        right: padding.right,
                        lineHeight:
                            MediaQuery.textScalerOf(context).scale(23) * 1.8,
                        scroll: 0,
                        controller: scroll,
                      ),
                    ),
                  ),
                ),
              ),
            RepaintBoundary(
              key: fieldRenderKey,
              child: Padding(
                padding: hasChosenGuide ? visiblePadding : writingMargins,
                child: Semantics(
                  identifier: marking
                      ? 'writing-page-marking'
                      : 'writing-page-body',
                  child: TextSelectionTheme(
                    data: TextSelectionThemeData(
                      selectionColor: const Color(
                        0xffaa833c,
                      ).withValues(alpha: .25),
                      selectionHandleColor: penColors[style.penIndex],
                    ),
                    child: InkReveal(
                      controller: text,
                      focus: focus,
                      enabled: style.penMotion,
                      child: TextField(
                        key: const ValueKey('page-text'),
                        controller: text,
                        scrollController: scroll,
                        focusNode: focus,
                        // Keep native input/selection, with a separate ink indicator.
                        showCursor: false,
                        readOnly: marking,
                        canRequestFocus: !marking,
                        enableInteractiveSelection: !marking,
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
                        // Keep the native scroll viewport the height of the
                        // paper, including when the editable has no text.
                        decoration: hasChosenGuide
                            ? null
                            : InputDecoration(
                                contentPadding: EdgeInsets.only(
                                  top: visiblePadding.top,
                                  bottom: visiblePadding.bottom,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              left: writingMargins.left,
              right: writingMargins.right,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                excludeFromSemantics: true,
                supportedDevices: const {PointerDeviceKind.touch},
                onTapUp: preciseSelection || focus.hasFocus
                    ? _placeCaret
                    : null,
              ),
            ),
            if (marking && stroke != null)
              Positioned.fill(
                key: ValueKey(tool),
                child: PaperHighlighter(
                  controller: text,
                  scroll: scroll,
                  editable: () => _editable,
                  choice: style.bookDetails.pencil,
                  tool: tool,
                  onStroke: (range) =>
                      stroke(widget.page.id, range.start, range.end),
                ),
              ),
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
            if (_comparison case final comparison?)
              Positioned.fill(
                child: TranscriptionMarks(
                  comparison: comparison,
                  controller: text,
                  scroll: scroll,
                  fieldKey: fieldRenderKey,
                ),
              ),
            if (widget.originals.any((item) => item.reflection != null))
              Positioned.fill(
                child: NotebookReflection(
                  originals: widget.originals,
                  guided: widget.guidedOriginal,
                  controller: text,
                  scroll: scroll,
                  fieldKey: fieldRenderKey,
                  padding: visiblePadding,
                ),
              ),
            Positioned.fill(
              child: WritingPen(
                controller: text,
                scroll: scroll,
                focus: focus,
                fieldKey: fieldRenderKey,
                color: penColors[style.penIndex],
              ),
            ),
          ],
        );
        return Padding(
          padding: EdgeInsets.only(
            bottom: math.min(overlap, constraints.maxHeight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: writing),
              if (source != null && referenceHeight > 0)
                Padding(
                  padding: writingMargins,
                  child: SizedBox(
                    height: referenceHeight,
                    child: TranscriptionReference(
                      key: const ValueKey('transcription-reference'),
                      original: source,
                      comparison: _comparison,
                      photoPanelColor: panelPaperColor(
                        paperColors[style.paperIndex],
                      ),
                      controller: text,
                      style: writingTextStyle(
                        style.fontIndex,
                        size: 16,
                        color: ink,
                        useDevelopmentTypeface: style.useDevelopmentTypeface,
                      ).copyWith(height: 1.35),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WritingScrollController extends ScrollController {
  _WritingScrollController({
    required super.initialScrollOffset,
    required this.lastLineExtent,
  });

  final double Function(double pixels, double anchor) lastLineExtent;
  double? writingCenter;
  double Function(double pixels)? layoutOffset;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _WritingScrollPosition(
    controller: this,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
  );
}

class _WritingScrollPosition extends ScrollPositionWithSingleContext {
  _WritingScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    required super.initialPixels,
    required super.keepScrollOffset,
    super.oldPosition,
  });

  final _WritingScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final center = controller.writingCenter;
    final min = center == null
        ? minScrollExtent
        : math.min(minScrollExtent, -center);
    final max = center == null
        ? maxScrollExtent
        : math.max(maxScrollExtent, controller.lastLineExtent(pixels, center));

    // Resolve the requested position before RenderEditable paints the page.
    final restore = controller.layoutOffset;
    controller.layoutOffset = null;
    if (restore != null || !hasContentDimensions) {
      final target = (restore?.call(pixels) ?? pixels).clamp(min, max);
      if (target != pixels) correctPixels(target);
    }
    return super.applyContentDimensions(min, max);
  }
}
