// Actual Flutter frames, replayed at the recorded timing; no generated art.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_materials.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_walk.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Capture timed quiet walking, stopping and meditation joints',
    () async {
      final output = Directory(
        const String.fromEnvironment(
          'MOTION_CAPTURE',
          defaultValue: 'output/cafe-human-motion-20261128/frames',
        ),
      );
      await output.create(recursive: true);
      final c = CafeViewController();
      final world = c.world;
      world.faces.clear();
      world.plants.clear();
      world.linkedWorld.faces.clear();
      world.linkedWorld.plants.clear();
      world.faces.add(
        CafeFace(const [
          CafePoint(-8, 0, -8),
          CafePoint(-8, 0, 8),
          CafePoint(8, 0, 8),
          CafePoint(8, 0, -8),
        ], const ui.Color(0xffc6bda8)),
      );
      for (var z = -7.0; z < 7; z += .4) {
        world.faces.add(
          CafeFace([
            CafePoint(-8, .001, z),
            CafePoint(-8, .001, z + .003),
            CafePoint(8, .001, z + .003),
            CafePoint(8, .001, z),
          ], const ui.Color(0xffb6ad99)),
        );
      }
      final knit = await CafeMaterials.knit();
      Future<void> save(
        String name,
        CafeAvatar avatar, {
        double side = .8,
        CafeWorld? scene,
      }) async {
        final r = ui.PictureRecorder();
        final origin = avatar.origin;
        CafeRenderer(
          world: scene ?? world,
          avatar: avatar.faces,
          use: avatar.use,
          useCamera: avatar.eye,
          knit: knit,
          allowPortal: false,
          camera: CafeCamera(
            position: origin + CafePoint(side, 1.04, -2.55),
            yaw: math.atan2(-side, -2.55),
            pitch: -.14,
          ),
        ).paint(ui.Canvas(r), const ui.Size(480, 600));
        final picture = r.endRecording();
        final image = await picture.toImage(480, 600);
        picture.dispose();
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      }

      try {
        const fps = 12;
        final timing = CafeWalkTiming(1.45);
        final count = (timing.seconds * fps).ceil();
        for (var i = 0; i <= count; i++) {
          final progress = i / count;
          c.advanceCamera(
            CafeCamera(position: CafePoint(0, 1.62, -timing.at(progress))),
            dt: timing.seconds / count,
            walking: true,
          );
          await save('walk-${i.toString().padLeft(3, '0')}', c.avatar);
        }
        c.stopWalking(smooth: true);
        for (var i = 1; i <= 6; i++) {
          c.advanceSettle(i / 6);
          await save(
            'walk-${(count + i).toString().padLeft(3, '0')}',
            c.avatar,
          );
        }
        final yard = CafeWorld(courtyard: true);
        final mat = yard.faces
            .where((f) => f.target == CafeTarget.meditation)
            .map(
              (f) => CafeFace(
                f.points
                    .map((p) => CafePoint(p.x - 2.8, p.y, p.z + 8.5))
                    .toList(),
                f.color,
                part: 'motion.mat',
                vertexNormals: f.vertexNormals,
                doubleSided: f.doubleSided,
              ),
            )
            .toList();
        world.faces.addAll(mat);
        for (var i = 0; i <= 30; i++) {
          final p = i / 30;
          final a = CafeAvatar(
            eye: CafeCamera(position: CafePoint(0, 1.62 - p * .84, 0)),
            yaw: 0,
            meditation: p,
          );
          await save('fold-${i.toString().padLeft(3, '0')}', a);
        }
        for (final side in [.05, 1.5, -1.5]) {
          await save(
            'meditation-$side',
            CafeAvatar(
              eye: const CafeCamera(position: CafePoint(0, .78, 0)),
              yaw: 0,
              meditation: 1,
            ),
            side: side,
          );
        }
        final props = CafeWorld();
        props.faces.removeWhere((f) => f.objectId != 'shared.cup');
        props.plants.clear();
        props.faces.addAll(world.faces.where((f) => f.part != 'motion.mat'));
        for (var i = 0; i <= 26; i++) {
          final frame = CafeUseFrame(
            'shared.cup',
            CafeUseKind.sip,
            held: true,
            progress: Curves.easeInOutCubic.transform(i / 26),
          );
          final avatar = CafeAvatar(
            eye: const CafeCamera(position: CafePoint(0, 1.62, 0)),
            yaw: 0,
            use: frame,
            object: props.objects['shared.cup'],
          );
          await save(
            'sip-${i.toString().padLeft(3, '0')}',
            avatar,
            scene: props,
          );
        }
        expect(c.camera.position.z, closeTo(-1.45, 1e-9));
      } finally {
        knit.dispose();
        c.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
