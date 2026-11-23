import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Wide transparent entrance remains a directly selectable exit', () {
    final world = CafeWorld();
    final panes = world.faces
        .where(
          (f) => f.surface == CafeSurface.glass && f.target == CafeTarget.exit,
        )
        .toList();
    expect(panes.length, 2);
    final xs = panes.expand((f) => f.points.map((p) => p.x));
    expect(xs.reduce(math.max) - xs.reduce(math.min), greaterThan(2.1));
    final approach = world.targetApproach(CafeTarget.exit);
    expect(world.canStand(approach), isTrue);
    expect(world.path(CafeCamera.entrance.position, approach), isNotEmpty);
  });

  test(
    'Entry view has no backing fragments across front, side and close views',
    () async {
      final world = CafeWorld();
      // A blue sentinel in the actual exterior recess makes any opaque backing,
      // wall or checkerboard overpaint visible, independently of material assets.
      for (var i = 0; i < world.faces.length; i++) {
        final face = world.faces[i];
        if (face.layer < 0) {
          world.faces[i] = CafeFace(
            face.points,
            const ui.Color(0xff173c76),
            unlit: true,
            doubleSided: true,
            layer: face.layer,
          );
        } else if (face.target == CafeTarget.exit &&
            face.surface == CafeSurface.oak &&
            face.center.y < .3) {
          world.faces[i] = CafeFace(
            face.points,
            const ui.Color(0xffc81e1e),
            unlit: true,
            layer: face.layer,
            target: CafeTarget.exit,
          );
        }
      }
      const size = ui.Size(390, 720);
      for (final camera in [
        const CafeCamera(
          position: CafePoint(.35, 1.62, 2.10),
          yaw: 3.02,
          pitch: -.18,
        ),
        const CafeCamera(
          position: CafePoint(-.85, 1.62, 2.55),
          yaw: 3.42,
          pitch: -.12,
        ),
        const CafeCamera(
          position: CafePoint(.85, 1.62, 2.55),
          yaw: 2.86,
          pitch: -.12,
        ),
        const CafeCamera(
          position: CafePoint(0, 1.62, 4.05),
          yaw: math.pi,
          pitch: -.10,
        ),
      ]) {
        final recorder = ui.PictureRecorder();
        CafeRenderer(
          world: world,
          camera: camera,
        ).paint(ui.Canvas(recorder), size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(390, 720);
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var checked = 0;
          for (final x in [-.80, -.55, -.30, .30, .55, .80]) {
            for (final y in [.65, .95, 1.45, 1.8, 2.2, 2.45]) {
              final p = CafeRenderer.project(
                CafePoint(x, y, 4.91),
                camera,
                size,
              );
              if (p == null ||
                  p.dx < 3 ||
                  p.dx > 386 ||
                  p.dy < 3 ||
                  p.dy > 716) {
                continue;
              }
              final hit = CafeRenderer.pick(p, camera, size, world);
              // A real pendant or nearer furniture may legitimately hide a
              // piece of the doorway. Door/back-wall fragments must not.
              if (hit != null &&
                  hit.target != CafeTarget.exit &&
                  hit.position.z < 4.80) {
                continue;
              }
              expect(hit?.target, CafeTarget.exit);
              final i = (p.dy.round() * 390 + p.dx.round()) * 4;
              expect(
                pixels[i + 2],
                greaterThan(pixels[i] + 45),
                reason: 'opaque fragment at x=$x y=$y eye=${camera.position.x}',
              );
              expect(
                CafeRenderer.pick(p, camera, size, world)?.target,
                CafeTarget.exit,
              );
              checked++;
            }
          }
          expect(checked, greaterThan(3));
          for (final x in [-.8, -.55, -.3, .3, .55, .8]) {
            for (final y in [.06, .095, .125, .155]) {
              final p = CafeRenderer.project(
                CafePoint(x, y, 4.9025),
                camera,
                size,
              );
              if (p == null ||
                  p.dx < 3 ||
                  p.dx > 386 ||
                  p.dy < 3 ||
                  p.dy > 716) {
                continue;
              }
              final i = (p.dy.round() * 390 + p.dx.round()) * 4;
              expect(
                pixels[i + 1],
                lessThan(80),
                reason:
                    'threshold overpaint at x=$x y=$y eye=${camera.position.x}',
              );
              expect(pixels[i], greaterThan(160));
            }
          }
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
    },
  );
}
