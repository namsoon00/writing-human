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
        remainingReference,
        settleSourceSheets,
        sourceCitation,
        sourceField;
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
      final add = find.widgetWithText(FilledButton, '원문 담기');
      expect(add.hitTestable(), findsOneWidget);
      expect(
        tester.getTopLeft(add).dy -
            tester.getBottomLeft(find.text('담은 원문이 없어요.')).dy,
        inInclusiveRange(0, 20),
      );
      await tester.tap(find.text('새 원문 찾기'));
      await settleSourceSheets(tester);
      expect(find.text('작품 제목이나 작가'), findsOneWidget);
      expect(store.writes, 0);
      await tester.tap(find.byKey(const ValueKey('paper-back')).hitTestable());
      await settleSourceSheets(tester);
      expect(reading, findsOneWidget);
      expect(find.byType(SourceImportSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'The footer opens the current original and still offers the list',
    (tester) async {
      const first = RegisteredOriginal('guided', '햇빛이 책장에 내려앉았다.');
      const second = RegisteredOriginal('other', '정오에 종소리가 울렸다.');
      final store = MemoryStore()
        ..data = const Library(
          books: [
            Book(id: 'book', title: '필사 노트', originals: [first, second]),
          ],
          records: [WritingRecord(id: 'r', bookId: 'book', title: '필사')],
          pages: [
            WritingPage(
              id: 'p',
              recordId: 'r',
              number: 1,
              text: '햇빛이',
              base: 3,
              extent: 3,
              guidedOriginalId: 'guided',
            ),
          ],
          activePageId: 'p',
          writing: true,
        );
      await open(tester, store, FakeIntake());
      final input = tester.widget<TextField>(bodyField).controller!;
      final before = input.value;
      final writes = store.writes;

      await tester.tap(place);
      await tester.pumpAndSettle();
      expect(readingText, findsOneWidget);
      expect(
        tester.widget<Text>(readingText).textSpan!.toPlainText(),
        first.text,
      );
      await tester.tap(find.byTooltip('원문 목록'));
      await tester.pumpAndSettle();
      expect(find.text(first.text).hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('other')).hitTestable(), findsOneWidget);
      expect(find.text('원문 담기').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('other')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(readingText).textSpan!.toPlainText(),
        second.text,
      );
      await tester.tap(closeIn(reading));
      await tester.pumpAndSettle();
      // Detail back restores its list; the following back restores paper.
      await tester.tap(closeIn(reading));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(bodyField).controller, same(input));
      expect(input.value, before);

      await tester.tap(place);
      await tester.pumpAndSettle();
      expect(readingText, findsOneWidget);
      expect(
        tester.widget<Text>(readingText).textSpan!.toPlainText(),
        first.text,
      );
      await tester.tap(find.byTooltip('원문 목록'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('원문 담기'));
      await tester.pumpAndSettle();
      expect(sourceField.hitTestable(), findsOneWidget);
      expect(store.data.activePage!.guidedOriginalId, first.id);
      expect(store.writes, writes);
    },
  );

  testWidgets(
    'The source list shows written text and resumes the original in one tap',
    (tester) async {
      const original = RegisteredOriginal('resume', '햇빛이 책장에 내려앉았다.');
      const written = '햇빛이 내려왔다.';
      final store = MemoryStore()
        ..data = const Library(
          books: [
            Book(id: 'b', title: '필사 노트', originals: [original]),
          ],
          records: [
            WritingRecord(id: 'memo', bookId: 'b', title: '새 메모'),
            WritingRecord(id: 'copy', bookId: 'b', title: '지난 필사'),
          ],
          pages: [
            WritingPage(
              id: 'memo-page',
              recordId: 'memo',
              number: 1,
              text: '기억할 메모',
            ),
            WritingPage(
              id: 'copy-page',
              recordId: 'copy',
              number: 1,
              text: written,
              base: 4,
              extent: 4,
              passages: [
                PagePassage(
                  id: 'linked',
                  start: 0,
                  attached: true,
                  original: original,
                ),
              ],
            ),
          ],
          activePageId: 'memo-page',
          writing: true,
        );
      await open(tester, store, FakeIntake());
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      await tester.tap(place);
      await tester.pumpAndSettle();
      expect(readingText, findsNothing);
      expect(find.text('쓴 글 · $written').hitTestable(), findsOneWidget);
      final resume = find.byKey(const ValueKey('original-resume-resume'));
      expect(resume.hitTestable(), findsOneWidget);
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(reading, findsNothing);
      expect(store.data.activePageId, 'copy-page');
      expect(store.data.pages, hasLength(2));
      expect(store.data.records, hasLength(2));
      final input = tester.widget<TextField>(bodyField).controller!;
      expect(input.text, written);
      expect(input.selection, const TextSelection.collapsed(offset: 4));
      expect(remainingReference(tester), '책장에 내려앉았다.');
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
      expect(store.data.activeRecord!.originals, isEmpty);
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
      expect(store.data.activeRecord!.originals.single.text, '고쳐서 보관할 문장');
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
      await tester.tap(find.text('필사하기'));
      await settleSourceSheets(tester);
      final original = store.data.activeRecord!.originals.single;
      expect(reading, findsNothing);
      expect(find.byType(SourceImportSheet), findsNothing);
      expect(store.data.pages.first.text, before.text);
      expect(store.data.activePage!.id, isNot(before.id));
      expect(store.data.activePage!.guidedOriginalId, original.id);
      expect(store.data.activePage!.text, isEmpty);
    },
  );
  testWidgets(
    'Visible book and citation fields save to another book on a compact screen',
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
      tester.view.physicalSize = const Size(320, 640);
      await openRegistration(tester);
      final destination = find.byType(DropdownButtonFormField<String>);
      expect(destination.hitTestable(), findsOneWidget);
      expect(sourceCitation.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: destination, matching: find.text('쓰던 책')),
        findsOneWidget,
      );
      await tester.enterText(sourceField, '다른 책에 보관할 원문');
      await tester.pumpAndSettle();
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();
      await tester.tap(find.text('담을 책').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(sourceCitation);
      await tester.pumpAndSettle();
      await tester.tap(sourceCitation);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(sourceCitation.hitTestable(), findsOneWidget);
      await tester.enterText(sourceCitation, '원문 12쪽');
      await tester.pumpAndSettle();
      expect(confirm.hitTestable(), findsOneWidget);
      await tester.tap(confirm);
      tester.view.resetViewInsets();
      await settleSourceSheets(tester);
      expect(reading, findsOneWidget);
      expect(
        tester.widget<Text>(readingText).textSpan!.toPlainText(),
        '다른 책에 보관할 원문',
      );
      expect(store.data.books.first.originals, isEmpty);
      expect(store.data.books.last.originals.single.text, '다른 책에 보관할 원문');
      expect(store.data.books.last.originals.single.citation, '원문 12쪽');
      expect(store.data.activePageId, before.id);
      expect(store.data.activePage!.text, before.text);
    },
  );
}
