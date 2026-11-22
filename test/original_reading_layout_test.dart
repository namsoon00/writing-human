import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/library_search.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/original_photo_store.dart';
import 'package:writing_human/ui/editor.dart';
import 'package:writing_human/ui/original_photo.dart';
import 'package:writing_human/ui/page_originals_panel.dart';
import 'package:writing_human/ui/source_reading.dart';
import 'package:writing_human/ui/transcription_reference.dart';

import 'source_intake_test.dart' show FakeIntake, preparePhotoStorage;

Future<void> finishPhotoLoad(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 20));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(900, 700),
    const Size(320, 640),
  ]) {
    testWidgets(
      'A readable original keeps a small photo with attribution at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await preparePhotoStorage(tester);
        final intake = FakeIntake();
        addTearDown(intake.dispose);
        final photoId = await tester.runAsync(
          () => const OriginalPhotoStore().save(intake.photo.bytes),
        );
        final original = RegisteredOriginal(
          'photo',
          '사진과 함께 읽는 원문입니다.\n구절을 천천히 옮겨 씁니다.',
          photoId: photoId,
          photoRegion: const [.1, .25, .8, .9],
        );
        RegisteredOriginal? transcribed;
        Passage? opened;
        var openedRegistration = false;
        var savedReflection = false;
        const savedWriting = Passage(
          WritingPage(id: 'page', recordId: 'record', number: 1),
          '필사',
          '옮겨 쓴 구절',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SourceReading(
                originals: [original],
                initialOriginalId: original.id,
                transcribeLabel: '필사하기',
                onRegister: () async {
                  openedRegistration = true;
                  return null;
                },
                onTranscribe: (source) => transcribed = source,
                onSaveReflection: (_, _) async {
                  savedReflection = true;
                  return true;
                },
                onOpenWriting: (passage) => opened = passage,
                writingLocations: const {
                  'photo': (passage: savedWriting, marked: false),
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final body = find.byKey(const ValueKey('source-reading-text'));
        final showPhoto = find.text('원본 사진 보기');
        final transcribe = find.widgetWithText(FilledButton, '필사하기');
        final openWriting = find.widgetWithText(TextButton, '필사한 쪽 열기');
        expect(find.byType(OriginalPhoto), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('source-details'))).dy,
          greaterThan(tester.getTopLeft(body).dy),
        );
        expect(body, findsOneWidget);
        expect(tester.getTopLeft(body).dy, lessThan(150));
        expect(showPhoto, findsOneWidget);
        expect(transcribe.hitTestable(), findsOneWidget);
        expect(openWriting.hitTestable(), findsOneWidget);
        expect(find.text('원문 담기'), findsNothing);
        expect(find.text('느낀 점 남기기'), findsNothing);
        expect(savedReflection, isFalse);
        expect(
          tester.getSize(transcribe).width,
          greaterThan(size.width < 600 ? size.width - 60 : 500),
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('source-open-writing'))).top,
          lessThan(tester.getRect(transcribe).top),
        );

        await tester.tap(showPhoto);
        await finishPhotoLoad(tester);
        final viewer = find.byType(InteractiveViewer);
        final photo = find.descendant(
          of: viewer,
          matching: find.byType(OriginalPhoto),
        );
        expect(tester.widget<OriginalPhoto>(photo).region, isNull);
        final image = tester.widget<Image>(
          find.byKey(const ValueKey('saved-original-photo')),
        );
        expect(
          (image.image as MemoryImage).bytes,
          orderedEquals(intake.photo.bytes),
        );
        expect(find.text('원본 사진'), findsOneWidget);
        expect(find.text('볼 부분 고르기'), findsNothing);
        expect(find.text('사진 전체 보기'), findsNothing);
        expect(find.text('글자 부분 보기'), findsNothing);
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        expect(body, findsOneWidget);
        expect(find.byType(OriginalPhoto), findsOneWidget);

        await tester.tap(find.byTooltip('원문 목록'));
        await finishPhotoLoad(tester);
        final preview = find.byType(OriginalPhoto);
        final thumbnail = tester.widget<OriginalPhoto>(preview);
        expect(thumbnail.thumbnailSize, const Size(46, 68));
        final previewImage = tester.widget<Image>(
          find.descendant(
            of: preview,
            matching: find.byKey(const ValueKey('saved-original-photo')),
          ),
        );
        final resized = previewImage.image as ResizeImage;
        expect(resized.policy, ResizeImagePolicy.fit);
        expect(
          (resized.imageProvider as MemoryImage).bytes,
          orderedEquals(intake.photo.bytes),
        );
        await tester.tap(preview);
        await finishPhotoLoad(tester);
        expect(body, findsOneWidget);

        await tester.tap(find.byTooltip('원문 더 보기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('원문 담기'));
        await tester.pumpAndSettle();
        expect(openedRegistration, isTrue);

        await tester.tap(transcribe);
        expect(transcribed, same(original));
        await tester.ensureVisible(openWriting);
        await tester.tap(openWriting);
        expect(opened, same(savedWriting));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Long originals keep one primary action visible without asking for a reflection',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final original = RegisteredOriginal(
        'long',
        List.generate(30, (i) => '읽고 남길 검수 문장 ${i + 1}').join('\n'),
        citation: '출처가 길어도 전체를 읽을 수 있는 직접 쓴 검수 원문',
      );
      RegisteredOriginal? started;
      var reflections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceReading(
              originals: [original],
              initialOriginalId: original.id,
              transcribeLabel: '필사하기',
              onTranscribe: (value) => started = value,
              onSaveReflection: (_, _) async {
                reflections++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('source-start-transcription'));
      final rect = tester.getRect(action);
      expect(action.hitTestable(), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('source-attribution')),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(action), rect);
      expect(find.text('느낀 점 남기기'), findsNothing);
      expect(reflections, 0);
      await tester.tap(action);
      expect(started, same(original));
      expect(original.reflection, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Returning from a saved original restores a long index scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceReading(
            originals: [
              for (var i = 0; i < 16; i++)
                RegisteredOriginal('item-$i', '서랍에 담은 원문 $i'),
            ],
            transcribeLabel: '필사하기',
          ),
        ),
      ),
    );
    final list = find.byKey(const PageStorageKey('saved-original-list'));
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final entry = find.text('서랍에 담은 원문 2');
    await tester.scrollUntilVisible(entry, 180, scrollable: scrollable);
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset, greaterThan(200));
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('source-reading-text')), findsOneWidget);
    await tester.tap(find.byTooltip('원문 목록'));
    await tester.pumpAndSettle();
    expect(entry.hitTestable(), findsOneWidget);
    expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
  });

  for (final withText in [true, false]) {
    testWidgets('Writing only shows original text (with text: $withText)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await preparePhotoStorage(tester);
      final intake = FakeIntake();
      addTearDown(intake.dispose);
      final photoId = await tester.runAsync(
        () => const OriginalPhotoStore().save(intake.photo.bytes),
      );
      final original = RegisteredOriginal(
        'photo',
        withText ? '한 문장을 읽습니다.' : '',
        photoId: photoId,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: PageEditor(
              page: WritingPage(
                id: 'p',
                recordId: 'r',
                number: 1,
                guidedOriginalId: original.id,
              ),
              originals: [original],
              onChanged: (_, _, _, _, _) {},
            ),
          ),
        ),
      );
      final field = find.byKey(const ValueKey('page-text'));
      await tester.showKeyboard(field);
      await tester.pumpAndSettle();
      final reference = find.byType(TranscriptionReference);
      expect(find.byType(OriginalPhoto), findsNothing);
      expect(reference, withText ? findsOneWidget : findsNothing);
      if (!withText) return;

      const composing = TextEditingValue(
        text: '하ㄴ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      final line = find.text(original.text, findRichText: true);
      expect(line, findsOneWidget);
      expect(
        tester.getTopLeft(line).dx,
        closeTo(tester.getTopLeft(reference).dx, 1),
      );
      await tester.tap(reference);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.value, composing);
      expect(find.byType(PageOriginalsPanel), findsNothing);

      tester.testTextInput.updateEditingValue(
        composing.copyWith(composing: TextRange.empty),
      );
      await tester.pumpAndSettle();
      await tester.tap(reference);
      tester.view.resetViewInsets();
      await finishPhotoLoad(tester);
      expect(find.byType(PageOriginalsPanel), findsOneWidget);
      expect(find.byType(OriginalPhoto), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Archived source copies remain readable without a numbered writing UI',
    (tester) async {
      const first = RegisteredOriginal('old-a', '이전에 쓴 첫 원문', citation: '첫 출처');
      const second = RegisteredOriginal(
        'old-b',
        '이전에 쓴 둘째 원문',
        citation: '둘째 출처',
      );
      const links = [
        PagePassage(
          id: 'a',
          start: 0,
          source: '이전에 쓴 첫 원문',
          original: first,
          attached: true,
        ),
        PagePassage(
          id: 'b',
          start: 5,
          source: '이전에 쓴 둘째 원문',
          original: second,
          attached: true,
        ),
      ];
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PageOriginalsPanel(
              passages: links,
              textLength: 10,
              style: WritingStyle(),
              selectedId: 'b',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(second.text), findsOneWidget);
      expect(find.text(first.text), findsNothing);
      await tester.tap(find.text('이전 원문 기록'));
      await tester.pumpAndSettle();
      expect(find.text(first.text), findsOneWidget);
      expect(find.text(second.text), findsOneWidget);
      await tester.tap(find.text(first.text));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('page-original-reading-text')),
        findsOneWidget,
      );
      expect(find.text(first.text), findsOneWidget);
      expect(links[0].original, first);
      expect(links[1].original, second);
    },
  );
}
