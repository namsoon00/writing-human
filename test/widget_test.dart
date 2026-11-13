import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/transcription_guide.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/store.dart';

class MemoryStore implements LibraryStore {
  Library data = const Library();
  bool fail = false;
  int writes = 0;
  @override
  Future<Library> load() async => Library.decode(data.encode());
  @override
  Future<void> save(Library library) async {
    writes++;
    if (fail) {
      throw StateError('disk full');
    }
    data = Library.decode(library.encode());
  }

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
    'iOS touch places the caret inside a word and holds to select',
    (tester) async {
      const sentence = '햇빛이 책장에\n\n다음 줄';
      final store = MemoryStore()
        ..data = const Library(
          records: [WritingRecord(id: 'r', title: '필사')],
          pages: [
            WritingPage(id: 'p', recordId: 'r', number: 1, text: sentence),
          ],
          activePageId: 'p',
          writing: true,
        );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      final render = editor.renderEditable;
      final controller = tester.widget<TextField>(field).controller!;
      Offset pointAt(int offset) => render.localToGlobal(
        render.getLocalRectForCaret(TextPosition(offset: offset)).center,
      );
      final menu = find.byKey(const ValueKey('paper-selection-menu'));
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tapAt(pointAt(1));
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.extentOffset, 1);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.longPressAt(pointAt(1));
      await tester.pumpAndSettle();
      expect(controller.selection.textInside(sentence), '햇빛이');
      expect(menu, findsOneWidget);
      final drag = await tester.startGesture(pointAt(1));
      await tester.pump(kLongPressTimeout);
      await drag.moveTo(pointAt(5));
      await drag.up();
      await tester.pumpAndSettle();
      expect(controller.selection.textInside(sentence), '햇빛이 책장에');
      expect(menu, findsOneWidget);
      await tester.tapAt(pointAt(2));
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.extentOffset, 2);
      expect(menu, findsNothing);
      await tester.longPressAt(pointAt(sentence.indexOf('\n') + 1));
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.extentOffset, sentence.indexOf('\n') + 1);
      const composing = TextEditingValue(
        text: sentence,
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      await tester.tapAt(pointAt(5));
      await tester.longPressAt(pointAt(5));
      await tester.pumpAndSettle();
      expect(controller.value, composing);
      expect(menu, findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS touch opens and reopens input at the existing caret',
    (tester) async {
      await tester.pumpWidget(WritingHumanApp(store: MemoryStore()));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      final render = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final point = render.localToGlobal(
        render.getLocalRectForCaret(const TextPosition(offset: 0)).center,
      );
      final margin = tester.getTopLeft(field) + const Offset(-12, 100);
      await tester.tapAt(margin);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(field);
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(input.controller!.selection.extentOffset, 0);
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(input.controller!.selection.extentOffset, 0);
      final before = input.controller!.value;
      await tester.tapAt(margin);
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(input.controller!.value, before);
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Tapping below the writing or on the title hides input without moving the caret',
    (tester) async {
      final store = MemoryStore()
        ..data = const Library(
          records: [WritingRecord(id: 'r', title: '필사')],
          pages: [
            WritingPage(id: 'p', recordId: 'r', number: 1, text: '한 줄의 글'),
          ],
          activePageId: 'p',
          writing: true,
        );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      final render = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final caret = render.localToGlobal(
        render.getLocalRectForCaret(const TextPosition(offset: 1)).center,
      );
      final blank = caret + const Offset(0, 100);
      await tester.tapAt(caret);
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(field);
      final before = input.controller!.value;
      expect(tester.testTextInput.isVisible, isTrue);

      final composing = before.copyWith(
        composing: const TextRange(start: 0, end: 1),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      await tester.tapAt(blank);
      await tester.pumpAndSettle();
      expect(input.controller!.value, composing);
      expect(tester.testTextInput.isVisible, isTrue);

      tester.testTextInput.updateEditingValue(before);
      await tester.pumpAndSettle();
      await tester.tapAt(blank);
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(input.controller!.value, before);

      await tester.tapAt(caret);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byKey(const ValueKey('writing-title')));
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isFalse);
      expect(input.controller!.value, before);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('Paper and page number stay centered with uneven side insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 44, right: 12);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(WritingHumanApp(store: MemoryStore()));
    await tester.pumpAndSettle();
    final paper = find.byKey(const ValueKey('page-turn-live'));
    final body = find.byKey(const ValueKey('page-text'));
    final number = find.byKey(const ValueKey('page-number'));
    expect(tester.getCenter(paper).dx, 422);
    expect(tester.getCenter(body).dx, 422);
    expect(tester.getCenter(number).dx, 422);
    expect(tester.getRect(body).left, greaterThanOrEqualTo(44));
  });

  testWidgets('Paper menu follows the selection and opens a unique original', (
    tester,
  ) async {
    const original = '아침이다. 책장에 새 빛이 닿았다. 아침이다.';
    const prose = '다시 보는 책장에 메모\n\n아침이다';
    final store = MemoryStore()
      ..data = const Library(
        books: [
          Book(
            id: 'b',
            title: '책',
            originals: [RegisteredOriginal('o', original)],
          ),
        ],
        records: [WritingRecord(id: 'r', bookId: 'b', title: '필사')],
        pages: [WritingPage(id: 'p', recordId: 'r', number: 1, text: prose)],
        activePageId: 'p',
        writing: true,
      );
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messenger = tester.binding.defaultBinaryMessenger;
    String clipboard = '붙일 글';
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.hasStrings':
          return {'value': clipboard.isNotEmpty};
        case 'Clipboard.getData':
          return {'text': clipboard};
        case 'Clipboard.setData':
          clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('page-text'));
    final menu = find.byKey(const ValueKey('paper-selection-menu'));
    Finder action(String label) =>
        find.descendant(of: menu, matching: find.text(label));
    await tester.tap(editor);
    await tester.pumpAndSettle();
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    final controller = tester.widget<TextField>(editor).controller!;
    Future<void> showMenu(TextSelection selection) async {
      state.hideToolbar();
      tester.testTextInput.updateEditingValue(
        TextEditingValue(text: prose, selection: selection),
      );
      await tester.pumpAndSettle();
      expect(state.showToolbar(), isTrue);
      await tester.pumpAndSettle();
    }

    final editorRect = tester.getRect(editor);
    final repeated = prose.indexOf('아침이다');
    await showMenu(
      TextSelection(baseOffset: repeated, extentOffset: prose.length),
    );
    expect(action('느낀 점'), findsNothing);
    expect(action('복사'), findsOneWidget);
    expect(action('잘라내기'), findsOneWidget);
    expect(action('연필 표시'), findsOneWidget);
    await tester.tap(action('복사'));
    await tester.pumpAndSettle();
    expect(clipboard, '아침이다');

    await showMenu(TextSelection.collapsed(offset: prose.indexOf('\n') + 1));
    expect(action('붙여넣기'), findsOneWidget);
    expect(
      find.descendant(of: menu, matching: find.byType(TextButton)),
      findsOneWidget,
    );

    final unique = prose.indexOf('책장에');
    final selection = TextSelection(
      baseOffset: unique,
      extentOffset: unique + 3,
    );
    await showMenu(selection);
    expect(tester.getRect(editor), editorRect);
    expect(tester.getRect(menu).right, lessThanOrEqualTo(320));
    await tester.tap(action('느낀 점'));
    await tester.pumpAndSettle();
    final note = find.byKey(const ValueKey('notebook-reflection-input'));
    await tester.enterText(note, '이 대목을 다시 읽고 싶다.');
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopRight(editor) + const Offset(12, 130));
    await tester.pumpAndSettle();
    final saved = store.data.books.single.originals.single.reflection!;
    expect(saved.text, '이 대목을 다시 읽고 싶다.');
    expect(original.substring(saved.mark!.start, saved.mark!.end), '책장에');
    expect(controller.text, prose);
    expect(controller.selection, selection);
    expect(find.byTooltip('느낀 점 고치기'), findsOneWidget);
  });

  testWidgets(
    'Create book, compose Korean, reopen and restore text and selection',
    (tester) async {
      final store = MemoryStore();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('책장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('새 노트'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '오래 곁에 둘 문장들');
      await tester.tap(find.text('책 만들고 쓰기'));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('page-text'));
      await tester.tap(editor);
      await tester.pump();
      const composing = TextEditingValue(
        text: '한글을 쓰는 사ㄹ',
        selection: TextSelection.collapsed(offset: 9),
        composing: TextRange(start: 7, end: 9),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller!.value, composing);
      const committed = TextEditingValue(
        text: '한글을 쓰는 사람.\n천천히, 나의 속도로.',
        selection: TextSelection(baseOffset: 2, extentOffset: 6),
      );
      tester.testTextInput.updateEditingValue(committed);
      await tester.pumpAndSettle();
      expect(store.data.activePage!.text, committed.text);
      expect(store.data.activePage!.base, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final restored = tester.widget<TextField>(editor).controller!.value;
      expect(restored.text, committed.text);
      expect(restored.selection, committed.selection);
      expect(find.text('저장됨'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Save failure is visible; retry persists the latest draft', (
    tester,
  ) async {
    final store = MemoryStore();
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('page-text'));
    final controller = tester.widget<TextField>(editor).controller!;
    await tester.tap(editor);
    await tester.pumpAndSettle();
    store.fail = true;
    const value = TextEditingValue(
      text: '지워지면 안 되는 문ㅈ',
      selection: TextSelection.collapsed(offset: 12),
      composing: TextRange(start: 10, end: 12),
    );
    tester.testTextInput.updateEditingValue(value);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(editor).controller, same(controller));
    expect(controller.value, value);
    expect(find.text('저장 실패'), findsOneWidget);
    expect(find.text('저장됨'), findsNothing);
    store.fail = false;
    await tester.tap(find.text('저장 재시도'));
    await tester.pumpAndSettle();
    expect(store.data.activePage!.text, value.text);
    expect(find.text('저장됨'), findsOneWidget);
  });

  testWidgets(
    'Narrow screen restores long-page scroll and fits an open keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final store = MemoryStore();
      store.data = Library(
        books: const [Book(id: 'b', title: '긴 문장')],
        records: const [WritingRecord(id: 'r', bookId: 'b', title: '필사 1')],
        pages: [
          WritingPage(
            id: 'p',
            recordId: 'r',
            number: 1,
            text: List.filled(70, '천천히 적는 긴 한글 문장입니다.').join('\n'),
            scroll: 340,
            base: 10,
            extent: 10,
          ),
        ],
        activePageId: 'p',
        writing: true,
      );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('page-text'));
      expect(tester.widget<TextField>(editor).scrollController!.offset, 340);
      tester.widget<TextField>(editor).scrollController!.jumpTo(710);
      await tester.pumpAndSettle();
      expect(store.data.activePage!.scroll, 710);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).scrollController!.offset, 710);
      await tester.tap(editor);
      await tester.pumpAndSettle();
      final editorTop = tester.getTopLeft(editor);
      final title = find.byKey(const ValueKey('writing-title'));
      final titlePosition = tester.getTopLeft(title);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(editor), editorTop);
      expect(tester.getTopLeft(title), titlePosition);
      expect(tester.getRect(editor).bottom, lessThanOrEqualTo(524));
      expect(find.text('완료'), findsNothing);
      final focused = tester.widget<TextField>(editor);
      final selection = focused.controller!.selection;
      await tester.tapAt(editorTop + const Offset(-12, 100));
      await tester.pumpAndSettle();
      expect(focused.focusNode!.hasFocus, isFalse);
      expect(focused.controller!.selection, selection);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The paper controls must leave the same live editor usable with
      // enlarged system text and a narrow viewport, including a keyboard.
      final controller = tester.widget<TextField>(editor).controller!;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller, same(controller));
      expect(tester.getSize(editor).height, greaterThan(80));
      expect(tester.getRect(editor).bottom, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Writing tools change independently without replacing text or selection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore();
      store.data = const Library(
        records: [WritingRecord(id: 'r', title: '필사 1')],
        pages: [
          WritingPage(
            id: 'p',
            recordId: 'r',
            number: 1,
            text: '끝까지 남아야 하는 문장',
            base: 2,
            extent: 5,
          ),
        ],
        activePageId: 'p',
        writing: true,
      );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('page-text'));
      final controller = tester.widget<TextField>(editor).controller!;
      expect(find.text('Aa'), findsNothing);
      final writingTools = find.text('쓰기 취향');
      expect(writingTools, findsOneWidget);
      await tester.tap(writingTools);
      await tester.pumpAndSettle();
      expect(find.text('쓰는 인간체'), findsOneWidget);
      await tester.tap(find.text('나눔고딕'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('미색지'));
      await tester.pumpAndSettle();
      expect(store.data.style.paperIndex, 1);
      expect(store.data.style.fontIndex, 2);
      expect(store.data.style.penIndex, 0);
      await tester.ensureVisible(find.text('잉크 반응'));
      await tester.tap(find.widgetWithText(SwitchListTile, '잉크 반응'));
      await tester.pumpAndSettle();
      expect(store.data.style.penMotion, isFalse);
      final writingSound = find.widgetWithText(SwitchListTile, '글씨 쓰는 소리');
      await tester.ensureVisible(writingSound);
      expect(tester.widget<SwitchListTile>(writingSound).value, isFalse);
      await tester.tap(writingSound);
      await tester.pumpAndSettle();
      expect(store.data.style.writingSound, isTrue);
      expect(store.data.style.pageSound, isFalse);
      expect(store.data.style.penMotion, isFalse);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller, same(controller));
      expect(controller.text, '끝까지 남아야 하는 문장');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Open directly on paper; first Korean input persists without replacing the editor',
    (tester) async {
      final store = MemoryStore();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('page-text'));
      expect(editor, findsOneWidget);
      expect(store.writes, 0);
      final controller = tester.widget<TextField>(editor).controller!;
      await tester.tap(editor);
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      const composing = TextEditingValue(
        text: 'ㅎ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller, same(controller));
      expect(controller.value, composing);
      expect(store.data.books, isEmpty);
      expect(store.data.records.length, 1);
      expect(store.data.pages.single.text, 'ㅎ');
      await tester.enterText(editor, '한 문장 🌿');
      await tester.pumpAndSettle();
      final id = store.data.activePageId;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller!.text, '한 문장 🌿');
      expect(store.data.activePageId, id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'New paper stays ephemeral until input, and does not disturb a saved page',
    (tester) async {
      final store = MemoryStore();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('page-text'));
      await tester.enterText(editor, '먼저 남긴 글');
      await tester.pumpAndSettle();
      final firstId = store.data.activePageId;
      await tester.tap(find.byTooltip('새 종이'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller!.text, '');
      await tester.tap(find.byTooltip('새 종이'));
      await tester.pumpAndSettle();
      expect(store.data.records.length, 1);
      expect(store.data.activePageId, firstId);
      await tester.enterText(editor, '새 종이에 남긴 글');
      await tester.pumpAndSettle();
      expect(store.data.records.length, 2);
      expect(store.data.pages.first.text, '먼저 남긴 글');
      expect(store.data.activePage!.text, '새 종이에 남긴 글');
    },
  );

  testWidgets('Write first, then bind the same record into a new book', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = MemoryStore();
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('page-text'));
    await tester.enterText(editor, '쓰고 나서 책으로 묶는 문장');
    await tester.pumpAndSettle();
    final pageId = store.data.activePageId;
    final controller = tester.widget<TextField>(editor).controller!;
    final tools = find.widgetWithText(TextButton, '쓰기 취향');
    final source = find.byKey(const ValueKey('writing-originals'));
    final pageNumber = find.byKey(const ValueKey('page-number'));
    final more = find.byTooltip('더 보기');
    expect(
      tester.getRect(tools).right,
      lessThanOrEqualTo(tester.getRect(pageNumber).left),
    );
    expect(tester.getCenter(pageNumber).dx, 195);
    expect(
      tester.getRect(source).left,
      greaterThanOrEqualTo(tester.getRect(pageNumber).right),
    );
    expect(
      tester.getRect(source).right,
      lessThanOrEqualTo(tester.getRect(more).left),
    );
    expect(tester.getSize(source).height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip('더 보기'));
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.byType(BottomSheet));
    final lastItem = tester.getRect(find.widgetWithText(ListTile, '기기 동기화'));
    expect(menu.height, lessThan(tester.view.physicalSize.height / 2));
    expect(menu.bottom - lastItem.bottom, 18);
    await tester.tap(find.text('책으로 묶기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 책 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '나중에 지은 책 이름');
    await tester.tap(find.text('책 만들고 쓰기'));
    await tester.pumpAndSettle();
    expect(store.data.records.length, 1);
    expect(store.data.books.single.title, '나중에 지은 책 이름');
    expect(store.data.records.single.bookId, store.data.books.single.id);
    expect(store.data.activePageId, pageId);
    expect(tester.widget<TextField>(editor).controller, same(controller));
    expect(controller.text, '쓰고 나서 책으로 묶는 문장');
  });

  testWidgets('Saved book originals guide a reopened editor after input', (
    tester,
  ) async {
    const source = '먼저 골라 둔 원문\n\n다음에 골라 둔 원문';
    const written = '먼저 골라 둔 원문\n다음에 골라';
    final store = MemoryStore()
      ..data = const Library(
        books: [
          Book(
            id: 'b',
            title: '책',
            originals: [RegisteredOriginal('o', source)],
          ),
        ],
        records: [WritingRecord(id: 'r', bookId: 'b', title: '필사')],
        pages: [WritingPage(id: 'p', recordId: 'r', number: 1)],
        activePageId: 'p',
        writing: true,
      );
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('page-text'));
    await tester.enterText(editor, written);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(editor);
    final overlay = find.byKey(const ValueKey('transcription-guide'));
    final painter =
        tester.widget<CustomPaint>(overlay).painter!
            as TranscriptionGuidePainter;
    expect(field.controller!.text, written);
    expect(field.focusNode!.hasFocus, isFalse);
    expect(painter.remainderFor(field.controller!.value), ' 둔 원문');
    expect(store.data.books.single.originals.single.text, source);
    await tester.tap(find.byKey(const ValueKey('writing-originals')));
    await tester.pumpAndSettle();
    final original = find.byKey(const ValueKey('source-reading-text'));
    expect(tester.widget<Text>(original).textSpan!.toPlainText(), source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unreadable data shows recovery screen without saving', (
    tester,
  ) async {
    final store = UnreadableStore();
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('기록을 불러오지 못했습니다.'), findsOneWidget);
    expect(store.writes, 0);
  });
}

class UnreadableStore implements LibraryStore {
  int writes = 0;
  @override
  Future<Library> load() async => throw const FormatException('broken');
  @override
  Future<void> save(Library library) async {
    writes++;
  }

  @override
  Future<void> close() async {}
}
