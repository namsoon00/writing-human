// Native Flutter specimens with synthetic copy; never user data or device captures.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/demo_store.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/book_detail_design.dart';
import 'package:writing_human/ui/book_detail_tools.dart';
import 'package:writing_human/ui/paper.dart';

void main() {
  testWidgets('Render seven independent design sheets with shapes and palettes', (
    tester,
  ) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = shadows);
    tester.view.physicalSize = const Size(1080, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('WritingHumanDevelopment')..addFont(
            rootBundle.load('assets/fonts/WritingHumanDevelopment-Regular.ttf'),
          ))
          .load();
      await (FontLoader(
            'NanumMyeongjo',
          )..addFont(rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf')))
          .load();
      await (FontLoader('NanumGothic')
            ..addFont(rootBundle.load('assets/fonts/NanumGothic-Regular.ttf')))
          .load();
    });
    for (final kind in BookDetailKind.values) {
      final key = GlobalKey();
      final design = BookDetailDesign.of(kind);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'NanumGothic',
            scaffoldBackgroundColor: paper,
          ),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(kind.index + 1).toString().padLeft(2, '0')}   ${design.title}',
                      style: const TextStyle(
                        fontFamily: serif,
                        fontSize: 25,
                        color: brandInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      design.description,
                      style: const TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 22),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < 2 ? 28 : 0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      design.variants[i],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    BookDetailPreview(
                                      kind: kind,
                                      choice: BookDetailChoice(variant: i),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: Row(
                              children: [
                                Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: design.colors[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: line),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  design.tones[i],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        const Text(
                          '쓰는 인간 · 모양과 색은 각각 선택',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/ink-mark.png'),
          key.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final rendered =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts').create(recursive: true);
        await File(
          'artifacts/book-detail-polished-${kind.name}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        rendered.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDisableShadows = shadows;
  });

  testWidgets('Render polished details inside the ordinary application', (
    tester,
  ) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = shadows);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final font in [
        [
          'WritingHumanDevelopment',
          'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        ],
        ['NanumMyeongjo', 'assets/fonts/NanumMyeongjo-Regular.ttf'],
        ['NanumGothic', 'assets/fonts/NanumGothic-Regular.ttf'],
        ['MaterialIcons', 'fonts/MaterialIcons-Regular.otf'],
        [
          'packages/cupertino_icons/CupertinoIcons',
          'packages/cupertino_icons/assets/CupertinoIcons.ttf',
        ],
      ]) {
        await (FontLoader(font[0])..addFont(rootBundle.load(font[1]))).load();
      }
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: WritingHumanApp(store: DemoStore()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final name in [
        'cotton-paper.jpg',
        'ink-mark.png',
        'linen-cover.png',
        'ivory-linen-cover.png',
        'blue-linen-cover.png',
      ]) {
        await precacheImage(
          AssetImage('assets/images/$name'),
          key.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      expect(find.textContaining('예시'), findsNothing);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts').create(recursive: true);
        await File(
          'artifacts/book-details-polished-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('writing');
    await tester.tap(find.text('새는 알에서 나오려고 투쟁한다. 알은 세계다.'));
    await tester.pumpAndSettle();
    await capture('source');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보관함'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('책'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('데미안').last);
    await tester.pumpAndSettle();
    await capture('bookplate');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('쓰기 도구'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('책의 디테일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('책의 디테일'));
    await tester.pumpAndSettle();
    await capture('settings');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDisableShadows = shadows;
  });
}
