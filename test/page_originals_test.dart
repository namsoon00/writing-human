import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/library_backup.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/data/store.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/source/page_originals.dart';
import 'package:writing_human/source/originals.dart';
import 'package:writing_human/source/transcription_comparison.dart';
import 'package:writing_human/sync/merge.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/paper_panel.dart';
import 'package:writing_human/ui/transcription_guide.dart';
import 'package:writing_human/ui/transcription_reference.dart';

const first = RegisteredOriginal('a', '첫 원문을 씁니다.', citation: '첫 책');
const second = RegisteredOriginal('b', '다음 원문입니다.', citation: '둘째 책');
Library fixture({String text = '내 생각\n'}) => Library(
  records: const [
    WritingRecord(id: 'r', title: '함께 쓰는 글', originals: [first, second]),
  ],
  pages: [
    WritingPage(
      id: 'p',
      recordId: 'r',
      number: 1,
      text: text,
      base: text.length,
      extent: text.length,
    ),
  ],
  activePageId: 'p',
  writing: true,
);

class TestStore implements LibraryStore {
  TestStore(this.data);
  Library data;
  bool fail = false;
  @override
  Future<Library> load() async => data;
  @override
  Future<void> save(Library value) async {
    if (fail) throw StateError('disk failure');
    data = value;
  }

  @override
  Future<void> close() async {}
}

