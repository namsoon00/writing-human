import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/sync/merge.dart';
import 'package:writing_human/ui/book_details.dart';
import 'widget_test.dart' show MemoryStore;

Library specimen() => const Library(
  books: [Book(id: 'b', title: '오래 곁에 둘 문장들')],
  records: [
    WritingRecord(
      id: 'r',
      bookId: 'b',
      title: '나의 필사',
      source: '책에서 만난 문장 · 24쪽',
    ),
  ],
  pages: [
    WritingPage(
      id: 'p',
      recordId: 'r',
      number: 1,
      text: '천천히 읽고 씁니다. 🌿',
      writtenOn: '2026-11-10',
    ),
  ],
  activePageId: 'p',
  writing: true,
);
List<List<int>> ranges(List<PencilMark> marks) => [
  for (final m in marks) [m.start, m.end],
];

void main() {
  sqfliteFfiInit();
  test(
    'Pencil ranges follow untouched text, clear replaced text and retain whole emoji',
    () {
      expect(
        ranges(PencilMark.afterEdit('가나다라', '앞가나다라', [const PencilMark(1, 3)])),
        [
          [2, 4],
        ],
      );
      expect(
        ranges(PencilMark.afterEdit('가나다라', '가나새다라', [const PencilMark(0, 4)])),
        [
          [0, 2],
          [3, 5],
        ],
      );
      expect(
        ranges(PencilMark.afterEdit('가나다라', '가마라', [const PencilMark(1, 3)])),
        isEmpty,
      );
      expect(
        ranges(
          PencilMark.afterEdit('🌿 끝', '🌸 끝', [
            const PencilMark(0, 2),
            const PencilMark(3, 4),
          ]),
        ),
        [
          [3, 4],
        ],
      );
      expect(
        ranges(PencilMark.afterEdit('가나다', '', [const PencilMark(0, 3)])),
        isEmpty,
      );
    },
  );

  test(
    'Owner, date and annotations survive a real SQLite file close/reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'writing-book-details-',
      );
      final path = '${dir.path}/library.db';
      var store = await SqliteLibraryStore.open(
        path,
        factory: databaseFactoryFfi,
      );
      final c = LibraryController(store, specimen());
      try {
        c.setBookOwner('b', '나의 필명');
        c.togglePencilMark('p', 0, 7);
        c.editPage('p', '앞 천천히 읽고 씁니다. 🌿', 2, 9, 0);
        await c.settled;
        expect(c.saveError, isNull);
        await store.close();
        store = await SqliteLibraryStore.open(
          path,
          factory: databaseFactoryFfi,
        );
        final restored = await store.load();
        expect(restored.books.single.owner, '나의 필명');
        expect(restored.activePage!.writtenOn, '2026-11-10');
        expect(ranges(restored.activePage!.pencilMarks), [
          [2, 9],
        ]);
        expect(restored.activePage!.base, 2);
        expect(restored.activePage!.extent, 9);
        expect(
          Library.decode(restored.encode()).activePage!.toJson(),
          restored.activePage!.toJson(),
        );
      } finally {
        c.dispose();
        await store.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'Version 3 migration preserves prose and does not invent historical dates',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'writing-book-migration-',
      );
      final path = '${dir.path}/v3.db';
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE books (id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL)',
            );
            await db.execute(
              "CREATE TABLE records (id TEXT PRIMARY KEY, book_id TEXT, title TEXT NOT NULL, source TEXT NOT NULL DEFAULT '')",
            );
            await db.execute(
              'CREATE TABLE pages (id TEXT PRIMARY KEY, record_id TEXT NOT NULL, number INTEGER NOT NULL, text TEXT NOT NULL, selection_base INTEGER NOT NULL, selection_extent INTEGER NOT NULL, scroll REAL NOT NULL, UNIQUE(record_id, number))',
            );
            await db.execute(
              "CREATE TABLE app_state (id INTEGER PRIMARY KEY, active_page_id TEXT, writing INTEGER NOT NULL, settings TEXT NOT NULL DEFAULT '{}', sync_state TEXT NOT NULL DEFAULT '{}')",
            );
            await db.insert('books', {
              'id': 'b',
              'title': '오래된 책',
              'author': '',
            });
            await db.insert('records', {
              'id': 'r',
              'book_id': 'b',
              'title': '필사',
              'source': '출처',
            });
            await db.insert('pages', {
              'id': 'p',
              'record_id': 'r',
              'number': 1,
              'text': '남아 있어야 할 문장',
              'selection_base': 2,
              'selection_extent': 5,
              'scroll': 17.5,
            });
            await db.insert('app_state', {
              'id': 1,
              'active_page_id': 'p',
              'writing': 1,
            });
          },
        ),
      );
      await db.close();
      final store = await SqliteLibraryStore.open(
        path,
        factory: databaseFactoryFfi,
      );
      try {
        final data = await store.load();
        expect(data.activePage!.text, '남아 있어야 할 문장');
        expect(data.activePage!.base, 2);
        expect(data.activePage!.extent, 5);
        expect(data.activePage!.scroll, 17.5);
        expect(data.activePage!.writtenOn, isNull);
        expect(data.activePage!.pencilMarks, isEmpty);
        expect(data.books.single.owner, '');
        await store.save(data);
        expect((await store.load()).activePage!.writtenOn, isNull);
      } finally {
        await store.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'Sync merges owner and independent annotations without losing local position',
    () {
      final base = specimen();
      final local = base.copy(
        pages: [
          base.activePage!
              .edited(
                text: base.activePage!.text,
                base: 3,
                extent: 3,
                scroll: 5,
              )
              .withDetails(pencilMarks: [const PencilMark(0, 3)]),
        ],
      );
      final remote = base.copy(
        books: [const Book(id: 'b', title: '오래 곁에 둘 문장들', owner: '필명')],
        pages: [
          base.activePage!.withDetails(pencilMarks: [const PencilMark(5, 7)]),
        ],
      );
      final merged = mergeLibraries(base, local, remote).library;
      expect(merged.books.single.owner, '필명');
      expect(merged.activePage!.base, 3);
      expect(ranges(merged.activePage!.pencilMarks), [
        [0, 3],
        [5, 7],
      ]);
      expect(merged.activePage!.writtenOn, '2026-11-10');
      final remoteEdit = remote.copy(
        pages: [
          remote.activePage!.edited(
            text: '${remote.activePage!.text} 다른 끝',
            base: 0,
            extent: 0,
            scroll: 0,
          ),
        ],
      );
      final localEdit = local.copy(
        pages: [
          local.activePage!.edited(
            text: '${local.activePage!.text} 내 끝',
            base: 0,
            extent: 0,
            scroll: 0,
          ),
        ],
      );
      final conflict = mergeLibraries(base, localEdit, remoteEdit).library;
      final copy = conflict.pages.firstWhere(
        (p) => p.recordId.startsWith('conflict-'),
      );
      expect(copy.writtenOn, '2026-11-10');
      expect(ranges(copy.pencilMarks), [
        [5, 7],
      ]);
    },
  );

  test('Invalid dates and out-of-range pencil marks fail validation', () {
    final badDate = specimen().copy(
      pages: [specimen().activePage!.withDetails(writtenOn: '2026-02-30')],
    );
    expect(badDate.validate, throwsFormatException);
    final badMark = specimen().copy(
      pages: [
        specimen().activePage!.withDetails(
          pencilMarks: [const PencilMark(0, 999)],
        ),
      ],
    );
    expect(badMark.validate, throwsFormatException);
  });

  test(
    'A remote text insertion and a local pencil mark merge in either direction',
    () {
      final base = specimen();
      final local = base.copy(
        pages: [
          base.activePage!.withDetails(pencilMarks: [const PencilMark(0, 7)]),
        ],
      );
      final remote = base.copy(
        pages: [
          base.activePage!.edited(
            text: '앞 ${base.activePage!.text}',
            base: 2,
            extent: 2,
            scroll: 0,
          ),
        ],
      );
      for (final merged in [
        mergeLibraries(base, local, remote),
        mergeLibraries(base, remote, local),
      ]) {
        expect(merged.conflictCopies, 0);
        expect(ranges(merged.library.activePage!.pencilMarks), [
          [2, 9],
        ]);
        expect(merged.library.activePage!.writtenOn, '2026-11-10');
      }
    },
  );

  testWidgets(
    'Pencil toolbar preserves live selection and IME; failed annotation save retries',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()..data = specimen();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      await tester.tap(field);
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(field).controller!;
      final selected = TextEditingValue(
        text: controller.text,
        selection: const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      tester.testTextInput.updateEditingValue(selected);
      await tester.pumpAndSettle();
      store.fail = true;
      tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('연필 표시'));
      await tester.pumpAndSettle();
      expect(controller.value, selected);
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(find.text('저장 재시도'), findsOneWidget);
      store.fail = false;
      await tester.tap(find.text('저장 재시도'));
      await tester.pumpAndSettle();
      expect(ranges(store.data.activePage!.pencilMarks), [
        [0, 7],
      ]);
      tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('연필 표시 지우기'));
      await tester.pumpAndSettle();
      expect(store.data.activePage!.pencilMarks, isEmpty);
      expect(controller.value, selected);
      final composing = TextEditingValue(
        text: '${controller.text} 사ㄹ',
        selection: TextSelection.collapsed(offset: controller.text.length + 3),
        composing: TextRange(
          start: controller.text.length + 1,
          end: controller.text.length + 3,
        ),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(controller.value, composing);
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Bookplate owner edits save through the collection; details fit large type and landscape',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = MemoryStore()..data = specimen();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byType(SourceSlip), findsOneWidget);
      await tester.tap(find.text('보관함'));
      await tester.pumpAndSettle();
      expect(find.byType(DateStamp), findsOneWidget);
      await tester.tap(find.text('책'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('오래 곁에 둘 문장들').last);
      await tester.pumpAndSettle();
      expect(find.byType(Bookplate), findsOneWidget);
      await tester.tap(find.text('이 책의 주인 이름 남기기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('book-owner')), '나의 필명');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(store.data.books.single.owner, '나의 필명');
      expect(find.text('나의 필명의 책 · 이름 고치기'), findsOneWidget);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('더 보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
