import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/book_details.dart';

import 'widget_test.dart' show MemoryStore;

void main() {
  final collection = find.byKey(const ValueKey('open-bookshelf'));
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

  testWidgets('Notebook covers resume each book after the app reopens', (
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    store.data = Library.decode(store.data.encode());
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();

    await shelf(tester);
    await tester.scrollUntilVisible(cover('a'), 200, scrollable: scroll);
    await tester.tap(cover('a'));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    expect(tester.widget<TextField>(editor).controller!.text, '첫 쪽');
    expect(store.data.pages.length, 3);
  });

  testWidgets(
    'Contents show volume page numbers and open each record at its start',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()
        ..data = const Library(
          books: [Book(id: 'book', title: '한 권')],
          records: [
            WritingRecord(id: 'a', bookId: 'book', title: '첫 기록'),
            WritingRecord(id: 'b', bookId: 'book', title: '둘째 기록'),
            WritingRecord(id: 'other', title: '책 밖의 기록'),
          ],
          pages: [
            WritingPage(id: 'a2', recordId: 'a', number: 2),
            WritingPage(id: 'b2', recordId: 'b', number: 2),
            WritingPage(id: 'a1', recordId: 'a', number: 1),
            WritingPage(id: 'outside', recordId: 'other', number: 1),
            WritingPage(id: 'b1', recordId: 'b', number: 1, text: '둘째 기록 첫 쪽'),
          ],
          activePageId: 'b2',
          writing: true,
          style: WritingStyle(pageMotion: false),
        );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      await shelf(tester);
      await tester.tap(find.byKey(const ValueKey('shelf-details-book')));
      await tester.pumpAndSettle();
      expect(find.text('2편 · 4쪽'), findsOneWidget);
      await tester.tap(find.text('이어서 쓰기'));
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'b2');
      expect(store.data.pages, hasLength(5));

      await shelf(tester);
      await tester.tap(find.byKey(const ValueKey('shelf-details-book')));
      await tester.pumpAndSettle();
      final firstNumber = find.byKey(const ValueKey('contents-page-a'));
      final secondNumber = find.byKey(const ValueKey('contents-page-b'));
      expect(tester.widget<Text>(firstNumber).data, '1');
      expect(tester.widget<Text>(secondNumber).data, '3');
      expect(
        tester.getTopRight(firstNumber).dx,
        tester.getTopRight(secondNumber).dx,
      );
      expect(
        tester.getTopLeft(firstNumber).dy,
        lessThan(tester.getTopLeft(secondNumber).dy),
      );
      expect(find.text('책 밖의 기록'), findsNothing);

      final bookmark = find.descendant(
        of: find.byKey(const ValueKey('contents-record-b')),
        matching: find.byType(RibbonBookmark),
      );
      expect(bookmark, findsOneWidget);
      expect(tester.getSize(bookmark), const Size(13, 32));
      expect(tester.widget<RibbonBookmark>(bookmark).choice.variant, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contents-record-a')),
          matching: find.byType(RibbonBookmark),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('contents-record-b')));
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'b1');
      expect(tester.widget<TextField>(editor).controller!.text, '둘째 기록 첫 쪽');
      final pageNumber = find.byKey(const ValueKey('page-number'));
      expect(
        find.descendant(of: pageNumber, matching: find.text('3')),
        findsOneWidget,
      );
      expect(tester.getCenter(pageNumber).dx, closeTo(195, .5));
    },
  );

  testWidgets('Loose pages share one shelf cover without creating a book', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = MemoryStore()
      ..data = const Library(
        books: [Book(id: 'book', title: '책에 묶인 글')],
        records: [
          WritingRecord(id: 'a', title: '첫 낱장'),
          WritingRecord(id: 'b', title: '둘째 낱장'),
          WritingRecord(id: 'bound', bookId: 'book', title: '묶인 기록'),
        ],
        pages: [
          WritingPage(id: 'a2', recordId: 'a', number: 2),
          WritingPage(id: 'a1', recordId: 'a', number: 1, text: '첫 문장'),
          WritingPage(id: 'b1', recordId: 'b', number: 1),
          WritingPage(id: 'inside', recordId: 'bound', number: 1),
        ],
        activePageId: 'inside',
        writing: true,
        style: WritingStyle(pageMotion: false),
      );
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    await shelf(tester);
    final looseCover = find.byKey(const ValueKey('shelf-loose-pages'));
    expect(looseCover, findsOneWidget);
    await tester.tap(looseCover);
    await tester.pumpAndSettle();

    expect(find.text('낱장 모음'), findsOneWidget);
    expect(find.text('2편 · 3쪽'), findsOneWidget);
    expect(find.byKey(const ValueKey('contents-record-bound')), findsNothing);
    expect(store.writes, 0);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('contents-page-b'))).data,
      '3',
    );
    await tester.tap(find.byKey(const ValueKey('contents-record-a')));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'a1');
    expect(store.data.activeRecord!.bookId, isNull);

    await shelf(tester);
    await tester.tap(looseCover);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '새 종이'));
    await tester.pumpAndSettle();
    await tester.enterText(editor, '새로 쓴 낱장');
    await tester.pumpAndSettle();
    expect(store.data.books.single.id, 'book');
    expect(store.data.activeRecord!.bookId, isNull);
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
    final body = tester.widget<Semantics>(
      find.bySemanticsIdentifier('writing-page-body'),
    );
    final render = tester.renderObject<RenderObject>(find.byWidget(body));
    expect(render.debugSemantics?.attached ?? false, isFalse);
    final editable = find.descendant(
      of: search,
      matching: find.byType(EditableText),
    );
    final input = tester.widget<EditableText>(editable);
    final searchTop = tester.getTopLeft(search).dy;
    final composing = TextEditingValue(
      text: '노',
      selection: const TextSelection.collapsed(offset: 1),
      composing: const TextRange(start: 0, end: 1),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pumpAndSettle();
    addTearDown(tester.view.resetViewInsets);
    for (final inset in [280.0, 0.0, 280.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(editable).focusNode, input.focusNode);
      expect(input.focusNode.hasFocus, isTrue);
      expect(input.controller.value, composing);
      expect(tester.getTopLeft(search).dy, closeTo(searchTop, 1));
    }
    tester.view.resetViewInsets();
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
    expect(find.byKey(const ValueKey('bookshelf-scroll')), findsNothing);
    expect(store.data.books.length, 16);
    expect(store.data.pages.length, 1);
  });
}
