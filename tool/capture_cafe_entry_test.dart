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
import 'package:writing_human/cafe/cafe_visit.dart';

void main() {
  testWidgets('Capture the clear cafe entrance', (tester) async {
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
        final file = File(
          'output/cafe-entry-${Platform.environment["CAFE_CAPTURE_STAGE"] ?? "after"}-20261123/$name.png',
        );
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
    await capture('entrance-390');
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    await capture('entrance-wide');
    final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
    for (final shot in <String, CafeCamera>{
      'exit-front': const CafeCamera(
        position: CafePoint(0, 1.62, 1.75),
        yaw: 3.14159,
        pitch: -.13,
      ),
      'exit-photo': const CafeCamera(
        position: CafePoint(.35, 1.62, 2.10),
        yaw: 3.02,
        pitch: -.18,
      ),
      'exit-left': const CafeCamera(
        position: CafePoint(-.85, 1.62, 2.55),
        yaw: 3.42,
        pitch: -.12,
      ),
      'exit-right': const CafeCamera(
        position: CafePoint(.85, 1.62, 2.55),
        yaw: 2.86,
        pitch: -.12,
      ),
      'exit-near': const CafeCamera(
        position: CafePoint(0, 1.62, 4.05),
        yaw: 3.14159,
        pitch: -.10,
      ),
    }.entries) {
      tester.view.physicalSize = const Size(390, 720);
      c.updateCamera(shot.value);
      await tester.pumpAndSettle();
      await capture(shot.key);
    }
    tester.view.physicalSize = const Size(1200, 800);
    c.updateCamera(
      const CafeCamera(
        position: CafePoint(0, 1.62, 2.10),
        yaw: 3.14159,
        pitch: -.08,
      ),
    );
    await tester.pumpAndSettle();
    await capture('exit-wide');
    c.sit(CafeSeat.quiet);
    await tester.pumpAndSettle();
    await capture('quiet-wide');
    debugDisableShadows = shadows;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
