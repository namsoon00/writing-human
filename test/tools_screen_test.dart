import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/ui/control_theme.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/paper_tool.dart';
import 'package:writing_human/ui/pencil_marks.dart';
import 'package:writing_human/ui/tools_screen.dart';

import 'widget_test.dart' show MemoryStore;

const _library = Library(
  books: [
    Book(
      id: 'b',
      title: '내 책',
      paperIndex: 2,
      detailOverrides: {
        BookDetailKind.ribbon: BookDetailChoice(tone: 3),
        BookDetailKind.pencil: BookDetailChoice(tone: 2),
      },
    ),
    Book(id: 'other', title: '다른 책'),
  ],
  records: [WritingRecord(id: 'r', title: '내 글', bookId: 'b')],
  pages: [
    WritingPage(
      id: 'p',
      recordId: 'r',
      number: 1,
      text: '남겨 둔 문장',
      base: 2,
      extent: 5,
      scroll: 37,
      pencilMarks: [PencilMark(0, 3)],
    ),
  ],
  activePageId: 'p',
  writing: true,
);

void main() {
  Future<void> open(
    WidgetTester tester,
    LibraryController controller, {
    PaperTool tool = PaperTool.writing,
    String? bookId = 'b',
    ValueChanged<PaperTool>? onSelected,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: withPaperControls(ThemeData(fontFamily: appFontFamily)),
        home: Scaffold(
          body: ToolsScreen(
            controller: controller,
            bookId: bookId,
            paperTool: tool,
            onToolSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Tools stay open for contextual settings; erasing is secondary and reversible',
    (tester) async {
      final store = MemoryStore()..data = _library;
      final controller = LibraryController(store, _library);
      addTearDown(controller.dispose);
      final before = controller.library.encode();
      final selected = <PaperTool>[];
      await open(tester, controller, onSelected: selected.add);
      expect(
        find.byKey(const ValueKey('tool-paper-specimen')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('밑칠 지우기'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('choose-paper-tool-highlighter')),
      );
      await tester.pumpAndSettle();
      expect(selected, [PaperTool.highlighter]);
      expect(find.byType(ToolsScreen), findsOneWidget);
      expect(find.text('잉크'), findsNothing);
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('tool-specimen-text')),
      );
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(
        spans.where((s) => s.style?.backgroundColor != null).single.text,
        '천천히 옮겨',
      );
      final erase = find.byKey(const ValueKey('choose-paper-tool-eraser'));
      await tester.ensureVisible(erase);
      await tester.tap(erase);
      await tester.pumpAndSettle();
      expect(selected.last, PaperTool.eraser);
      final erased = tester.widget<Text>(
        find.byKey(const ValueKey('tool-specimen-text')),
      );
      expect(
        (erased.textSpan! as TextSpan).children!.cast<TextSpan>().any(
          (s) => s.style?.backgroundColor != null,
        ),
        isFalse,
      );
      await tester.tap(erase);
      await tester.pumpAndSettle();
      expect(selected.last, PaperTool.highlighter);
      expect(store.writes, 0);
      expect(controller.library.encode(), before);
    },
  );

  testWidgets(
    'Wash settings update only this book and preserve marks, paper and position through save retry',
    (tester) async {
      final store = MemoryStore()..data = _library;
      final controller = LibraryController(store, _library);
      addTearDown(controller.dispose);
      await open(tester, controller, tool: PaperTool.highlighter);
      store.fail = true;
      await tester.tap(find.byKey(const ValueKey('tool-wash-tone-3')));
      await tester.pumpAndSettle();
      final density = tester.widget<Slider>(
        find.byKey(const ValueKey('tool-wash-density')),
      );
      density.onChanged!(2);
      await tester.pumpAndSettle();
      expect(controller.saveError, isNotNull);
      final retry = find.text('설정 저장 실패 · 다시 시도');
      await tester.ensureVisible(retry);
      expect(retry.hitTestable(), findsOneWidget);
      expect(store.data.encode(), _library.encode());
      final book = controller.library.books.first;
      expect(book.paperIndex, 2);
      expect(book.detailOverrides[BookDetailKind.ribbon]!.tone, 3);
      expect(controller.styleFor(book).bookDetails.pencil.tone, 3);
      expect(controller.styleFor(book).bookDetails.pencil.variant, 2);
      expect(
        controller
            .styleFor(controller.library.books.last)
            .bookDetails
            .pencil
            .tone,
        0,
      );
      expect(controller.library.style.toJson(), _library.style.toJson());
      expect(
        controller.library.pages.single.toJson(),
        _library.pages.single.toJson(),
      );
      store.fail = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(controller.saveError, isNull);
      expect(store.data.encode(), controller.library.encode());
      final specimen = tester.widget<Text>(
        find.byKey(const ValueKey('tool-specimen-text')),
      );
      final span = specimen.textSpan! as TextSpan;
      expect(span.style!.fontSize, _library.style.fontSize);
      expect(
        span.children!
            .cast<TextSpan>()
            .firstWhere((s) => s.style?.backgroundColor != null)
            .style!
            .backgroundColor,
        passageWashStyle(
          controller.styleFor(book).bookDetails.pencil,
        ).backgroundColor,
      );
    },
  );

  testWidgets(
    'Disabled wash can be restored without changing saved annotations',
    (tester) async {
      final library = _library.copy(
        books: [
          _library.books.first.copy(
            detailOverrides: {
              BookDetailKind.pencil: const BookDetailChoice(
                enabled: false,
                tone: 2,
                variant: 1,
              ),
            },
          ),
        ],
      );
      final store = MemoryStore()..data = library;
      final controller = LibraryController(store, library);
      addTearDown(controller.dispose);
      await open(tester, controller);
      await tester.ensureVisible(find.text('밑칠 켜기'));
      await tester.tap(find.text('밑칠 켜기'));
      await tester.pumpAndSettle();
      final wash = controller
          .styleFor(controller.library.books.first)
          .bookDetails
          .pencil;
      expect(wash.enabled, isTrue);
      expect(wash.tone, 2);
      expect(wash.variant, 1);
      expect(store.data.pages.single.toJson(), library.pages.single.toJson());
      expect(find.byKey(const ValueKey('tool-wash-density')), findsOneWidget);
    },
  );

  testWidgets(
    'Bookless wash settings remain usable on narrow screens with large text',
    (tester) async {
      final store = MemoryStore();
      final controller = LibraryController(store, const Library());
      addTearDown(controller.dispose);
      await open(tester, controller, bookId: null, tool: PaperTool.highlighter);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      final tone = find.byKey(const ValueKey('tool-wash-tone-1'));
      await tester.ensureVisible(tone);
      await tester.tap(tone);
      await tester.pumpAndSettle();
      expect(store.data.style.bookDetails.pencil.tone, 1);
      final erase = find.byKey(const ValueKey('choose-paper-tool-eraser'));
      await tester.ensureVisible(erase);
      await tester.tap(erase);
      await tester.pumpAndSettle();
      expect(find.text('밑칠한 곳을 문지르면 지워져요.'), findsOneWidget);
      expect(store.data.pages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
