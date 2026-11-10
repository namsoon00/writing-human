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
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';

void main() {
  testWidgets(
    'Render ordinary app pages with the global Writing Human typeface',
    (tester) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = previousShadows);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.runAsync(() async {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('WritingHumanDevelopment')..addFont(
              rootBundle.load(
                'assets/fonts/WritingHumanDevelopment-Regular.ttf',
              ),
            ))
            .load();
        await (FontLoader('NanumMyeongjo')
              ..addFont(
                rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf'),
              )
              ..addFont(rootBundle.load('assets/fonts/NanumMyeongjo-Bold.ttf')))
            .load();
        await (FontLoader(
              'NanumGothic',
            )..addFont(rootBundle.load('assets/fonts/NanumGothic-Regular.ttf')))
            .load();
        await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
              rootBundle.load(
                'packages/cupertino_icons/assets/CupertinoIcons.ttf',
              ),
            ))
            .load();
      });
      final boundary = GlobalKey();
      final preview = DemoStore();
      await preview.save(const Library());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WritingHumanApp(store: preview),
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
          'ink-mark.png',
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
            'artifacts/readability-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('page-text')))
            .style!
            .fontFamily,
        'WritingHumanDevelopment',
      );
      await capture('blank');
      await tester.tap(find.byTooltip('쓰기 도구'));
      await tester.pumpAndSettle();
      await capture('tools');
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('page-text')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('page-text')),
        '천천히 읽고,\n마음에 남은 문장을 씁니다.\n\n오래 곁에 두고 싶은 생각을\n한 줄씩 남깁니다.',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('page-text')))
            .style!
            .fontFamily,
        'WritingHumanDevelopment',
      );
      await capture('writing');
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
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await capture('keyboard');
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      await capture('resting');
      final number = find.byKey(const ValueKey('page-number'));
      final reveal = find.byKey(const ValueKey('page-turn-reveal'));
      final forward = await tester.startGesture(tester.getCenter(number));
      await forward.moveBy(const Offset(-160, 0));
      await tester.pump();
      expect(reveal, findsOneWidget);
      await capture('forward-middle');
      await forward.up();
      await tester.pumpAndSettle();
      await capture('new-page');
      await tester.enterText(
        find.byKey(const ValueKey('page-text')),
        '새는 알에서 나오려고\n투쟁한다. 알은 세계다.',
      );
      await tester.pumpAndSettle();
      final backward = await tester.startGesture(tester.getCenter(number));
      await backward.moveBy(const Offset(165, 0));
      await tester.pump();
      expect(reveal, findsOneWidget);
      await capture('backward-middle');
      await backward.up();
      await tester.pumpAndSettle();
      final close = await tester.startGesture(tester.getCenter(number));
      await close.moveBy(const Offset(160, 0));
      await tester.pump();
      await capture('cover-middle');
      await close.up();
      await tester.pumpAndSettle();
      await capture('cover');
      await tester.tap(find.text('책 펼치기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('page-number')));
      await tester.pumpAndSettle();
      await capture('overview');
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('쓰기 도구'));
      await tester.pumpAndSettle();
      await capture('tools');
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('보관함'));
      await tester.pumpAndSettle();
      await capture('collection');
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpAndSettle();
      await capture('desktop');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugDisableShadows = previousShadows;
    },
  );
}
