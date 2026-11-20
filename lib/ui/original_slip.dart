import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/model.dart';
import 'book_details.dart';
import 'original_photo.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'source_browser.dart';

class OriginalSlipTab extends StatelessWidget {
  const OriginalSlipTab({super.key, required this.paperColor, this.onPressed});

  final Color paperColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '끼운 원문 쪽지 펼쳐 보기',
    onPressed: onPressed,
    style: IconButton.styleFrom(foregroundColor: brandInk),
    icon: Container(
      width: 26,
      height: 33,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(paperColor, const Color(0xffc8a77c), .38),
        border: Border.all(color: const Color(0x40704d32)),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20614c3b),
            offset: Offset(-1, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Transform.rotate(
        angle: -.18,
        child: const Icon(CupertinoIcons.paperclip, size: 17, color: brandInk),
      ),
    ),
  );
}

Future<bool?> showOriginalSlip(
  BuildContext context,
  RegisteredOriginal original,
  WritingStyle style,
) {
  const panel = originalPanelColor;
  final photoId = original.photoId;
  final link = RegisteredOriginal.webLink(original.citation);
  return Navigator.of(context).push<bool>(
    paperPanelRoute<bool>(
      (context) => PaperPanel(
        color: panel,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              const PaperPanelHeader('끼운 원문 쪽지'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    SourceSlip(
                      choice: style.bookDetails.sourceSlip,
                      panelColor: panel,
                      showCaption: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (photoId != null) ...[
                            SizedBox(
                              height: 220,
                              child: OriginalPhoto(
                                id: photoId,
                                region: original.photoRegion,
                                fitWidth: true,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => showOriginalPhoto(
                                  context,
                                  photoId,
                                  color: panel,
                                  region: original.photoRegion,
                                ),
                                child: const Text('원본 사진 크게 보기'),
                              ),
                            ),
                          ],
                          if (original.text.trim().isNotEmpty)
                            Text(
                              original.text,
                              style: writingTextStyle(
                                style.fontIndex,
                                size: style.fontSize,
                                color: ink,
                                useDevelopmentTypeface:
                                    style.useDevelopmentTypeface,
                              ),
                            ),
                          if (original.citation.trim().isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                top: original.text.trim().isEmpty ? 0 : 14,
                              ),
                              child: Text(
                                original.citation,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (link != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => openSourceBrowser(
                                  context,
                                  url: link,
                                  title: '원문 링크',
                                  launchLabel: '링크 열기',
                                  hasCitation: true,
                                ),
                                child: const Text('출처 열기'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final remove = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              title: const Text('이 쪽에서 쪽지를 뺄까요?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: const Text('취소'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: const Text('빼기'),
                                ),
                              ],
                            ),
                          );
                          if (remove == true && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: const Text('쪽지 빼기'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      color: panel,
    ),
  );
}
