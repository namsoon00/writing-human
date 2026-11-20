import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:writing_human/data/library_backup.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/original_photo_store.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/source/source_intake.dart';
import 'package:writing_human/source/source_scan.dart';
import 'package:writing_human/source/originals.dart';
import 'package:writing_human/source/transcription_comparison.dart';
import 'package:writing_human/ui/collection_sheet.dart';
import 'package:writing_human/ui/book_details.dart';
import 'package:writing_human/ui/book_detail_design.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/paper_panel.dart';
import 'package:writing_human/ui/reading_details.dart';
import 'package:writing_human/ui/source_import_sheet.dart';
import 'package:writing_human/ui/source_reading.dart';
import 'package:writing_human/ui/transcription_marks.dart';
import 'package:writing_human/ui/transcription_guide.dart';

import 'widget_test.dart' show MemoryStore;

final sourceField = find.byKey(const ValueKey('source-text'));
final bodyField = find.byKey(const ValueKey('page-text'));
final confirm = find.byKey(const ValueKey('source-confirm'));
final place = find.byKey(const ValueKey('writing-originals'));
final reading = find.byType(SourceReading);
final readingText = find.byKey(const ValueKey('source-reading-text'));
final transcriptionReference = find.byKey(
  const ValueKey('transcription-reference'),
);

TextSpan referenceText(WidgetTester tester) =>
    tester
            .widget<RichText>(
              find.descendant(
                of: transcriptionReference,
                matching: find.byType(RichText),
              ),
            )
            .text
        as TextSpan;

String remainingReference(WidgetTester tester) =>
    referenceText(tester).children!.last.toPlainText();

Finder closeIn(Finder parent) =>
    find.descendant(of: parent, matching: find.byTooltip('닫기'));

Future<void> settleSourceSheets(WidgetTester tester) async {
  // App callbacks can open or dismiss another route after its first animation.
  // Advance both transitions before interacting with the underlying paper.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> openRegistration(WidgetTester tester) async {
  await tester.tap(place);
  await tester.pumpAndSettle();
  expect(find.byType(SourceImportSheet), findsOneWidget);
  expect(reading, findsNothing);
}

class FakeIntake extends SourceIntake {
  final events = StreamController<void>.broadcast();
  final shares = <IncomingSource>[];
  final acknowledged = <String>[];
  List<String> blocks = ['첫 문단입니다.', '둘째 문단입나다.'];
  Completer<List<String>>? reading;
  int photos = 0, cancellations = 0, scans = 0;
  bool cancelPicker = false;
  SourcePhoto? recovered;
  SourceScan? positioned;
  Rect? recognizedRegion;
  List<Rect> recognizedMask = const [];
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
  Future<SourcePhoto> readSharedPhoto(String id) async => photo;

  @override
  Future<SourcePhoto?> recoverPhoto() async => recovered;
  @override
  Future<SourceScan> scan(
    SourcePhoto photo, {
    Rect? region,
    List<Rect> mask = const [],
  }) async {
    scans++;
    recognizedRegion = region;
    recognizedMask = mask;
    if (region == null && positioned != null) return positioned!;
    return SourceScan.fromText(
      photo.bytes,
      reading == null ? blocks : await reading!.future,
    );
  }

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

Future<void> preparePhotoStorage(WidgetTester tester) async {
  final dir = await tester.runAsync(
    () => Directory.systemTemp.createTemp('writing-original-'),
  );
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (_) async => dir!.path,
  );
  addTearDown(() async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    await dir!.delete(recursive: true);
  });
}

Future<void> saveWithPhoto(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(confirm);
    await tester.pump();
    for (
      var i = 0;
      i < 50 && find.byType(SourceImportSheet).evaluate().isNotEmpty;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 30));
    }
  });
  await tester.pumpAndSettle();
}

