import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/source/source_intake.dart';
import 'package:writing_human/ui/source_import_sheet.dart';
import 'package:writing_human/ui/transcription_guide.dart';

import 'widget_test.dart' show MemoryStore;

final sourceField = find.byKey(const ValueKey('source-text'));
final bodyField = find.byKey(const ValueKey('page-text'));
final confirm = find.byKey(const ValueKey('source-confirm'));
final place = find.byKey(const ValueKey('place-source'));

class FakeIntake extends SourceIntake {
  final events = StreamController<void>.broadcast();
  final shares = <IncomingSource>[];
  final acknowledged = <String>[];
  List<String> blocks = ['첫 문단입니다.', '둘째 문단입나다.'];
  Completer<List<String>>? reading;
  int photos = 0, cancellations = 0;
  bool cancelPicker = false;
  SourcePhoto? recovered;
  final SourcePhoto photo;

  FakeIntake({SourcePhoto? photo})
    : photo =
          photo ??
          SourcePhoto(
            'synthetic.png',
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGP4DwABAQEAsTj2FAAAAABJRU5ErkJggg==',
            ),
          );

  @override
  bool get canUseCamera => true;
  @override
  Future<SourcePhoto?> pickPhoto({required bool camera}) async {
    photos++;
    return cancelPicker ? null : photo;
  }

  @override
  Future<SourcePhoto?> recoverPhoto() async => recovered;
  @override
  Future<List<String>> recognize(SourcePhoto photo) async =>
      reading == null ? blocks : await reading!.future;
  @override
  void cancelRecognition() => cancellations++;
  @override
  Stream<void> get incomingChanges => events.stream;
  @override
  Future<List<IncomingSource>> pendingShares() async => [...shares];
  @override
  Future<void> acknowledgeShare(String id) async {
    acknowledged.add(id);
    shares.removeWhere((item) => item.id == id);
  }

  void deliver(IncomingSource share) {
    shares.add(share);
    events.add(null);
  }

  @override
  void dispose() {
    events.close();
  }
}

Library existing() => Library(
  records: const [WritingRecord(id: 'r', title: '기존 필사')],
  pages: const [
    WritingPage(
      id: 'p',
      recordId: 'r',
      number: 1,
      text: '기존에 적은 문장',
      base: 2,
      extent: 5,
    ),
  ],
  activePageId: 'p',
  writing: true,
);

Future<void> open(
  WidgetTester tester,
  MemoryStore store,
  FakeIntake intake,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(intake.dispose);
  await tester.pumpWidget(WritingHumanApp(store: store, sourceIntake: intake));
  await tester.pumpAndSettle();
}

