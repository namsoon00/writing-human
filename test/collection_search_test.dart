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
      await tester.tap(find.text('보관함'));
      await tester.pumpAndSettle();
      expect(find.text('다시 만난 문장'), findsOneWidget);
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
}
