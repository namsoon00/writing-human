// Real Flutter mesh renders with synthetic poses, not generated concept art.
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_yard.dart';
import 'package:writing_human/ui/cafe_scene.dart';

void main() {
  testWidgets('Render implemented front yard and resting poses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.runAsync(() async {
      for (final e in {
        'WritingHumanDevelopment':
            'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
      }
    });
    final timings = <Map<String, Object>>[];
    final boundary = GlobalKey();
    final c = CafeViewController();
    c.inCourtyard = true;
    c.updateCamera(
      const CafeCamera(position: CafeYard.gate, yaw: math.pi, pitch: -.10),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'WritingHumanDevelopment'),
        home: RepaintBoundary(
          key: boundary,
          child: CafeScene(
            controller: c,
            onRenderTiming: (t) => timings.add({
              'courtyard': t.courtyard,
              'visible': t.visibleFaces,
              'projectUs': t.projectMicros,
              'orderUs': t.orderMicros,
              'submitUs': t.submitMicros,
              'linkedUs': t.linkedMicros,
            }),
            onWrite: () {},
            moment: DateTime(2026, 11, 25, 16),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    Future<void> save(String name) async {
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '${const String.fromEnvironment('CAFE_CAPTURE', defaultValue: 'output/cafe-yard-20261125')}/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await save('gate-wide');
    c.updateCamera(
      const CafeCamera(
        position: CafePoint(-13, 1.62, -7),
        yaw: 2.04,
        pitch: -.05,
      ),
    );
    await save('long-trail');
    c.updateCamera(
      const CafeCamera(
        position: CafePoint(-18.8, 1.62, -15.5),
        yaw: -1.1,
        pitch: -.25,
      ),
    );
    await save('stone-and-grass');
    c.updateCamera(
      const CafeCamera(
        position: CafePoint(-5.5, 1.62, -17.5),
        yaw: -.75,
        pitch: -.45,
      ),
    );
    await save('earth-underfoot');
    tester.view.physicalSize = const Size(390, 844);
    c.toggleBarefoot();
    c.updateCamera(
      const CafeCamera(position: CafeYard.shoeApproach, yaw: -.25, pitch: -.15),
    );
    await save('barefoot-390');
    c.visit(CafeTarget.meditation);
    await save('meditation-390');
    c.stand();
    c.visit(CafeTarget.trailRest);
    await save('rest-390');
    await tester.runAsync(() async {
      final path = const String.fromEnvironment(
        'CAFE_CAPTURE',
        defaultValue: 'output/cafe-yard-20261125',
      );
      await File('$path/render-metrics.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'scope': 'Native synthetic CPU paint samples, not device FPS',
          'faces': c.world.faces.length,
          'grassFaces': c.world.faces
              .where((f) => f.part == 'yard.grass.blade')
              .length,
          'samples': timings,
        }),
      );
    });
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
