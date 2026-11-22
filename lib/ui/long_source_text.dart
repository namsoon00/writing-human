import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps long manuscripts out of a single text layout during review.
class LongSourceText extends StatefulWidget {
  const LongSourceText({super.key, required this.text, this.style});

  static const threshold = 6000;
  final String text;
  final TextStyle? style;

  @override
  State<LongSourceText> createState() => _LongSourceTextState();
}

class _LongSourceTextState extends State<LongSourceText> {
  final _scroll = ScrollController();
  late List<String> _blocks = _split(widget.text);

  @override
  void didUpdateWidget(LongSourceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) _blocks = _split(widget.text);
  }

  static List<String> _split(String text) {
    const blockSize = 800;
    final blocks = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = math.min(start + blockSize, text.length);
      if (end < text.length) {
        final window = text.substring(start, end);
        final newline = start + window.lastIndexOf('\n') + 1;
        final space = start + window.lastIndexOf(' ') + 1;
        if (newline >= start + blockSize ~/ 2) {
          end = newline;
        } else if (space >= start + blockSize ~/ 2) {
          end = space;
        } else {
          // Find a grapheme boundary when there is no natural break nearby.
          final tail = text.substring(start);
          var boundary = start;
          for (final glyph in tail.characters) {
            if (boundary + glyph.length > end) break;
            boundary += glyph.length;
          }
          end = boundary == start
              ? start + tail.characters.first.length
              : boundary;
        }
      }
      var block = text.substring(start, end);
      if (end < text.length && block.endsWith('\n')) {
        // The next widget starts a new line already.
        block = block.substring(0, block.length - 1);
      }
      blocks.add(block);
      start = end;
    }
    return blocks;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 240,
    child: Scrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        key: const ValueKey('long-source-scroll'),
        padding: EdgeInsets.zero,
        primary: false,
        itemCount: _blocks.length,
        itemBuilder: (context, index) =>
            Text(_blocks[index], style: widget.style),
      ),
    ),
  );
}
