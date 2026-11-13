import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/model.dart';
import '../source/originals.dart';
import 'editable_geometry.dart';
import 'reflection_ink.dart';

typedef _Placement = ({Rect rect, int lines});

final _writtenCharacter = RegExp(r'\S');

/// Places the pencil note on the same paper as the native editor.
class NotebookReflection extends StatefulWidget {
  const NotebookReflection({
    super.key,
    required this.originals,
    required this.controller,
    required this.scroll,
    required this.fieldKey,
    required this.padding,
    required this.paperColor,
    this.focus,
    this.onSave,
    this.onEditingState,
  });

  final List<RegisteredOriginal> originals;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final EdgeInsets padding;
  final Color paperColor;
  final FocusNode? focus;
  final Future<bool> Function(RegisteredOriginal, OriginalReflection?)? onSave;
  final void Function(bool focused, bool composing)? onEditingState;

  @override
  State<NotebookReflection> createState() => NotebookReflectionState();
}

class NotebookReflectionState extends State<NotebookReflection> {
  final _field = TextEditingController();
  final _tapGroup = Object();
  late final _focus = widget.focus ?? FocusNode();
  NotebookReflectionMatch? _active;
  PencilMark? _mark;
  String _submitted = '';
  int _revision = 0;
  bool _failed = false;
  bool _saving = false;
  bool _opening = false;
  bool _queued = false;
  _Placement? _placement;

  bool get _composing =>
      _field.value.isComposingRangeValid && !_field.value.composing.isCollapsed;

