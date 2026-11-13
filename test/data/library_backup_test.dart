import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/library_backup.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';

void main() {
  sqfliteFfiInit();

  test(
    'Backup round trips through SQLite and keeps both versions on restore',
    () async {
      final dir = await Directory.systemTemp.createTemp('writing-backup-');
      addTearDown(() => dir.delete(recursive: true));
      final db = '${dir.path}/library.db';
      Future<SqliteLibraryStore> open() =>
          SqliteLibraryStore.open(db, factory: databaseFactoryFfi);
      final store = await open();
      final controller = LibraryController(store, await store.load());
      controller.createBook('문장집', '기록자');
      final record = controller.library.activeRecord!;
      final page = controller.library.activePage!;
      const source = '첫 문단\n\n둘째 문단';
      controller.setSource(record.id, source);
      controller.setSourceParagraph(record.id, source, 1);
      controller.editPage(page.id, '기록한 문장', 1, 4, 8);
      controller.togglePencilMark(page.id, 0, 3);
      final date = DateTime.utc(2026, 11, 11);
      controller.recordBackupExport(date);
      await controller.settled;
      expect(controller.saveError, isNull);
      final backup = LibraryBackup(
        controller.library.copy(
          sync: const SyncMetadata(accountId: 'test-account'),
        ),
        date,
      );
      final file = File('${dir.path}/backup.json');
      await file.writeAsString(backup.encode());
      final parsed = LibraryBackup.decode(await file.readAsString());
      expect(parsed.library.sync.accountId, isNull);
      expect(parsed.library.lastBackupAt, isNull);
      expect(parsed.createdAt, date);
      expect(parsed.library.bookPositions[record.bookId], page.id);

      controller.editPage(page.id, '이 기기에서 바꾼 문장', 2, 6, 4);
      controller.setSource(record.id, '새로 붙인 원문');
      expect(controller.library.activeRecord!.sourceParagraph, 0);
      expect(await controller.restoreBackup(parsed.library), isTrue);
      expect(await controller.restoreBackup(parsed.library), isTrue);
      controller.dispose();
      await store.close();

      final reopened = await open();
      addTearDown(reopened.close);
      final result = await reopened.load();
      expect(result.lastBackupAt, date);
      expect(result.books, hasLength(1));
      expect(result.records, hasLength(2));
      expect(result.pages, hasLength(2));
      expect(result.activePage!.text, '이 기기에서 바꾼 문장');
      expect(result.bookPositions[record.bookId], page.id);
      final restored = result.pages.singleWhere((p) => p.id != page.id);
      expect(restored.text, '기록한 문장');
      expect(restored.base, 1);
      expect(restored.extent, 4);
      expect(restored.scroll, 8);
      expect(restored.pencilMarks.single.end, 3);
      expect(
        result.records
            .singleWhere((r) => r.id == restored.recordId)
            .sourceParagraph,
        1,
      );
    },
  );

  test('Malformed backup fails validation before it can be applied', () {
    const raw = '''
{"format":"writing-human-backup","version":1,"createdAt":"2026-11-11",
"library":{"version":1,"books":[],"records":[],"pages":[],
"activePageId":"missing","writing":true}}
''';
    expect(() => LibraryBackup.decode(raw), throwsFormatException);
  });
}
