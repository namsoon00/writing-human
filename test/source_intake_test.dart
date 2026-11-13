import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/library_backup.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/original_photo_store.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/source/source_intake.dart';
import 'package:writing_human/source/source_scan.dart';
import 'package:writing_human/source/originals.dart';
import 'package:writing_human/ui/collection_sheet.dart';
import 'package:writing_human/ui/book_details.dart';
import 'package:writing_human/ui/book_detail_design.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/reading_details.dart';
import 'package:writing_human/ui/source_import_sheet.dart';
import 'package:writing_human/ui/source_reading.dart';
import 'package:writing_human/ui/transcription_guide.dart';

import 'widget_test.dart' show MemoryStore;

final sourceField = find.byKey(const ValueKey('source-text'));
final bodyField = find.byKey(const ValueKey('page-text'));
final confirm = find.byKey(const ValueKey('source-confirm'));
final place = find.byKey(const ValueKey('writing-originals'));
final reading = find.byType(SourceReading);
final readingText = find.byKey(const ValueKey('source-reading-text'));

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
  int photos = 0, cancellations = 0;
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
  Future<SourcePhoto?> recoverPhoto() async => recovered;
  @override
  Future<SourceScan> scan(
    SourcePhoto photo, {
    Rect? region,
    List<Rect> mask = const [],
  }) async {
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

  testWidgets('Book originals register once and match in another record', (
    tester,
  ) async {
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

    final overlay = find.byKey(const ValueKey('transcription-guide'));
    final body = tester.widget<TextField>(bodyField).controller!;
    String remainder() =>
        (tester.widget<CustomPaint>(overlay).painter!
                as TranscriptionGuidePainter)
            .remainderFor(body.value);
    expect(remainder(), isEmpty);
    await tester.enterText(bodyField, '햇빛이');
    await tester.pumpAndSettle();
    expect(remainder(), isEmpty);
    await tester.enterText(bodyField, '책장에');
    await tester.pumpAndSettle();
    expect(remainder(), ' 천천히 내려앉았다.');
    await tester.enterText(bodyField, '햇빛이 책장');
    await tester.pumpAndSettle();
    expect(remainder(), isEmpty);
    await tester.enterText(bodyField, '햇빛이 책장에');
    await tester.pumpAndSettle();
    expect(remainder(), ' 천천히 내려앉았다.');
    await tester.enterText(bodyField, '햇빛이 책장에 다르게');
    await tester.pumpAndSettle();
    expect(remainder(), isEmpty);
    await tester.enterText(bodyField, '내 글을 쓰고\n\n햇빛이 책장에');
    await tester.pumpAndSettle();
    expect(remainder(), ' 천천히 내려앉았다.');
    final before = body.value;
    tester.widget<TextField>(bodyField).focusNode!.unfocus();
    await settleSourceSheets(tester);

    await tester.tap(place.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('12쪽'), findsOneWidget);
    expect(tester.widget<Text>(readingText).textSpan!.toPlainText(), first);
    expect(tester.getTopLeft(reading).dy, greaterThan(250));
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
      final paper = tester.widget<PaperBackdrop>(
        find.byKey(const ValueKey('source-paper')),
      );
      final panel = panelPaperColor(paperColors[3]);
      expect(paper.color, panel);
      expect(paper.grainOpacity, panelGrainOpacity);
      expect(paper.coverIndex, 2);
      expect(paper.binding.toJson(), style.bookDetails.binding.toJson());
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
      expect(filter.backgroundColor, panelChipColor(panel));
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
      await tester.enterText(sourceField, '둘째 문단입니다.');
      await tester.pumpAndSettle();
      await saveWithPhoto(tester);
      expect(store.data.records.single.originals.single.text, '둘째 문단입니다.');
      expect(reading, findsNothing);
      expect(store.data.activePage!.text, isEmpty);
      expect(tester.widget<TextField>(bodyField).controller, same(body));
      expect(tester.widget<TextField>(bodyField).focusNode!.hasFocus, isFalse);
      expect(find.byKey(const ValueKey('transcription-guide')), findsOneWidget);
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
      final frame = tester.getRect(rangePhoto);
      final imageWidth = frame.height * 600 / 800;
      final rightLine = frame.center.dx + imageWidth * (.73 - .5);
      await tester.tapAt(Offset(rightLine, frame.top + frame.height * .22));
      await tester.pumpAndSettle();
      expect(find.textContaining('끝 줄을 누르세요.'), findsOneWidget);
      await tester.tapAt(Offset(rightLine, frame.top + frame.height * .22));
      await tester.pumpAndSettle();
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
    final overlay = find.byKey(const ValueKey('transcription-guide'));
    final painter =
        tester.widget<CustomPaint>(overlay).painter!
            as TranscriptionGuidePainter;
    expect(painter.remainderFor(composing), '천히 내려앉았다.');

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
      expect(store.data.records.last.source, '공유한 문장입니다.');
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
    'Saved original can be transcribed without pre-filling the page',
    (tester) async {
      final store = MemoryStore();
      await open(tester, store, FakeIntake());
      await openRegistration(tester);
      await tester.enterText(sourceField, '한 문장을 옮겨 쓴다.');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await settleSourceSheets(tester);
      await tester.tap(find.text('이 구절 필사하기').hitTestable());
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(bodyField);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('transcription-guide')),
                  )
                  .painter!
              as TranscriptionGuidePainter;
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(painter.remainderFor(field.controller!.value), '한 문장을 옮겨 쓴다.');
      expect(store.data.pages.single.text, isEmpty);
      await tester.enterText(bodyField, '한 문장을');
      await tester.pumpAndSettle();
      expect(find.text('느낀 점'), findsNothing);
      expect(store.data.pages.single.text, '한 문장을');
    },
  );

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
    await tester.tap(find.text('밑칠한 구절만 보기'));
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
