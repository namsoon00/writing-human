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
import 'package:writing_human/ui/photo_original_paper.dart';
import 'package:writing_human/ui/original_list_item.dart';
import 'package:writing_human/ui/original_photo.dart';
import 'package:writing_human/ui/reading_details.dart';
import 'package:writing_human/ui/source_import_sheet.dart';
import 'package:writing_human/ui/source_reading.dart';
import 'package:writing_human/ui/writing_chrome.dart';
import 'package:writing_human/ui/transcription_guide.dart';

import 'widget_test.dart' show MemoryStore;

final sourceField = find.byKey(const ValueKey('source-text'));
final photoPaper = find.byKey(const ValueKey('photo-original-paper'));
final photoCorrection = find.descendant(
  of: find.byType(PhotoOriginalCorrection),
  matching: find.byType(EditableText),
);

Text photoDraft(WidgetTester tester) => tester.widget<Text>(photoPaper);

Future<void> correctPhoto(WidgetTester tester, String text) async {
  await tester.tap(find.text('글 고치기'));
  await tester.pumpAndSettle();
  await tester.enterText(photoCorrection, text);
  await tester.pumpAndSettle();
}

final bodyField = find.byKey(const ValueKey('page-text'), skipOffstage: false);
final confirm = find.byKey(const ValueKey('source-confirm'));
final place = find.byKey(const ValueKey('writing-originals'));
final reading = find.byType(SourceReading);
final readingText = find.byKey(const ValueKey('source-reading-text'));
final transcriptionReference = find.byKey(
  const ValueKey('transcription-reference'),
);
final transcriptionGuide = find.byKey(const ValueKey('transcription-guide'));

String remainingInline(WidgetTester tester) {
  final painter =
      tester.widget<CustomPaint>(transcriptionGuide).painter!
          as TranscriptionGuidePainter;
  final value = tester.widget<TextField>(bodyField).controller!.value;
  return painter.remainderFor(value);
}

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

Future<void> openOriginalRegistration(WidgetTester tester) async {
  final add = find.text('원문 담기').hitTestable();
  if (add.evaluate().isEmpty) {
    await tester.tap(find.byTooltip('원문 더 보기'));
    await tester.pumpAndSettle();
  }
  await tester.tap(add);
  await tester.pumpAndSettle();
}

Future<void> openRegistration(WidgetTester tester) async {
  await tester.tap(place);
  await tester.pumpAndSettle();
  expect(reading, findsOneWidget);
  await openOriginalRegistration(tester);
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
  bool? pickedWithCamera;
  SourcePhoto? recovered;
  SourceScan? positioned;
  Rect? recognizedRegion;
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
    pickedWithCamera = camera;
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

Future<void> saveWithPhoto(WidgetTester tester, {Finder? action}) async {
  await tester.runAsync(() async {
    final archive = find.widgetWithText(TextButton, '원문만 담기');
    await tester.tap(
      action ?? (archive.evaluate().isEmpty ? confirm : archive),
    );
    await tester.pump();
    for (
      var i = 0;
      i < 50 && find.byType(SourceImportSheet).evaluate().isNotEmpty;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 30));
    }
    // Saved originals now open their reader, which loads a local photo.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 30));
    }
  });
  await tester.pumpAndSettle();
}

Future<void> openSourceSearch(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('source-search-direct')));
  await tester.pumpAndSettle();
}

Future<void> showSourceDetails(WidgetTester tester) async {
  final details = find.byKey(const ValueKey('source-details'));
  await tester.ensureVisible(details);
  await tester.pumpAndSettle();
  await tester.tap(details);
  await tester.pumpAndSettle();
}

Future<void> extractPhoto(WidgetTester tester, {bool settle = true}) async {
  final secondary = find.widgetWithText(TextButton, '사진에서 글자 읽기');
  if (secondary.evaluate().isNotEmpty) {
    await tester.ensureVisible(secondary);
    await tester.tap(secondary);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '사진에서 글자 읽기'));
  } else {
    await tester.tap(confirm);
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> openPhotoMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('사진 편집 더 보기'));
  await tester.pumpAndSettle();
}

