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
import 'package:writing_human/cafe/cafe_camera.dart';

void main() {
  testWidgets('Capture first-person walking without an avatar', (tester) async {
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
        final file = File('output/cafe-first-person-20261122/$name.png');
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
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/cafe-garden-view.png'),
        boundary.currentContext!,
      );
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('공간 안내'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cafe-guide-courtyard')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CafeScene>(find.byType(CafeScene)).controller.inCourtyard,
      isTrue,
    );
    final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
    c.updateCamera(
      const CafeCamera(position: CafePoint(.4, 1.62, .3), pitch: -.1),
    );
    await tester.pumpAndSettle();
    await capture('first-idle-390');
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    await tester.pump();
    c.walkTo(const CafePoint(.4, 0, -.9));
    for (var i = 0; i < 3; i++) {
      for (var frame = 0; frame < 22; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await capture('first-walk-$i');
    }
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    c.updateCamera(c.destination ?? c.camera);
    c.finishTravel();
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    await capture('first-wide');
    await tester.pumpAndSettle();
    await capture('first-person-wide');
    debugDisableShadows = shadows;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
