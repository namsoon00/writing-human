import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'model.dart';

const maxBackupBytes = 32 * 1024 * 1024;

class LibraryBackup {
  const LibraryBackup(this.library, this.createdAt);

  final Library library;
  final DateTime createdAt;

  String encode() => jsonEncode({
    'format': 'writing-human-backup',
    'version': 1,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'library': library.toCloudJson(),
  });

  factory LibraryBackup.decode(String raw) {
    try {
      final json = jsonDecode(raw) as Json;
      if (json['format'] != 'writing-human-backup' || json['version'] != 1) {
        throw const FormatException();
      }
      final payload = Map<String, dynamic>.of(json['library'] as Json)
        ..remove('sync')
        ..remove('lastBackupAt');
      return LibraryBackup(
        Library.decode(jsonEncode(payload)),
        DateTime.parse(json['createdAt'] as String),
      );
    } on TypeError {
      throw const FormatException('백업 파일의 형식이 올바르지 않습니다.');
    } on FormatException {
      throw const FormatException('이 백업 파일을 읽을 수 없습니다.');
    }
  }
}

String _copyId(String kind, Object content, int attempt) => const Uuid().v5(
  Namespace.url.value,
  jsonEncode(['writing-human-backup', kind, content, attempt]),
);

Map<String, List<WritingPage>> _groupPages(List<WritingPage> pages) {
  final groups = <String, List<WritingPage>>{};
  for (final page in pages) {
    (groups[page.recordId] ??= []).add(page);
  }
  for (final group in groups.values) {
    group.sort((a, b) => a.number.compareTo(b.number));
  }
  return groups;
}

Json _recordContent(WritingRecord record) =>
    record.toJson()..remove('sourceParagraph');

List<Json> _pageContent(List<WritingPage> pages) => [
  for (final page in pages)
    page.toJson()
      ..remove('base')
      ..remove('extent')
      ..remove('scroll'),
];

/// Add the backup to the current library. Matching copies are reused, while
/// collisions receive new IDs so existing records and their pages stay intact.
Library mergeBackup(Library current, Library backup) {
  backup.validate();
  if (current.books.isEmpty && current.records.isEmpty) {
    return backup.copy(sync: current.sync, lastBackupAt: current.lastBackupAt);
  }
  final books = {for (final book in current.books) book.id: book};
  final bookIds = <String, String>{};
  for (final book in backup.books) {
    final json = book.toJson();
    for (var attempt = 0; ; attempt++) {
      final id = attempt == 0 ? book.id : _copyId('book', json, attempt);
      final candidate = Book.fromJson({...json, 'id': id});
      final existing = books[id];
      if (existing == null ||
          jsonEncode(existing.toJson()) == jsonEncode(candidate.toJson())) {
        books[id] = existing ?? candidate;
        bookIds[book.id] = id;
        break;
      }
    }
  }

  final records = {for (final record in current.records) record.id: record};
  final pages = {for (final page in current.pages) page.id: page};
  final currentGroups = _groupPages(current.pages);
  final backupGroups = _groupPages(backup.pages);
  final restoredPageIds = <String, String>{};
  for (final record in backup.records) {
    final json = {..._recordContent(record), 'bookId': bookIds[record.bookId]};
    final group = backupGroups[record.id] ?? [];
    final identity = [json, _pageContent(group)];
    for (var attempt = 0; ; attempt++) {
      final id = attempt == 0
          ? record.id
          : _copyId('record', identity, attempt);
      final candidate = WritingRecord.fromJson({
        ...json,
        'id': id,
        'sourceParagraph': record.sourceParagraph,
      });
      final candidatePages = [
        for (final page in group)
          WritingPage.fromJson({
            ...page.toJson(),
            'id': attempt == 0 ? page.id : _copyId('page', [id, page.id], 0),
            'recordId': id,
          }),
      ];
      final existing = records[id];
      if (existing != null) {
        if (jsonEncode(_recordContent(existing)) !=
                jsonEncode(_recordContent(candidate)) ||
            jsonEncode(_pageContent(currentGroups[id] ?? [])) !=
                jsonEncode(_pageContent(candidatePages))) {
          continue;
        }
      } else {
        if (candidatePages.any((page) => pages.containsKey(page.id))) continue;
        records[id] = candidate;
        currentGroups[id] = candidatePages;
        for (final page in candidatePages) {
          pages[page.id] = page;
        }
      }
      for (var i = 0; i < group.length; i++) {
        restoredPageIds[group[i].id] = candidatePages[i].id;
      }
      break;
    }
  }

  final active = current.activePageId ?? restoredPageIds[backup.activePageId];
  final merged = current.copy(
    books: books.values.toList(),
    records: records.values.toList(),
    pages: pages.values.toList(),
    activePageId: active,
    writing: current.activePageId == null ? backup.writing : current.writing,
    style: current.style.copy(
      favoriteBookIds: [
        ...{
          ...current.style.favoriteBookIds,
          ...backup.style.favoriteBookIds.map((id) => bookIds[id]).nonNulls,
        },
      ],
    ),
  );
  merged.validate();
  return merged;
}
