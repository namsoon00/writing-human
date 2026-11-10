// Native Flutter specimens with synthetic copy; never user data or device captures.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
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
    tester.view.physicalSize = const Size(1080, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
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
          'artifacts/book-detail-design-${kind.name}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        rendered.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDisableShadows = shadows;
  });
}
