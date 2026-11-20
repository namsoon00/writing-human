import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/ui/source_import_sheet.dart';
import 'package:writing_human/data/model.dart';

import 'source_intake_test.dart'
    show
        FakeIntake,
        bodyField,
        closeIn,
        confirm,
        existing,
        open,
        openRegistration,
        place,
        reading,
        readingText,
        settleSourceSheets,
        sourceField,
        showSourceDetails;
import 'widget_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'An empty original library offers reading discovery before a form',
    (tester) async {
      final store = MemoryStore();
      await open(tester, store, FakeIntake());
      await tester.tap(place);
      await tester.pumpAndSettle();
      expect(reading, findsOneWidget);
      expect(sourceField, findsNothing);
      expect(find.text('새 원문 찾기').hitTestable(), findsOneWidget);
      expect(find.text('원문 담기').hitTestable(), findsOneWidget);
      await tester.tap(find.text('새 원문 찾기'));
      await settleSourceSheets(tester);
      expect(find.text('천천히 읽을 시'), findsOneWidget);
      expect(store.writes, 0);
      await tester.tap(find.byTooltip('검색 닫기'));
      await settleSourceSheets(tester);
      expect(reading, findsOneWidget);
      expect(find.byType(SourceImportSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.writes, 0);
    },
  );

  testWidgets('Close and system back protect an edited original draft', (
    tester,
  ) async {
    final store = MemoryStore();
    await open(tester, store, FakeIntake());
    await openRegistration(tester);
    await tester.enterText(sourceField, '천천히 읽고 담을 문장');
    final controller = tester.widget<TextField>(sourceField).controller!;
    final value = controller.value;
    await tester.tap(closeIn(find.byType(SourceImportSheet)));
    await tester.pumpAndSettle();
    expect(find.text('담지 않은 원문을 닫을까요?'), findsOneWidget);
    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();
    expect(controller.value, value);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('담지 않은 원문을 닫을까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '닫기'));
    await tester.pumpAndSettle();
    expect(reading, findsOneWidget);
    expect(store.writes, 0);
  });

  testWidgets(
    'Failed registration keeps the draft and retry saves one original',
    (tester) async {
      final store = MemoryStore()..data = existing();
      await open(tester, store, FakeIntake());
      final body = tester.widget<TextField>(bodyField).controller!;
      final before = body.value;
      await openRegistration(tester);
      await tester.enterText(sourceField, '처음 고른 문장');
      await tester.pumpAndSettle();
      store.fail = true;
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byType(SourceImportSheet), findsOneWidget);
      expect(find.text('원문을 저장하지 못했어요. 이 화면에서 다시 담아 주세요.'), findsOneWidget);
      expect(store.data.records.single.originals, isEmpty);
      await tester.enterText(sourceField, '고쳐서 보관할 문장');
      await tester.pumpAndSettle();
      store.fail = false;
      await tester.tap(confirm);
      await settleSourceSheets(tester);
      expect(reading, findsOneWidget);
      expect(
        tester.widget<Text>(readingText).textSpan!.toPlainText(),
        '고쳐서 보관할 문장',
      );
      expect(store.data.records.single.originals.single.text, '고쳐서 보관할 문장');
      expect(store.data.activePageId, 'p');
      expect(body.value, before);
      expect(store.data.activePage!.guidedOriginalId, isNull);
      await tester.tap(closeIn(reading));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(bodyField).controller, same(body));
    },
  );

  testWidgets(
    'Save and transcribe explicitly opens a new page after written text',
    (tester) async {
      final store = MemoryStore()..data = existing();
      await open(tester, store, FakeIntake());
      final before = store.data.activePage!;
      await openRegistration(tester);
      await tester.enterText(sourceField, '지금 옮겨 쓰고 싶은 문장');
      await tester.pumpAndSettle();
      await tester.tap(find.text('담고 필사하기'));
      await settleSourceSheets(tester);
      final original = store.data.records.single.originals.single;
      expect(reading, findsNothing);
      expect(find.byType(SourceImportSheet), findsNothing);
      expect(store.data.pages.first.text, before.text);
      expect(store.data.activePage!.id, isNot(before.id));
      expect(store.data.activePage!.guidedOriginalId, original.id);
      expect(store.data.activePage!.text, isEmpty);
    },
  );
  testWidgets(
    'Saving to another book opens that original without moving the writing page',
    (tester) async {
      final store = MemoryStore()
        ..data = existing().copy(
          books: const [
            Book(id: 'current', title: '쓰던 책'),
            Book(id: 'destination', title: '담을 책'),
          ],
          records: const [
            WritingRecord(id: 'r', bookId: 'current', title: '쓰던 글'),
          ],
        );
      await open(tester, store, FakeIntake());
      final before = store.data.activePage!;
      await openRegistration(tester);
      await tester.enterText(sourceField, '다른 책에 보관할 원문');
      await showSourceDetails(tester);
      final destination = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();
      await tester.tap(find.text('담을 책').last);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await settleSourceSheets(tester);
      expect(reading, findsOneWidget);
      expect(
        tester.widget<Text>(readingText).textSpan!.toPlainText(),
        '다른 책에 보관할 원문',
      );
      expect(store.data.books.first.originals, isEmpty);
      expect(store.data.books.last.originals.single.text, '다른 책에 보관할 원문');
      expect(store.data.activePageId, before.id);
      expect(store.data.activePage!.text, before.text);
    },
  );
}
