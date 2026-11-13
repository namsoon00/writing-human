import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/library_backup.dart';
import '../data/library_controller.dart';
import '../data/model.dart';
import '../data/writing_export.dart';
import 'paper.dart';

class ArchiveSheet extends StatefulWidget {
  const ArchiveSheet({
    super.key,
    required this.controller,
    required this.canAccess,
    this.record,
    this.book,
  });

  final LibraryController controller;
  final bool Function() canAccess;
  final WritingRecord? record;
  final Book? book;

  @override
  State<ArchiveSheet> createState() => _ArchiveSheetState();
}

class _ArchiveSheetState extends State<ArchiveSheet> {
  bool _busy = false;
  bool _failed = false;
  String? _status;
  LibraryController get _controller => widget.controller;
  bool get _available => mounted && widget.canAccess();

  Future<void> _run(Future<String?> Function() action, String failure) async {
    if (_busy || !_available) return;
    setState(() {
      _busy = true;
      _failed = false;
      _status = null;
    });
    try {
      final result = await action();
      if (mounted) setState(() => _status = result);
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _status = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _status = failure;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _save(String name, Uint8List bytes) async {
    if (!_available) return false;
    final location = await FilePicker.platform.saveFile(
      fileName: name,
      bytes: bytes,
    );
    return kIsWeb || location != null;
  }

  String get _savedMessage => kIsWeb ? '브라우저에 다운로드를 요청했어요.' : '파일을 내보냈어요.';

  Future<String?> _backup() async {
    final now = DateTime.now();
    final backup = await LibraryBackup.collect(_controller.library, now);
    final bytes = utf8.encode(backup.encode());
    if (bytes.length > maxBackupBytes) {
      throw const FormatException('백업 파일이 32MB를 넘습니다.');
    }
    final timestamp = now
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '-');
    if (!await _save('writing-human-$timestamp.json', bytes)) {
      return null;
    }
    if (_available) {
      _controller.recordBackupExport(now);
      await _controller.settled;
    }
    return _savedMessage;
  }

  Future<String?> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      withReadStream: true,
    );
    final file = result?.files.single;
    if (file == null || !_available) return null;
    if (file.size > maxBackupBytes) {
      throw const FormatException('32MB 이하의 백업 파일을 선택해 주세요.');
    }
    final stream = file.readStream;
    if (stream == null) throw const FormatException('파일을 읽을 수 없습니다.');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (!_available) return null;
      if (bytes.length + chunk.length > maxBackupBytes) {
        throw const FormatException('32MB 이하의 백업 파일을 선택해 주세요.');
      }
      bytes.add(chunk);
    }
    final LibraryBackup backup;
    try {
      backup = LibraryBackup.decode(utf8.decode(bytes.takeBytes()));
    } on FormatException {
      throw const FormatException('이 백업 파일을 읽을 수 없습니다.');
    }
    if (!mounted || !widget.canAccess()) return null;
    final library = backup.library;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(backup.createdAt.toLocal());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('백업에서 가져오기'),
        content: Text(
          '$date\n${library.books.length}권 · ${library.records.length}편 · ${library.pages.length}쪽'
          '${backup.photos.isEmpty ? '' : ' · 사진 ${backup.photos.length}장'}\n\n'
          '지금 기록에 합칩니다. 내용이 다른 기록은 따로 보관합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_available) return null;
    try {
      await backup.restorePhotos();
    } catch (_) {
      throw const FormatException('백업에 담긴 사진을 저장하지 못했어요. 다시 가져와 주세요.');
    }
    if (!_available) return null;
    if (!await _controller.restoreBackup(library)) {
      throw const FormatException('가져온 기록을 저장하지 못했어요. 다시 저장해 주세요.');
    }
    return '백업을 보관함에 가져왔어요.';
  }

  String _fileName(String title, String extension) {
    final clean = title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return '${clean.isEmpty ? '쓰는 인간' : String.fromCharCodes(clean.runes.take(80))}.$extension';
  }

  Future<String?> _text(WritingRecord record) async =>
      await _save(
        _fileName(record.title, 'txt'),
        exportRecordText(_controller.library, record),
      )
      ? _savedMessage
      : null;

  Future<String?> _pdf(Book book) async {
    final bytes = await exportBookPdf(_controller.library, book);
    return await _save(_fileName(book.title, 'pdf'), bytes)
        ? _savedMessage
        : null;
  }

  Future<String?> _retrySave() async {
    _controller.retrySave();
    await _controller.settled;
    if (_controller.saveError != null) {
      throw const FormatException('기기에 저장하지 못했어요. 다시 시도해 주세요.');
    }
    return '기기에 저장했어요.';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final last = _controller.library.lastBackupAt?.toLocal();
          final locale = MaterialLocalizations.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 0, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '기록 보관',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '닫기',
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.xmark, size: 18),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.arrow_down_doc),
                  title: const Text('전체 백업 내보내기'),
                  subtitle: last == null
                      ? null
                      : Text(
                          '마지막 내보내기 ${locale.formatMediumDate(last)} '
                          '${locale.formatTimeOfDay(TimeOfDay.fromDateTime(last))}',
                        ),
                  onTap: _busy
                      ? null
                      : () => _run(_backup, '백업 파일을 내보내지 못했어요.'),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.arrow_up_doc),
                  title: const Text('백업에서 가져오기'),
                  onTap: _busy ? null : () => _run(_restore, '백업 파일을 열지 못했어요.'),
                ),
                if (widget.record case final record?)
                  ListTile(
                    leading: const Icon(CupertinoIcons.doc_plaintext),
                    title: const Text('이 필사 텍스트 내보내기'),
                    onTap: _busy
                        ? null
                        : () => _run(() => _text(record), '텍스트 파일을 내보내지 못했어요.'),
                  ),
                if (widget.book case final book?)
                  ListTile(
                    leading: const Icon(CupertinoIcons.book),
                    title: const Text('이 책 PDF 내보내기'),
                    subtitle: Text(book.title),
                    onTap: _busy
                        ? null
                        : () => _run(() => _pdf(book), 'PDF를 내보내지 못했어요.'),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (_status case final status?)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        style: TextStyle(color: _failed ? burgundy : ink),
                      ),
                    ),
                  ),
                if (_controller.saveError != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(_retrySave, '기기에 저장하지 못했어요.'),
                    child: const Text('저장 실패 · 다시 시도'),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
