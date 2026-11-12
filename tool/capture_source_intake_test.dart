// Synthetic photo + product UI renders. No camera or browser interaction.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/source/source_intake.dart';
import 'package:writing_human/ui/source_reading.dart';

import '../test/source_intake_test.dart' show FakeIntake;
import '../test/widget_test.dart' show MemoryStore;

const paragraphs = [
  '책장을 넘기면 새로운 문장이 보입니다.\n마음에 남은 구절을 천천히 옮겨 씁니다.',
  '종이의 결을 따라 작은 이야기를 남깁니다.\n하루에 한 문장이면 충분합니다.',
];

Future<Uint8List> printedPage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xfffffdf7), BlendMode.src);
  final text = TextPainter(
    text: TextSpan(
      text: paragraphs.join('\n\n'),
      style: const TextStyle(
        fontFamily: 'NanumMyeongjo',
        color: Color(0xff24201b),
        fontSize: 39,
        height: 1.65,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 960);
  text.paint(canvas, const Offset(60, 70));
  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 520);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  text.dispose();
  picture.dispose();
  image.dispose();
  return bytes;
}

void main() {
  testWidgets('Render source placement, photo paragraphs, review and writing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('artifacts');
    late Uint8List photo;
    await tester.runAsync(() async {
      await output.create(recursive: true);
      for (final (name, path) in [
        (
          'WritingHumanDevelopment',
          'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        ),
        ('NanumMyeongjo', 'assets/fonts/NanumMyeongjo-Regular.ttf'),
        ('NanumGothic', 'assets/fonts/NanumGothic-Regular.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        (
          'packages/cupertino_icons/CupertinoIcons',
          'packages/cupertino_icons/assets/CupertinoIcons.ttf',
        ),
      ]) {
        await (FontLoader(name)..addFont(rootBundle.load(path))).load();
      }
      photo = await printedPage();
      await File('artifacts/source-intake-ocr-fixture.png').writeAsBytes(photo);
    });
    final boundary = GlobalKey();
    final intake = FakeIntake(photo: SourcePhoto('fixture.png', photo))
      ..blocks = paragraphs;
    addTearDown(intake.dispose);
    final store = MemoryStore();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: WritingHumanApp(store: store, sourceIntake: intake),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        ResizeImage.resizeIfNeeded(640, null, MemoryImage(photo)),
        boundary.currentContext!,
      );
      for (final name in [
        'cotton-paper.jpg',
        'ink-mark-bleed.png',
        'fountain-pen.png',
      ]) {
        await precacheImage(
          AssetImage('assets/images/$name'),
          boundary.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    Future<void> capture(String label) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        await File('artifacts/source-intake-$label.png').writeAsBytes(bytes);
        image.dispose();
      });
    }

    await capture('paper');
    final originals = find.byKey(const ValueKey('writing-originals'));
    final reading = find.byType(SourceReading);
    final closeReading = find.descendant(
      of: reading,
      matching: find.byTooltip('닫기'),
    );
    await tester.tap(originals);
    await tester.pumpAndSettle();
    await capture('choose');
    await tester.tap(find.byKey(const ValueKey('source-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 고르기'));
    await tester.pumpAndSettle();
    await capture('paragraphs');
    final confirm = find.byKey(const ValueKey('source-confirm'));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await capture('review');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(
      store.data.records.single.originals.single.text,
      paragraphs.join('\n\n'),
    );
    expect(store.data.activePage!.text, isEmpty);
    expect(find.byKey(const ValueKey('transcription-guide')), findsOneWidget);
    await capture('guide');
    await tester.enterText(find.byKey(const ValueKey('page-text')), '책장을 넘기면 ');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('page-text')),
      '책장을 넘기면 새',
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 35));
    expect(find.byKey(const ValueKey('fresh-ink')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('page-text')))
          .controller!
          .text,
      '책장을 넘기면 새',
    );
    await capture('ink-writing');
    await tester.pumpAndSettle();
    await capture('guide-writing');
    await tester.tap(originals);
    await tester.pumpAndSettle();
    await capture('reading');
    await tester.tap(closeReading);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('page-text')),
      '책장을 넘기면 새로운 문장이 보입니다.',
    );
    await tester.pumpAndSettle();
    await capture('writing');
    await tester.enterText(
      find.byKey(const ValueKey('page-text')),
      '책장을 넘기면 새로운 문장이 보입니다.\n\n종이의 결을 따라',
    );
    await tester.pumpAndSettle();
    await tester.tap(originals);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('source-reading-text')),
    );
    expect(text.textSpan!.toPlainText(), paragraphs.join('\n\n'));
    await capture('next-passage');
  });
}