void main() {
  sqfliteFfiInit();
  test(
    'Multiple sources retain boundaries, selected copies and unlinked writing',
    () async {
      final c = LibraryController(TestStore(fixture()), fixture());
      c.attachOriginal('p', first);
      final a = c.library.activePage!.passages.single;
      expect(a.start, '내 생각\n'.length);
      final text = '내 생각\n첫 원문을 씁니다.\n';
      c.editPage('p', text, text.length, text.length, 0);
      c.attachOriginal('p', second);
      final b = c.library.activePage!.passages.last;
      c.editPage('p', '$text다음 원문', text.length + 5, text.length + 5, 0);
      final before = c.library.activePage!;
      expect(passageAt(before.passages, a.start)?.original?.id, 'a');
      expect(passageAt(before.passages, b.start)?.original?.id, 'b');
      expect(passageAt(before.passages, 0), isNull);
      c.writeWithoutOriginal('p');
      expect(
        passageOriginal(
          passageAt(c.library.activePage!.passages, before.extent)!,
        ),
        isNull,
      );
      c.editPage('p', '앞글\n${before.text}', 0, 0, 0);
      expect(c.library.activePage!.passages.first.start, a.start + 3);
      c.detachOriginal('p', b.id);
      final page = c.library.activePage!;
      expect(page.text, '앞글\n${before.text}');
      expect(passageOriginal(passageAt(page.passages, b.start + 3)!), isNull);
      expect(page.passages.first.original?.text, first.text);
      c.library.validate();
      await c.settled;
      c.dispose();
    },
  );
  test(
    'A new page continues only the unwritten part of the active source',
    () async {
      final data = fixture();
      final c = LibraryController(TestStore(data), data);
      c.attachOriginal('p', first);
      const text = '내 생각\n첫 원문';
      c.editPage('p', text, text.length, text.length, 0);
      c.addPage();
      final next = c.library.activePage!;
      expect(next.passages.single.continued, isTrue);
      expect(next.passages.single.sourceOffset, 4);
      expect(
        TranscriptionComparison(
          next.passages.single.original!,
          sourceOffset: 4,
        ).remainderFor(''),
        '을 씁니다.',
      );
      expect(next.text, isEmpty);
      expect(c.library.pages.first.text, text);
      await c.settled;
      c.dispose();
    },
  );
  test('Legacy guide and slip survive attaching another source', () async {
    final initial = fixture().copy(
      pages: [
        fixture().activePage!.withDetails(
          guidedOriginalId: first.id,
          originalSlip: second,
        ),
      ],
    );
    final c = LibraryController(TestStore(initial), initial);
    c.attachOriginal('p', const RegisteredOriginal('c', '세 번째'));
    final links = pageOriginals(c.library.activePage!, const [first, second]);
    expect(
      links.map((p) => passageOriginal(p)?.text),
      containsAll([first.text, second.text, '세 번째']),
    );
    expect(c.library.activePage!.text, initial.activePage!.text);
    await c.settled;
    c.dispose();
  });
  test(
    'Anchored sources survive real SQLite reopen, backup and independent sync edits',
    () async {
      final dir = await Directory.systemTemp.createTemp('anchored-originals-');
      final file = '${dir.path}/library.db';
      final store = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final initial = fixture();
      final c = LibraryController(store, initial);
      c.attachOriginal('p', first);
      c.editPage('p', '${initial.activePage!.text}${first.text}', 7, 7, 0);
      c.attachOriginal('p', second);
      await c.settled;
      final expected = c.library;
      c.dispose();
      await store.close();
      final reopened = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      try {
        final actual = await reopened.load();
        expect(actual.activePage!.toJson(), expected.activePage!.toJson());
        final backup = LibraryBackup.decode(
          LibraryBackup(actual, DateTime.utc(2026, 11, 21)).encode(),
        );
        expect(
          mergeBackup(const Library(), backup.library).activePage!.toJson(),
          actual.activePage!.toJson(),
        );
        final changed = actual.copy(
          pages: [
            actual.activePage!.edited(
              text: '앞\n${actual.activePage!.text}',
              base: 0,
              extent: 0,
              scroll: 0,
            ),
          ],
        );
        final detached = LibraryController(TestStore(actual), actual);
        detached.detachOriginal('p', actual.activePage!.passages.last.id);
        final merged = mergeLibraries(
          actual,
          changed,
          detached.library,
        ).library;
        final reverse = mergeLibraries(
          actual,
          detached.library,
          changed,
        ).library;
        for (final result in [merged, reverse]) {
          result.validate();
          expect(result.activePage!.passages.first.original?.id, first.id);
          expect(result.activePage!.passages.last.original, isNull);
          expect(
            result.activePage!.passages.last.start,
            actual.activePage!.passages.last.start + 2,
          );
        }
        await detached.settled;
        detached.dispose();
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'Writing two sources follows the active segment without rewriting Korean input',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = fixture().copy(style: const WritingStyle(paperIndex: 3));
      final store = TestStore(data);
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      final controller = tester.widget<TextField>(field).controller!;
      Future<void> attach(String id) async {
        await tester.tap(find.text('원문').last);
        await tester.pumpAndSettle();
        final list = find.byTooltip('원문 목록');
        if (list.evaluate().isNotEmpty) {
          await tester.tap(list);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(ValueKey(id)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('이 쪽에 끼우기'));
        await tester.pumpAndSettle();
      }

      final initial = controller.value;
      await attach('a');
      expect(controller.value, initial);
      final guide =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('transcription-guide')),
                  )
                  .painter!
              as TranscriptionGuidePainter;
      expect(guide.remainderFor(controller.value), first.text);
      await tester.showKeyboard(field);
      final written = '${data.activePage!.text}${first.text}\n';
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: written,
          selection: TextSelection.collapsed(offset: written.length),
        ),
      );
      await tester.pumpAndSettle();
      await attach('b');
      expect(tester.widget<TextField>(field).controller, same(controller));
      final bGuide =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('transcription-guide')),
                  )
                  .painter!
              as TranscriptionGuidePainter;
      expect(bGuide.remainderFor(controller.value), second.text);
      expect(store.data.activePage!.passages, hasLength(2));
      controller.selection = TextSelection.collapsed(
        offset: data.activePage!.text.length + 2,
      );
      await tester.pumpAndSettle();
      expect(find.text('1/2 · 첫 책'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('page-originals-button')));
      await tester.pumpAndSettle();
      expect(find.text('끼운 원문'), findsOneWidget);
      expect(
        tester.widget<PaperPanel>(find.byType(PaperPanel)).color,
        originalPanelColor,
      );
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final ref = tester.widget<TranscriptionReference>(
        find.byKey(const ValueKey('transcription-reference')),
      );
      expect(ref.original.id, 'a');
      expect(ref.startOffset, data.activePage!.text.length);
      await tester.showKeyboard(field);
      final composing = TextEditingValue(
        text: written,
        selection: TextSelection.collapsed(offset: written.length),
        composing: TextRange(start: written.length - 1, end: written.length),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(controller.value, composing);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('page-originals-button')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Inserting an original before existing writing keeps the old text outside its range',
    () async {
      final initial = fixture(text: '앞글 뒤에 남겨 둔 글');
      final page = initial.activePage!.edited(
        text: initial.activePage!.text,
        base: 3,
        extent: 3,
        scroll: 0,
      );
      final c = LibraryController(
        TestStore(initial),
        initial.copy(pages: [page]),
      );
      c.attachOriginal('p', first);
      final old = c.library.activePage!;
      expect(old.passages, hasLength(2));
      expect(passageAt(old.passages, 3)?.original?.id, 'a');
      final text = '${page.text.substring(0, 3)}첫 원문${page.text.substring(3)}';
      c.editPage('p', text, 7, 7, 0);
      final updated = c.library.activePage!;
      expect(updated.passages.last.start, 7);
      expect(passageAt(updated.passages, 7)?.original?.id, 'a');
      expect(passageOriginal(passageAt(updated.passages, 8)!), isNull);
      expect(
        updated.text.substring(updated.passages.last.start),
        page.text.substring(3),
      );
      expect(
        TranscriptionComparison(
          first,
        ).remainderFor(updated.text.substring(3, 7)),
        '을 씁니다.',
      );
      await c.settled;
      c.dispose();
    },
  );
  testWidgets(
    'Enter before an existing line break keeps the attached original and old writing',
    (tester) async {
      tester.view.physicalSize = const Size(390, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      const prefix = '먼저 쓴 글';
      const suffix = '\n이미 쓴 문장';
      final initial = fixture(text: '$prefix$suffix');
      final page = initial.activePage!.edited(
        text: initial.activePage!.text,
        base: prefix.length,
        extent: prefix.length,
        scroll: 0,
      );
      final data = initial.copy(pages: [page]);
      final store = TestStore(data);
      final library = LibraryController(store, data);
      expect(library.attachOriginal('p', first), isTrue);
      await library.settled;
      library.dispose();

      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      final reference = find.byType(TranscriptionReference);
      final controller = tester.widget<TextField>(field).controller!;
      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      await tester.showKeyboard(field);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TranscriptionReference>(reference).original.id,
        first.id,
      );

      const lineBreaks = ['\n', '\n\n'];
      for (final inserted in lineBreaks) {
        final caret = prefix.length + inserted.length;
        final value = TextEditingValue(
          text: '$prefix$inserted$suffix',
          selection: TextSelection.collapsed(offset: caret),
        );
        tester.testTextInput.updateEditingValue(value);
        await tester.pumpAndSettle();
        expect(controller.value, value);
        final saved = store.data.activePage!;
        expect(saved.text, value.text);
        expect(saved.passages.last.start, caret);
        expect(saved.text.substring(caret), suffix);
        final visible = tester.widget<TranscriptionReference>(reference);
        expect(visible.original.id, first.id);
        expect(visible.comparison!.remainderFor(inserted), first.text);
      }
      expect(tester.takeException(), isNull);
    },
  );

  test('Extra line breaks leave the next original characters available', () {
    final comparison = TranscriptionComparison(
      const RegisteredOriginal('a', '가나\r\n다'),
    );
    expect(comparison.remainderFor('가\n'), '나\r\n다');
    expect(comparison.differencesFor('가\n'), isEmpty);
    expect(comparison.remainderFor('가\n나\n'), '다');
    expect(comparison.differencesFor('가\n나\n다\n'), isEmpty);
  });

  test(
    'Deleting a catalog original clears only its linked segments and retains the writing',
    () async {
      final initial = fixture();
      final c = LibraryController(TestStore(initial), initial);
      c.attachOriginal('p', first);
      const text = '내 생각\n첫 원문을 씁니다.\n';
      c.editPage('p', text, text.length, text.length, 0);
      c.attachOriginal('p', second);
      final edited = await c.saveOriginalEdit(
        bookId: null,
        recordId: 'r',
        original: first,
        text: '고친 원문',
        citation: '고친 출처',
      );
      expect(edited, isNotNull);
      expect(c.library.activePage!.passages.first.original?.text, first.text);
      expect(
        await c.deleteOriginal(bookId: null, recordId: 'r', original: second),
        isTrue,
      );
      expect(c.library.activePage!.passages.first.original?.id, 'a');
      expect(c.library.activePage!.passages.last.original, isNull);
      expect(c.library.activePage!.text, text);
      expect(originalsFor(c.library, recordId: 'r').map((p) => p.id), ['a']);
      c.dispose();
    },
  );
  testWidgets(
    'Older source offsets remain readable after leading whitespace is trimmed',
    (tester) async {
      const original = RegisteredOriginal('legacy', '   가');
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 100,
              child: TranscriptionReference(
                original: original,
                comparison: TranscriptionComparison(original, sourceOffset: 4),
                sourceOffset: 4,
                controller: controller,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('가', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('Failed saves keep attached sources available for retry', () async {
    final initial = fixture();
    final store = TestStore(initial)..fail = true;
    final c = LibraryController(store, initial);
    c.attachOriginal('p', first);
    await c.settled;
    expect(c.saveError, isNotNull);
    expect(c.library.activePage!.passages.single.original?.id, 'a');
    expect(store.data.activePage!.passages, isEmpty);
    store.fail = false;
    c.retrySave();
    await c.settled;
    expect(c.saveError, isNull);
    expect(store.data.activePage!.passages.single.original?.id, 'a');
    c.dispose();
  });
}
