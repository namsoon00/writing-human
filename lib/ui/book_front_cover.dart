import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';
import 'page_turn.dart';

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
    this.back = false,
    this.onAppend,
  });
  final String title, author;
  final WritingStyle style;
  final int pageCount, variant;
  final VoidCallback onOpen, onCollection;
  final bool back;
  final VoidCallback? onAppend;

  @override
  Widget build(BuildContext context) {
    final motion = CoverHinge.maybeOf(context);
    final visibility = 1.0 - (motion?.fraction ?? 0.0);
    return ColoredBox(
      key: ValueKey(back ? 'book-back-cover' : 'book-front-cover'),
      color: appPaper.withValues(alpha: visibility),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context);
            final minHeight =
                150 +
                (onAppend == null ? 0 : 48) +
                scale.scale(22) * 2.8 +
                scale.scale(13) * (author.isEmpty ? 1 : 3);
            final content = _content(motion, visibility);
            if (box.maxHeight >= minHeight) return content;
            return SingleChildScrollView(
              child: SizedBox(height: minHeight, child: content),
            );
          },
        ),
      ),
    );
  }

  Widget _content(CoverHinge? motion, double visibility) {
    Widget caption(Widget child) => Opacity(opacity: visibility, child: child);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          caption(
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCollection,
                child: const Text('보관함'),
              ),
            ),
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
                final artwork = BookCover(
                  title: title,
                  width: width,
                  variant: variant,
                  pageCount: pageCount,
                  details: style.bookDetails,
                  back: back,
                );
                return Center(
                  child: ExcludeSemantics(
                    child: MediaQuery.withNoTextScaling(
                      child: motion?.transformArtwork(artwork) ?? artwork,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          caption(
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, color: ink, height: 1.4),
            ),
          ),
          if (author.isNotEmpty)
            caption(
              Text(
                author,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: muted),
              ),
            ),
          caption(
            Text(
              '$pageCount쪽 · ${back ? '뒷표지' : '앞표지'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
          const SizedBox(height: 12),
          caption(
            Center(
              child: OutlinedButton(
                onPressed: onOpen,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(140, 48),
                ),
                child: Text(back ? '마지막 장 펼치기' : '책 펼치기'),
              ),
            ),
          ),
          if (onAppend != null)
            caption(
              Center(
                child: TextButton(
                  onPressed: onAppend,
                  style: TextButton.styleFrom(minimumSize: const Size(140, 48)),
                  child: const Text('한 쪽 더'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
