import 'package:flutter/material.dart';

import '../data/model.dart';
import '../source/photo_lines.dart';
import 'original_photo.dart';
import 'paper.dart';

/// Keep the source photograph and readable transcription visible together.
class OriginalReadingLayout extends StatelessWidget {
  const OriginalReadingLayout({
    super.key,
    required this.original,
    required this.child,
    this.onOpenPhoto,
  });

  final RegisteredOriginal original;
  final Widget child;
  final VoidCallback? onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final photoId = original.photoId;
    if (photoId == null) return child;
    final photo = Semantics(
      button: onOpenPhoto != null,
      label: onOpenPhoto == null ? '원문 사진' : '원본 사진 크게 보기',
      child: InkWell(
        onTap: onOpenPhoto,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: paper,
            border: Border.all(color: line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox.expand(
              child: OriginalPhoto(
                id: photoId,
                region: originalPhotoPreviewRegion(original),
              ),
            ),
          ),
        ),
      ),
    );
    if (original.text.trim().isEmpty) return photo;
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 500 && box.maxHeight >= 240) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: KeyedSubtree(
                  key: const ValueKey('original-reading-photo'),
                  child: photo,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: child),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const ValueKey('original-reading-photo'),
              height: (box.maxHeight * .3).clamp(0.0, 210.0),
              child: photo,
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