Future<void> takePhoto(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.byKey(const ValueKey('source-photo-menu')));
  await tester.pumpAndSettle();
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
  testWidgets('A compensated reread can return to the first result', (
    tester,
  ) async {
    final intake = FakeIntake()..blocks = ['처음 읽은 문장'];
    await open(tester, MemoryStore(), intake);
    await openRegistration(tester);
    await takePhoto(tester);
    expect(find.text('처음 읽은 문장'), findsOneWidget);

    intake.blocks = ['보정 후 다시 읽은 문장'];
    await tester.runAsync(() async {
      await tester.tap(find.text('보정해 다시 읽기'));
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (find.text('보정 전 결과 보기').evaluate().isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('보정 후 다시 읽은 문장'), findsOneWidget);
    await tester.tap(find.text('보정 전 결과 보기'));
    await tester.pumpAndSettle();
    expect(find.text('처음 읽은 문장'), findsOneWidget);
    expect(find.text('보정 후 다시 읽은 문장'), findsNothing);
  });

  testWidgets('원문 정리는 저장 전 되돌릴 수 있고 저장한 글을 필사에 쓴다', (tester) async {
    final store = MemoryStore();
    await open(tester, store, FakeIntake());
    await openRegistration(tester);
    const original = '“봄”…\n별★바람';
    const cleaned = '"봄"...\n별 바람';
    await tester.enterText(sourceField, original);
    await tester.pumpAndSettle();
    final clean = find.text('특수문자 정리');
    await tester.ensureVisible(clean);
    await tester.tap(clean);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(sourceField).controller!.text, cleaned);
    expect(store.data.records, isEmpty);
    await tester.tap(find.text('정리 되돌리기'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(sourceField).controller!.text, original);
    await tester.tap(clean);
    await tester.pumpAndSettle();
    final transcribe = find.byKey(
      const ValueKey('source-transcribe-after-save'),
    );
    await tester.ensureVisible(transcribe);
    await tester.tap(transcribe);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await settleSourceSheets(tester);
    expect(store.data.records.single.originals.single.text, cleaned);
    expect(store.data.activePage!.text, isEmpty);
    expect(remainingReference(tester), cleaned);
  });

  testWidgets('Original editing keeps the draft through IME and save retry', (
    tester,
  ) async {
    final store = MemoryStore()
      ..data = existing().copy(
        records: const [
          WritingRecord(
            id: 'r',
            title: '기존 필사',
            originals: [
              RegisteredOriginal('source', '고치기 전 원문', citation: '초판'),
            ],
          ),
        ],
      );
    final writing = store.data.activePage!.toJson();
    await open(tester, store, FakeIntake());
    await tester.tap(place);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('source')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('원문 더 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('원문 수정'));
    await tester.pumpAndSettle();
    final text = find.byKey(const ValueKey('edit-original-text'));
    final citation = find.byKey(const ValueKey('edit-original-citation'));
    final button = find.widgetWithText(FilledButton, '저장');
    expect(tester.widget<TextField>(text).controller!.text, '고치기 전 원문');
    expect(tester.widget<TextField>(citation).controller!.text, '초판');

    await tester.ensureVisible(citation);
    await tester.enterText(citation, '개정판');
    await tester.enterText(text, '고친 글');
    const composing = TextEditingValue(
      text: '고친 글',
      composing: TextRange(start: 3, end: 4),
      selection: TextSelection.collapsed(offset: 4),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(tester.widget<TextField>(text).controller!.value, composing);
    tester.testTextInput.updateEditingValue(
      composing.copyWith(composing: TextRange.empty),
    );
    await tester.pumpAndSettle();

    await tester.enterText(text, '“고친 글”…');
    await tester.pumpAndSettle();
    final cleanup = find.text('특수문자 정리');
    await tester.ensureVisible(cleanup);
    await tester.tap(cleanup);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(text).controller!.text, '"고친 글"...');
    expect(store.data.records.single.originals.single.text, '고치기 전 원문');

    store.fail = true;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('수정 내용을 저장하지 못했어요. 입력한 내용은 남아 있어요.'), findsOneWidget);
    expect(tester.widget<TextField>(text).controller!.text, '"고친 글"...');
    expect(store.data.records.single.originals.single.text, '고치기 전 원문');
    store.fail = false;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(text, findsNothing);
    expect(store.data.records.single.originals.single.text, '"고친 글"...');
    expect(store.data.records.single.originals.single.citation, '개정판');
    expect(store.data.records.single.originals.single.id, 'source');
    expect(store.data.activePage!.toJson(), writing);
  });

  testWidgets(
    'Original deletion retains a prior citation and leaves writing intact',
    (tester) async {
      const original = RegisteredOriginal(
        'remove',
        '지울 원문',
        citation: '이전에 읽은 책',
        reflection: OriginalReflection('함께 지울 느낀 점'),
      );
      final store = MemoryStore()
        ..data = existing().copy(
          pages: [
            existing().pages.first.withDetails(guidedOriginalId: 'remove'),
          ],
          records: const [
            WritingRecord(
              id: 'r',
              title: '기존 필사',
              originals: [original, RegisteredOriginal('keep', '남겨 둘 원문')],
            ),
          ],
        );
      final writing = store.data.activePage!.text;
      await open(tester, store, FakeIntake());
      await tester.tap(place);
      await tester.pumpAndSettle();

      Future<void> askToDelete() async {
        await tester.tap(find.byTooltip('원문 더 보기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('원문 삭제'));
        await tester.pumpAndSettle();
        expect(find.text('원문을 삭제할까요?'), findsOneWidget);
      }

      await askToDelete();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(store.data.records.single.originals.length, 2);

      store.fail = true;
      await askToDelete();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(find.text('원문을 삭제하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(
        store.data.records.single.originals.first.reflection!.text,
        '함께 지울 느낀 점',
      );

      store.fail = false;
      await askToDelete();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(find.text('남겨 둘 원문'), findsOneWidget);
      expect(find.text('지울 원문'), findsNothing);
      expect(store.data.records.single.originals.single.id, 'keep');
      expect(store.data.activePage!.text, writing);
      expect(store.data.activePage!.guidedOriginalId, isNull);
      expect(store.data.activePage!.originalCitations, ['이전에 읽은 책']);
    },
  );

  testWidgets('The original list searches saved text and citations locally', (
    tester,
  ) async {
    final store = MemoryStore()
      ..data = existing().copy(
        records: const [
          WritingRecord(
            id: 'r',
            title: '기존 필사',
            originals: [
              RegisteredOriginal('older', '등록 시각이 없는 예전 원문'),
              RegisteredOriginal(
                'spring',
                '봄날을 기다려요.\n잔디 사이에 꽃이 피었어요.',
                citation: '봄날의 편지 · 기록자',
                registeredAt: 300,
              ),
              RegisteredOriginal(
                'winter',
                '눈 내리는 저녁',
                citation: '겨울 일기',
                registeredAt: 100,
              ),
            ],
          ),
        ],
      );
    await open(tester, store, FakeIntake());
    final writes = store.writes;
    await tester.tap(place);
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextButton, '원문 검색');
    final register = find.widgetWithText(TextButton, '원문 등록');
    expect(
      tester.getTopLeft(search).dy,
      greaterThan(tester.getBottomLeft(register).dy),
    );
    final filter = find.widgetWithText(FilterChip, '밑칠만 보기');
    expect(
      tester.getCenter(filter).dy,
      closeTo(tester.getCenter(search).dy, 1),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('spring'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('winter'))).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('winter'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('older'))).dy),
    );
    await tester.tap(search);
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('saved-original-search'));
    final candidates = find.byKey(const ValueKey('search-completions'));
    final candidate = find.descendant(
      of: candidates,
      matching: find.text('봄날의'),
    );
    await tester.enterText(input, '봄날');
    await tester.pumpAndSettle();
    final editable = find.descendant(
      of: input,
      matching: find.byType(EditableText),
    );
    final bounds = tester.getRect(editable);
    final controller = tester.widget<TextField>(input).controller!;
    expect(
      tester.widget<TextField>(input).decoration!.focusedBorder,
      isA<UnderlineInputBorder>(),
    );
    await tester.tapAt(Offset(bounds.left + 1, bounds.center.dy));
    await tester.pumpAndSettle();
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, 0);
    await tester.tapAt(Offset(bounds.right - 12, bounds.center.dy));
    await tester.pumpAndSettle();
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, 2);
    expect(candidate, findsOneWidget);
    expect(
      find.descendant(of: candidates, matching: find.text('봄날의 편지')),
      findsNothing,
    );
    expect(find.text('눈 내리는 저녁'), findsNothing);
    expect(find.byType(SourceImportSheet), findsNothing);
    await tester.tap(candidate);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(input);
    expect(field.controller!.text, '봄날의');
    expect(field.focusNode!.hasFocus, isFalse);
    await tester.tap(find.byKey(const ValueKey('spring')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('원문 목록'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '검색 닫기'), findsNothing);
    await tester.tap(find.byTooltip('원문 목록'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, '봄날의');

    await tester.enterText(input, '잔디 ');
    await tester.pumpAndSettle();
    expect(candidates, findsNothing);
    await tester.enterText(input, '잔디 사x 꽃이');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '잔디 사x 꽃이',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pumpAndSettle();
    final middleWord = find.descendant(
      of: candidates,
      matching: find.text('사이에'),
    );
    expect(middleWord, findsOneWidget);
    await tester.tap(middleWord);
    await tester.pumpAndSettle();
    expect(controller.text, '잔디 사이에 꽃이');
    expect(find.byKey(const ValueKey('winter')), findsNothing);
    expect(find.text('봄날의 편지 · 기록자'), findsOneWidget);
    await tester.enterText(input, '없는 원문');
    await tester.pumpAndSettle();
    expect(find.text('일치하는 원문이 없어요.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '검색 닫기'));
    await tester.pumpAndSettle();
    expect(find.text('눈 내리는 저녁'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(search.hitTestable(), findsOneWidget);
    expect(register.hitTestable(), findsOneWidget);
    expect(find.text('밑칠만 보기').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(store.writes, writes);
  });

  testWidgets('Web completions wait for IME commit and ignore stale requests', (
    tester,
  ) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final params = request.url.queryParameters;
      if (params['srsearch'] == 'intitle:바람*') {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final (key, rows) = switch (params) {
        {'pssearch': '윤동'} => (
          'prefixsearch',
          [
            {'title': '저자:윤동렬', 'pageid': 1},
          ],
        ),
        {'srsearch': 'intitle:바람*'} => (
          'search',
          [
            {'title': '바람결', 'pageid': 1},
          ],
        ),
        {'srsearch': '"하늘을" 우러*'} => (
          'search',
          [
            {'snippet': '앞 글 <span>하늘을</span> 우러러 한 점 부끄럼'},
          ],
        ),
        _ => ('search', <Map<String, Object>>[]),
      };
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'query': {key: rows},
          }),
        ),
        200,
      );
    });
    await http.runWithClient(() async {
      await open(tester, MemoryStore(), FakeIntake());
      await openRegistration(tester);
      await tester.tap(find.text('시·문장 검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '웹 검색'));
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextField, '검색어');
      await tester.showKeyboard(input);
      const composing = TextEditingValue(
        text: '바람',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests, isEmpty);
      final controller = tester.widget<TextField>(input).controller!;
      expect(controller.value, composing);
      tester.testTextInput.updateEditingValue(
        composing.copyWith(composing: TextRange.empty),
      );
      await tester.pump(const Duration(milliseconds: 360));
      expect(requests.single.queryParameters['srsearch'], 'intitle:바람*');

      await tester.tap(find.text('작가 이름'));
      await tester.enterText(input, '윤동');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();
      final suggestions = find.byKey(const ValueKey('search-completions'));
      Finder option(String title) =>
          find.descendant(of: suggestions, matching: find.text(title));
      expect(requests.last.queryParameters['psnamespace'], '100');
      expect(option('윤동렬'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 550));
      expect(option('바람결'), findsNothing);
      expect(option('윤동렬'), findsOneWidget);

      await tester.tap(find.text('기억나는 구절'));
      await tester.enterText(input, '하늘을 우러');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();
      final phrase = option('우러러');
      expect(phrase, findsOneWidget);
      await tester.tap(phrase);
      await tester.pumpAndSettle();
      expect(controller.text, '하늘을 우러러');
      expect(requests.last.queryParameters['srsearch'], '"하늘을 우러러"');
    }, () => client);
  });

  testWidgets('Search imports a source citation and keeps the original draft', (
    tester,
  ) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final work = request.url.host == 'ko.wikisource.org';
      final params = request.url.queryParameters;
      final author = params['list'] == 'prefixsearch';
      final spacing = params['srsearch'] == 'intitle:별헤는밤';

      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'query': {
              if (author)
                'prefixsearch': [
                  {'title': '저자:윤동주', 'pageid': 515},
                ]
              else if (spacing)
                'search': [
                  {'title': '시집/별 헤는 밤의 추억', 'pageid': 122},
                  {'title': '별 헤는 밤/다른 작품', 'pageid': 123},
                  {'title': '시집/별 헤는 밤', 'pageid': 124},
                ]
              else
                'search': [
                  if (work) {'title': '바람', 'pageid': 1516},
                  if (work) {'title': '바다와 나비', 'pageid': 123},
                  if (work) {'title': '두시언해/서시흥', 'pageid': 124},
                ],
            },
          }),
        ),
        200,
      );
    });
    await http.runWithClient(() async {
      final store = MemoryStore();
      await open(tester, store, FakeIntake());
      await openRegistration(tester);
      await tester.enterText(sourceField, '직접 고른 구절');
      final search = find.text('시·문장 검색');
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '웹 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '검색어'), '바람');
      expect(requests, isEmpty);
      final input = find.widgetWithText(TextField, '검색어');
      final submit = find.byTooltip('자료 검색');
      await tester.enterText(input, '별헤는밤');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final exact = find.widgetWithText(ListTile, '시집/별 헤는 밤');
      final prefix = find.widgetWithText(ListTile, '시집/별 헤는 밤의 추억');
      expect(
        tester.getTopLeft(exact).dy,
        lessThan(tester.getTopLeft(prefix).dy),
      );
      expect(find.text('별 헤는 밤/다른 작품'), findsNothing);
      final naver = find.text('네이버에서 더 찾기');
      await tester.scrollUntilVisible(
        naver,
        140,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('paper-panel-page')),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(naver, findsOneWidget);

      await tester.tap(find.text('작가 이름'));
      await tester.pumpAndSettle();
      await tester.enterText(input, '윤동주');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['psnamespace'], '100');
      expect(find.text('저자:윤동주'), findsOneWidget);

      await tester.tap(find.text('작품 제목'));
      await tester.pumpAndSettle();
      await tester.enterText(input, '바람');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(requests.last.host, 'ko.wikisource.org');
      expect(requests.last.queryParameters['srsearch'], 'intitle:바람');
      final result = find.widgetWithText(ListTile, '바람');
      expect(result, findsOneWidget);
      expect(find.text('웹 원문 · 복사 필요'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '바로 담기'));
      await tester.pumpAndSettle();
      expect(find.text('바로 담을 수 있는 시'), findsOneWidget);
      expect(result, findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '웹 검색'));
      await tester.pumpAndSettle();
      expect(result, findsOneWidget);
      expect(find.text('바다와 나비'), findsNothing);
      expect(find.text('두시언해/서시흥'), findsNothing);
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(
        find.text('원문에서 구절을 복사한 뒤 ‘복사한 구절과 출처 담기’를 누르세요.'),
        findsOneWidget,
      );
      await tester.tap(find.text('출처만 넣기'));
      await tester.pumpAndSettle();
      final citation = tester.widget<TextField>(
        find.byKey(const ValueKey('original-citation')),
      );
      expect(citation.controller!.text, contains('curid=1516'));
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '직접 고른 구절',
      );
      expect(store.data.records, isEmpty);
      await tester.tap(search);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '웹 검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기억나는 구절'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '검색어'), '하늘을 우러러');
      await tester.tap(find.byTooltip('자료 검색'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['srsearch'], '"하늘을 우러러"');
      await tester.tap(result);
      await tester.pumpAndSettle();
      String? clipboard;
      int clipboardReads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method != 'Clipboard.getData') return null;
          clipboardReads++;
          return clipboard == null ? null : {'text': clipboard};
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.text('원문 열기'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('원문 브라우저 닫기'), findsOneWidget);
      expect(clipboardReads, 0);
      final collect = find.text('복사한 구절과 출처 담기');
      await tester.tap(collect);
      await tester.pumpAndSettle();
      expect(find.text('복사한 구절이 없어요.'), findsOneWidget);
      clipboard = '복사한 구절';
      await tester.tap(collect);
      await tester.pumpAndSettle();
      expect(clipboardReads, 2);
      expect(find.text('입력한 원문을 바꿀까요?'), findsOneWidget);
      await tester.tap(find.text('바꾸기'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(sourceField).controller!.text, '복사한 구절');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        store.data.records.single.originals.single.citation,
        contains('위키문헌'),
      );
    }, () => client);
  });

  testWidgets(
    'Reviewed poem imports only selected stanzas and keeps line breaks',
    (tester) async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        final params = request.url.queryParameters;
        final data = params['action'] == 'parse'
            ? {
                'parse': {
                  'pageid': 1515,
                  'revid': 387685,
                  'text':
                      '<p>머리말</p><div class="poem"><p>첫 연<br>둘째 줄<br><br>'
                      '고르지 않은 연<br>&nbsp;<br>마지막 연<br>다음 줄</p></div>',
                  'categories': [
                    {'category': 'PD-old-70'},
                  ],
                },
              }
            : {
                'query': {
                  'search': [
                    {'title': '서시', 'pageid': 1515},
                  ],
                },
              };
        return http.Response.bytes(utf8.encode(jsonEncode(data)), 200);
      });
      await http.runWithClient(() async {
        final store = MemoryStore();
        await open(tester, store, FakeIntake());
        await openRegistration(tester);
        await tester.tap(find.text('시·문장 검색'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, '웹 검색'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, '검색어'), '서시');
        await tester.tap(find.byTooltip('자료 검색'));
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        await tester.tap(find.widgetWithText(ListTile, '서시'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['oldid'], '387685');
        expect(find.text('머리말'), findsNothing);
        expect(find.text('전체 담기'), findsOneWidget);
        final import = find.widgetWithText(FilledButton, '선택한 구절 담기');
        expect(tester.widget<FilledButton>(import).onPressed, isNull);
        await tester.tap(find.widgetWithText(CheckboxListTile, '마지막 연\n다음 줄'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, '첫 연\n둘째 줄'));
        await tester.pumpAndSettle();
        await tester.tap(import);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(sourceField).controller!.text,
          '첫 연\n둘째 줄\n\n마지막 연\n다음 줄',
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('original-citation')),
              )
              .controller!
              .text,
          '서시 · 윤동주 · 위키문헌 · https://ko.wikisource.org/w/index.php?oldid=387685',
        );
        expect(store.data.records, isEmpty);
      }, () => client);
    },
  );

  testWidgets('The collection opens a reviewed edition without a search', (
    tester,
  ) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'parse': {
              'pageid': 1522,
              'revid': 430577,
              'categories': [
                {'category': 'PD-old-70'},
              ],
              'text':
                  '<div class="poem"><p><big>산유화</big><br>첫 줄<br>둘째 줄</p></div>'
                  '<div class="poem"><p>다른 판본</p></div>',
            },
          }),
        ),
        200,
      );
    });
    await http.runWithClient(() async {
      final store = MemoryStore();
      await open(tester, store, FakeIntake());
      await openRegistration(tester);
      await tester.tap(find.text('시·문장 검색'));
      await tester.pumpAndSettle();
      expect(find.text('바로 담을 수 있는 시'), findsOneWidget);
      expect(find.widgetWithText(TextField, '검색어'), findsNothing);
      expect(requests, isEmpty);
      final poem = find.widgetWithText(ListTile, '산유화');
      await tester.scrollUntilVisible(
        poem,
        230,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('paper-panel-page')),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.ensureVisible(poem);
      await tester.pumpAndSettle();
      await tester.tap(poem);
      await tester.pumpAndSettle();
      expect(requests.single.queryParameters['oldid'], '430577');
      expect(find.text('다른 판본'), findsNothing);
      await tester.tap(find.text('전체 담기'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '첫 줄\n둘째 줄',
      );
      expect(store.data.records, isEmpty);
    }, () => client);
  });

  test('A complete unique word can suggest text before a second word', () {
    const original = RegisteredOriginal('a', '아침이다. 햇빛이 책장에 내려앉았다.');
    const repeated = RegisteredOriginal('b', '햇빛이 창문에 번졌다.');
    const duplicateWithin = RegisteredOriginal('c', '햇빛이 곁에, 햇빛이 앞에.');
    OriginalMatch? findMatch(
      List<RegisteredOriginal> originals,
      String typed,
    ) => matchOriginal(originals, typed, typed.length);

    expect(findMatch([original], '햇빛이')?.remainder, ' 책장에 내려앉았다.');
    expect(
      findMatch([
        const RegisteredOriginal('short', '봄 바람이 분다.'),
      ], '봄')?.remainder,
      ' 바람이 분다.',
    );
    expect(findMatch([original], '햇빛'), isNull);
    expect(findMatch([original], '빛이'), isNull);
    expect(findMatch([original], '햇빛이 책')?.remainder, '장에 내려앉았다.');
    expect(findMatch([original, repeated], '햇빛이'), isNull);
    expect(findMatch([duplicateWithin], '햇빛이'), isNull);
    expect(findMatch([original], '햇빛이 문'), isNull);
  });

  test(
    'A saved reflection follows the marked words while the line continues',
    () {
      const original = RegisteredOriginal(
        'saved',
        '책장에 천천히 내려앉았다.',
        reflection: OriginalReflection('천천히 쓰자.', mark: PencilMark(0, 3)),
      );
      const written = '책장에 천천히';
      final attachment = reflectionForWriting(
        [original],
        written,
        written.length,
      )!;
      expect(attachment.match.original, original);
      expect(attachment.offset, 3);
    },
  );

  testWidgets('A margin pencil leaves with the clipped writing line', (
    tester,
  ) async {
    const first = '책장에 햇빛이 내려앉았다.';
    const note = '천천히 읽고 싶다.';
    final store = MemoryStore()
      ..data = Library(
        records: const [
          WritingRecord(
            id: 'r',
            title: '필사',
            originals: [
              RegisteredOriginal(
                'o',
                first,
                reflection: OriginalReflection(note, mark: PencilMark(0, 3)),
              ),
            ],
          ),
        ],
        pages: [
          WritingPage(
            id: 'p',
            recordId: 'r',
            number: 1,
            text: '$first\n${List.filled(25, '다른 필사 줄').join('\n')}',
          ),
        ],
        activePageId: 'p',
        writing: true,
      );
    await open(tester, store, FakeIntake());
    final marker = find.descendant(
      of: find.byKey(const ValueKey('writing-reflection')),
      matching: find.byIcon(CupertinoIcons.pencil),
    );
    expect(marker, findsOneWidget);
    tester.widget<TextField>(bodyField).scrollController!.jumpTo(12);
    await tester.pumpAndSettle();
    expect(marker, findsNothing);
    expect(store.data.records.single.originals.single.reflection!.text, note);
  });

  testWidgets('Book originals can open from another record', (tester) async {
    const title = '함께 읽는 책';
    const first = '서두를 건너뛰어도 됩니다. 햇빛이 책장에 천천히 내려앉았다.';
    const second = '햇빛이 책장까지 번졌다.';
    final store = MemoryStore()
      ..data = const Library(
        books: [
          Book(id: 'b', title: title),
          Book(
            id: 'other',
            title: '다른 책',
            originals: [
              RegisteredOriginal('other-original', '햇빛이 책장에 다른 이야기가 남았다.'),
            ],
          ),
        ],
        records: [
          WritingRecord(id: 'r', bookId: 'b', title: '첫 필사'),
          WritingRecord(id: 'r2', bookId: 'b', title: '둘째 필사'),
        ],
        pages: [
          WritingPage(id: 'p', recordId: 'r', number: 1),
          WritingPage(id: 'p2', recordId: 'r2', number: 1, text: '먼저 쓰던 기록'),
        ],
        activePageId: 'p',
        writing: true,
      );
    await open(tester, store, FakeIntake());
    expect(find.byTooltip('여기에 필사 추가'), findsNothing);
    expect(find.text('다음 쪽'), findsNothing);
    Future<void> saveOriginal(String source, String citation) async {
      await tester.enterText(sourceField, source);
      await tester.enterText(
        find.byKey(const ValueKey('original-citation')),
        citation,
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    }

    await openRegistration(tester);
    await saveOriginal(first, '12쪽');
    expect(store.data.books.first.originals.single.text, first);
    expect(store.data.records.first.originals, isEmpty);
    await tester.tap(find.text('책장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-details-b')));
    await tester.pumpAndSettle();
    final collection = find.byType(CollectionSheet);
    final bookOriginals = find.descendant(
      of: collection,
      matching: find.text('원문'),
    );
    await tester.ensureVisible(bookOriginals);
    await tester.tap(bookOriginals);
    await tester.pumpAndSettle();
    await tester.tap(find.text('원문 등록'));
    await tester.pumpAndSettle();
    await saveOriginal(second, '45쪽');
    expect(store.data.books.first.originals.map((entry) => entry.text), [
      first,
      second,
    ]);
    expect(store.data.books.last.originals.single.id, 'other-original');
    expect(store.data.pages.map((page) => page.text), ['', '먼저 쓰던 기록']);
    await tester.tap(closeIn(reading));
    await tester.pumpAndSettle();
    await tester.tap(find.text('먼저 쓰던 기록'));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'p2');

    final overlay = transcriptionReference;
    final body = tester.widget<TextField>(bodyField).controller!;
    await tester.enterText(bodyField, '책장에');
    await tester.pumpAndSettle();
    expect(overlay, findsNothing);
    await tester.enterText(bodyField, '내 글을 쓰고\n\n햇빛이 책장에');
    await tester.pumpAndSettle();
    expect(overlay, findsNothing);
    expect(find.byType(TranscriptionMarks), findsNothing);
    final before = body.value;
    tester.widget<TextField>(bodyField).focusNode!.unfocus();
    await settleSourceSheets(tester);

    await tester.tap(place.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('12쪽'), findsOneWidget);
    expect(tester.widget<Text>(readingText).textSpan!.toPlainText(), first);
    expect(
      tester.getRect(reading),
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio),
    );
    await tester.tap(find.text('원문 등록'));
    await tester.pumpAndSettle();
    await saveOriginal('정오의 종소리가 들렸다.', '60쪽');
    expect(store.data.books.first.originals, hasLength(3));
    expect(
      tester.widget<Text>(readingText).textSpan!.toPlainText(),
      '정오의 종소리가 들렸다.',
    );
    expect(find.text('이 구절 필사하기'), findsOneWidget);
    await tester.tap(closeIn(reading));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(bodyField).controller, same(body));
    expect(body.value, before);
    expect(tester.widget<TextField>(bodyField).focusNode!.hasFocus, isTrue);
    expect(store.data.activePage!.text, before.text);
    expect(tester.testTextInput.isVisible, isTrue);
    final resumed = '${before.text} 천';
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: resumed,
        selection: TextSelection.collapsed(offset: resumed.length),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.data.activePage!.text, resumed);
    expect(store.data.activePage!.passages, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reflections autosave under the original without editing the writing paper',
    (tester) async {
      const source = '햇빛이 책장에 천천히 내려앉았다.';
      final store = MemoryStore()
        ..data = const Library(
          books: [
            Book(
              id: 'b',
              title: '책',
              originals: [
                RegisteredOriginal('o', source, citation: '첫 원문'),
                RegisteredOriginal('second', '다른 날의 문장', citation: '둘째 원문'),
              ],
            ),
          ],
          records: [WritingRecord(id: 'r', bookId: 'b', title: '필사')],
          pages: [
            WritingPage(id: 'p', recordId: 'r', number: 1, text: '햇빛이'),
            WritingPage(id: 'p2', recordId: 'r', number: 2),
          ],
          activePageId: 'p',
          writing: true,
          style: WritingStyle(pageMotion: false),
        );
      await open(tester, store, FakeIntake());
      await tester.enterText(bodyField, '햇빛이');
      final body = tester.widget<TextField>(bodyField).controller!;
      final before = body.value;
      const note = '오늘도 천천히 걷고 싶다.';
      final field = find.byKey(const ValueKey('original-reflection-input'));
      await tester.tap(place);
      await tester.pumpAndSettle();
      expect(find.text('첫 원문'), findsOneWidget);
      await tester.tap(find.text('느낀 점 남기기'));
      await tester.pumpAndSettle();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '하ㄴ',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(store.data.books.single.originals.first.reflection, isNull);

      store.fail = true;
      await tester.enterText(field, note);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      final retry = find.text('느낀 점 저장 실패 · 다시 시도');
      expect(retry, findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, note);
      store.fail = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(store.data.books.single.originals.first.reflection!.text, note);

      await tester.tap(closeIn(reading));
      await tester.pumpAndSettle();
      expect(body.value, before);
      expect(find.text(note), findsOneWidget);
      expect(field, findsNothing);
      expect(find.text('느낀 점 남기기'), findsNothing);

      await tester.tap(place);
      await tester.pumpAndSettle();
      await tester.tap(find.text(note).hitTestable().last);
      await tester.pumpAndSettle();
      await tester.enterText(field, '');
      await tester.tap(find.byTooltip('원문 목록'));
      await tester.pumpAndSettle();
      expect(store.data.books.single.originals.first.reflection, isNull);
      await tester.tap(find.text('다른 날의 문장'));
      await tester.pumpAndSettle();
      await tester.tap(closeIn(reading));
      await tester.pumpAndSettle();
      await tester.tap(place);
      await tester.pumpAndSettle();
      expect(find.text('둘째 원문'), findsOneWidget);
      await tester.tap(find.byTooltip('원문 목록'));
      await tester.pumpAndSettle();
      expect(find.text('다른 날의 문장').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'Originals use the book paper, note slips and in-between divider',
    (tester) async {
      const slip = BookDetailChoice(variant: 2, tone: 2);
      const divider = BookDetailChoice(variant: 1, tone: 3);
      const pencil = BookDetailChoice(variant: 1, tone: 2);
      const first = '햇빛이 책장에 내려앉았다.';
      final style = const WritingStyle().copy(
        fontIndex: 2,
        useDevelopmentTypeface: false,
        bookDetails: const BookDetailsStyle()
            .withChoice(BookDetailKind.sourceSlip, slip)
            .withChoice(BookDetailKind.recordDivider, divider)
            .withChoice(BookDetailKind.pencil, pencil),
      );
      final store = MemoryStore()
        ..data = Library(
          books: const [
            Book(
              id: 'b',
              title: '책',
              coverIndex: 2,
              paperIndex: 3,
              originals: [
                RegisteredOriginal(
                  'a',
                  first,
                  citation: '12쪽',
                  reflection: OriginalReflection(
                    '내일도 읽고 싶다.',
                    mark: PencilMark(0, 3),
                  ),
                ),
                RegisteredOriginal('b', '저녁이 창가에 내려왔다.', citation: '25쪽'),
              ],
            ),
          ],
          records: const [WritingRecord(id: 'r', bookId: 'b', title: '필사')],
          pages: const [WritingPage(id: 'p', recordId: 'r', number: 1)],
          activePageId: 'p',
          writing: true,
          style: style,
        );
      await open(tester, store, FakeIntake());
      await tester.tap(place);
      await tester.pumpAndSettle();
      final surface = find.byKey(const ValueKey('source-paper'));
      final paper = tester.widget<PaperBackdrop>(
        find.descendant(of: surface, matching: find.byType(PaperBackdrop)),
      );
      expect(tester.widget<PaperPanel>(surface).color, paper.color);
      final panel = panelPaperColor(paperColors[3]);
      expect(paper.color, panel);
      expect(paper.grainOpacity, panelGrainOpacity);
      expect(paper.coverIndex, isNull);
      expect(paper.binding.enabled, isFalse);
      final slips = find.descendant(
        of: reading,
        matching: find.byType(SourceSlip),
      );
      expect(
        tester
            .widgetList<SourceSlip>(slips)
            .map((item) => item.choice.toJson()),
        [slip.toJson(), slip.toJson()],
      );
      final sourceCard = tester.widget<SourceSlip>(slips.first);
      expect(sourceCard.panelColor, panel);
      expect(sourceCard.stockColor, isNot(Colors.white));
      expect(tester.widget<Text>(find.text(first)).style!.color, ink);
      final filter = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(filter.selectedColor, panelSelectedColor(panel));
      final separators = find.descendant(
        of: reading,
        matching: find.byType(RecordDivider),
      );
      expect(
        tester.widget<RecordDivider>(separators).choice.toJson(),
        divider.toJson(),
      );
      await tester.tap(find.text(first));
      await tester.pumpAndSettle();
      final span = tester.widget<Text>(readingText).textSpan! as TextSpan;
      expect(span.style!.fontFamily, 'NanumGothic');
      final washed = span.children!.whereType<TextSpan>().first;
      expect(washed.text, '햇빛이');
      expect(washed.style!.decoration, isNull);
      expect(
        washed.style!.backgroundColor,
        BookDetailDesign.color(
          BookDetailKind.pencil,
          pencil,
        ).withValues(alpha: .26),
      );
      expect(find.text('내일도 읽고 싶다.'), findsOneWidget);
    },
  );

  testWidgets('Older sources and citation-only passages stay visible', (
    tester,
  ) async {
    final store = MemoryStore()
      ..data = existing().copy(
        records: const [
          WritingRecord(id: 'r', title: '필사', source: '기록에 있던 원문'),
        ],
        pages: const [
          WritingPage(
            id: 'p',
            recordId: 'r',
            number: 1,
            passages: [
              PagePassage(
                id: 'a',
                start: 0,
                source: '줄에 붙인 원문',
                citation: '책 · 24쪽',
              ),
              PagePassage(id: 'b', start: 0, citation: '출처만 · 30쪽'),
            ],
          ),
        ],
      );
    await open(tester, store, FakeIntake());
    await tester.tap(place);
    await tester.pumpAndSettle();
    expect(find.text('기록에 있던 원문'), findsOneWidget);
    expect(find.text('줄에 붙인 원문'), findsOneWidget);
    expect(find.text('책 · 24쪽'), findsOneWidget);
    await tester.tap(find.text('출처만 · 30쪽'));
    await tester.pumpAndSettle();
    expect(find.text('출처를 남긴 기록입니다.'), findsOneWidget);
    expect(store.data.activePage!.passages, hasLength(2));
    await tester.tap(find.byTooltip('원문 목록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('줄에 붙인 원문'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('느낀 점 남기기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('original-reflection-input')),
      '다시 볼 구절.',
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    final promoted = store.data.records.single.originals.single;
    expect(promoted.reflection!.text, '다시 볼 구절.');
    expect(promoted.citation, '책 · 24쪽');
    expect(store.data.activePage!.passages.first.source, '줄에 붙인 원문');
    expect(store.data.activePage!.passages, hasLength(2));
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
      await openRegistration(tester);
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
      expect(store.data.records.single.originals.single.text, '첫 줄\n\n둘째 줄');
      expect(reading, findsNothing);
      expect(tester.widget<TextField>(bodyField).controller, same(body));
      expect(body.value, original);
      expect(store.data.activePageId, 'p');
      await settleSourceSheets(tester);
      await tester.tap(place.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('첫 줄 둘째 줄'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(readingText).textSpan!.toPlainText(),
        '첫 줄\n\n둘째 줄',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Choose photo paragraphs, correct a character, then save only reviewed text',
    (tester) async {
      await preparePhotoStorage(tester);
      final store = MemoryStore();
      final intake = FakeIntake();
      await open(tester, store, intake);
      final body = tester.widget<TextField>(bodyField).controller!;
      await openRegistration(tester);
      await takePhoto(tester);
      expect(intake.photos, 1);
      expect(find.text('페이지 인식 결과'), findsOneWidget);
      expect(store.data.records, isEmpty);
      final paragraph = find.byKey(const ValueKey('source-paragraph-0'));
      await Scrollable.ensureVisible(tester.element(paragraph), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(paragraph);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '둘째 문단입나다.',
      );
      await tester.enterText(sourceField, '“둘째 문단입니다.”');
      await tester.pumpAndSettle();
      final cleanup = find.text('특수문자 정리');
      await tester.ensureVisible(cleanup);
      await tester.tap(cleanup);
      await tester.pumpAndSettle();
      await saveWithPhoto(tester);
      expect(store.data.records.single.originals.single.text, '"둘째 문단입니다."');
      expect(reading, findsNothing);
      expect(store.data.activePage!.text, isEmpty);
      expect(tester.widget<TextField>(bodyField).controller, same(body));
      expect(tester.widget<TextField>(bodyField).focusNode!.hasFocus, isFalse);
      expect(transcriptionReference, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Page review stores the whole page, selected range, and exact photo bytes',
    (tester) async {
      await preparePhotoStorage(tester);
      final store = MemoryStore();
      final intake = FakeIntake();
      intake.positioned = SourceScan(
        intake.photo.bytes,
        const [
          ScanParagraph([
            ScanLine('오른쪽 문단', bounds: Rect.fromLTRB(.58, .17, .89, .27)),
          ]),
          ScanParagraph([
            ScanLine(
              '왼쪽 문단',
              bounds: Rect.fromLTRB(.12, .17, .44, .27),
              confidence: .5,
            ),
          ]),
        ],
        width: 600,
        height: 800,
      );
      await open(tester, store, intake);
      await openRegistration(tester);
      await takePhoto(tester);
      final preview = find.byKey(const ValueKey('source-scan-preview'));
      final inlineHeight = tester.getSize(preview).height;
      expect(inlineHeight, greaterThan(350));
      await tester.tap(find.text('사진 크게 보기'));
      await tester.pumpAndSettle();
      final fullPhoto = find.descendant(
        of: find.byType(Dialog),
        matching: preview,
      );
      expect(tester.getSize(fullPhoto).height, greaterThan(inlineHeight * 1.7));
      await tester.tap(find.byTooltip('큰 사진 닫기'));
      await tester.pumpAndSettle();
      expect(tester.getSize(preview).height, inlineHeight);
      expect(intake.photos, 1);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final first = tester.widget<TextField>(sourceField);
      expect(first.controller!.text, '왼쪽 문단');
      final line = find.byKey(const ValueKey('source-review-line-0-0'));
      await tester.ensureVisible(line);
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(find.text('사진과 대조'), findsOneWidget);
      expect(find.bySemanticsLabel('사진 속 해당 줄 확대'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '닫기'));
      await tester.pumpAndSettle();
      final citation = find.byKey(const ValueKey('original-citation'));
      await tester.ensureVisible(citation);
      await tester.enterText(citation, '12쪽');
      await tester.pumpAndSettle();
      final chooseRange = find.text('필사 범위 · 전체 페이지');
      await tester.ensureVisible(chooseRange);
      await tester.tap(chooseRange);
      await tester.pumpAndSettle();
      final rangePhoto = find.byKey(const ValueKey('source-scan-preview'));
      expect(find.bySemanticsLabel('인식한 책 사진'), findsOneWidget);
      final frame = tester.getRect(
        find.descendant(of: rangePhoto, matching: find.byType(Image)),
      );
      final rightLine = Offset(
        frame.left + frame.width * .73,
        frame.top + frame.height * .22,
      );
      await tester.tapAt(rightLine);
      await tester.pumpAndSettle();
      expect(find.textContaining('끝 줄을 누르세요.'), findsOneWidget);
      await tester.tapAt(rightLine);
      await tester.pumpAndSettle();
      final rangeText = find.byKey(const ValueKey('original-range-text'));
      String highlighted() {
        final editable = tester.widget<EditableText>(
          find.descendant(of: rangeText, matching: find.byType(EditableText)),
        );
        return editable.controller
            .buildTextSpan(
              context: tester.element(rangeText),
              style: editable.style,
              withComposing: false,
            )
            .children!
            .whereType<TextSpan>()
            .where((span) => span.style?.backgroundColor != null)
            .map((span) => span.text)
            .join();
      }

      await tester.tap(find.text('글로 선택'));
      await tester.pumpAndSettle();
      final rangeSlider = find.byKey(const ValueKey('original-line-range'));
      expect(find.text('2–2줄'), findsOneWidget);
      expect(highlighted(), '오른쪽 문단');
      tester.widget<RangeSlider>(rangeSlider).onChanged!(
        const RangeValues(0, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('1–1줄'), findsOneWidget);
      expect(highlighted(), '왼쪽 문단');
      tester.widget<RangeSlider>(rangeSlider).onChanged!(
        const RangeValues(0, 1),
      );
      await tester.pumpAndSettle();
      expect(highlighted(), '왼쪽 문단\n\n오른쪽 문단');
      final rangeField = tester.widget<TextField>(rangeText);
      rangeField.controller!.selection = const TextSelection(
        baseOffset: 7,
        extentOffset: 10,
      );
      await tester.pumpAndSettle();
      expect(find.text('2–2줄'), findsOneWidget);
      expect(highlighted(), '오른쪽');
      tester.widget<RangeSlider>(rangeSlider).onChanged!(
        const RangeValues(1, 1),
      );
      await tester.pumpAndSettle();
      expect(highlighted(), '오른쪽 문단');
      await tester.tap(find.text('범위 적용'));
      await tester.pumpAndSettle();
      await saveWithPhoto(tester);
      final original = store.data.records.single.originals.single;
      expect(original.text, '왼쪽 문단\n\n오른쪽 문단');
      expect(original.citation, '12쪽');
      expect(original.isFullPage, isTrue);
      expect(original.photoLines, hasLength(2));
      expect(
        original.text.substring(
          original.writingRange!.start,
          original.writingRange!.end,
        ),
        '오른쪽 문단',
      );
      final bytes = await tester.runAsync(
        () => const OriginalPhotoStore().load(original.photoId!),
      );
      expect(bytes, intake.photo.bytes);
      expect(matchOriginal([original], '왼쪽', 2), isNull);
      expect(matchOriginal([original], '오른쪽', 3)?.remainder, ' 문단');
      final restored = await tester.runAsync(() async {
        final backup = await LibraryBackup.collect(
          store.data,
          DateTime.utc(2026, 11, 13),
        );
        return LibraryBackup.decode(backup.encode());
      });
      expect(restored!.photos.keys.toSet(), {original.photoId});
      expect(
        restored.library.records.single.originals.single.writingRange?.toJson(),
        original.writingRange?.toJson(),
      );
      expect(store.data.pages.single.text, isEmpty);
    },
  );

  testWidgets(
    'Paragraph mode selects by photo and re-reads only the selected area',
    (tester) async {
      await preparePhotoStorage(tester);
      final store = MemoryStore();
      final intake = FakeIntake()..blocks = ['다시 읽은 구절'];
      intake.positioned = SourceScan(
        intake.photo.bytes,
        const [
          ScanParagraph([
            ScanLine(
              '선택한 단어',
              bounds: Rect.fromLTRB(.2, .4, .8, .55),
              words: [
                ScanWord('선택한', Rect.fromLTRB(.2, .4, .49, .55), .9),
                ScanWord('단어', Rect.fromLTRB(.51, .4, .8, .55), .9),
              ],
            ),
          ]),
        ],
        width: 800,
        height: 800,
      );
      await open(tester, store, intake);
      await openRegistration(tester);
      await tester.tap(find.byKey(const ValueKey('source-photo-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source-paragraph-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 찍기'));
      await tester.pumpAndSettle();
      final preview = find.byKey(const ValueKey('source-scan-preview'));
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-word-range')), findsOneWidget);
      final frame = tester.getRect(preview);
      final rightWord = Offset(
        frame.center.dx + frame.shortestSide * (.66 - .5),
        frame.center.dy,
      );
      await tester.tapAt(rightWord);
      await tester.pumpAndSettle();
      expect(find.text('사진에서 끝 단어를 누르세요.'), findsOneWidget);
      await tester.tapAt(rightWord);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('source-selected-passage')))
            .data,
        '단어',
      );
      final retry = find.text('선택 영역 다시 읽기');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(intake.recognizedRegion!.width, lessThan(.34));
      expect(intake.recognizedMask, hasLength(1));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '다시 읽은 구절',
      );
      await saveWithPhoto(tester);
      expect(store.data.records.single.originals.single.text, '다시 읽은 구절');
    },
  );

  testWidgets('Original panel preserves composition, selection, and scroll', (
    tester,
  ) async {
    final source =
        '${List.filled(18, '앞쪽에 있는 문장을 옮깁니다.').join('\n')}'
        '\n햇빛이 책장에 천천히 내려앉았다.';
    final store = MemoryStore()
      ..data = existing().copy(
        records: [WritingRecord(id: 'r', title: '기존 필사', source: source)],
      );
    await open(tester, store, FakeIntake());
    final field = tester.widget<TextField>(bodyField);
    await tester.showKeyboard(bodyField);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();

    const composing = TextEditingValue(
      text: '햇빛이 책장에 처',
      selection: TextSelection.collapsed(offset: 9),
      composing: TextRange(start: 8, end: 9),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    expect(tester.widget<TextButton>(place).onPressed, isNull);
    expect(field.controller!.value, composing);
    expect(transcriptionReference, findsNothing);

    const committed = TextEditingValue(
      text: '햇빛이 책장에',
      selection: TextSelection.collapsed(offset: 7),
    );
    tester.testTextInput.updateEditingValue(committed);
    await tester.pumpAndSettle();
    final before = store.data.activePage!;
    final writingArea = tester.getRect(bodyField);
    await tester.tap(place);
    await tester.pumpAndSettle();
    final scrollView = find.ancestor(
      of: readingText,
      matching: find.byType(SingleChildScrollView),
    );
    final sourceScroll = tester
        .widget<SingleChildScrollView>(scrollView)
        .controller!;
    expect(sourceScroll.offset, greaterThan(0));
    expect(tester.widget<Text>(readingText).textSpan!.toPlainText(), source);
    await tester.tap(closeIn(reading));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(bodyField).controller,
      same(field.controller),
    );
    expect(field.controller!.value, committed);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.getRect(bodyField), writingArea);
    final after = store.data.activePage!;
    expect(
      (after.text, after.base, after.extent),
      (before.text, before.base, before.extent),
    );
    expect(after.scroll, closeTo(before.scroll, 1));
    expect(store.data.records.single.source, source);
    expect(store.data.records.single.sourceParagraph, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Photo cancel, empty result and closing active OCR leave the source alone',
    (tester) async {
      final store = MemoryStore();
      final intake = FakeIntake()..cancelPicker = true;
      await open(tester, store, intake);
      await openRegistration(tester);
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
      await tester.tap(closeIn(find.byType(SourceImportSheet)));
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
      expect(store.data.records.last.originals.single.text, '공유한 문장입니다.');
      expect(store.data.records.last.originals.single.registeredAt, isNotNull);
      expect(store.data.activePage!.text, isEmpty);
      expect(store.data.pages.first.text, composing.text);
      expect(intake.acknowledged, ['test-delivery']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Shared text can be stored on an existing book and acknowledged once',
    (tester) async {
      final store = MemoryStore()
        ..data = existing().copy(
          books: const [Book(id: 'shared-book', title: '문장 수첩')],
        );
      final intake = FakeIntake()
        ..shares.add(const IncomingSource('book-share', '책에 남길 구절'));
      await open(tester, store, intake);
      final destination = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();
      await tester.tap(find.text('문장 수첩').last);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(store.data.records, hasLength(1));
      expect(store.data.books.single.originals.single.text, '책에 남길 구절');
      expect(store.data.activePageId, 'p');
      expect(intake.acknowledged, ['book-share']);
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
      await openRegistration(tester);
      await tester.tap(sourceField);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      final caret = find.byKey(const ValueKey('writing-caret-stroke'));
      final sheet = find.byType(SourceImportSheet);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('저장'), findsOneWidget);
      expect(tester.getSize(sheet), const Size(320, 640));
      expect(tester.getBottomLeft(confirm).dy, closeTo(628, 1));
      final sourceCaret = find.descendant(of: sheet, matching: caret);
      expect(sourceCaret, findsOneWidget);
      expect(tester.widget<TextField>(sourceField).showCursor, isFalse);
      final initialCaret = tester.getTopLeft(sourceCaret);
      tester.view.viewInsets = const FakeViewPadding(bottom: 270);
      const composing = TextEditingValue(
        text: '하ㄴ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(confirm).dy, closeTo(358, 1));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(
        tester.widget<TextField>(sourceField).controller!.value,
        composing,
      );
      expect(sourceCaret, findsOneWidget);
      expect(tester.getTopLeft(sourceCaret).dx, greaterThan(initialCaret.dx));
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
      expect(store.data.records.single.originals.single.text, '한');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Save and transcribe restores the chosen guide and typed prefix after reopening',
    (tester) async {
      final store = MemoryStore();
      await open(tester, store, FakeIntake());
      await openRegistration(tester);
      const first = '한 문장을 옮겨 쓴다.';
      const second = '그다음 문장을 읽는다.';
      const original = '$first\n$second';
      await tester.enterText(sourceField, original);
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('source-transcribe-after-save'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await settleSourceSheets(tester);
      final field = tester.widget<TextField>(bodyField);
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(remainingReference(tester), original);
      expect(store.data.pages.single.text, isEmpty);
      await tester.enterText(bodyField, '한 문쟝을');
      await tester.pumpAndSettle();
      expect(remainingReference(tester), ' 옮겨 쓴다.\n$second');
      expect(store.data.pages.single.text, '한 문쟝을');
      const composing = TextEditingValue(
        text: '한 문쟝을 ㅇ',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 6, end: 7),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(remainingReference(tester), '옮겨 쓴다.\n$second');
      expect(field.controller!.value, composing);
      await tester.enterText(bodyField, '한 문장을');
      await tester.pumpAndSettle();
      expect(find.text('느낀 점'), findsNothing);
      expect(store.data.pages.single.text, '한 문장을');
      await tester.enterText(bodyField, '$first\n');
      await tester.pumpAndSettle();
      expect(remainingReference(tester), second);
      expect(store.data.pages.single.text, '$first\n');
      const mistyped = '한 문쟝을 옮겨 쓴다.\n';
      await tester.enterText(bodyField, mistyped);
      await tester.pumpAndSettle();
      expect(store.data.pages.single.text, mistyped);
      final saved = store.data;
      expect(
        saved.activePage!.guidedOriginalId,
        saved.records.single.originals.single.id,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      store.data = Library.decode(saved.encode());
      await tester.pumpWidget(
        WritingHumanApp(store: store, sourceIntake: FakeIntake()),
      );
      await tester.pumpAndSettle();
      final reopened = tester.widget<TextField>(bodyField);
      expect(reopened.controller!.text, mistyped);
      expect(reopened.controller!.selection.extentOffset, first.length + 1);
      expect(remainingReference(tester), second);
      expect(reopened.focusNode!.hasFocus, isFalse);
    },
  );

  test(
    'Transcription comparison resumes after an extra or missing grapheme',
    () {
      final comparison = TranscriptionComparison(
        const RegisteredOriginal('o', '가나다라마바사.'),
      );
      expect(comparison.differencesFor('가나다라'), isEmpty);
      expect(comparison.differencesFor('가낙다라'), [
        (start: 1, end: 2, expected: '나'),
      ]);
      expect(comparison.differencesFor('가😀나다라'), [
        (start: 1, end: 3, expected: ''),
      ]);
      expect(comparison.remainderFor('가😀나다라'), '마바사.');
      expect(comparison.differencesFor('가다라'), [
        (start: 1, end: 1, expected: '나'),
      ]);
      expect(comparison.remainderFor('가다라'), '마바사.');
      expect(comparison.differencesFor('가나다라'), isEmpty);
      expect(comparison.differencesFor('가나다라마바사.'), isEmpty);
      expect(comparison.differencesFor('가나다라마바사.!'), [
        (start: 8, end: 9, expected: ''),
      ]);
    },
  );

  testWidgets(
    'A transcription mark opens the original letter after composition',
    (tester) async {
      final store = MemoryStore()
        ..data = const Library(
          records: [
            WritingRecord(
              id: 'r',
              title: '필사',
              originals: [RegisteredOriginal('o', '한 문장을 계속 이어 쓴다.')],
            ),
          ],
          pages: [
            WritingPage(
              id: 'p',
              recordId: 'r',
              number: 1,
              guidedOriginalId: 'o',
            ),
          ],
          activePageId: 'p',
          writing: true,
        );
      await open(tester, store, FakeIntake());
      await tester.tap(bodyField);
      await tester.pumpAndSettle();
      const composing = TextEditingValue(
        text: '한 문쟝',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 3, end: 4),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      final painting = find.descendant(
        of: find.byType(TranscriptionMarks),
        matching: find.byType(CustomPaint),
      );
      List<CustomPainterSemantics> marks() => tester
          .widget<CustomPaint>(painting)
          .painter!
          .semanticsBuilder!(tester.getSize(painting));
      expect(marks(), isEmpty);
      final field = tester.widget<TextField>(bodyField);
      expect(field.controller!.value, composing);
      await tester.enterText(bodyField, '한 문쟝을 계속');
      await tester.pumpAndSettle();
      expect(marks(), hasLength(1));

      final target = marks().single.rect.center;
      await tester.tapAt(tester.getTopLeft(painting) + target);
      await tester.pumpAndSettle();
      expect(find.text('원문 글자 ‘장’'), findsOneWidget);
      expect(field.controller!.text, '한 문쟝을 계속');
      await tester.tap(find.widgetWithText(TextButton, '닫기'));
      await tester.pumpAndSettle();
      await tester.enterText(bodyField, '한 문장을 계속');
      await tester.pumpAndSettle();
      expect(marks(), isEmpty);
      expect(store.data.activePage!.text, '한 문장을 계속');
    },
  );

  testWidgets('Guided writing follows the line above the source reference', (
    tester,
  ) async {
    const first = '첫 줄을 옮겨 적는다.';
    const second = '두 번째 줄을 따라 쓴다.';
    const third = '다음 줄을 읽는다.';
    final store = MemoryStore()
      ..data = const Library(
        records: [
          WritingRecord(
            id: 'r',
            title: '필사',
            originals: [RegisteredOriginal('o', '$first\n$second\n$third')],
          ),
        ],
        pages: [
          WritingPage(id: 'p', recordId: 'r', number: 1, guidedOriginalId: 'o'),
        ],
        activePageId: 'p',
        writing: true,
      );
    await open(tester, store, FakeIntake());
    final reference = transcriptionReference;
    expect(reference, findsOneWidget);
    expect(remainingReference(tester), '$first\n$second\n$third');
    const keyboard = 290.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
    await tester.showKeyboard(bodyField);
    await tester.pumpAndSettle();
    expect(reference, findsOneWidget);
    final editable = tester
        .state<EditableTextState>(
          find.descendant(of: bodyField, matching: find.byType(EditableText)),
        )
        .renderEditable;
    final field = tester.widget<TextField>(bodyField);
    final rect = tester.getRect(find.byKey(const ValueKey('writing-surface')));
    final middle = rect.top + (rect.height - keyboard) / 2;
    double caretY() => editable
        .localToGlobal(
          editable
              .getLocalRectForCaret(field.controller!.selection.extent)
              .center,
        )
        .dy;
    expect(caretY(), closeTo(middle, 5));
    expect(tester.getTopLeft(reference).dy, greaterThan(caretY()));
    await tester.enterText(bodyField, '$first\n');
    await tester.pumpAndSettle();
    expect(caretY(), closeTo(middle, 5));
    expect(remainingReference(tester), '$second\n$third');
    const draft = '$first\n두';
    final composing = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
      composing: TextRange(start: draft.length - 1, end: draft.length),
    );
    final offset = field.scrollController!.offset;
    tester.testTextInput.updateEditingValue(composing);
    await tester.pumpAndSettle();
    expect(field.controller!.value, composing);
    expect(field.scrollController!.offset, offset);
    tester.testTextInput.updateEditingValue(
      composing.copyWith(composing: TextRange.empty),
    );
    await tester.pumpAndSettle();
    expect(store.data.activePage!.text, draft);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'The remaining source returns to roomy paper without changing input',
    (tester) async {
      final passage = [
        '첫 줄을 옮겨 적는다.',
        ...List.generate(30, (i) => '${i + 1}번째 줄을 천천히 옮겨 적는다.'),
      ].join('\n');
      const heading = '머리말\n';
      final store = MemoryStore()
        ..data = Library(
          records: [
            WritingRecord(
              id: 'r',
              title: '필사',
              originals: [
                RegisteredOriginal(
                  'o',
                  '$heading$passage\n꼬리말',
                  isFullPage: true,
                  writingRange: PencilMark(
                    heading.length,
                    heading.length + passage.length,
                  ),
                ),
              ],
            ),
          ],
          pages: const [
            WritingPage(
              id: 'p',
              recordId: 'r',
              number: 1,
              guidedOriginalId: 'o',
            ),
          ],
          activePageId: 'p',
          writing: true,
        );
      await open(tester, store, FakeIntake());
      final guide = find.byKey(const ValueKey('transcription-guide'));
      TranscriptionGuidePainter painter() =>
          tester.widget<CustomPaint>(guide).painter!
              as TranscriptionGuidePainter;
      final field = tester.widget<TextField>(bodyField);
      expect(guide, findsOneWidget);
      expect(transcriptionReference, findsOneWidget);
      expect(painter().remainderFor(field.controller!.value), passage);
      expect(field.controller!.text, isEmpty);
      expect(
        field.scrollController!.position.maxScrollExtent,
        greaterThan(500),
      );

      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      await tester.showKeyboard(bodyField);
      await tester.pumpAndSettle();
      expect(guide, findsNothing);
      expect(transcriptionReference, findsOneWidget);
      expect(field.controller!.text, isEmpty);

      const composing = TextEditingValue(
        text: '첫 줄을 ㅇ',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 5, end: 6),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(guide, findsOneWidget);
      expect(transcriptionReference, findsOneWidget);
      expect(field.controller!.value, composing);
      expect(painter().remainderFor(composing), passage.substring(6));

      await tester.enterText(bodyField, '첫 줄윽');
      await tester.pumpAndSettle();
      field.focusNode!.unfocus();
      await tester.pumpAndSettle();
      expect(guide, findsOneWidget);
      expect(
        painter().remainderFor(field.controller!.value),
        passage.substring(4),
      );
      expect(store.data.activePage!.text, '첫 줄윽');
      expect(store.data.activePage!.guidedOriginalId, 'o');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A long original scrolls in the bottom reference on a compact screen',
    (tester) async {
      final lines = List.generate(32, (i) => '${i + 1}번째 줄을 천천히 옮겨 적는다.');
      final source = lines.join('\n');
      final store = MemoryStore()
        ..data = Library(
          records: [
            WritingRecord(
              id: 'r',
              title: '필사',
              originals: [RegisteredOriginal('source', source)],
            ),
          ],
          pages: const [
            WritingPage(
              id: 'p',
              recordId: 'r',
              number: 1,
              guidedOriginalId: 'source',
            ),
          ],
          activePageId: 'p',
          writing: true,
        );
      await open(tester, store, FakeIntake());
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(bodyField);
      expect(transcriptionReference, findsOneWidget);
      expect(remainingReference(tester), source);
      expect(field.controller!.text, isEmpty);

      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      await tester.showKeyboard(bodyField);
      await tester.pumpAndSettle();
      expect(transcriptionReference, findsOneWidget);
      expect(
        tester.getTopLeft(transcriptionReference).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(bodyField).dy),
      );
      expect(tester.getBottomLeft(transcriptionReference).dy, lessThan(350));

      final viewport = find.descendant(
        of: transcriptionReference,
        matching: find.byType(SingleChildScrollView),
      );
      final scroll = tester.widget<SingleChildScrollView>(viewport).controller!;
      expect(scroll.position.maxScrollExtent, greaterThan(500));
      final initial = field.controller!.value;
      final editorOffset = field.scrollController!.offset;
      await tester.drag(viewport, const Offset(0, -380));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(200));
      expect(field.controller!.value, initial);
      expect(field.scrollController!.offset, editorOffset);
      expect(store.data.activePage!.text, isEmpty);

      final written = '${lines.take(8).join('\n')}\n';
      await tester.enterText(bodyField, written);
      await tester.pumpAndSettle();
      expect(remainingReference(tester), lines.skip(8).join('\n'));
      expect(scroll.offset, greaterThan(140));
      expect(scroll.offset, lessThan(scroll.position.maxScrollExtent));

      field.focusNode!.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(transcriptionReference, findsOneWidget);
      expect(referenceText(tester).toPlainText(), source);
      expect(field.controller!.text, written);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Save and transcribe from the original panel preserves the existing page',
    (tester) async {
      final store = MemoryStore()
        ..data = const Library(
          books: [
            Book(
              id: 'b',
              title: '문장 수첩',
              originals: [RegisteredOriginal('first', '먼저 저장한 구절')],
            ),
          ],
          records: [WritingRecord(id: 'r', bookId: 'b', title: '필사')],
          pages: [
            WritingPage(id: 'p', recordId: 'r', number: 1, text: '이미 쓴 글'),
          ],
          activePageId: 'p',
          writing: true,
        );
      await open(tester, store, FakeIntake());
      await tester.tap(place);
      await tester.pumpAndSettle();
      expect(reading, findsOneWidget);
      await tester.tap(find.text('원문 등록'));
      await tester.pumpAndSettle();
      final registration = find.byType(SourceImportSheet);
      expect(
        find.ancestor(of: registration, matching: find.byType(PaperBackdrop)),
        findsNothing,
      );
      expect(
        find.descendant(of: registration, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
      expect(find.widgetWithText(CheckboxListTile, '바로 필사하기'), findsOneWidget);
      await tester.enterText(sourceField, '새로 옮겨 쓸 구절');
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('source-transcribe-after-save'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await settleSourceSheets(tester);

      expect(reading, findsNothing);
      expect(store.data.pages.first.text, '이미 쓴 글');
      expect(store.data.pages, hasLength(1));
      expect(store.data.activePageId, 'p');
      expect(store.data.activeBook!.id, 'b');
      expect(store.data.activePage!.text, '이미 쓴 글');
      expect(store.data.activePage!.referenceOnly, isTrue);
      expect(
        store.data.activePage!.guidedOriginalId,
        store.data.activeBook!.originals.last.id,
      );
    },
  );

  testWidgets(
    'Shared photo opens as a guide without recognition or prefilled writing',
    (tester) async {
      await preparePhotoStorage(tester);
      final store = MemoryStore()
        ..data = const Library(
          books: [Book(id: 'b', title: '노트')],
          records: [WritingRecord(id: 'r', bookId: 'b', title: '필사')],
          pages: [WritingPage(id: 'p', recordId: 'r', number: 1)],
          activePageId: 'p',
          writing: true,
        );
      final intake = FakeIntake()
        ..shares.add(const IncomingSource('image-share', '', hasPhoto: true));
      await open(tester, store, intake);
      expect(
        find.byKey(const ValueKey('original-photo-preview')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('original-citation')),
        '책 72쪽',
      );
      await tester.pumpAndSettle();
      await saveWithPhoto(tester);
      final original = store.data.books.single.originals.single;
      expect(original.text, isEmpty);
      expect(original.photoId, isNotNull);
      expect(intake.scans, 0);
      expect(intake.acknowledged, ['image-share']);
      expect(
        await tester.runAsync(
          () => const OriginalPhotoStore().load(original.photoId!),
        ),
        intake.photo.bytes,
      );

      await tester.tap(place);
      await tester.pumpAndSettle();
      Future<void> loadPhotoAfter(Finder target) async {
        await tester.runAsync(() async {
          await tester.tap(target);
          for (var frame = 0; frame < 20; frame++) {
            await tester.pump(const Duration(milliseconds: 30));
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
      }

      await loadPhotoAfter(find.text('원본 사진').last);
      await loadPhotoAfter(find.text('이 구절 필사하기'));
      expect(store.data.activePageId, 'p');
      expect(store.data.activePage!.text, isEmpty);
      expect(store.data.activePage!.guidedOriginalId, original.id);
      expect(store.data.activePage!.originalCitations, ['책 72쪽']);
      expect(find.text('사진 크게 보기'), findsOneWidget);
    },
  );

  testWidgets('A shared URL saves as a link without body text', (tester) async {
    final store = MemoryStore()..data = existing();
    const url = 'https://example.com/reading';
    final intake = FakeIntake()
      ..shares.add(const IncomingSource('url-share', url));
    await open(tester, store, intake);
    expect(tester.widget<TextField>(sourceField).controller!.text, isEmpty);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    final original = store.data.records.last.originals.single;
    expect(original.text, isEmpty);
    expect(original.citation, url);
    expect(original.canTranscribe, isFalse);
    expect(intake.acknowledged, ['url-share']);
  });

  testWidgets('Pencil filter opens the page containing the marked original', (
    tester,
  ) async {
    final store = MemoryStore()
      ..data = const Library(
        books: [
          Book(
            id: 'b',
            title: '문장 수첩',
            originals: [
              RegisteredOriginal('marked', '책장에 천천히 내려앉았다.'),
              RegisteredOriginal('plain', '정오의 종소리가 들렸다.'),
            ],
          ),
        ],
        records: [WritingRecord(id: 'r', bookId: 'b', title: '필사')],
        pages: [
          WritingPage(id: 'p', recordId: 'r', number: 1),
          WritingPage(
            id: 'marked-page',
            recordId: 'r',
            number: 2,
            text: '책장에 천천히 내려앉았다.',
            pencilMarks: [PencilMark(0, 3)],
          ),
        ],
        activePageId: 'p',
        writing: true,
      );
    await open(tester, store, FakeIntake());
    await tester.tap(place);
    await tester.pumpAndSettle();
    await tester.tap(find.text('밑칠만 보기'));
    await tester.pumpAndSettle();
    expect(find.text('정오의 종소리가 들렸다.'), findsNothing);
    await tester.tap(find.text('책장에 천천히 내려앉았다.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('필사한 쪽 열기'));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'marked-page');
    expect(
      tester.widget<TextField>(bodyField).controller!.text,
      '책장에 천천히 내려앉았다.',
    );
  });

  testWidgets('Recovered Android picker photo enters review without saving', (
    tester,
  ) async {
    final store = MemoryStore();
    final intake = FakeIntake();
    intake.recovered = intake.photo;
    await open(tester, store, intake);
    expect(find.text('페이지 인식 결과'), findsOneWidget);
    expect(intake.photos, 0);
    expect(store.writes, 0);
  });
}