  String get _draft => _field.text.trim().isEmpty ? '' : _field.text;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    _field.addListener(_draftChanged);
  }

  void edit(NotebookReflectionMatch anchor) {
    if (widget.onSave == null || _composing) return;
    if (_active?.match.original.id == anchor.match.original.id) {
      _focus.requestFocus();
      return;
    }
    if (_failed || _saving) return;
    final match = anchor.match;
    final reflection = match.original.reflection;
    _revision++;
    _active = anchor;
    _mark = reflection?.mark ?? PencilMark(match.start, match.end);
    _submitted = reflection?.text ?? '';
    _opening = true;
    _field.value = TextEditingValue(
      text: _submitted,
      selection: TextSelection.collapsed(offset: _submitted.length),
    );
    _opening = false;
    setState(() {});
    // Attach the native field before asking it to open the keyboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _active != anchor) return;
      _focus.requestFocus();
    });
  }

  void _draftChanged() {
    if (_active == null || _opening) return;
    widget.onEditingState?.call(_focus.hasFocus, _composing);
    if (!_composing) unawaited(_save());
  }

  void _focusChanged() {
    if (_active == null) return;
    widget.onEditingState?.call(_focus.hasFocus, _composing);
    if (!_focus.hasFocus) unawaited(_save());
  }

  Future<void> _save({bool retry = false}) async {
    final active = _active;
    final save = widget.onSave;
    if (active == null || save == null || _composing) return;
    final draft = _draft;
    if (draft == _submitted && !retry) {
      if (!_focus.hasFocus && !_failed && !_saving) _close();
      return;
    }
    final revision = ++_revision;
    _submitted = draft;
    _saving = true;
    final saved = await save(
      active.match.original,
      draft.isEmpty ? null : OriginalReflection(draft, mark: _mark),
    );
    if (!mounted || revision != _revision) return;
    _saving = false;
    if (!_focus.hasFocus && saved && !_composing && _draft == draft) {
      _close();
    } else if (_failed == saved) {
      setState(() => _failed = !saved);
    }
  }

  void _close() {
    if (!mounted || _active == null) return;
    setState(() {
      _active = null;
      _failed = false;
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _field.removeListener(_draftChanged);
    _field.dispose();
    if (widget.focus == null) _focus.dispose();
    super.dispose();
  }

  void _measure(
    NotebookReflectionMatch? reflection,
    Size size,
    double lineHeight,
  ) {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      final next = reflection == null
          ? null
          : _locate(reflection, size, lineHeight);
      if (next != _placement) setState(() => _placement = next);
    });
  }

  _Placement? _locate(
    NotebookReflectionMatch reflection,
    Size size,
    double lineHeight,
  ) {
    final field = widget.fieldKey.currentContext?.findRenderObject();
    final editable = findEditable(field);
    final text = widget.controller.text;
    final offset = reflection.offset;
    if (field == null ||
        editable == null ||
        !editable.hasSize ||
        offset < 0 ||
        offset > text.length) {
      return null;
    }
    final origin = MatrixUtils.transformPoint(
      editable.getTransformTo(field),
      Offset.zero,
    );
    final writingLine = editable.preferredLineHeight;
    double bottomOf(int offset, TextAffinity affinity) => editable
        .getEndpointsForSelection(
          TextSelection.collapsed(offset: offset, affinity: affinity),
        )
        .single
        .point
        .dy;
    final lineBottom = bottomOf(offset, TextAffinity.upstream);
    final lineTop = origin.dy + lineBottom - writingLine;
    final anchorBottom = origin.dy + lineBottom;
    if (anchorBottom <= origin.dy || lineTop >= size.height) return null;

    final noteTop = anchorBottom + 5;
    var available = size.height - 4 - noteTop;
    if (offset < text.length) {
      // Probe the next visual line so wrapped text is treated like a new line.
      final next = editable
          .getPositionForPoint(
            editable.localToGlobal(Offset(0, lineBottom + writingLine * .45)),
          )
          .offset;
      final written = _writtenCharacter
          .allMatches(text, math.max(next, offset))
          .firstOrNull;
      if (written != null) {
        final nextBottom = bottomOf(written.start, TextAffinity.downstream);
        if (nextBottom > lineBottom + 1) {
          available = math.min(
            available,
            origin.dy + nextBottom - writingLine - noteTop - 3,
          );
        }
      }
    }
    final hasNote = reflection.match.original.reflection != null;
    if (available >= lineHeight + 5) {
      final maxWidth = size.width - widget.padding.horizontal - 7;
      if (maxWidth > 40) {
        final maxLines = _active != null ? 3 : (hasNote ? 2 : 1);
        final lines = ((available - 5) ~/ lineHeight).clamp(1, maxLines);
        return (
          rect: Rect.fromLTWH(
            widget.padding.left + 7,
            noteTop,
            math.min(maxWidth, hasNote ? 300.0 : 132.0),
            math.min(available, math.max(40.0, lineHeight * lines + 5)),
          ),
          lines: lines,
        );
      }
    }

    // When another written line occupies the space, leave a pencil mark beside
    // the original line so its reflection can still be opened.
    final top = math.max(0.0, lineTop);
    final height = math.min(anchorBottom - top, size.height - top);
    if (height <= 0 || widget.padding.left < 18) return null;
    return (
      rect: Rect.fromLTWH(0, top, widget.padding.left - 2, height),
      lines: 0,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.scroll]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final value = widget.controller.value;
        final selection = value.selection;
        final composing =
            value.isComposingRangeValid && !value.composing.isCollapsed;
        final caret = composing && value.composing.end == selection.extentOffset
            ? value.composing.start
            : selection.extentOffset;
        NotebookReflectionMatch? reflection;
        if (selection.isCollapsed) {
          reflection = reflectionForWriting(
            widget.originals,
            value.text,
            caret,
          );
        } else if (!composing &&
            selection.isValid &&
            selection.end <= value.text.length) {
          final passage = selection.textInside(value.text);
          final match = matchSelectedOriginal(widget.originals, passage);
          if (match != null && match.original.reflection != null) {
            reflection = (
              match: match,
              offset: selection.start + passage.trimRight().length,
            );
          }
        }
        final lineHeight = MediaQuery.textScalerOf(context).scale(21);
        _measure(_active ?? reflection, box.biggest, lineHeight);
        final placement = _placement;
        if (_active != null) {
          return _editor(box.biggest, placement, lineHeight);
        }
        if (reflection == null || placement == null) {
          return const SizedBox.expand();
        }
        final note = reflection.match.original.reflection?.text;
        final anchor = reflection;
        final label = note == null ? '느낀 점 남기기' : '느낀 점 고치기';
        return Stack(
          children: [
            Positioned.fromRect(
              rect: placement.rect,
              child: Align(
                alignment: placement.lines == 0
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: TextFieldTapRegion(
                  child: Tooltip(
                    message: label,
                    child: Semantics(
                      label: label,
                      child: InkWell(
                        key: const ValueKey('writing-reflection'),
                        onTap: widget.onSave == null || composing
                            ? null
                            : () => edit(anchor),
                        child: SizedBox(
                          height: placement.rect.height,
                          child: placement.lines == 0
                              ? const Center(
                                  child: Icon(
                                    CupertinoIcons.pencil,
                                    size: 15,
                                    color: reflectionGraphite,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CustomPaint(
                                      size: Size(24, 22),
                                      painter: ReflectionArrow(),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Transform.rotate(
                                        angle: -.018,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          note ?? '느낀 점',
                                          maxLines: placement.lines,
                                          overflow: TextOverflow.ellipsis,
                                          style: reflectionHandwriting.copyWith(
                                            fontSize: 21,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _editor(Size size, _Placement? placement, double lineHeight) {
    final left = widget.padding.left + 7;
    final hasRoom = placement != null && placement.lines > 0;
    final height = math.min(
      size.height,
      hasRoom ? placement.rect.height : lineHeight * 2 + 8,
    );
    final anchorY = hasRoom ? placement.rect.top : placement?.rect.bottom;
    final top = (anchorY ?? size.height - height).clamp(
      0.0,
      size.height - height,
    );
    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          right: widget.padding.right,
          height: height,
          child: TextFieldTapRegion(
            groupId: _tapGroup,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: hasRoom ? null : widget.paperColor,
                boxShadow: hasRoom
                    ? null
                    : const [
                        BoxShadow(color: Color(0x2270472f), blurRadius: 4),
                      ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomPaint(
                    size: Size(24, 22),
                    painter: ReflectionArrow(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Semantics(
                      label: '느낀 점 입력',
                      child: TextField(
                        key: const ValueKey('notebook-reflection-input'),
                        groupId: _tapGroup,
                        controller: _field,
                        focusNode: _focus,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        onTapOutside: (_) {
                          if (!_composing) _focus.unfocus();
                        },
                        style: reflectionHandwriting.copyWith(fontSize: 21),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: '느낀 점',
                          hintStyle: reflectionHandwriting.copyWith(
                            fontSize: 21,
                            color: reflectionGraphite.withValues(alpha: .62),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_failed)
                    IconButton(
                      tooltip: '느낀 점 저장 재시도',
                      onPressed: () => _save(retry: true),
                      icon: const Icon(Icons.refresh, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
