import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/model.dart';
import '../source/page_originals.dart';
import 'original_photo.dart';
import 'original_reading_layout.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'source_browser.dart';

enum PageOriginalAction { jump, remove, add, free }

typedef PageOriginalChoice = ({PageOriginalAction action, String? id});

class PageOriginalsPanel extends StatefulWidget {
  const PageOriginalsPanel({
    super.key,
    required this.passages,
    required this.textLength,
    required this.style,
    this.selectedId,
  });
  final List<PagePassage> passages;
  final int textLength;
  final WritingStyle style;
  final String? selectedId;

  @override
  State<PageOriginalsPanel> createState() => _PageOriginalsPanelState();
}

class _PageOriginalsPanelState extends State<PageOriginalsPanel> {
  late String? selectedId = widget.selectedId;

  Future<void> _history(List<PagePassage> sources) async {
    final choice = await Navigator.of(context).push<PagePassage>(
      paperPanelRoute(
        (context) => PaperPanel(
          color: originalPanelColor,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 6, 12, 8),
                child: PaperPanelHeader('이전 원문 기록'),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    for (final link in sources)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _title(passageOriginal(link)!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: link.citation.isEmpty
                            ? null
                            : Text(
                                link.citation,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                        ),
                        onTap: () => Navigator.pop(context, link),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        color: originalPanelColor,
      ),
    );
    if (mounted && choice != null) setState(() => selectedId = choice.id);
  }

  String _title(RegisteredOriginal source) => source.text.trim().isNotEmpty
      ? source.text.trim().split('\n').first
      : source.photoId != null
      ? '사진 원문'
      : source.citation;

  @override
  Widget build(BuildContext context) {
    final sources = widget.passages
        .where((p) => passageOriginal(p) != null)
        .toList();
    final link =
        sources.where((p) => p.id == selectedId).firstOrNull ??
        sources.firstOrNull;
    final original = link == null ? null : passageOriginal(link);
    final style = widget.style;
    final url = original == null
        ? null
        : RegisteredOriginal.webLink(original.citation);
    return PaperPanel(
      color: originalPanelColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
        child: Column(
          children: [
            const PaperPanelHeader('필사 원문'),
            if (original != null && original.citation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    original.citation,
                    style: const TextStyle(color: muted),
                  ),
                ),
              ),
            Expanded(
              child: original == null
                  ? const Center(child: Text('연결된 원문이 없어요.'))
                  : OriginalReadingLayout(
                      original: original,
                      onOpenPhoto: original.photoId == null
                          ? null
                          : () => showOriginalPhoto(
                              context,
                              original.photoId!,
                              color: originalPanelColor,
                              region: original.photoRegion,
                            ),
                      child: SingleChildScrollView(
                        child: Text(
                          original.text,
                          key: const ValueKey('page-original-reading-text'),
                          style: writingTextStyle(
                            style.fontIndex,
                            size: style.fontSize,
                            color: penColors[style.penIndex],
                            useDevelopmentTypeface:
                                style.useDevelopmentTypeface,
                          ).copyWith(height: 1.65),
                        ),
                      ),
                    ),
            ),
            if (url != null)
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
            if (sources.length > 1)
              TextButton(
                onPressed: () => _history(sources),
                child: const Text('이전 원문 기록'),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, (
                action: PageOriginalAction.add,
                id: null,
              )),
              icon: const Icon(CupertinoIcons.pencil, size: 18),
              label: const Text('다른 원문으로 필사하기'),
            ),
          ],
        ),
      ),
    );
  }
}
