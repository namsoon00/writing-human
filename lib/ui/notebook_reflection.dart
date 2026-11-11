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
    this.onEdit,
  });

  final List<RegisteredOriginal> originals;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final EdgeInsets padding;
  final ValueChanged<OriginalMatch>? onEdit;

  @override
  State<NotebookReflection> createState() => _NotebookReflectionState();
}

class _NotebookReflectionState extends State<NotebookReflection> {
  bool _queued = false;
  _Placement? _placement;

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
        final lines = hasNote && available >= lineHeight * 2 + 5 ? 2 : 1;
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
        final reflection = selection.isCollapsed
            ? reflectionForWriting(widget.originals, value.text, caret)
            : null;
        final lineHeight = MediaQuery.textScalerOf(context).scale(21);
        _measure(reflection, box.biggest, lineHeight);
        final placement = _placement;
        if (reflection == null || placement == null) {
          return const SizedBox.expand();
        }
        final note = reflection.match.original.reflection?.text;
        final action = widget.onEdit;
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
                        onTap: action == null || composing
                            ? null
                            : () => action(reflection.match),
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
}
