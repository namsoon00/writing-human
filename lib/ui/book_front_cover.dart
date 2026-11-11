import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';

/// The cover is a reading position, never a synthetic page in the library.
class BookFrontCover extends StatelessWidget {
  const BookFrontCover({
    super.key,
    required this.title,
    required this.style,
    required this.pageCount,
    required this.onOpen,
    required this.onCollection,
    this.author = '',
    this.variant = 0,
  });
  final String title, author;
  final WritingStyle style;
  final int pageCount, variant;
  final VoidCallback onOpen, onCollection;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('book-front-cover'),
    color: appPaper,
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context);
          final minHeight =
              150 +
              scale.scale(22) * 2.8 +
              scale.scale(13) * (author.isEmpty ? 1 : 3);
          if (box.maxHeight >= minHeight) return _content();
          return SingleChildScrollView(
            child: SizedBox(height: minHeight, child: _content()),
          );
        },
      ),
    ),
  );

  Widget _content() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onCollection, child: const Text('보관함')),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final coverWidth =
                  (box.maxWidth - 12) /
                  BookCover.totalWidthFactor(style.bookDetails);
              final width = math
                  .min(coverWidth, box.maxHeight / 1.36 - 12)
                  .clamp(1.0, 420.0);
              return Center(
                child: ExcludeSemantics(
                  child: MediaQuery.withNoTextScaling(
                    child: BookCover(
                      title: title,
                      width: width,
                      variant: variant,
                      pageCount: pageCount,
                      details: style.bookDetails,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22, color: ink, height: 1.4),
        ),
        if (author.isNotEmpty)
          Text(
            author,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: muted),
          ),
        Text(
          '$pageCount쪽 · 표지',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            onPressed: onOpen,
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
            child: const Text('책 펼치기'),
          ),
        ),
      ],
    ),
  );
}