Future<void> takePhoto(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('source-camera-direct')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Different originals use separate pages while previous writing stays intact',
    (tester) async {
      final store = MemoryStore()
        ..data = existing().copy(
          records: const [
            WritingRecord(
              id: 'r',
              title: '기존 필사',
              originals: [
                RegisteredOriginal('first-slip', '먼저 끼울 구절', citation: '첫 출처'),
                RegisteredOriginal(
                  'second-slip',
                  '나중에 끼울 구절',
                  citation: '둘째 출처',
                ),
              ],
            ),
          ],
        );
      final before = store.data.activePage!;
      await open(tester, store, FakeIntake());
      Future<void> attach(String id) async {
        await tester.tap(place);
        await tester.pumpAndSettle();
        if (find.byTooltip('원문 목록').evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('원문 목록'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(ValueKey(id)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('필사하기'));
        await settleSourceSheets(tester);
      }

      await attach('first-slip');
      final firstPage = store.data.activePage!;
      expect(firstPage.passages.single.original?.text, '먼저 끼울 구절');
      expect(firstPage.passages.single.start, 0);
      expect(firstPage.id, isNot(before.id));
      await attach('second-slip');
      expect(
        store.data.activePage!.passages.single.original?.id,
        'second-slip',
      );
      expect(store.data.activePage!.id, isNot(firstPage.id));
      expect(store.data.pages.first.text, before.text);
      expect(store.data.pages.first.extent, before.extent);
      expect(store.data.activePage!.text, isEmpty);
      expect(find.byKey(const ValueKey('page-original-markers')), findsNothing);
      expect(store.data.activeRecord!.originals, hasLength(2));
    },
  );

  testWidgets(
    'The capture sheet exposes search, camera, paste and explicit save actions',
    (tester) async {
      await preparePhotoStorage(tester);
      final store = MemoryStore();
      final intake = FakeIntake();
      await open(tester, store, intake);
      await openRegistration(tester);

      expect(find.text('원문 담기'), findsOneWidget);
      expect(find.text('사진 찍기').hitTestable(), findsOneWidget);
      expect(sourceField.hitTestable(), findsOneWidget);
      expect(find.text('붙여넣기').hitTestable(), findsOneWidget);
      expect(find.text('새 원문 찾기').hitTestable(), findsOneWidget);
      expect(find.text('작품 제목이나 작가'), findsNothing);
      expect(find.byType(OriginalListItem), findsNothing);
      expect(find.byKey(const ValueKey('original-citation')), findsNothing);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.tap(find.text('사진 고르기'));
      await tester.pumpAndSettle();
      expect(intake.photos, 1);
      expect(intake.scans, 1);
      expect(photoPaper, findsOneWidget);
      expect(sourceField, findsNothing);
      await openPhotoMenu(tester);
      await saveWithPhoto(tester, action: find.text('사진만 담기'));
      expect(store.data.activeRecord!.originals.single.photoId, isNotNull);
      expect(store.data.activeRecord!.originals.single.canTranscribe, isFalse);
      expect(reading, findsOneWidget);
      expect(store.data.activePage!.guidedOriginalId, isNull);
    },
  );

  testWidgets(
    'Camera capture opens all paragraphs and keeps corrections when reading',
    (tester) async {
      final intake = FakeIntake();
      await open(tester, MemoryStore(), intake);
      await openRegistration(tester);
      final camera = find.byKey(const ValueKey('source-camera-direct'));
      expect(
        tester.getTopLeft(camera).dy,
        lessThan(tester.getTopLeft(sourceField).dy),
      );

      await tester.tap(camera);
      await tester.pumpAndSettle();

      expect(intake.photos, 1);
      expect(intake.pickedWithCamera, isTrue);
      expect(intake.scans, 1);
      expect(find.text('원문 확인'), findsOneWidget);
      expect(find.text('구절 고르기'), findsNothing);
      expect(photoDraft(tester).data, '첫 문단입니다.\n\n둘째 문단입나다.');
      expect(photoCorrection, findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(photoPaper);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await correctPhoto(tester, '고친 첫 문단입니다.\n\n둘째 문단입나다.');
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.text('고치기 마치기'));
      await tester.pumpAndSettle();
      await openPhotoMenu(tester);
      expect(find.text('구절 고르기'), findsNothing);
      expect(find.text('옮겨 쓸 구절'), findsNothing);
      await tester.tap(find.text('보정해 다시 읽기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(photoDraft(tester).data, '고친 첫 문단입니다.\n\n둘째 문단입나다.');
    },
  );

  testWidgets(
    'Photo correction selects a word, preserves composing and saves the whole text',
    (tester) async {
      await preparePhotoStorage(tester);
      final store = MemoryStore();
      final intake = FakeIntake();
      const header = '사진의 머리글';
      const first = '처음 남길 글.';
      const second = '둘째 줄입니다.';
      const footer = '마지막 줄';
      intake.positioned = SourceScan(
        intake.photo.bytes,
        const [
          ScanParagraph([
            ScanLine(header, bounds: Rect.fromLTWH(.1, .1, .7, .04)),
          ]),
          ScanParagraph([
            ScanLine(first, bounds: Rect.fromLTWH(.1, .3, .7, .04)),
            ScanLine(second, bounds: Rect.fromLTWH(.1, .35, .7, .04)),
          ]),
          ScanParagraph([
            ScanLine(footer, bounds: Rect.fromLTWH(.1, .9, .7, .04)),
          ]),
        ],
        width: 800,
        height: 1000,
      );
      await open(tester, store, intake);
      tester.view.physicalSize = const Size(320, 640);
      await openRegistration(tester);
      await takePhoto(tester);
      expect(photoDraft(tester).data, '$header\n\n$first\n$second\n\n$footer');
      final archive = find.widgetWithText(TextButton, '원문만 담기');
      expect(archive.hitTestable(), findsOneWidget);
      expect(store.data.records, isEmpty);

      await correctPhoto(tester, '$header\n\n$first\n$second\n\n고친 마지막 줄');
      final controller = tester
          .widget<EditableText>(photoCorrection)
          .controller;
      final render = tester
          .state<EditableTextState>(photoCorrection)
          .renderEditable;
      final word = render.localToGlobal(
        render.getLocalRectForCaret(const TextPosition(offset: 1)).center,
      );
      await tester.tapAt(word);
      await tester.pump(const Duration(milliseconds: 65));
      await tester.tapAt(word);
      await tester.pumpAndSettle();
      expect(controller.selection.textInside(controller.text), '사진의');
      expect(
        find.byKey(const ValueKey('paper-selection-menu')),
        findsOneWidget,
      );

      final revised = controller.value.replaced(controller.selection, '고친 사진의');
      tester.testTextInput.updateEditingValue(
        revised.copyWith(
          selection: TextSelection.collapsed(offset: revised.text.length),
        ),
      );
      await tester.pumpAndSettle();
      final corrected = controller.text;
      expect(corrected, '고친 $header\n\n$first\n$second\n\n고친 마지막 줄');
      final composing = TextRange(
        start: corrected.length - 1,
        end: corrected.length,
      );
      tester.testTextInput.updateEditingValue(
        controller.value.copyWith(composing: composing),
      );
      await tester.pumpAndSettle();
      expect(controller.value.composing, composing);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '고치기 마치기'))
            .onPressed,
        isNull,
      );
      expect(tester.widget<TextButton>(archive).onPressed, isNull);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '필사하기'))
            .onPressed,
        isNull,
      );

      tester.testTextInput.updateEditingValue(
        controller.value.copyWith(composing: TextRange.empty),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('고치기 마치기'));
      await tester.pumpAndSettle();
      expect(photoCorrection, findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(photoDraft(tester).data, corrected);
      await saveWithPhoto(
        tester,
        action: find.widgetWithText(FilledButton, '필사하기'),
      );
      await settleSourceSheets(tester);

      final page = store.data.activePage!;
      expect(
        page.guidedOriginalId,
        store.data.activeRecord!.originals.single.id,
      );
      expect(page.text, isEmpty);
      expect(reading, findsNothing);
      expect(tester.widget<TextField>(bodyField).focusNode!.hasFocus, isTrue);
      final original = store.data.activeRecord!.originals.single;
      expect(original.text, corrected);
      expect(page.passages.single.original?.text, corrected);
      expect(original.photoId, isNotNull);
      expect(original.writingRange, isNull);
      expect(
        OriginalPhotoLine.validList(original.text, original.photoLines),
        isTrue,
      );
      expect(
        original.photoLines.map(
          (line) => original.text.substring(line.range.start, line.range.end),
        ),
        [first, second],
      );
      expect(original.photoLines.first.top, 3000);
      expect(original.photoLines.last.top, 3500);
      expect(store.data.activePage!.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

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
      await openPhotoMenu(tester);
      await tester.tap(find.text('보정해 다시 읽기'));
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (photoPaper.evaluate().isNotEmpty &&
            photoDraft(tester).data == intake.blocks.single) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
    });
    await tester.pumpAndSettle();
    expect(photoDraft(tester).data, '보정 후 다시 읽은 문장');
    await openPhotoMenu(tester);
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
    await tester.tap(confirm);
    await settleSourceSheets(tester);
    await tester.tap(find.text('필사하기'));
    await tester.pumpAndSettle();
    expect(store.data.activeRecord!.originals.single.text, cleaned);
    expect(store.data.activePage!.text, isEmpty);
    expect(remainingInline(tester), cleaned);
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
    expect(store.data.activeRecord!.originals.single.text, '고치기 전 원문');

    store.fail = true;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('수정 내용을 저장하지 못했어요. 입력한 내용은 남아 있어요.'), findsOneWidget);
    expect(tester.widget<TextField>(text).controller!.text, '"고친 글"...');
    expect(store.data.activeRecord!.originals.single.text, '고치기 전 원문');
    store.fail = false;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(text, findsNothing);
    expect(store.data.activeRecord!.originals.single.text, '"고친 글"...');
    expect(store.data.activeRecord!.originals.single.citation, '개정판');
    expect(store.data.activeRecord!.originals.single.id, 'source');
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
      expect(store.data.activeRecord!.originals.length, 2);

      store.fail = true;
      await askToDelete();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(find.text('원문을 삭제하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(
        store.data.activeRecord!.originals.first.reflection!.text,
        '함께 지울 느낀 점',
      );

      store.fail = false;
      await askToDelete();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(find.text('남겨 둘 원문'), findsOneWidget);
      expect(find.text('지울 원문'), findsNothing);
      expect(store.data.activeRecord!.originals.single.id, 'keep');
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
    final search = find.byKey(const ValueKey('saved-original-search'));
    final register = find.widgetWithText(TextButton, '원문 담기');
    expect(tester.widget<TextField>(search).decoration!.hintText, '담은 원문 찾기');
    expect(find.text('새 원문 찾기'), findsNothing);
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
    await tester.tap(find.byTooltip('검색 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('눈 내리는 저녁'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(search.hitTestable(), findsOneWidget);
    expect(register.hitTestable(), findsOneWidget);
    expect(find.text('밑칠만 보기').hitTestable(), findsOneWidget);
    await tester.tap(register);
    await tester.pumpAndSettle();
    expect(find.byType(SourceImportSheet), findsOneWidget);
    expect(find.text('새 원문 찾기'), findsOneWidget);
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
      await openSourceSearch(tester);
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

  testWidgets(
    'iOS search taps place the caret between characters and preserve composing',
    (tester) async {
      await open(tester, MemoryStore(), FakeIntake());
      await openRegistration(tester);
      await openSourceSearch(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, '웹 검색'));
      await tester.pumpAndSettle();

      final input = find.widgetWithText(TextField, '검색어');
      await tester.tap(input);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(input, '하늘을우러러');
      await tester.pump();
      final field = tester.widget<TextField>(input);
      final editor = field.focusNode!.context!
          .findAncestorStateOfType<EditableTextState>()!;
      final render = editor.renderEditable;
      Offset pointAt(int offset) => render.localToGlobal(
        render.getLocalRectForCaret(TextPosition(offset: offset)).center,
      );

      await tester.tapAt(pointAt(2));
      await tester.pump();
      expect(field.controller!.selection.extentOffset, 2);

      const composing = TextEditingValue(
        text: '하느을우러러',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pump();
      await tester.tapAt(pointAt(4));
      await tester.pump();
      expect(field.controller!.value, composing);
      expect(tester.testTextInput.isVisible, isTrue);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

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
      await openSourceSearch(tester);
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
      expect(find.text('웹 원문 · 복사 또는 캡처'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '작품 둘러보기'));
      await tester.pumpAndSettle();
      expect(find.text('작품 제목이나 작가'), findsOneWidget);
      expect(result, findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '웹 검색'));
      await tester.pumpAndSettle();
      expect(result, findsOneWidget);
      expect(find.text('바다와 나비'), findsNothing);
      expect(find.text('두시언해/서시흥'), findsNothing);
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(find.text('원문을 복사하거나 화면을 캡처한 뒤 가져오세요.'), findsOneWidget);
      await tester.tap(find.text('출처만 넣기'));
      await tester.pumpAndSettle();
      await showSourceDetails(tester);
      final citation = tester.widget<TextField>(
        find.byKey(const ValueKey('original-citation')),
      );
      expect(citation.controller!.text, contains('curid=1516'));
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '직접 고른 구절',
      );
      expect(store.data.records, isEmpty);
      await openSourceSearch(tester);
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
      final collect = find.text('복사한 글과 출처 가져오기');
      await tester.tap(collect);
      await tester.pumpAndSettle();
      expect(find.text('복사한 글이 없어요.'), findsOneWidget);
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
        store.data.activeRecord!.originals.single.citation,
        contains('위키문헌'),
      );
    }, () => client);
  });

  for (final fromBrowser in [false, true]) {
    testWidgets(
      'A web screenshot is read with its source (from browser: $fromBrowser)',
      (tester) async {
        final client = MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'query': {
                  'search': [
                    {'title': '검수 작품', 'pageid': 5182},
                  ],
                },
              }),
            ),
            200,
          ),
        );
        await http.runWithClient(() async {
          await preparePhotoStorage(tester);
          final store = MemoryStore()..data = existing();
          final intake = FakeIntake();
          await open(tester, store, intake);
          await openRegistration(tester);

          Future<void> findSource() async {
            await openSourceSearch(tester);
            await tester.tap(find.widgetWithText(ChoiceChip, '웹 검색'));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.widgetWithText(TextField, '검색어'),
              '검수 작품',
            );
            await tester.tap(find.byTooltip('자료 검색'));
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(ListTile, '검수 작품'));
            await tester.pumpAndSettle();
            if (fromBrowser) {
              await tester.tap(find.text('원문 열기'));
              await tester.pumpAndSettle();
              expect(find.byTooltip('원문 브라우저 닫기'), findsOneWidget);
            }
          }

          const oldText = '직접 적은 초안';
          const oldCitation = '메모해 둔 출처';
          if (fromBrowser) {
            await tester.enterText(sourceField, oldText);
            await showSourceDetails(tester);
            await tester.enterText(
              find.byKey(const ValueKey('original-citation')),
              oldCitation,
            );
          }
          await findSource();
          final capture = find.text('캡처 가져오기');
          expect(capture.hitTestable(), findsOneWidget);
          intake.cancelPicker = true;
          await tester.tap(capture);
          await tester.pumpAndSettle();
          expect(capture.hitTestable(), findsOneWidget);
          expect(intake.scans, 0);
          intake.cancelPicker = false;

          if (fromBrowser) {
            intake.blocks = [];
            await tester.tap(capture);
            await tester.pumpAndSettle();
            expect(find.text('입력한 원문을 바꿀까요?'), findsOneWidget);
            await tester.tap(find.text('바꾸기'));
            await tester.pumpAndSettle();
            expect(intake.scans, 1);
            expect(
              tester.widget<TextField>(sourceField).controller!.text,
              oldText,
            );
            expect(
              tester
                  .widget<TextField>(
                    find.byKey(const ValueKey('original-citation')),
                  )
                  .controller!
                  .text,
              oldCitation,
            );
            expect(find.textContaining('읽힌 글자가 없어요.'), findsOneWidget);
            intake.blocks = ['캡처 첫 문단', '캡처 둘째 문단'];
            await findSource();
          } else {
            intake.blocks = ['캡처 첫 문단', '캡처 둘째 문단'];
          }
          await tester.tap(capture);
          await tester.pumpAndSettle();
          if (fromBrowser) {
            await tester.tap(find.text('바꾸기'));
            await tester.pumpAndSettle();
          }
          expect(intake.photos, fromBrowser ? 3 : 2);
          expect(intake.pickedWithCamera, isFalse);
          expect(intake.scans, fromBrowser ? 2 : 1);
          expect(find.text('원문 확인'), findsOneWidget);
          expect(photoDraft(tester).data, '캡처 첫 문단\n\n캡처 둘째 문단');
          expect(store.data.activeRecord!.originals, isEmpty);
          await saveWithPhoto(tester);
          final saved = store.data.activeRecord!.originals.single;
          expect(saved.text, '캡처 첫 문단\n\n캡처 둘째 문단');
          expect(saved.citation, contains('curid=5182'));
          expect(saved.photoId, isNotNull);
          expect(store.data.activePage!.text, existing().activePage!.text);
        }, () => client);
      },
    );
  }

  testWidgets(
    'The catalog combines genre and author filters and imports prose',
    (tester) async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'parse': {
                'pageid': 2370,
                'revid': 468924,
                'categories': [
                  {'category': 'PD-old-50'},
                ],
                'text':
                    '<div class="mw-parser-output"><div class="ws-header">'
                    '<p>작품 머리말</p></div><p>첫 문단<sup>각주</sup></p>'
                    '<p>둘째 문단</p></div>',
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
        await openSourceSearch(tester);
        await tester.enterText(
          find.byKey(const ValueKey('source-catalog-query')),
          '현 진 건',
        );
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        final novel = find.byKey(const ValueKey('wikisource-work-2370'));
        final poemFilter = find.widgetWithText(ChoiceChip, '시');
        final novelFilter = find.widgetWithText(ChoiceChip, '소설');
        await tester.tap(poemFilter);
        await tester.pumpAndSettle();
        expect(novel, findsNothing);
        expect(find.text('다른 제목이나 작가로 찾거나 갈래를 바꿔 보세요.'), findsOneWidget);
        await tester.tap(novelFilter);
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(tester.widget<ChoiceChip>(novelFilter).selected, isTrue);
        final card = tester.widget<OriginalListItem>(novel);
        expect(card.indexCard, isTrue);
        expect(card.subtitle, contains('현진건 · 소설 · 약 '));
        expect(card.preview, startsWith('새침하게'));
        await tester.tap(novel);
        await tester.pumpAndSettle();
        expect(requests.single.queryParameters['oldid'], '468924');
        await tester.tap(find.byTooltip('작품 목록으로 돌아가기'));
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(novelFilter).selected, isTrue);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('source-catalog-query')),
              )
              .controller!
              .text,
          '현 진 건',
        );
        await tester.tap(novel);
        await tester.pumpAndSettle();
        await tester.tap(find.text('원문 가져오기'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(sourceField).controller!.text,
          '첫 문단\n\n둘째 문단',
        );
        await showSourceDetails(tester);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('original-citation')),
              )
              .controller!
              .text,
          contains('운수 좋은 날 · 현진건 · 위키문헌'),
        );
        expect(store.data.records, isEmpty);
      }, () => client);
    },
  );

  testWidgets('Reviewed poem imports all stanzas and keeps line breaks', (
    tester,
  ) async {
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
      await openSourceSearch(tester);
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
      expect(find.byType(CheckboxListTile), findsNothing);
      final import = find.widgetWithText(FilledButton, '원문 가져오기');
      await tester.tap(import);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '첫 연\n둘째 줄\n\n고르지 않은 연\n\n마지막 연\n다음 줄',
      );
      await showSourceDetails(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('original-citation')))
            .controller!
            .text,
        '서시 · 윤동주 · 위키문헌 · https://ko.wikisource.org/w/index.php?oldid=387685',
      );
      expect(store.data.records, isEmpty);
    }, () => client);
  });

  testWidgets(
    'A collection title opens a preview and only explicit save starts writing',
    (tester) async {
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
        final more = find.text('새 원문 찾기');
        await tester.ensureVisible(more);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(find.text('작품 제목이나 작가'), findsOneWidget);
        expect(find.widgetWithText(TextField, '검색어'), findsNothing);
        expect(requests, isEmpty);
        await tester.enterText(
          find.byKey(const ValueKey('source-catalog-query')),
          '산 유 화',
        );
        await tester.pumpAndSettle();
        final poem = find.byKey(const ValueKey('wikisource-work-1522'));
        await tester.ensureVisible(poem);
        await tester.pumpAndSettle();
        expect(tester.widget<OriginalListItem>(poem).indexCard, isTrue);
        await tester.tap(poem);
        await settleSourceSheets(tester);
        expect(requests.single.queryParameters['oldid'], '430577');
        expect(find.text('원문 미리보기'), findsOneWidget);
        expect(store.writes, 0);
        await tester.tap(find.text('원문 가져오기'));
        await tester.pumpAndSettle();
        expect(store.writes, 0);
        await tester.tap(find.text('필사하기'));
        await settleSourceSheets(tester);
        expect(find.byType(SourceImportSheet), findsNothing);
        final saved = store.data.activeRecord!.originals.single;
        expect(saved.text, '첫 줄\n둘째 줄');
        expect(store.data.activePage!.guidedOriginalId, saved.id);
        expect(remainingInline(tester), saved.text);
      }, () => client);
    },
  );

  for (final existingText in [false, true]) {
    testWidgets(
      'Poems from source search preview and start writing with the full text (existing text: $existingText)',
      (tester) async {
        final requests = <Uri>[];
        final client = MockClient((request) async {
          requests.add(request.url);
          if (!existingText && requests.length == 1) {
            return http.Response('', 503);
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'parse': {
                  'pageid': 1515,
                  'revid': 387685,
                  'categories': [
                    {'category': 'PD-old-70'},
                  ],
                  'text': '<div class="poem"><p>첫 번째 연</p><p>옮겨 쓸 연</p></div>',
                },
              }),
            ),
            200,
          );
        });
        await http.runWithClient(() async {
          final store = MemoryStore();
          if (existingText) {
            store.data = const Library(
              records: [
                WritingRecord(
                  id: 'r',
                  title: '기록',
                  originals: [RegisteredOriginal('previous', '이미 담은 원문')],
                ),
              ],
              pages: [
                WritingPage(id: 'p', recordId: 'r', number: 1, text: '이미 쓴 글'),
              ],
              activePageId: 'p',
              writing: true,
            );
          }
          await open(tester, store, FakeIntake());
          if (existingText) {
            await tester.tap(place);
            await tester.pumpAndSettle();
            await openOriginalRegistration(tester);
          } else {
            await openRegistration(tester);
          }
          expect(requests, isEmpty);
          expect(find.text('작품 제목이나 작가'), findsNothing);
          await tester.tap(find.text('새 원문 찾기'));
          await tester.pumpAndSettle();
          expect(find.text('작품 제목이나 작가'), findsOneWidget);
          expect(requests, isEmpty);
          final poem = find.byKey(const ValueKey('wikisource-work-1515'));
          await tester.ensureVisible(poem);
          await tester.tap(poem);
          await settleSourceSheets(tester);
          if (!existingText) {
            expect(find.textContaining('원문 미리보기를 불러오지 못했어요'), findsOneWidget);
            expect(store.writes, 0);
            await tester.tap(find.text('다시 시도'));
            await settleSourceSheets(tester);
          }
          expect(
            requests.map((request) => request.queryParameters['oldid']),
            List.filled(existingText ? 1 : 2, '387685'),
          );
          expect(find.text('원문 미리보기'), findsOneWidget);
          expect(find.byType(SourceImportSheet), findsNothing);
          expect(
            store.data.records
                .expand((r) => r.originals)
                .where((o) => o.citation.contains('oldid=387685')),
            isEmpty,
          );
          await tester.tap(find.text('원문 가져오기'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('필사하기'));
          await settleSourceSheets(tester);
          final saved = store.data.activeRecord!.originals.last;
          final page = store.data.activePage!;
          expect(saved.text, '첫 번째 연\n\n옮겨 쓸 연');
          expect(saved.citation, contains('oldid=387685'));
          expect(page.guidedOriginalId, saved.id);
          expect(page.text, isEmpty);
          expect(page.referenceOnly, isFalse);
          if (existingText) {
            expect(store.data.pages.first.text, '이미 쓴 글');
            expect(store.data.pages.first.guidedOriginalId, isNull);
            expect(page.number, 1);
            expect(
              store.data.activeRecord!.id,
              isNot(store.data.records.first.id),
            );
          }
          expect(reading, findsNothing);
          expect(find.byType(SourceImportSheet), findsNothing);
          expect(remainingInline(tester), saved.text);
        }, () => client);
      },
    );
  }

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
    expect(store.data.activeRecord!.originals.single.reflection!.text, note);
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
      await showSourceDetails(tester);
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
    await tester.tap(closeIn(reading));
    await tester.pumpAndSettle();
    await tester.tap(find.text('책장'));
    await tester.pumpAndSettle();
    expect(find.text('목차'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('shelf-book-b')));
    await tester.pumpAndSettle();
    final collection = find.byType(CollectionSheet);
    final bookOriginals = find.descendant(
      of: collection,
      matching: find.text('원문'),
    );
    await tester.ensureVisible(bookOriginals);
    await tester.tap(bookOriginals);
    await tester.pumpAndSettle();
    await openOriginalRegistration(tester);
    await saveOriginal(second, '45쪽');
    expect(store.data.books.first.originals.map((entry) => entry.text), [
      first,
      second,
    ]);
    expect(store.data.books.last.originals.single.id, 'other-original');
    expect(store.data.pages.map((page) => page.text), ['', '먼저 쓰던 기록']);
    await tester.tap(closeIn(reading));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contents-record-r2')));
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
    await openOriginalRegistration(tester);
    await saveOriginal('정오의 종소리가 들렸다.', '60쪽');
    expect(store.data.books.first.originals, hasLength(3));
    expect(
      tester.widget<Text>(readingText).textSpan!.toPlainText(),
      '정오의 종소리가 들렸다.',
    );
    expect(find.text('필사하기'), findsOneWidget);
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
    'Existing reflections remain editable without changing the writing paper',
    (tester) async {
      const source = '햇빛이 책장에 천천히 내려앉았다.';
      final store = MemoryStore()
        ..data = const Library(
          books: [
            Book(
              id: 'b',
              title: '책',
              originals: [
                RegisteredOriginal(
                  'o',
                  source,
                  citation: '첫 원문',
                  reflection: OriginalReflection('이전에 남긴 생각'),
                ),
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
      await tester.tap(find.text('이전에 남긴 생각'));
      await tester.pumpAndSettle();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '하ㄴ',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        store.data.books.single.originals.first.reflection!.text,
        '이전에 남긴 생각',
      );

      store.fail = true;
      await tester.enterText(field, note);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('느낀 점을 저장하지 못했어요.'), findsOneWidget);
      final retry = find.descendant(of: reading, matching: find.text('다시 저장'));
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
    'Originals use a fixed background and keep the book slip and divider',
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
      final writingPaper = tester.widget<PaperBackdrop>(
        find.ancestor(of: place, matching: find.byType(PaperBackdrop)),
      );
      expect(writingPaper.color, paperColors[3]);
      await tester.tap(place);
      await tester.pumpAndSettle();
      final surface = find.byKey(const ValueKey('source-paper'));
      final paper = tester.widget<PaperBackdrop>(
        find.descendant(of: surface, matching: find.byType(PaperBackdrop)),
      );
      expect(tester.widget<PaperPanel>(surface).color, paper.color);
      const panel = originalPanelColor;
      expect(panel, isNot(writingPaper.color));
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
      expect(sourceCard.indexCard, isTrue);
      expect(find.text('책'), findsOneWidget);
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

      await openOriginalRegistration(tester);
      final capture = find.byType(SourceImportSheet);
      expect(
        tester
            .widget<Scaffold>(
              find.ancestor(of: capture, matching: find.byType(Scaffold)).first,
            )
            .backgroundColor,
        panel,
      );
      expect(find.text('서시'), findsNothing);
      final catalog = find.text('새 원문 찾기');
      await tester.ensureVisible(catalog);
      await tester.tap(catalog);
      await tester.pumpAndSettle();
      final title = find.text('서시');
      await tester.ensureVisible(title);
      final row = find.ancestor(
        of: title,
        matching: find.byType(OriginalListItem),
      );
      final suggestionCard = tester.widget<SourceSlip>(
        find.descendant(of: row, matching: find.byType(SourceSlip)),
      );
      expect(suggestionCard.choice.toJson(), sourceCard.choice.toJson());
      expect(suggestionCard.panelColor, sourceCard.panelColor);
      expect(suggestionCard.compact, sourceCard.compact);
      expect(suggestionCard.indexCard, sourceCard.indexCard);
      expect(tester.widget<Text>(title).style!.fontFamily, 'NanumGothic');
      expect(
        tester
            .widget<RecordDivider>(
              find.descendant(of: row, matching: find.byType(RecordDivider)),
            )
            .choice
            .toJson(),
        divider.toJson(),
      );
      expect(
        tester
            .widget<PaperPanel>(
              find.ancestor(
                of: find.text('새 원문 찾기'),
                matching: find.byType(PaperPanel),
              ),
            )
            .color,
        panel,
      );
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
    expect(find.text('느낀 점 남기기'), findsNothing);
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
      expect(store.data.activeRecord!.originals.single.text, '첫 줄\n\n둘째 줄');
      expect(reading, findsOneWidget);
      await tester.tap(closeIn(reading));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(bodyField).controller, same(body));
      expect(body.value, original);
      expect(store.data.activePageId, 'p');
      await settleSourceSheets(tester);
      await tester.tap(place.hitTestable());
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(readingText).textSpan!.toPlainText(),
        '첫 줄\n\n둘째 줄',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Photo text cleanup can save corrected paragraphs without opening transcription',
    (tester) async {
      await preparePhotoStorage(tester);
      final store = MemoryStore();
      final intake = FakeIntake();
      await open(tester, store, intake);
      final body = tester.widget<TextField>(bodyField).controller!;
      await openRegistration(tester);
      await takePhoto(tester);
      expect(intake.photos, 1);
      expect(find.text('원문 확인'), findsOneWidget);
      expect(store.data.records, isEmpty);
      await correctPhoto(tester, '첫 문단입니다.\n\n“둘째 문단입니다.”');
      final cleanup = find.text('특수문자 정리');
      await tester.ensureVisible(cleanup);
      await tester.tap(cleanup);
      await tester.pumpAndSettle();
      await saveWithPhoto(tester);
      expect(
        store.data.activeRecord!.originals.single.text,
        '첫 문단입니다.\n\n"둘째 문단입니다."',
      );
      expect(reading, findsOneWidget);
      await tester.tap(closeIn(reading));
      await tester.pumpAndSettle();
      expect(store.data.activePage!.text, isEmpty);
      expect(tester.widget<TextField>(bodyField).controller, same(body));
      expect(tester.widget<TextField>(bodyField).focusNode!.hasFocus, isFalse);
      expect(transcriptionReference, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Page review stores the whole page with line positions and exact photo bytes',
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
      expect(photoDraft(tester).data, '왼쪽 문단\n\n오른쪽 문단');
      expect(intake.photos, 1);
      await tester.tap(find.byTooltip('사진 크게 보기'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('인식한 책 사진'), findsOneWidget);
      await tester.tap(find.byTooltip('큰 사진 닫기'));
      await tester.pumpAndSettle();
      await showSourceDetails(tester);
      final citation = find.byKey(const ValueKey('original-citation'));
      await tester.ensureVisible(citation);
      await tester.enterText(citation, '12쪽');
      await tester.pumpAndSettle();
      await saveWithPhoto(tester);
      final original = store.data.activeRecord!.originals.single;
      expect(original.text, '왼쪽 문단\n\n오른쪽 문단');
      expect(original.citation, '12쪽');
      expect(original.isFullPage, isTrue);
      expect(original.photoLines, hasLength(2));
      expect(original.writingRange, isNull);
      final bytes = await tester.runAsync(
        () => const OriginalPhotoStore().load(original.photoId!),
      );
      expect(bytes, intake.photo.bytes);
      expect(matchOriginal([original], '왼쪽', 2)?.remainder, ' 문단');
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
      await extractPhoto(tester);
      expect(find.textContaining('읽힌 글자가 없어요'), findsOneWidget);
      expect(
        tester.widget<TextField>(sourceField).controller!.text,
        '직접 입력한 원문',
      );
      intake.reading = Completer<List<String>>();
      await extractPhoto(tester, settle: false);
      expect(find.text('사진 속 글자를 읽고 있어요'), findsOneWidget);
      await tester.tap(closeIn(find.byType(SourceImportSheet)));
      await tester.pumpAndSettle();
      expect(find.text('담지 않은 원문을 닫을까요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '닫기'));
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
      await showSourceDetails(tester);
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
      expect(find.text('원문을 저장하지 못했어요. 이 화면에서 다시 담아 주세요.'), findsOneWidget);
      expect(store.data.records, hasLength(1));
      expect(intake.shares, hasLength(1));
      expect(intake.acknowledged, isEmpty);
      store.fail = false;
      await tester.tap(confirm);
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
      expect(find.text('담기'), findsOneWidget);
      expect(tester.getSize(sheet), const Size(320, 640));
      expect(tester.getBottomLeft(confirm).dy, closeTo(628, 1));
      final sourceCaret = find.descendant(of: sheet, matching: caret);
      expect(sourceCaret, findsOneWidget);
      expect(tester.widget<TextField>(sourceField).showCursor, isFalse);
      double caretLeft() {
        late double left;
        expect(
          tester.renderObject(sourceCaret),
          paints..something((method, arguments) {
            if (method != #drawRRect) return false;
            left = (arguments.first as RRect).left;
            return true;
          }),
        );
        return left;
      }

      final initialCaret = caretLeft();
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
      expect(caretLeft(), greaterThan(initialCaret));
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
      expect(store.data.activeRecord!.originals.single.text, '한');
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
      await tester.tap(confirm);
      await settleSourceSheets(tester);
      final previousPage = store.data.activePage!.toJson();
      await tester.tap(find.text('필사하기'));
      await settleSourceSheets(tester);
      expect(store.data.activePageId, isNot(previousPage['id']));
      expect(store.data.pages, hasLength(2));
      expect(store.data.pages.first.toJson(), previousPage);
      final field = tester.widget<TextField>(bodyField);
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(remainingInline(tester), original);
      expect(store.data.activePage!.text, isEmpty);
      await tester.enterText(bodyField, '한 문쟝을');
      await tester.pumpAndSettle();
      expect(remainingInline(tester), '장을 옮겨 쓴다.\n$second');
      expect(store.data.activePage!.text, '한 문쟝을');
      const composing = TextEditingValue(
        text: '한 문쟝을 ㅇ',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 6, end: 7),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(remainingInline(tester), '장을 옮겨 쓴다.\n$second');
      expect(field.controller!.value, composing);
      await tester.enterText(bodyField, '한 문장을');
      await tester.pumpAndSettle();
      expect(find.text('느낀 점'), findsNothing);
      expect(store.data.activePage!.text, '한 문장을');
      await tester.enterText(bodyField, '$first\n');
      await tester.pumpAndSettle();
      expect(remainingInline(tester), second);
      expect(store.data.activePage!.text, '$first\n');
      const mistyped = '한 문쟝을 옮겨 쓴다.\n';
      await tester.enterText(bodyField, mistyped);
      await tester.pumpAndSettle();
      expect(store.data.activePage!.text, mistyped);
      final saved = store.data;
      expect(
        saved.activePage!.guidedOriginalId,
        saved.activeRecord!.originals.single.id,
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
      expect(remainingInline(tester), second);
      expect(reopened.focusNode!.hasFocus, isFalse);
    },
  );

  test('Transcription waits for the text to resume after an interruption', () {
    final comparison = TranscriptionComparison(
      const RegisteredOriginal('o', '가나다라마바사.'),
    );
    expect(comparison.remainderFor('가나다라'), '마바사.');
    expect(comparison.remainderFor('가X나'), '나다라마바사.');
    expect(comparison.remainderFor('가X나다라'), '마바사.');
    expect(comparison.remainderFor('가낙다라마'), '바사.');
    expect(comparison.remainderFor('가나다라마바사.X'), isEmpty);
    expect(comparison.remainderFor('가나'), '다라마바사.');
  });

  test('Reference progress waits when a forward match is repeated', () {
    final comparison = TranscriptionComparison(
      const RegisteredOriginal('o', '첫 문장. 중간 구절. 나무 아래 새가 울고 나무 아래 바람이 분다.'),
    );
    const note = '첫 문장.\n메모를 남겨요.\n';
    const remainder = ' 중간 구절. 나무 아래 새가 울고 나무 아래 바람이 분다.';
    expect(comparison.remainderFor('$note나무 아래'), remainder);
    expect(comparison.remainderFor('$note나무 아래 바람'), '이 분다.');
  });

  test('Reference ignores formatting and tracks the original offsets', () {
    const original = '가😀·「漢」\r\n나, 다!';
    final comparison = TranscriptionComparison(
      const RegisteredOriginal('o', original),
    );

    expect(comparison.sourceOffsetFor('가!?1️⃣漢  나 다'), original.length);
    expect(comparison.remainderFor('가漢나다'), isEmpty);
    expect(comparison.remainderFor('가--漢\n'), '나, 다!');
    expect(comparison.remainderFor('가--漢'), '」\r\n나, 다!');
    expect(comparison.remainderFor('가--漢', composingLength: 1), ', 다!');
    expect(
      comparison.remainderFor('가—字', composingLength: 1),
      '😀·「漢」\r\n나, 다!',
    );
  });

  testWidgets(
    'The visible original waits through a detour and resumes at the next matching passage',
    (tester) async {
      const first = '첫 문장을 씁니다.';
      const skipped = '중간에 건너뛸 문장이 있습니다.';
      const next = '다음 구절을 이어 씁니다.';
      const last = '마지막 줄입니다.';
      const original = '$first\n$skipped\n$next\n$last';
      final store = MemoryStore()
        ..data = const Library(
          records: [
            WritingRecord(
              id: 'r',
              title: '필사',
              originals: [RegisteredOriginal('o', original)],
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
      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      await tester.showKeyboard(bodyField);
      await tester.pumpAndSettle();

      const note = '첫문장을씁니다!\n잠시 내 생각을 적습니다.\n';
      await tester.enterText(bodyField, note);
      await tester.pumpAndSettle();
      expect(remainingReference(tester), '$skipped\n$next\n$last');
      expect(referenceText(tester).toPlainText(), original);
      expect(store.data.activePage!.text, note);

      final partial = TextEditingValue(
        text: '$note다음 구',
        selection: TextSelection.collapsed(offset: note.length + 4),
        composing: TextRange(start: note.length + 3, end: note.length + 4),
      );
      tester.testTextInput.updateEditingValue(partial);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(bodyField);
      expect(field.controller!.value, partial);
      expect(remainingReference(tester), '$skipped\n$next\n$last');

      const resumed = '$note다음 구절';
      await tester.enterText(bodyField, resumed);
      await tester.pumpAndSettle();
      expect(remainingReference(tester), '을 이어 씁니다.\n$last');
      expect(store.data.activePage!.text, resumed);
      expect(referenceText(tester).toPlainText(), original);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        expect(find.bySemanticsLabel('원문과 다른 글자 확인'), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Guided writing follows the line on roomy paper', (tester) async {
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
    expect(transcriptionGuide, findsOneWidget);
    expect(transcriptionReference, findsNothing);
    expect(remainingInline(tester), '$first\n$second\n$third');
    const keyboard = 290.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
    await tester.showKeyboard(bodyField);
    await tester.pumpAndSettle();
    expect(transcriptionGuide, findsNothing);
    expect(transcriptionReference, findsOneWidget);
    expect(remainingReference(tester), '$first\n$second\n$third');
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
    expect(caretY(), lessThan(middle));
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
    'Keyboard visibility switches the original without changing Korean composition',
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
      final field = tester.widget<TextField>(bodyField);
      expect(transcriptionGuide, findsOneWidget);
      expect(transcriptionReference, findsNothing);
      expect(remainingInline(tester), passage);
      expect(field.controller!.text, isEmpty);
      expect(
        field.scrollController!.position.maxScrollExtent,
        greaterThan(500),
      );

      tester.view.physicalSize = const Size(320, 350);
      await tester.pumpAndSettle();
      expect(transcriptionGuide, findsOneWidget);
      expect(transcriptionReference, findsNothing);

      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      await tester.showKeyboard(bodyField);
      await tester.pumpAndSettle();
      expect(transcriptionGuide, findsNothing);
      expect(transcriptionReference, findsOneWidget);
      expect(field.controller!.text, isEmpty);

      const composing = TextEditingValue(
        text: '첫 줄을 ㅇ',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 5, end: 6),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(remainingReference(tester), passage.substring(5));
      expect(field.controller!.value, composing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(transcriptionGuide, findsOneWidget);
      expect(transcriptionReference, findsNothing);
      expect(field.controller!.value, composing);
      expect(remainingInline(tester), passage.substring(6));

      await tester.enterText(bodyField, '첫 줄윽');
      await tester.pumpAndSettle();
      field.focusNode!.unfocus();
      await tester.pumpAndSettle();
      expect(transcriptionGuide, findsOneWidget);
      expect(transcriptionReference, findsNothing);
      expect(remainingInline(tester), passage.substring(3));
      expect(store.data.activePage!.text, '첫 줄윽');
      expect(store.data.activePage!.guidedOriginalId, 'o');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Repeated keyboard transitions keep the written text and paper position',
    (tester) async {
      final lines = List.generate(30, (i) => '${i + 1}번째 줄을 옮겨 적는다.');
      final written = lines.take(16).join('\n');
      final caret = lines.take(5).join('\n').length;
      const paperOffset = 90.0;
      final store = MemoryStore()
        ..data = Library(
          records: [
            WritingRecord(
              id: 'r',
              title: '필사',
              originals: [RegisteredOriginal('o', lines.join('\n'))],
            ),
          ],
          pages: [
            WritingPage(
              id: 'p',
              recordId: 'r',
              number: 1,
              text: written,
              base: caret,
              extent: caret,
              scroll: paperOffset,
              guidedOriginalId: 'o',
            ),
          ],
          activePageId: 'p',
          writing: true,
        );
      await open(tester, store, FakeIntake());
      final field = tester.widget<TextField>(bodyField);
      final controller = field.controller!;
      final value = controller.value;
      final paper = field.scrollController!;
      final dismiss = find.widgetWithIcon(
        IconButton,
        CupertinoIcons.keyboard_chevron_compact_down,
      );

      expect(paper.offset, paperOffset);
      for (final dismissWithButton in [false, true]) {
        await tester.showKeyboard(bodyField);
        tester.view.viewInsets = const FakeViewPadding(bottom: 290);
        await tester.pumpAndSettle();
        expect(transcriptionReference, findsOneWidget);
        expect(controller.value, value);
        expect(paper.offset, paperOffset);

        if (dismissWithButton) await tester.tap(dismiss);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(field.focusNode!.hasFocus, !dismissWithButton);
        expect(transcriptionGuide, findsOneWidget);
        expect(
          tester.widget<TextField>(bodyField).controller,
          same(controller),
        );
        expect(controller.value, value);
        expect(store.data.activePage!.text, written);
        expect(paper.offset, paperOffset);
        expect(store.data.activePage!.scroll, paperOffset);
      }

      // Reading ahead on the paper can scroll past the end of the draft.
      final guideEnd = paper.position.maxScrollExtent;
      paper.jumpTo(guideEnd);
      await tester.pumpAndSettle();
      await tester.showKeyboard(bodyField);
      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      await tester.pumpAndSettle();
      expect(paper.position.maxScrollExtent, lessThan(guideEnd));
      expect(paper.offset, lessThanOrEqualTo(paper.position.maxScrollExtent));
      expect(controller.value, value);

      final continued = value.replaced(value.selection, '한');
      tester.testTextInput.updateEditingValue(continued);
      await tester.pumpAndSettle();
      expect(store.data.activePage!.text, continued.text);
    },
  );

  testWidgets(
    'A long original scrolls in the bottom reference on a compact screen',
    (tester) async {
      final lines = List.generate(32, (i) => '${i + 1}번째 줄을 옮겨 적는다.');
      final source = lines.join('\n');
      const citationLabel = '제목 · 작가 · 자료원';
      const citation = '$citationLabel · https://example.com/source';
      final store = MemoryStore()
        ..data = Library(
          records: [
            WritingRecord(
              id: 'r',
              title: '필사',
              originals: [
                RegisteredOriginal('source', source, citation: citation),
              ],
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
      expect(transcriptionGuide, findsOneWidget);
      expect(transcriptionReference, findsNothing);
      expect(remainingInline(tester), source);
      expect(field.controller!.text, isEmpty);
      final titleMark = find.descendant(
        of: find.byType(WritingHeader),
        matching: find.byType(InkMark),
      );
      final writingTop = tester.getTopLeft(bodyField).dy;
      expect(titleMark, findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      await tester.showKeyboard(bodyField);
      await tester.pumpAndSettle();
      expect(transcriptionReference, findsOneWidget);
      expect(
        tester.getTopLeft(transcriptionReference).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(bodyField).dy),
      );
      expect(tester.getBottomLeft(transcriptionReference).dy, lessThan(350));
      expect(tester.getTopLeft(bodyField).dy, lessThan(writingTop));
      final bodyStyle = field.style!;
      expect(
        tester.getSize(bodyField).height,
        greaterThanOrEqualTo(bodyStyle.fontSize! * bodyStyle.height!),
      );
      expect(titleMark, findsNothing);
      expect(find.text(citationLabel), findsNothing);

      final viewport = find.descendant(
        of: transcriptionReference,
        matching: find.byType(SingleChildScrollView),
      );
      final scroll = tester.widget<SingleChildScrollView>(viewport).controller!;
      final paragraph = find.descendant(
        of: viewport,
        matching: find.byType(RichText),
      );
      final lineHeight = tester.getSize(paragraph).height / lines.length;
      final viewportHeight = tester.getSize(viewport).height;
      final fullLines = (viewportHeight / lineHeight).round();
      expect(fullLines, greaterThanOrEqualTo(2));
      expect(viewportHeight, closeTo(fullLines * lineHeight, 1));
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
      expect(scroll.offset, closeTo(8 * lineHeight, 1));
      expect(scroll.offset, lessThan(scroll.position.maxScrollExtent));

      field.focusNode!.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(transcriptionGuide, findsOneWidget);
      expect(transcriptionReference, findsNothing);
      expect(remainingInline(tester), lines.skip(8).join('\n'));
      expect(titleMark, findsOneWidget);
      expect(field.controller!.text, written);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Transcribing from the original panel preserves written text on its own page',
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
      await openOriginalRegistration(tester);
      final registration = find.byType(SourceImportSheet);
      expect(
        find.ancestor(of: registration, matching: find.byType(PaperBackdrop)),
        findsNothing,
      );
      expect(
        find.descendant(of: registration, matching: find.text('담기')),
        findsOneWidget,
      );
      expect(find.widgetWithText(CheckboxListTile, '바로 필사하기'), findsNothing);
      await tester.enterText(sourceField, '새로 옮겨 쓸 구절');
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await settleSourceSheets(tester);
      await tester.tap(find.text('필사하기'));
      await settleSourceSheets(tester);

      expect(reading, findsNothing);
      expect(store.data.pages.first.text, '이미 쓴 글');
      expect(store.data.pages, hasLength(2));
      expect(store.data.activePageId, isNot('p'));
      expect(store.data.activeBook!.id, 'b');
      expect(store.data.activePage!.text, isEmpty);
      expect(store.data.activePage!.referenceOnly, isFalse);
      expect(transcriptionGuide, findsOneWidget);
      expect(transcriptionReference, findsNothing);
      expect(
        remainingInline(tester),
        store.data.activeBook!.originals.last.text,
      );
      expect(store.data.activePage!.passages.first.start, 0);
      expect(
        store.data.activePage!.guidedOriginalId,
        store.data.activeBook!.originals.last.id,
      );
    },
  );

  testWidgets(
    'Only the extracted text guides transcription on a compact keyboard layout',
    (tester) async {
      await preparePhotoStorage(tester);
      final photo = FakeIntake();
      final id = (await tester.runAsync(
        () => const OriginalPhotoStore().save(photo.photo.bytes),
      ))!;
      final store = MemoryStore()
        ..data = Library(
          records: [
            WritingRecord(
              id: 'r',
              title: '필사',
              originals: [RegisteredOriginal('o', '따라 쓸 구절', photoId: id)],
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
      await open(tester, store, photo);
      final image = find.byKey(const ValueKey('saved-original-photo'));
      expect(transcriptionGuide, findsOneWidget);
      expect(transcriptionReference, findsNothing);
      expect(remainingInline(tester), '따라 쓸 구절');
      expect(image, findsNothing);
      expect(find.text('사진 보기'), findsNothing);
      tester.view.physicalSize = const Size(320, 600);
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.showKeyboard(bodyField);
      await tester.pumpAndSettle();
      expect(transcriptionGuide, findsNothing);
      expect(remainingReference(tester), '따라 쓸 구절');
      expect(find.byKey(const ValueKey('page-originals-button')), findsNothing);
      expect(tester.getSize(bodyField).height, greaterThanOrEqualTo(36));
      expect(
        tester.getRect(transcriptionReference).bottom,
        lessThanOrEqualTo(260),
      );
      expect(tester.widget<TextField>(bodyField).focusNode!.hasFocus, isTrue);

      const composing = TextEditingValue(
        text: '따라 ㅆ',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 3, end: 4),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(bodyField);
      expect(field.controller!.value, composing);
      expect(image, findsNothing);
      final committed = composing.copyWith(
        text: '따라 씀',
        composing: TextRange.empty,
      );
      tester.testTextInput.updateEditingValue(committed);
      await tester.pumpAndSettle();
      expect(image, findsNothing);
      expect(store.data.activePage!.text, '따라 씀');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Shared photo remains archived until its text is extracted and chosen',
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
      expect(photoPaper, findsOneWidget);
      await showSourceDetails(tester);
      await tester.enterText(
        find.byKey(const ValueKey('original-citation')),
        '책 72쪽',
      );
      await tester.pumpAndSettle();
      await openPhotoMenu(tester);
      await saveWithPhoto(tester, action: find.text('사진만 담기'));
      final original = store.data.books.single.originals.single;
      expect(original.text, isEmpty);
      expect(original.photoId, isNotNull);
      expect(intake.scans, 1);
      expect(intake.acknowledged, ['image-share']);
      expect(
        await tester.runAsync(
          () => const OriginalPhotoStore().load(original.photoId!),
        ),
        intake.photo.bytes,
      );

      expect(reading, findsOneWidget);
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

      expect(find.text('필사하기'), findsOneWidget);
      expect(find.byType(OriginalPhoto), findsOneWidget);
      expect(store.data.activePage!.guidedOriginalId, isNull);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      final extract = find.ancestor(
        of: find.text('사진에서 글자 읽기'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      final photo = tester.getRect(find.byType(OriginalPhoto));
      final action = tester.getRect(extract);
      final slip = tester.getRect(find.text('필사하기'));
      expect(action.width, 320 - 48);
      expect(action.top - photo.bottom, greaterThanOrEqualTo(12));
      expect(slip.top, greaterThan(action.bottom));

      await loadPhotoAfter(extract);
      expect(intake.scans, 2);
      expect(find.text('사진만 담기'), findsNothing);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      final chooseArea = find.text('글자 영역 고르기');
      expect(chooseArea.hitTestable(), findsOneWidget);
      await loadPhotoAfter(chooseArea);
      final frame = tester.getRect(find.byType(Image).last);
      await tester.dragFrom(
        frame.topLeft + Offset(frame.width * .1, frame.height * .15),
        Offset(frame.width * .6, frame.height * .45),
      );
      await tester.pumpAndSettle();
      await loadPhotoAfter(find.text('이 부분 사용'));
      expect(intake.scans, 3);
      expect(intake.recognizedRegion!.width, closeTo(.6, .02));
      expect(find.text('글자 영역 바꾸기'), findsOneWidget);
      const corrected = '사진에서 확인한 첫 문단.\n\n둘째 문단입나다.';
      await correctPhoto(tester, corrected);

      expect(find.text('원문에 글 추가'), findsOneWidget);
      store.fail = true;
      await loadPhotoAfter(confirm);
      expect(find.text('원문 글을 저장하지 못했어요. 다시 저장해 주세요.'), findsOneWidget);
      expect(
        tester.widget<EditableText>(photoCorrection).controller.text,
        corrected,
      );
      expect(store.data.books.single.originals.single.text, isEmpty);
      store.fail = false;
      await saveWithPhoto(tester);

      final saved = store.data.books.single.originals.single;
      expect(saved.id, original.id);
      expect(saved.photoId, original.photoId);
      expect(saved.photoRegion, isNotNull);
      expect(saved.citation, '책 72쪽');
      expect(saved.text, '사진에서 확인한 첫 문단.\n\n둘째 문단입나다.');
      expect(store.data.activePage!.guidedOriginalId, isNull);
      final previousPage = store.data.activePage!.toJson();
      await loadPhotoAfter(find.text('필사하기'));
      expect(store.data.activePageId, isNot('p'));
      expect(
        store.data.pages.firstWhere((p) => p.id == 'p').toJson(),
        previousPage,
      );
      expect(store.data.activePage!.text, isEmpty);
      expect(store.data.activePage!.guidedOriginalId, original.id);
      expect(store.data.activePage!.originalCitations, ['책 72쪽']);
      expect(remainingInline(tester), saved.text);
      expect(find.byType(OriginalPhoto), findsNothing);
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

  testWidgets('Recovered Android picker photo is read without saving', (
    tester,
  ) async {
    final store = MemoryStore();
    final intake = FakeIntake();
    intake.recovered = intake.photo;
    await open(tester, store, intake);
    expect(photoPaper, findsOneWidget);
    expect(photoDraft(tester).data, '첫 문단입니다.\n\n둘째 문단입나다.');
    expect(intake.scans, 1);
    expect(intake.photos, 0);
    expect(store.writes, 0);
  });
}
