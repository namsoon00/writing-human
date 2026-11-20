import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/model.dart';
import '../source/page_originals.dart';
import 'original_photo.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'source_browser.dart';

enum PageOriginalAction { jump, remove, add, free }

typedef PageOriginalChoice = ({PageOriginalAction action, String? id});

class PageOriginalsPanel extends StatelessWidget {
  const PageOriginalsPanel({
    super.key,
    required this.passages,
    required this.textLength,
    required this.style,
  });
  final List<PagePassage> passages;
  final int textLength;
  final WritingStyle style;

  @override
  Widget build(BuildContext context) {
    final sources = passages.where((p) => passageOriginal(p) != null).toList();
    void choose(PageOriginalAction action, [String? id]) =>
        Navigator.pop(context, (action: action, id: id));
    return PaperPanel(
      color: panelPaperColor(paperColors[style.paperIndex]),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 6, 12, 8),
            child: PaperPanelHeader('끼운 원문'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                for (final (index, link) in sources.indexed)
                  ExpansionTile(
                    key: ValueKey('attached-original-${link.id}'),
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(bottom: BorderSide(color: line)),
                    collapsedShape: const Border(
                      bottom: BorderSide(color: line),
                    ),
                    leading: Text(
                      '${index + 1}',
                      style: const TextStyle(color: brandInk),
                    ),
                    title: Text(
                      passageOriginal(link)!.text.trim().isEmpty
                          ? (passageOriginal(link)!.photoId == null
                                ? passageOriginal(link)!.citation
                                : '사진 원문')
                          : passageOriginal(
                              link,
                            )!.text.trim().split('\n').first,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: link.citation.trim().isEmpty
                        ? null
                        : Text(
                            link.citation,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    children: [
                      if (passageOriginal(link)!.photoId case final photo?)
                        SizedBox(
                          height: 200,
                          child: OriginalPhoto(
                            id: photo,
                            region: passageOriginal(link)!.photoRegion,
                            fitWidth: true,
                          ),
                        ),
                      if (passageOriginal(link)!.text.trim().isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            passageOriginal(link)!.text,
                            style: writingTextStyle(
                              style.fontIndex,
                              size: style.fontSize,
                              useDevelopmentTypeface:
                                  style.useDevelopmentTypeface,
                            ),
                          ),
                        ),
                      if (RegisteredOriginal.webLink(link.citation)
                          case final url?)
                        TextButton(
                          onPressed: () => openSourceBrowser(
                            context,
                            url: url,
                            title: '원문 출처',
                            launchLabel: '링크 열기',
                            hasCitation: true,
                          ),
                          child: const Text('출처 열기'),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (passageEnd(passages, link, textLength) >
                                  link.start ||
                              identical(link, passages.last))
                            TextButton(
                              onPressed: () =>
                                  choose(PageOriginalAction.jump, link.id),
                              child: const Text('끼운 곳으로 이동'),
                            ),
                          TextButton(
                            onPressed: () async {
                              final remove = await showDialog<bool>(
                                context: context,
                                builder: (dialog) => AlertDialog(
                                  title: const Text('이 쪽에서 원문을 뺄까요?'),
                                  content: const Text('쓴 글은 그대로 남아요.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, false),
                                      child: const Text('취소'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, true),
                                      child: const Text('빼기'),
                                    ),
                                  ],
                                ),
                              );
                              if (remove == true && context.mounted) {
                                choose(PageOriginalAction.remove, link.id);
                              }
                            },
                            child: const Text('이 쪽에서 빼기'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => choose(PageOriginalAction.add),
                  icon: const Icon(CupertinoIcons.add, size: 18),
                  label: const Text('다른 원문 끼우기'),
                ),
                TextButton(
                  onPressed: () => choose(PageOriginalAction.free),
                  child: const Text('원문 없이 쓰기'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
