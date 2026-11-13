import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';

import 'widget_test.dart' show MemoryStore;

void main() {
  final collection = find.text('보관함');
  final editor = find.byKey(const ValueKey('page-text'));
  Finder cover(String id) => find.byKey(ValueKey('shelf-book-$id'));
  final scroll = find.descendant(
    of: find.byKey(const ValueKey('bookshelf-scroll')),
    matching: find.byType(Scrollable),
  );

  Future<void> shelf(WidgetTester tester) async {
    await tester.tap(collection);
    await tester.pumpAndSettle();
  }

  testWidgets('Notebook covers resume the page last open in each book', (
    tester,
  ) async {
    final store = MemoryStore()
      ..data = const Library(
        books: [
          Book(id: 'a', title: '첫 노트'),
          Book(id: 'b', title: '다른 노트'),
        ],
        records: [
          WritingRecord(id: 'a1', bookId: 'a', title: '필사'),
          WritingRecord(id: 'b1', bookId: 'b', title: '필사'),
        ],
        pages: [
          WritingPage(id: 'one', recordId: 'a1', number: 1, text: '첫 쪽'),
          WritingPage(id: 'two', recordId: 'a1', number: 2, text: '둘째 쪽'),
          WritingPage(id: 'other', recordId: 'b1', number: 1, text: '다른 글'),
        ],
        activePageId: 'one',
        writing: true,
        style: WritingStyle(pageMotion: false),
      );
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();

    await shelf(tester);
    final writes = store.writes;
    await tester.tap(cover('a'));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    expect(store.writes, writes);

    await shelf(tester);
    await tester.scrollUntilVisible(cover('b'), 200, scrollable: scroll);
    await tester.tap(cover('b'));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'other');

    await shelf(tester);
    await tester.scrollUntilVisible(cover('a'), 200, scrollable: scroll);
    await tester.tap(cover('a'));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    expect(tester.widget<TextField>(editor).controller!.text, '첫 쪽');
    expect(store.data.pages.length, 3);
  });

  testWidgets('A full shelf scrolls in rows and searches notebook titles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = MemoryStore()
      ..data = Library(
        books: [for (var i = 1; i <= 16; i++) Book(id: 'b$i', title: '노트 $i')],
        records: const [WritingRecord(id: 'r', bookId: 'b1', title: '필사')],
        pages: const [WritingPage(id: 'p', recordId: 'r', number: 1)],
        activePageId: 'p',
        writing: true,
      );
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    await shelf(tester);
    expect(find.text('이어 쓰기'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('shelf-recent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shelf-recent')), findsNothing);
    expect(store.data.activePageId, 'p');
    await shelf(tester);
    expect(find.text('모든 노트'), findsOneWidget);
    expect(
      tester.getTopLeft(cover('b1')).dy,
      tester.getTopLeft(cover('b3')).dy,
    );
    expect(
      tester.getTopLeft(cover('b4')).dy,
      greaterThan(tester.getTopLeft(cover('b3')).dy),
    );
    await tester.scrollUntilVisible(cover('b16'), 235, scrollable: scroll);
    expect(cover('b16'), findsOneWidget);
    await tester.tap(find.byTooltip('노트 검색'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('shelf-title-search'));
    await tester.enterText(search, ' 노트 16 ');
    await tester.pumpAndSettle();
    expect(cover('b1'), findsNothing);
    expect(cover('b16'), findsOneWidget);
    await tester.tap(find.byTooltip('노트 검색 닫기'));
    await tester.pumpAndSettle();
    expect(cover('b16'), findsOneWidget);
    expect(find.text('검색 결과'), findsNothing);
    expect(store.writes, 0);
    await tester.tap(find.byTooltip('노트 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(search, '노트 16');
    await tester.pumpAndSettle();
    await tester.tap(cover('b16'));
    await tester.pumpAndSettle();
    expect(find.text('책장'), findsNothing);
    expect(store.data.books.length, 16);
    expect(store.data.pages.length, 1);
  });
}
