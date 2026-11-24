// Synthetic fixture rendered by Flutter tests, not a browser or device capture.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/demo_store.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_home.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';

void main() {
  testWidgets('Capture a returning writing place', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = shadows);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      for (final entry in {
        'WritingHumanDevelopment':
            'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        'NanumMyeongjo': 'assets/fonts/NanumMyeongjo-Regular.ttf',
        'NanumGothic': 'assets/fonts/NanumGothic-Regular.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        'packages/cupertino_icons/CupertinoIcons':
            'packages/cupertino_icons/assets/CupertinoIcons.ttf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    });
    final store = DemoStore();
    await store.save(const Library());
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: WritingHumanApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-cafe')));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/cafe-homecoming-20261124/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/ink-mark-bleed.png'),
        boundary.currentContext!,
      );
    });
    await tester.pumpAndSettle();
    List<ui.Image?> sources() {
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is CafeRenderer,
                    ),
                  )
                  .painter!
              as CafeRenderer;
      return [
        painter.wood,
        painter.sign,
        painter.walnut,
        painter.limestone,
        painter.woven,
        painter.plaster,
        painter.artwork,
        painter.gravel,
        painter.tree,
        painter.flowers,
        ...painter.framedArt,
      ];
    }

    for (
      var i = 0;
      i < 100 && (sources().length != 13 || sources().any((v) => v == null));
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(sources().length, 13);
    expect(sources().every((v) => v != null && !v.debugDisposed), isTrue);

    final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
    c.applySpace(
      c.space.copy(
        home: const CafeHome(mood: 2, pinned: '좋아하는 문장 곁에 오늘의 나를 놓아두었다.'),
      ),
    );
    c.visit(CafeTarget.window);
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 100 &&
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is CafeRenderer,
                    ),
                  )
                  .painter
              is CafeRenderer &&
          (tester
                          .widget<CustomPaint>(
                            find.byWidgetPredicate(
                              (w) =>
                                  w is CustomPaint && w.painter is CafeRenderer,
                            ),
                          )
                          .painter
                      as CafeRenderer)
                  .letterAtlas ==
              null;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is CafeRenderer,
                  ),
                )
                .painter
            as CafeRenderer;
    expect(painter.letterAtlas, isNotNull);
    expect(painter.letterAtlas!.debugDisposed, isFalse);
    await capture('rain-window-390');
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    await capture('rain-window-wide');
    c.applySpace(c.space.copy(home: c.space.home.copy(mood: 1)));
    await tester.pumpAndSettle();
    await capture('dusk-window-wide');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    tester.widget<CafeScene>(find.byType(CafeScene)).onItemActivated!(
      'ritual.window.today',
    );
    await tester.pumpAndSettle();
    await capture('today-sentence-390');
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    c.updateCamera(
      const CafeCamera(position: CafePoint(-3.23, 1.67, -3.8), pitch: .14),
    );
    await tester.pumpAndSettle();
    await capture('my-sentence-frame');
    expect(tester.takeException(), isNull);
    debugDisableShadows = shadows;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
