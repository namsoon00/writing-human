import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';
import 'page_turn.dart';
import 'reading_details.dart';

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
    final visibility = Curves.easeInCubic.transform(
      1.0 - (motion?.fraction ?? 0.0),
    );
    final light = variant % coverNames.length == 1;
    final lettering = light ? const Color(0xff402e22) : const Color(0xffffe9ba);
    final artwork = Stack(
      fit: StackFit.expand,
      children: [
        BookCoverMaterial(
          key: const ValueKey('full-cover-material'),
          variant: variant,
          back: back,
          binding: style.bookDetails.binding,
        ),
        _lettering(lettering),
        if (!back && style.bookDetails.pressedFlower.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 144),
            child: Align(
              alignment: flowerAlignment(style.bookDetails.pressedFlower),
              child: PressedFlower(choice: style.bookDetails.pressedFlower),
            ),
          ),
      ],
    );

    return Stack(
      key: ValueKey(back ? 'book-back-cover' : 'book-front-cover'),
      fit: StackFit.expand,
      children: [
        motion?.transformArtwork(artwork) ?? artwork,
        IgnorePointer(
          ignoring: visibility < 1,
          child: Opacity(
            opacity: visibility,
            child: SafeArea(
              minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _controls(lettering, light),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lettering(Color color) => SafeArea(
    child: LayoutBuilder(
      builder: (context, box) {
        final titleSize = (box.biggest.shortestSide * .105).clamp(24.0, 54.0);
        final width = math.min(620.0, box.maxWidth * .78);
        return Align(
          alignment: const Alignment(0, -.40),
          child: SizedBox(
            width: width,
            height: box.maxHeight * .32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: back ? titleSize * .65 : titleSize,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (author.isNotEmpty && !back)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          author,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: color, fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _controls(Color color, bool light) => LayoutBuilder(
    builder: (context, box) {
      final button = TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: light
            ? const Color(0xfff2e6ce)
            : const Color(0xff292721),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      );
      final controls = Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: button,
              onPressed: onCollection,
              child: const Text('보관함'),
            ),
          ),
          const Spacer(),
          Text('$pageCount쪽', style: TextStyle(color: color, fontSize: 13)),
          const SizedBox(height: 10),
          TextButton(
            style: button,
            onPressed: onOpen,
            child: Text(back ? '마지막 장 펼치기' : '책 펼치기'),
          ),
          if (onAppend != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                style: button,
                onPressed: onAppend,
                child: const Text('한 쪽 더'),
              ),
            ),
        ],
      );
      final scale = MediaQuery.textScalerOf(context);
      final minHeight = (onAppend == null ? 3 : 4) * (scale.scale(14) + 34);
      if (box.maxHeight >= minHeight) return controls;
      return SingleChildScrollView(
        child: SizedBox(height: minHeight, child: controls),
      );
    },
  );
}
