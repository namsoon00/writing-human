import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/original_photo_store.dart';
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
    testWidgets('Photo and text remain visible together at $size', (
      tester,
    ) async {
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
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceReading(
              originals: [original],
              initialOriginalId: original.id,
              transcribeLabel: '필사하기',
            ),
          ),
        ),
      );
      await finishPhotoLoad(tester);
      final photo = tester.getRect(
        find.byKey(const ValueKey('original-reading-photo')),
      );
      final text = tester.getRect(
        find.byKey(const ValueKey('source-reading-text')),
      );
      expect(find.byType(OriginalPhoto), findsOneWidget);
      expect(photo.width, greaterThan(100));
      expect(photo.height, greaterThan(50));
      if (size.width >= 600) {
        expect(photo.right, lessThan(text.left));
      } else {
        expect(photo.bottom, lessThan(text.top));
        expect(photo.height, lessThan(size.height * .35));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'A photo thumbnail shares the writing reference without changing composing',
    (tester) async {
      await preparePhotoStorage(tester);
      final intake = FakeIntake();
      addTearDown(intake.dispose);
      final photoId = await tester.runAsync(
        () => const OriginalPhotoStore().save(intake.photo.bytes),
      );
      final controller = TextEditingController.fromValue(
        const TextEditingValue(
          text: '하ㄴ',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      addTearDown(controller.dispose);
      final before = controller.value;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 80,
                child: TranscriptionReference(
                  original: RegisteredOriginal(
                    'photo',
                    '한 문장을 읽습니다.',
                    photoId: photoId,
                  ),
                  comparison: null,
                  controller: controller,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      );
      await finishPhotoLoad(tester);
      expect(find.byKey(const ValueKey('reference-photo')), findsOneWidget);
      expect(find.text('한 문장을 읽습니다.', findRichText: true), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reference-photo')));
      await tester.pumpAndSettle();
      expect(controller.value, before);
      expect(find.text('원본 사진'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
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
