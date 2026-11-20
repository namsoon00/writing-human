// Render the product with a synthetic photograph and self-written QA text.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/original_photo_store.dart';
import 'package:writing_human/main.dart';

import '../test/source_intake_test.dart' show FakeIntake, preparePhotoStorage;
import '../test/original_reading_layout_test.dart' show finishPhotoLoad;
import '../test/widget_test.dart' show MemoryStore;

const sample =
    '창가에 앉아 책을 펼칩니다.\n천천히 읽고, 마음에 남은 문장을\n종이 위에 옮겨 씁니다.\n\n오늘 적은 한 줄은\n나의 한 권으로 남습니다.';

void main() {
  testWidgets('Capture one source with its photograph and readable text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await preparePhotoStorage(tester);
    late Uint8List bytes;
    await tester.runAsync(() async {
      for (final (family, asset) in [
        (
          'WritingHumanDevelopment',
          'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        ),
        ('NanumMyeongjo', 'assets/fonts/NanumMyeongjo-Regular.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        (
          'packages/cupertino_icons/CupertinoIcons',
          'packages/cupertino_icons/assets/CupertinoIcons.ttf',
        ),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xfff9f3e5), BlendMode.src);
      canvas.drawRect(
        const Rect.fromLTWH(25, 25, 550, 750),
        Paint()..color = const Color(0xfffffcf4),
      );
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: const TextSpan(
          text: '어느 날의 기록\n\n$sample',
          style: TextStyle(
            fontFamily: 'NanumMyeongjo',
            fontSize: 30,
            height: 1.9,
            color: Color(0xff382e24),
          ),
        ),
      )..layout(maxWidth: 460);
      painter.paint(canvas, const Offset(70, 80));
      painter.dispose();
      final picture = recorder.endRecording();
      final image = await picture.toImage(600, 800);
      bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      await Directory('artifacts/single-source').create(recursive: true);
      await File('artifacts/single-source/fixture.png').writeAsBytes(bytes);
    });
    final id = await tester.runAsync(
      () => const OriginalPhotoStore().save(bytes),
    );
    final store = MemoryStore()
      ..data = Library(
        books: [
          Book(
            id: 'book',
            title: '오래 곁에 둘 문장',
            originals: [
              RegisteredOriginal(
                'photo',
                sample,
                citation: '직접 쓴 검수 문장',
                photoId: id,
              ),
            ],
          ),
        ],
        records: const [
          WritingRecord(id: 'record', bookId: 'book', title: '필사'),
        ],
        pages: const [WritingPage(id: 'page', recordId: 'record', number: 1)],
        activePageId: 'page',
        writing: true,
      );
    final boundary = GlobalKey();
    final intake = FakeIntake();
    addTearDown(intake.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: WritingHumanApp(store: store, sourceIntake: intake),
      ),
    );
    await tester.pumpAndSettle();
    final output = Directory('artifacts/single-source');
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await output.create(recursive: true);
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${output.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.byKey(const ValueKey('writing-originals')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo')));
    await finishPhotoLoad(tester);
    await capture('reading-phone');
    tester.view.physicalSize = const Size(900, 700);
    await finishPhotoLoad(tester);
    await capture('reading-wide');
    tester.view.physicalSize = const Size(320, 700);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await finishPhotoLoad(tester);
    await capture('reading-large-text');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(390, 844);
    await finishPhotoLoad(tester);
    await tester.tap(find.text('필사하기'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('page-text'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 290);
    await tester.showKeyboard(field);
    await finishPhotoLoad(tester);
    await tester.enterText(field, '창가에 앉아 ');
    await tester.pumpAndSettle();
    await capture('writing-reference');
  });
}
