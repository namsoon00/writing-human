import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/collection_sheet.dart';
import 'package:writing_human/ui/original_edit.dart';
import 'package:writing_human/ui/original_list_item.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/paper_panel.dart';
import 'package:writing_human/ui/source_reading.dart';
import 'package:writing_human/ui/tools_screen.dart';

import 'widget_test.dart' show MemoryStore;

const sourceA = RegisteredOriginal(
  'source-a',
  '종이 위에 문장을 씁니다.',
  citation: '첫 원문',
);
const sourceB = RegisteredOriginal(
  'source-b',
  '다른 책의 문장을 읽습니다.',
  citation: '둘째 원문',
);
const fixture = Library(
  books: [
    Book(id: 'a', title: '쓰던 책', originals: [sourceA]),
    Book(id: 'b', title: '살펴볼 책', originals: [sourceB]),
  ],
  records: [
    WritingRecord(id: 'ra', title: '쓰던 글', bookId: 'a'),
    WritingRecord(id: 'rb', title: '다른 글', bookId: 'b'),
  ],
  pages: [
    WritingPage(
      id: 'pa',
      recordId: 'ra',
      number: 1,
      text: '종이 위에',
      base: 2,
      extent: 2,
      passages: [
        PagePassage(
          id: 'oa',
          start: 0,
          source: '종이 위에 문장을 씁니다.',
          original: sourceA,
          attached: true,
        ),
      ],
    ),
    WritingPage(
      id: 'pb',
      recordId: 'rb',
      number: 1,
      text: '다른 책의',
      base: 3,
      extent: 3,
      passages: [
        PagePassage(
          id: 'ob',
          start: 0,
          source: '다른 책의 문장을 읽습니다.',
          original: sourceB,
          attached: true,
        ),
      ],
    ),
  ],
  activePageId: 'pa',
  writing: true,
  style: WritingStyle(pageMotion: false),
);
const backKey = ValueKey('paper-back');
const editorKey = ValueKey('page-text');

void main() {
  Future<MemoryStore> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore()..data = fixture;
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> bookB(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-book-b')));
    await tester.pumpAndSettle();
  }

  Future<void> originalB(WidgetTester tester) async {
    await bookB(tester);
    await tester.tap(find.text('원문'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('source-b')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Browsing another book and source returns to the exact origin without creating writing',
    (tester) async {
      final store = await open(tester);
      final before = store.data.pages.map((p) => p.toJson()).toList();
      final controller = tester
          .widget<TextField>(find.byKey(editorKey))
          .controller!;
      final selection = controller.selection;
      await originalB(tester);
      expect(store.data.activePageId, 'pa');
      await tester.tap(find.byKey(const ValueKey('return-to-writing')));
      await tester.pumpAndSettle();
      expect(find.byType(SourceReading), findsNothing);
      expect(find.byType(CollectionSheet), findsNothing);
      expect(store.data.pages.map((p) => p.toJson()).toList(), before);
      expect(store.data.records, hasLength(2));
      expect(
        tester.widget<TextField>(find.byKey(editorKey)).controller,
        same(controller),
      );
      expect(controller.selection, selection);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'System back follows original list then book then shelf without changing the active page',
    (tester) async {
      final store = await open(tester);
      await originalB(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(OriginalListItem, sourceB.text),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SourceReading), findsNothing);
      expect(find.text('목차'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shelf-book-b')), findsOneWidget);
      expect(store.data.activePageId, 'pa');
    },
  );

  testWidgets(
    'Opening the current original returns directly to paper without an invented list parent',
    (tester) async {
      final store = await open(tester);
      await tester.tap(find.byKey(const ValueKey('writing-originals')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-open-writing')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SourceReading), findsNothing);
      expect(store.data.activePageId, 'pa');
    },
  );

  testWidgets(
    'Selecting a different existing transcription clears exploration and becomes the new writing',
    (tester) async {
      final store = await open(tester);
      await originalB(tester);
      await tester.tap(find.byKey(const ValueKey('source-open-writing')));
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'pb');
      expect(store.data.records, hasLength(2));
      expect(find.byType(SourceReading), findsNothing);
      expect(find.byType(CollectionSheet), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(editorKey)).controller!.text,
        '다른 책의',
      );
    },
  );

  testWidgets(
    'Returning during a source exit does not let its delayed callback pop the writing page',
    (tester) async {
      final store = await open(tester);
      await originalB(tester);
      await tester.tap(find.byKey(const ValueKey('source-open-writing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final navigation = tester
          .widget<PaperNavigationScope>(find.byType(PaperNavigationScope))
          .notifier!;
      navigation.returnToWriting();
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'pb');
      expect(find.byType(SourceReading), findsNothing);
      expect(find.byType(CollectionSheet), findsNothing);
      expect(find.byKey(editorKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tool panel drag returns to the same text and cursor with the selected tool',
    (tester) async {
      final store = await open(tester);
      final before = store.data.activePage!.toJson();
      await tester.tap(find.text('쓰기 도구'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paper-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-paper-tool-eraser')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('paper-sheet-handle')),
        const Offset(0, 160),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ToolsScreen), findsNothing);
      expect(store.data.activePage!.toJson(), before);
      expect(find.byKey(const ValueKey('active-paper-tool')), findsOneWidget);
      expect(find.text('지우개'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An origin shortcut stops at an intermediate dirty form and preserves its draft',
    (tester) async {
      final navigation = PaperNavigation();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [navigation],
          builder: (_, child) =>
              PaperNavigationScope(navigation: navigation, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  paperPanelRoute(
                    (context) => OriginalEdit(
                      original: sourceA,
                      style: const WritingStyle(),
                      color: paper,
                      onSave: (_, _) async => null,
                    ),
                  ),
                ),
                child: const Text('수정 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('수정 열기'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField).first;
      await tester.enterText(field, '저장 전 문장');
      await tester.pumpAndSettle();
      navigation.returnToWriting();
      await tester.pumpAndSettle();
      expect(find.text('원문 수정을 취소할까요?'), findsOneWidget);
      await tester.tap(find.text('계속 수정'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '저장 전 문장');
      expect(find.byType(OriginalEdit), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정 취소'));
      await tester.pumpAndSettle();
      expect(find.byType(OriginalEdit), findsNothing);
    },
  );
}
