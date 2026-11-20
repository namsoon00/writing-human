import 'package:flutter/material.dart';

import '../data/model.dart';
import 'book_details.dart';
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
  });

  final WritingStyle style;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showDivider;

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
            panelColor: originalPanelColor,
            choice: details.sourceSlip,
            child: ListTile(
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
}
