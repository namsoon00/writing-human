import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/library_controller.dart';
import '../data/model.dart';
import 'paper.dart';
import 'paper_panel.dart';

class PageTrash extends StatefulWidget {
  const PageTrash({
    super.key,
    required this.controller,
    required this.canAccess,
  });

  final LibraryController controller;
  final bool Function() canAccess;

  @override
  State<PageTrash> createState() => _PageTrashState();
}

class _PageTrashState extends State<PageTrash> {
  bool _saving = false;
  String? _error;

  String _excerpt(WritingPage page) {
    final text = page.text.trimLeft();
    final end = text.indexOf('\n');
    return text.isEmpty
        ? '빈 종이'
        : end < 0
        ? text
        : text.substring(0, end);
  }

  Future<void> _change(WritingPage page, {required bool restore}) async {
    if (_saving || !widget.canAccess()) return;
    if (!restore) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('이 쪽을 영구 삭제할까요?'),
          content: Text(
            '${String.fromCharCodes(_excerpt(page).runes.take(100))}\n\n'
            '영구 삭제하면 휴지통에서 복원할 수 없어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('영구 삭제'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || !widget.canAccess()) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.controller.changeTrashedPage(
      page.id,
      restore: restore,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = saved ? null : '변경을 저장하지 못했어요. 다시 시도해 주세요.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final library = widget.controller.library;
        final records = {for (final item in library.records) item.id: item};
        final books = {for (final item in library.books) item.id: item.title};
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaperPanelHeader('휴지통', canClose: !_saving),
              if (_saving) const LinearProgressIndicator(),
              if (_error case final error?)
                Semantics(
                  liveRegion: true,
                  child: Text(error, style: const TextStyle(color: burgundy)),
                ),
              if (library.trashedPages.isEmpty)
                const Text('휴지통이 비어 있어요.')
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: library.trashedPages.length,
                    separatorBuilder: (_, _) => const Divider(color: line),
                    itemBuilder: (_, index) {
                      final page = library.trashedPages[index];
                      final record = records[page.recordId];
                      final book = books[record?.bookId];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _excerpt(page),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [book ?? '책 없는 글', ?record?.title].join(' · '),
                        ),
                        trailing: PopupMenuButton<bool>(
                          enabled: !_saving,
                          tooltip: '휴지통 쪽 메뉴',
                          icon: const Icon(CupertinoIcons.ellipsis),
                          onSelected: (restore) =>
                              _change(page, restore: restore),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: true, child: Text('복원')),
                            PopupMenuItem(value: false, child: Text('영구 삭제')),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
