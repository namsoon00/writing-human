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
import 'package:writing_human/cafe/cafe_renderer.dart';

void main() {
  testWidgets('Capture the individual cafe items', (tester) async {
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
        final file = File('output/cafe-items-20261124/$name.png');
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
    await capture('entrance-390');
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    await capture('entrance-wide');
    final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
    for (final shot in <String, CafeCamera>{
      'central-items': const CafeCamera(
        position: CafePoint(1.65, 1.62, 1.95),
        yaw: -.65,
        pitch: -.43,
      ),
      'cup-close': const CafeCamera(
        position: CafePoint(.28, 1.06, .73),
        yaw: -.72,
        pitch: -.29,
      ),
      'note-close': const CafeCamera(
        position: CafePoint(.78, 1.18, 1.12),
        yaw: -.97,
        pitch: -.52,
      ),
      'chairs': const CafeCamera(
        position: CafePoint(1.85, 1.62, 2.65),
        yaw: -.40,
        pitch: -.44,
      ),
      'counter': const CafeCamera(
        position: CafePoint(1.35, 1.62, -3.1),
        yaw: -.02,
        pitch: -.22,
      ),
      'shelf': const CafeCamera(
        position: CafePoint(2.65, 1.62, -1.3),
        yaw: 1.8,
        pitch: -.14,
      ),
    }.entries) {
      c.updateCamera(shot.value);
      await tester.pumpAndSettle();
      await capture(shot.key);
    }
    final unedited = c.space;
    expect(
      c.applySpace(unedited.withFinish('shared.chair.right.2', 2)),
      isNull,
    );
    c.updateCamera(
      const CafeCamera(
        position: CafePoint(1.85, 1.30, 1.95),
        yaw: -.769,
        pitch: -.45,
      ),
    );
    await tester.pumpAndSettle();
    await capture('chair-finishes');
    expect(c.applySpace(unedited), isNull);
    c.updateCamera(CafeCamera.entrance);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-edit')));
    await tester.pumpAndSettle();
    tester.widget<CafeScene>(find.byType(CafeScene)).onObjectSelected!(
      'shared.cup',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-inspect')));
    await tester.pumpAndSettle();
    await capture('cup-controls-wide');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await capture('cup-controls-phone');
    await tester.ensureVisible(find.byKey(const ValueKey('room-cancel')));
    await tester.tap(find.byKey(const ValueKey('room-cancel')));
    await tester.pumpAndSettle();
    expect(c.visit(CafeTarget.courtyard), isTrue);
    await tester.pumpAndSettle();
    expect(c.inCourtyard, isTrue);
    tester.view.physicalSize = const Size(1200, 800);
    c.updateCamera(
      const CafeCamera(
        position: CafePoint(.35, 1.62, 2.6),
        yaw: -.65,
        pitch: -.30,
      ),
    );
    await tester.pumpAndSettle();
    await capture('garden');
    final flowers = c.world.objects.values
        .firstWhere((o) => o.id.startsWith('garden.flowers.'))
        .pivot;
    c.updateCamera(
      CafeCamera(
        position: flowers + const CafePoint(.37, .70, .52),
        yaw: -.618,
        pitch: -.60,
      ),
    );
    await tester.pumpAndSettle();
    await capture('flowers-close');
    expect(c.applySpace(c.space.withFinish('garden.tree.18', 1)), isNull);
    c.updateCamera(
      const CafeCamera(
        position: CafePoint(.35, 1.62, 2.6),
        yaw: -.65,
        pitch: -.30,
      ),
    );
    await tester.pumpAndSettle();
    await capture('garden-light-leaves');
    debugDisableShadows = shadows;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
