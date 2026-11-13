import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/ui/workspace.dart';

import 'widget_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'Search opens a later page and reveals the match without moving the caret',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()
        ..data = Library(
          books: const [Book(id: 'b', title: '문장집', author: '기록자')],
          records: const [WritingRecord(id: 'r', bookId: 'b', title: '첫 필사')],
          pages: [
            const WritingPage(id: 'p1', recordId: 'r', number: 1, text: '첫 쪽'),
            WritingPage(
              id: 'p2',
              recordId: 'r',
              number: 2,
              text: '${List.filled(45, '그날 적은 문장.').join('\n')}\n마지막에서 찾은 문장',
              base: 2,
              extent: 6,
              writtenOn: '2024-01-01',
            ),
          ],
          activePageId: 'p1',
          writing: true,
          style: const WritingStyle(pageMotion: false),
        );
      final controller = LibraryController(store, store.data);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: Workspace(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 글'));
      await tester.pumpAndSettle();
      expect(find.text('다시 만난 문장'), findsOneWidget);
      await tester.tap(find.byTooltip('내 글 검색'));
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, '문장, 책, 날짜 찾기');
      await tester.showKeyboard(search);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: search,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
      tester.testTextInput.enterText('마지막에서 찾은 문장');
      await tester.pumpAndSettle();
      final result = find.textContaining('마지막에서 찾은 문장').last;
      await tester.tap(result);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      expect(store.data.activePageId, 'p2');
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('page-text')),
      );
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      expect(field.focusNode!.hasFocus, isFalse);
      expect(field.scrollController!.offset, greaterThan(500));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Bookshelf and writing sheets restore their own scroll positions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()
        ..data = Library(
          books: [for (var i = 0; i < 15; i++) Book(id: 'b$i', title: '노트 $i')],
          records: [
            for (var i = 0; i < 15; i++)
              WritingRecord(
                id: 'r$i',
                bookId: i.isEven ? 'b$i' : null,
                title: '필사 $i',
              ),
          ],
          pages: [
            for (var i = 0; i < 15; i++)
              WritingPage(
                id: 'p$i',
                recordId: 'r$i',
                number: 1,
                text: '첫 문장 $i\n둘째 문장 $i',
              ),
          ],
          activePageId: 'p0',
          writing: true,
        );
      final controller = LibraryController(store, store.data);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: Workspace(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
      await tester.pumpAndSettle();

      final shelf = find.byKey(const ValueKey('bookshelf-scroll'));
      final sheets = find.byKey(const PageStorageKey('writing'));
      double position(Finder view) => tester
          .state<ScrollableState>(
            find.descendant(of: view, matching: find.byType(Scrollable)),
          )
          .position
          .pixels;

      await tester.drag(shelf, const Offset(0, -280));
      await tester.pumpAndSettle();
      final shelfOffset = position(shelf);
      expect(shelfOffset, greaterThan(0));
      await tester.tap(find.text('내 글'));
      await tester.pumpAndSettle();
      expect(find.text('첫 문장 14\n둘째 문장 14'), findsOneWidget);

      await tester.drag(sheets, const Offset(0, -340));
      await tester.pumpAndSettle();
      final sheetOffset = position(sheets);
      expect(sheetOffset, greaterThan(0));

      await tester.tap(find.widgetWithText(TextButton, '책장').last);
      await tester.pumpAndSettle();
      expect(position(shelf), closeTo(shelfOffset, .01));
      await tester.tap(find.text('내 글'));
      await tester.pumpAndSettle();
      expect(position(sheets), closeTo(sheetOffset, .01));
      expect(store.writes, 0);

      final looseSheet = find.byKey(const ValueKey('writing-sheet-r13'));
      final scrollable = find.descendant(
        of: sheets,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(looseSheet, -150, scrollable: scrollable);
      await tester.ensureVisible(looseSheet);
      await tester.tap(looseSheet);
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'p13');
      expect(store.data.activeRecord?.bookId, isNull);
    },
  );
}
