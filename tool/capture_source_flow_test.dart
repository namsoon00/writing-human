// Synthetic reading fixture; this is Flutter layout QA, not device/OCR QA.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/source_import_sheet.dart';

import '../test/source_intake_test.dart' show FakeIntake;
import '../test/widget_test.dart' show MemoryStore;

void main() {
  testWidgets('Capture reading, selection, saving and large type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final output = Directory('artifacts/source-flow');
    await tester.runAsync(() async {
      await output.create(recursive: true);
      for (final (family, asset) in [
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
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
    });
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'parse': {
              'pageid': 1515,
              'revid': 387685,
              'categories': [
                {'category': 'PD-old-70'},
              ],
              'text':
                  '<div class="poem"><p>오늘의 문장을 천천히 읽습니다.<br>마음에 남은 구절을 골라 봅니다.</p><p>종이에 옮긴 한 줄이<br>나의 한 권으로 남습니다.</p></div>',
            },
          }),
        ),
        200,
      ),
    );
    await http.runWithClient(() async {
      final store = MemoryStore();
      final intake = FakeIntake();
      addTearDown(intake.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WritingHumanApp(store: store, sourceIntake: intake),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final name in ['cotton-paper.jpg', 'ink-mark-bleed.png']) {
          await precacheImage(
            AssetImage('assets/images/$name'),
            boundary.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.tap(find.byKey(const ValueKey('writing-originals')));
      await tester.pumpAndSettle();
      await capture('01-originals');
      await tester.tap(find.text('원문 담기'));
      await tester.pumpAndSettle();
      await capture('02-import');
      await tester.tap(find.byKey(const ValueKey('source-search-direct')));
      await tester.pumpAndSettle();
      await capture('03-discover');
      await tester.tap(find.widgetWithText(ListTile, '서시'));
      await tester.pumpAndSettle();
      await capture('04-read');
      await tester.tap(find.text('전체 선택'));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      await capture('05-selected');
      await tester.tap(find.byKey(const ValueKey('source-confirm')));
      await tester.pumpAndSettle();
      await capture('06-saved');
      await tester.tap(find.text('원문 담기'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 700);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(find.byType(SourceImportSheet), findsOneWidget);
      await capture('07-large-text');
      await tester.enterText(
        find.byKey(const ValueKey('source-text')),
        '검수용 원문입니다.',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SourceImportSheet),
          matching: find.byTooltip('닫기'),
        ),
      );
      await tester.pumpAndSettle();
      await capture('08-close-draft');
    }, () => client);
  });
}