Future<void> takePhoto(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.byKey(const ValueKey('source-photo')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('사진 찍기'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('Trace a passage with real input and turn it by choice', (
    tester,
  ) async {
    const source = '새로운 문장을 읽습니다.\n\n내 글로 남깁니다.';
    final store = MemoryStore();
    await open(tester, store, FakeIntake());
    await tester.tap(place);
    await tester.pumpAndSettle();
    await tester.enterText(sourceField, source);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(bodyField);
    final overlay = find.byKey(const ValueKey('transcription-guide'));
    final toggle = find.byKey(const ValueKey('toggle-transcription-guide'));
    String remaining() =>
        (tester.widget<CustomPaint>(overlay).painter!
                as TranscriptionGuidePainter)
            .guide
            .remaining(field.controller!.value);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(remaining(), '새로운 문장을 읽습니다.');
    expect(store.data.activePage!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);

    const composing = TextEditingValue(
      text: '새ㄹ',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 1, end: 2),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    expect(field.controller!.value, composing);
    expect(remaining(), '운 문장을 읽습니다.');

    await tester.enterText(bodyField, '새로운 문장');
    await tester.pumpAndSettle();
    expect(remaining(), '을 읽습니다.');
    await tester.enterText(bodyField, '새로운 문장을\n내 방식으로');
    await tester.pumpAndSettle();
    expect(remaining(), isEmpty);
    final body = field.controller!.value;
    expect(store.data.activePage!.text, body.text);

    await tester.tap(find.byTooltip('다음 문단'));
    await tester.pumpAndSettle();
    expect(remaining(), '내 글로 남깁니다.');
    expect(field.controller!.value, body);
    await tester.enterText(bodyField, '${body.text}\n내 글');
    await tester.pumpAndSettle();
    expect(remaining(), '로 남깁니다.');
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(overlay, findsNothing);
    expect(find.text('내 글로 남깁니다.'), findsOneWidget);
    expect(
      tester.widget<TextField>(bodyField).controller,
      same(field.controller),
    );
    expect(store.data.activePage!.text, '${body.text}\n내 글');
    expect(store.data.records.single.source, source);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(remaining(), '로 남깁니다.');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Clipboard is read only on Paste; confirm saves a separate original',
    (tester) async {
      final store = MemoryStore()..data = existing();
      final intake = FakeIntake();
      var reads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method != 'Clipboard.getData') return null;
          reads++;
          return {'text': ' 첫 줄\r\n\r\n둘째 줄 '};
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester, store, intake);
      final body = tester.widget<TextField>(bodyField).controller!;
      final original = body.value;
      await tester.tap(place);
      await tester.pumpAndSettle();
      expect(reads, 0);
      await tester.tap(find.byKey(const ValueKey('source-paste')));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '첫 줄\n\n둘째 줄',
      );
      expect(store.data.records.single.source, isEmpty);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(store.data.records.single.source, '첫 줄\n\n둘째 줄');
      expect(tester.widget<TextField>(bodyField).controller, same(body));
      expect(body.value, original);
      expect(store.data.activePageId, 'p');
      expect(find.text('첫 줄'), findsOneWidget);
      expect(find.text('둘째 줄'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Choose photo paragraphs, correct a character, then save only reviewed text',
    (tester) async {
      final store = MemoryStore();
      final intake = FakeIntake();
      await open(tester, store, intake);
      final body = tester.widget<TextField>(bodyField).controller!;
      await tester.tap(place);
      await tester.pumpAndSettle();
      await takePhoto(tester);
      expect(intake.photos, 1);
      expect(find.text('문단 고르기'), findsOneWidget);
      expect(store.data.records, isEmpty);
      await tester.tap(find.byKey(const ValueKey('source-paragraph-0')));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '둘째 문단입나다.',
      );
      await tester.enterText(sourceField, '둘째 문단입니다.');
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(store.data.records.single.source, '둘째 문단입니다.');
      expect(store.data.activePage!.text, isEmpty);
      expect(tester.widget<TextField>(bodyField).controller, same(body));
      expect(tester.widget<TextField>(bodyField).focusNode!.hasFocus, isFalse);
      expect(find.text('둘째 문단입니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Turn source paragraphs without changing the writing field', (
    tester,
  ) async {
    final first = List.filled(12, '한 줄씩 읽고 종이에 옮깁니다.').join('\n');
    const second = '두 번째 문단은 내 글 아래에 이어서 씁니다.';
    final source = '$first\n \n$second';
    final store = MemoryStore()
      ..data = existing().copy(
        records: [WritingRecord(id: 'r', title: '기존 필사', source: source)],
      );
    await open(tester, store, FakeIntake());
    final paragraph = find.byKey(const ValueKey('source-reading-paragraph'));
    final next = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == '다음 문단',
    );
    final previous = find.byTooltip('이전 문단');
    expect(tester.widget<Text>(paragraph).data, first);
    final field = tester.widget<TextField>(bodyField);
    await tester.showKeyboard(bodyField);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();

    const composing = TextEditingValue(
      text: '한글 조하',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 3, end: 5),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    expect(field.controller!.value, composing);

    final committed = composing.copyWith(
      text: '한글 조합',
      composing: TextRange.empty,
    );
    tester.testTextInput.updateEditingValue(committed);
    await tester.pumpAndSettle();
    final scrollView = find.ancestor(
      of: paragraph,
      matching: find.byType(SingleChildScrollView),
    );
    final scrollable = find.descendant(
      of: scrollView,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    final writes = store.writes;
    final writingArea = tester.getRect(bodyField);
    await tester.tap(next, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(paragraph).data, second);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    expect(
      tester.widget<TextField>(bodyField).controller,
      same(field.controller),
    );
    expect(field.controller!.value, committed);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.getRect(bodyField), writingArea);
    expect(store.writes, writes);
    expect(store.data.records.single.source, source);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(paragraph).data, first);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Photo cancel, empty result and closing active OCR leave the source alone',
    (tester) async {
      final store = MemoryStore();
      final intake = FakeIntake()..cancelPicker = true;
      await open(tester, store, intake);
      await tester.tap(place);
      await tester.pumpAndSettle();
      await tester.enterText(sourceField, '직접 입력한 원문');
      await takePhoto(tester);
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '직접 입력한 원문',
      );
      intake.cancelPicker = false;
      intake.blocks = [];
      await takePhoto(tester);
      expect(find.textContaining('읽을 수 있는 글자가 없어요'), findsOneWidget);
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '직접 입력한 원문',
      );
      intake.reading = Completer<List<String>>();
      await takePhoto(tester, settle: false);
      expect(find.text('사진 속 글자를 읽고 있어요'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(intake.cancellations, 1);
      intake.reading!.complete(['늦게 온 결과']);
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      expect(find.byType(SourceImportSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Shared text waits through composing and starts a separate record after review',
    (tester) async {
      final store = MemoryStore()..data = existing();
      final intake = FakeIntake();
      await open(tester, store, intake);
      await tester.tap(bodyField);
      await tester.pumpAndSettle();
      const composing = TextEditingValue(
        text: '한글을 조합 중인 하ㄴ',
        selection: TextSelection.collapsed(offset: 12),
        composing: TextRange(start: 10, end: 12),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      final original = tester.widget<TextField>(bodyField).controller!;
      intake.deliver(const IncomingSource('test-delivery', '공유한 문장입니다.'));
      await tester.pumpAndSettle();
      expect(find.byType(SourceImportSheet), findsNothing);
      expect(find.text('공유한 원문 확인'), findsOneWidget);
      expect(original.value, composing);
      expect(intake.acknowledged, isEmpty);
      tester.testTextInput.updateEditingValue(
        composing.copyWith(composing: TextRange.empty),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('공유한 원문 확인'));
      await tester.pumpAndSettle();
      expect(store.data.records, hasLength(1));
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '공유한 문장입니다.',
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(store.data.records, hasLength(2));
      expect(store.data.records.last.source, '공유한 문장입니다.');
      expect(store.data.activePage!.text, isEmpty);
      expect(store.data.pages.first.text, composing.text);
      expect(intake.acknowledged, ['test-delivery']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Shared delivery survives save failure, and retry acknowledges it exactly once',
    (tester) async {
      final store = MemoryStore()..data = existing();
      final intake = FakeIntake()
        ..shares.add(const IncomingSource('retry-id', '다시 저장할 원문'));
      await open(tester, store, intake);
      expect(find.text('공유한 원문'), findsOneWidget);
      store.fail = true;
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('저장 재시도'), findsOneWidget);
      expect(store.data.records, hasLength(1));
      expect(intake.shares, hasLength(1));
      expect(intake.acknowledged, isEmpty);
      store.fail = false;
      await tester.tap(find.text('저장 재시도'));
      await tester.pumpAndSettle();
      expect(store.data.records, hasLength(2));
      expect(intake.acknowledged, ['retry-id']);
      intake.deliver(const IncomingSource('retry-id', '다시 저장할 원문'));
      await tester.pumpAndSettle();
      expect(find.byType(SourceImportSheet), findsNothing);
      expect(store.data.records, hasLength(2));
      expect(intake.shares, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Source composition is preserved until it is committed on a compact keyboard layout',
    (tester) async {
      final store = MemoryStore();
      await open(tester, store, FakeIntake());
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      await tester.tap(place);
      await tester.pumpAndSettle();
      await tester.tap(sourceField);
      tester.view.viewInsets = const FakeViewPadding(bottom: 270);
      const composing = TextEditingValue(
        text: '하ㄴ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(
        tester.widget<TextField>(sourceField).controller!.value,
        composing,
      );
      expect(store.writes, 0);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '한',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(store.data.records.single.source, '한');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Recovered Android picker photo enters review without saving', (
    tester,
  ) async {
    final store = MemoryStore();
    final intake = FakeIntake();
    intake.recovered = intake.photo;
    await open(tester, store, intake);
    expect(find.text('문단 고르기'), findsOneWidget);
    expect(intake.photos, 0);
    expect(store.writes, 0);
  });
}
