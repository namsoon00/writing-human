import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/model.dart';
import 'book_details.dart';
import 'original_photo.dart';
import 'paper.dart';
import 'reading_details.dart';

class OriginalListItem extends StatelessWidget {
  const OriginalListItem({
    super.key,
    required this.style,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showDivider = false,
    this.indexCard = false,
    this.photoId,
  });

  final WritingStyle style;
  final String title;
  final String? subtitle, photoId;
  final VoidCallback? onTap;
  final bool showDivider, indexCard;

  static final _hangulWord = RegExp(r'[가-힣]+');

  @override
  Widget build(BuildContext context) {
    final details = style.bookDetails;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDivider)
          details.recordDivider.enabled
              ? RecordDivider(choice: details.recordDivider, compact: true)
              : const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: SourceSlip(
            compact: true,
            indexCard: indexCard,
            panelColor: originalPanelColor,
            choice: details.sourceSlip,
            child: indexCard
                ? _indexContent()
                : ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: writingTextStyle(
                        style.fontIndex,
                        size: 17,
                        useDevelopmentTypeface: style.useDevelopmentTypeface,
                        color: ink,
                      ),
                    ),
                    subtitle: subtitle == null
                        ? null
                        : Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _indexContent() {
    // Avoid breaking Hangul words in the index. Semantics and the search
    // data retain the original characters.
    final excerpt = title.replaceAllMapped(
      _hangulWord,
      (word) => word[0]!.split('').join('\u2060'),
    );
    final originalPhotoId = photoId;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(text: excerpt, semanticsLabel: title),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: writingTextStyle(
                  style.fontIndex,
                  size: 18,
                  useDevelopmentTypeface: style.useDevelopmentTypeface,
                ).copyWith(height: 1.57),
              ),
              if (subtitle case final citation?) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 7, bottom: 6),
                  child: SizedBox(
                    width: 24,
                    height: 1,
                    child: ColoredBox(color: Color(0xffb7a17d)),
                  ),
                ),
                Text(
                  citation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        if (originalPhotoId != null) ...[
          const SizedBox(width: 10),
          Container(
            width: 54,
            height: 76,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xffecdfc6),
              border: Border.all(color: const Color(0xffb7a17d)),
            ),
            child: OriginalPhoto(
              id: originalPhotoId,
              compact: true,
              thumbnailSize: const Size(46, 68),
            ),
          ),
        ],
        const SizedBox(width: 9),
        const Icon(CupertinoIcons.chevron_right, color: brandInk, size: 14),
      ],
    );
  }
}
