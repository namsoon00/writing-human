// Synthetic fixture rendered by Flutter tests, not a browser or device capture.
import 'dart:io';
import 'dart:math' as math;
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
import 'package:writing_human/cafe/cafe_atmosphere.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';

void main() {
  testWidgets(
    'Capture light passage and personal sound mix',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
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
          final file = File('output/cafe-atmosphere-20261124/$name.png');
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
          home: const CafeHome(mood: 0),
          atmosphere: const CafeAtmosphere(),
        ),
      );
      c.visit(CafeTarget.window);
      await tester.pumpAndSettle();
      c.camera = CafeCamera(
        position: c.camera.position,
        yaw: -math.pi / 2 + .18,
        pitch: -.32,
      );
      c.inspect(null);
      await tester.pumpAndSettle();
      final original =
          tester
                  .widgetList<CustomPaint>(find.byType(CustomPaint))
                  .firstWhere((w) => w.painter is CafeRenderer)
                  .painter!
              as CafeRenderer;
      for (final phase in {
        'afternoon-window': 0.0,
        'late-window': 360.0,
        'leaf-shadow-desk': 0.0,
      }.entries) {
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder)..scale(2);
          CafeRenderer(
            world: c.world,
            camera: phase.key == 'leaf-shadow-desk'
                ? CafeCamera(
                    position: c.camera.position,
                    yaw: -math.pi / 2 + .18,
                    pitch: -.68,
                  )
                : c.camera,
            lightTime: phase.value,
            time: 12,
            wood: original.wood,
            sign: original.sign,
            walnut: original.walnut,
            limestone: original.limestone,
            woven: original.woven,
            plaster: original.plaster,
            artwork: original.artwork,
            gravel: original.gravel,
            tree: original.tree,
            flowers: original.flowers,
            framedArt: original.framedArt,
            letterAtlas: original.letterAtlas,
          ).paint(canvas, const Size(390, 844));
          final picture = recorder.endRecording();
          final image = await picture.toImage(780, 1688);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('output/cafe-atmosphere-20261124/${phase.key}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        });
      }
      await tester.tap(find.byTooltip('공간 안내'));
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('cafe-ritual-ambience'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await capture('personal-sound-mix');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugDisableShadows = shadows;
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
