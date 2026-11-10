// Visual QA helper. Uses explicit demo data and the Flutter test renderer;
// captures are not browser/device screenshots or persistence verification.
// Run: flutter test tool/capture_preview_test.dart --no-pub
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/demo_store.dart';
import 'package:writing_human/main.dart';

void main() {
  testWidgets('Render the reference flow with bundled fonts and materials', (
    tester,
  ) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await (FontLoader('NanumMyeongjo')
            ..addFont(rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/NanumMyeongjo-Bold.ttf')))
          .load();
      await (FontLoader('NanumGothic')
            ..addFont(rootBundle.load('assets/fonts/NanumGothic-Regular.ttf')))
          .load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    });
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: WritingHumanApp(store: DemoStore(), demo: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final name in [
        'cotton-paper.jpg',
        'linen-cover.png',
        'ivory-linen-cover.png',
        'blue-linen-cover.png',
        'fountain-pen.png',
        'sunlit-desk.jpg',
      ]) {
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
        await Directory('artifacts').create(recursive: true);
        await File(
          'artifacts/material-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('shelf');
    await tester.tap(find.text('데미안').last);
    await tester.pumpAndSettle();
    await capture('book');
    await tester.tap(find.text('이어서 쓰기'));
    await tester.pumpAndSettle();
    await capture('writing');
    await tester.tap(find.byKey(const ValueKey('page-text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('page-text')),
      '새는 알에서 나오려고\n투쟁한다. 알은 세계다.\n\n한 문장씩, 나의 속도로.',
    );
    await tester.pumpAndSettle();
    await capture('pen-follow');
    final typed = tester.widget<TextField>(
      find.byKey(const ValueKey('page-text')),
    );
    final nextText = '${typed.controller!.text} 천천히';
    typed.controller!.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await capture('pen-stroke');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aa'));
    await tester.pumpAndSettle();
    await capture('fonts');
    await tester.tap(find.text('종이'));
    await tester.pumpAndSettle();
    await capture('paper');
    await tester.tap(find.text('펜'));
    await tester.pumpAndSettle();
    await capture('pen');
    await tester.tap(find.byTooltip('돌아가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('나의 책장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('나의 책장'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpAndSettle();
    await capture('desktop');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDisableShadows = previousShadows;
  });
}
