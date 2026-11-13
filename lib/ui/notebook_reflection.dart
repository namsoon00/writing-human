import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../data/model.dart';
import '../source/originals.dart';
import 'editable_geometry.dart';
import 'reflection_ink.dart';

typedef _Placement = ({Rect rect, int lines});
final _writtenCharacter = RegExp(r'\S');

/// Reads the committed notes without taking focus or changing the paper layout.
class NotebookReflection extends StatefulWidget {
  const NotebookReflection({
    super.key,
    required this.originals,
    this.guided,
    required this.controller,
    required this.scroll,
    required this.fieldKey,
    required this.padding,
  });

  final List<RegisteredOriginal> originals;
  final RegisteredOriginal? guided;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final EdgeInsets padding;

  @override
  State<NotebookReflection> createState() => _NotebookReflectionState();
}

class _NotebookReflectionState extends State<NotebookReflection> {
  List<({String note, _Placement placement})> _notes = const [];
  bool _queued = false;

  void _measure(Size size, double lineHeight) {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      final value = widget.controller.value;
      final end = value.isComposingRangeValid && !value.composing.isCollapsed
          ? value.composing.start
          : value.text.length;
      final notes = <({String note, _Placement placement})>[];
      final seen = <String>{};
      var offset = 0;
      for (final line in value.text.substring(0, end).split('\n')) {
        if (line.trim().isEmpty) {
          offset += line.length + 1;
          continue;
        }
        final lineEnd = offset + line.trimRight().length;
        final match = reflectionForWriting(
          widget.originals,
          value.text,
          lineEnd,
          guided: offset == 0 ? widget.guided : null,
        );
        offset += line.length + 1;
        final original = match?.match.original;
        final note = original?.reflection?.text;
        if (match == null || note == null || seen.contains(original!.id)) {
          continue;
        }
        final placement = _locate(match, size, lineHeight);
        if (placement != null) {
          seen.add(original.id);
          notes.add((note: note, placement: placement));
        }
      }
      if (notes.length != _notes.length ||
          notes.indexed.any((entry) => entry.$2 != _notes[entry.$1])) {
        setState(() => _notes = notes);
      }
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
    if (available >= lineHeight + 5) {
      final maxWidth = size.width - widget.padding.horizontal - 7;
      if (maxWidth > 40) {
        final lines = ((available - 5) ~/ lineHeight).clamp(1, 2);
        return (
          rect: Rect.fromLTWH(
            widget.padding.left + 7,
            noteTop,
            math.min(maxWidth, 300.0),
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
        _measure(box.biggest, MediaQuery.textScalerOf(context).scale(21));
        return IgnorePointer(
          child: Stack(
            key: const ValueKey('writing-reflection'),
            fit: StackFit.expand,
            children: [
              for (final (:note, :placement) in _notes)
                Positioned.fromRect(
                  rect: placement.rect,
                  child: placement.lines == 0
                      ? Semantics(
                          label: note,
                          child: const Icon(
                            CupertinoIcons.pencil,
                            size: 14,
                            color: reflectionGraphite,
                          ),
                        )
                      : Row(
                          children: [
                            const CustomPaint(
                              size: Size(24, 22),
                              painter: ReflectionArrow(),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                note,
                                maxLines: placement.lines,
                                overflow: TextOverflow.ellipsis,
                                style: reflectionHandwriting.copyWith(
                                  fontSize: 21,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
