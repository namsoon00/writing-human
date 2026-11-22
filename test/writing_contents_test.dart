import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/data/writing_title.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/sync/merge.dart';
import 'package:writing_human/ui/collection_sheet.dart';

import 'widget_test.dart' show MemoryStore;

const poem = RegisteredOriginal(
  'source',
  '한 줄을 옮겨 씁니다.\n다음 줄을 이어 씁니다.',
  citation: '창가에서 · 검수 지은이 · https://example.com/source',
);
const bookFixture = Library(
  books: [
    Book(id: 'book', title: '문장을 모은 책', author: '검수 지은이', originals: [poem]),
  ],
  records: [WritingRecord(id: 'old', bookId: 'book', title: '필사 7')],
  pages: [
    WritingPage(
      id: 'old-page',
      recordId: 'old',
      number: 1,
      text: '먼저 쓴 문장',
      base: 3,
      extent: 3,
    ),
  ],
  activePageId: 'old-page',
  writing: true,
  style: WritingStyle(pageMotion: false),
);

void main() {
  testWidgets(
    'A transcription is one contents entry; continuation and rename preserve its pages',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()..data = bookFixture;
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final old = store.data.activePage!.toJson();
      await tester.tap(find.byKey(const ValueKey('writing-originals')));
      await tester.pumpAndSettle();
      if (find
          .byKey(const ValueKey('source-start-transcription'))
          .evaluate()
          .isEmpty) {
        await tester.tap(find.byKey(const ValueKey('source')));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.byKey(const ValueKey('source-start-transcription')),
      );
      await tester.pumpAndSettle();
      final writing = store.data.activeRecord!;
      expect(writing.id, isNot('old'));
      expect(writing.bookId, 'book');
      expect(writing.title, '창가에서');
      expect(store.data.records, hasLength(2));
      expect(store.data.activePage!.number, 1);
      expect(store.data.pages.first.toJson(), old);
      await tester.enterText(
        find.byKey(const ValueKey('page-text')),
        '한 줄을 옮겨 씁니다.\n',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('한 쪽 더'));
      await tester.pumpAndSettle();
      expect(store.data.records, hasLength(2));
      expect(store.data.activeRecord!.id, writing.id);
      expect(store.data.activePage!.number, 2);
      final continuation = store.data.activePage!;
      expect(continuation.passages.single.continued, isTrue);
      expect(continuation.passages.single.sourceOffset, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-book-book')));
      await tester.pumpAndSettle();
      expect(find.text('2편 · 3쪽'), findsOneWidget);
      expect(find.text('지은이 검수 지은이'), findsOneWidget);
      expect(find.text('필사 7'), findsNothing);
      expect(find.text('먼저 쓴 문장'), findsOneWidget);
      expect(find.text('창가에서'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('contents-page-${writing.id}')))
            .data,
        '2',
      );
      await tester.tap(
        find.byKey(ValueKey('contents-writing-menu-${writing.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('글 이름 변경'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('writing-title-input')),
        '나의 첫 필사',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('나의 첫 필사'), findsOneWidget);
      expect(store.data.activeRecord!.titleIsManual, isTrue);
      expect(store.data.activePage!.toJson(), continuation.toJson());
      await tester.tap(find.byKey(const ValueKey('contents-resume-writing')));
      await tester.pumpAndSettle();
      expect(store.data.activePageId, continuation.id);
    },
  );

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(640, 320), 1.0),
  ]) {
    testWidgets(
      'Contents remains readable and resume reachable at $size scale $scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = MemoryStore()..data = bookFixture;
        final c = LibraryController(store, store.data);
        addTearDown(c.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CollectionSheet(
                controller: c,
                initialBookId: 'book',
                onRecord: (_) {},
                onResumeBook: (_) {},
                onNewWriting: (_) {},
                onNewBook: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final resume = find.byKey(const ValueKey('contents-resume-writing'));
        if (resume.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            resume,
            120,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('book-contents-book')),
              matching: find.byType(Scrollable),
            ),
          );
        } else {
          await tester.ensureVisible(resume);
        }
        await tester.pumpAndSettle();
        expect(resume.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'Titles prefer explicit names, then source titles and written first lines',
    () {
      const automatic = WritingRecord(id: 'r', title: '필사 7');
      const page = WritingPage(
        id: 'p',
        recordId: 'r',
        number: 1,
        text: '내가 쓴 첫 문장\n둘째 줄',
      );
      expect(writingTitle(automatic, [page]), '내가 쓴 첫 문장');
      final c = LibraryController(
        MemoryStore(),
        const Library(records: [automatic], pages: [page]),
      );
      addTearDown(c.dispose);
      c.setRecordTitle('r', '필사 8');
      expect(writingTitle(c.library.records.single, [page]), '필사 8');
      final decoded = Library.decode(c.library.encode());
      final merged = mergeLibraries(
        const Library(records: [automatic], pages: [page]),
        decoded,
        const Library(records: [automatic], pages: [page]),
      );
      expect(merged.library.records.single.titleIsManual, isTrue);
      expect(writingTitle(merged.library.records.single, [page]), '필사 8');
      expect(
        originalWritingTitle(
          const RegisteredOriginal('a', '글', citation: 'https://example.com'),
        ),
        isEmpty,
      );
      expect(
        originalWritingTitle(
          const RegisteredOriginal('a', '글', citation: '42쪽'),
        ),
        isEmpty,
      );
      expect(writingTitle(automatic, const []), '제목 없는 글');
    },
  );

  test(
    'Version 13 file upgrades and preserves renamed titles after a real disk reopen',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('writing-contents-');
      final file = '${dir.path}/library.sqlite';
      try {
        final first = await SqliteLibraryStore.open(
          file,
          factory: databaseFactoryFfi,
        );
        await first.save(bookFixture);
        await first.close();
        final old = await databaseFactoryFfi.openDatabase(file);
        await old.execute('ALTER TABLE records DROP COLUMN title_is_manual');
        await old.execute('PRAGMA user_version = 13');
        await old.close();
        final upgraded = await SqliteLibraryStore.open(
          file,
          factory: databaseFactoryFfi,
        );
        final before = await upgraded.load();
        expect(before.pages.single.toJson(), bookFixture.pages.single.toJson());
        final c = LibraryController(upgraded, before);
        c.setRecordTitle('old', '필사 8');
        await c.settled;
        expect(c.saveError, isNull);
        c.dispose();
        await upgraded.close();
        final reopened = await SqliteLibraryStore.open(
          file,
          factory: databaseFactoryFfi,
        );
        final saved = await reopened.load();
        expect(saved.records.single.titleIsManual, isTrue);
        expect(writingTitle(saved.records.single, saved.pages), '필사 8');
        expect(saved.pages.single.toJson(), before.pages.single.toJson());
        await reopened.close();
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
