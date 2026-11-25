// Real Flutter mesh renders with synthetic poses, not generated concept art.
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/ui/cafe_scene.dart';

void main() {
  testWidgets('Render A male model and actual third-person cafe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final entry in {
        'WritingHumanDevelopment':
            'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    });
    final boundary = GlobalKey();
    Future<void> save(String name) async {
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '${const String.fromEnvironment('CAFE_CAPTURE', defaultValue: 'output/cafe-avatar-a-20261125')}/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    final world = CafeWorld();
    world.faces.clear();
    world.faces.add(
      CafeFace(const [
        CafePoint(-8, 0, -8),
        CafePoint(-8, 0, 8),
        CafePoint(8, 0, 8),
        CafePoint(8, 0, -8),
      ], const Color(0xffc6b8a1)),
    );
    for (final front in [true, false]) {
      final avatar = CafeAvatar(
        eye: const CafeCamera(position: CafePoint(0, 1.62, 0)),
        yaw: 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: CustomPaint(
              painter: CafeRenderer(
                world: world,
                avatar: avatar.faces,
                allowPortal: false,
                camera: CafeCamera(
                  position: CafePoint(
                    front ? -.65 : .65,
                    1.2,
                    front ? -2.8 : 2.8,
                  ),
                  yaw: front ? math.pi - .228 : -.228,
                  pitch: -.11,
                ),
              ),
              size: Size.infinite,
            ),
          ),
        ),
      );
      await save(front ? 'model-front' : 'model-back');
    }
    final props = CafeWorld();
    final volume = props.objects.values.firstWhere(
      (o) => o.type == CafeItemType.volume,
    );
    props.faces.removeWhere(
      (f) => f.objectId != 'shared.cup' && f.objectId != volume.id,
    );
    props.faces.addAll(world.faces);
    const eye = CafeCamera(position: CafePoint(0, 1.62, 0));
    for (final frame in [
      const CafeUseFrame(
        'shared.cup',
        CafeUseKind.sip,
        held: true,
        progress: .5,
      ),
      CafeUseFrame(volume.id, CafeUseKind.hold, held: true, open: true),
    ]) {
      final avatar = CafeAvatar(
        eye: eye,
        yaw: 0,
        use: frame,
        object: props.objects[frame.id],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: CustomPaint(
              painter: CafeRenderer(
                world: props,
                avatar: avatar.faces,
                use: frame,
                useCamera: eye,
                allowPortal: false,
                camera: const CafeCamera(
                  position: CafePoint(-1.15, 1.3, -2.6),
                  yaw: 2.725,
                  pitch: -.15,
                ),
              ),
              size: Size.infinite,
            ),
          ),
        ),
      );
      await save(frame.kind == CafeUseKind.sip ? 'model-sip' : 'model-book');
    }
    tester.view.physicalSize = const Size(390, 844);
    final c = CafeViewController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'WritingHumanDevelopment'),
        home: RepaintBoundary(
          key: boundary,
          child: CafeScene(controller: c, onWrite: () {}),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await save('entrance-390');
    c.updateCamera(
      const CafeCamera(
        position: CafePoint(1.6, 1.62, 1.4),
        yaw: -.9,
        pitch: -.1,
      ),
    );
    await tester.pump();
    await save('aisle-390');
    c.sit(CafeSeat.window);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    await save('seated-390');
    unawaited(c.performUse('desk.window.cup', CafeUseKind.pickUp));
    c.advanceUse(1);
    c.finishUse();
    unawaited(c.performUse('desk.window.cup', CafeUseKind.sip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await save('sip-390');
    c.finishUse();
    c.look(-math.pi / 2, 0);
    unawaited(c.performUse('desk.window.cup', CafeUseKind.sip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await save('sip-side-390');
    c.finishUse();
    c.cancelUse();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
