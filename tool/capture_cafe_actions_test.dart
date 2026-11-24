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
import 'package:writing_human/cafe/cafe_renderer.dart';

void main() {
  testWidgets('Capture first-person cafe actions', (tester) async {
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
        final file = File('output/cafe-actions-20261124/$name.png');
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
    final scene = tester.widget<CafeScene>(find.byType(CafeScene));
    c.visit(CafeTarget.shared);
    await tester.pumpAndSettle();
    scene.onItemActivated!('shared.cup');
    await tester.pumpAndSettle();
    expect(c.heldId, 'shared.cup');
    await capture('cup-held-390');
    await tester.tap(find.byKey(const ValueKey('cafe-use-sip')));
    await tester.pumpAndSettle();
    await capture('cup-sipped-390');
    await tester.tap(find.byKey(const ValueKey('cafe-use-put-down')));
    await tester.pumpAndSettle();
    final id = 'shelf.recommendations.1.1';
    c.visit(CafeTarget.recommendations);
    await tester.pumpAndSettle();
    scene.onItemActivated!(id);
    await tester.pumpAndSettle();
    await capture('book-held-390');
    await tester.tap(find.byKey(const ValueKey('cafe-use-open')));
    await tester.pumpAndSettle();
    await capture('book-open-390');
    await tester.tap(find.byKey(const ValueKey('cafe-use-put-down')));
    await tester.pumpAndSettle();
    c.visit(CafeTarget.shared);
    await tester.pumpAndSettle();
    scene.onItemActivated!('shared.pen');
    await tester.pumpAndSettle();
    await capture('pencil-held-390');
    // Let a real gesture reach its middle frame instead of injecting a pose.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cafe-use-put-down')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 325));
    await capture('pencil-returning-390');
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    c.cancelUse();
    await tester.pump();
    expect(tester.takeException(), isNull);
    debugDisableShadows = shadows;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
