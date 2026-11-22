import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Long grain follows a table top and its upright legs without collapsing',
    () {
      CafeFace face(CafeGrain grain, List<CafePoint> points) => CafeFace(
        points,
        CafeWorld.oak,
        surface: CafeSurface.oak,
        grain: grain,
      );
      final top = face(CafeGrain.z, const [
        CafePoint(0, .75, 1),
        CafePoint(1, .75, 1),
        CafePoint(1, .75, 0),
        CafePoint(0, .75, 0),
      ]);
      final leg = face(CafeGrain.y, const [
        CafePoint(0, 0, 0),
        CafePoint(.05, 0, 0),
        CafePoint(.05, .7, 0),
        CafePoint(0, .7, 0),
      ]);
      for (final mesh in [top, leg]) {
        final uv = mesh.points
            .map((p) => CafeRenderer.materialUv(mesh, p))
            .toList();
        expect(uv.map((p) => p.dx).toSet().length, greaterThan(1));
        expect(uv.map((p) => p.dy).toSet().length, greaterThan(1));
      }
      expect(
        CafeRenderer.materialUv(top, top.points[0]).dx,
        CafeRenderer.materialUv(top, top.points[3]).dx,
      );
      expect(
        CafeRenderer.materialUv(leg, leg.points[0]).dx,
        CafeRenderer.materialUv(leg, leg.points[3]).dx,
      );
    },
  );

  test(
    'Tabletop does not paint across the seated notebook, pencil or cup',
    () async {
      final world = CafeWorld(), camera = CafeCamera.seated(CafeSeat.shared);
      const size = ui.Size(1000, 800);
      final recorder = ui.PictureRecorder();
      CafeRenderer(
        world: world,
        camera: camera,
      ).paint(ui.Canvas(recorder), size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1000, 800);
      try {
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        int brightness(CafePoint point) {
          final p = CafeRenderer.project(point, camera, size)!;
          final x = p.dx.round(), y = p.dy.round();
          expect(x, inInclusiveRange(1, 998));
          expect(y, inInclusiveRange(1, 798));
          final i = (y * 1000 + x) * 4;
          return pixels[i] + pixels[i + 1] + pixels[i + 2];
        }

        // Check both ends as well as the middle, where long painter-sorted
        // tabletop triangles previously hid part of the small resting objects.
        for (final x in [.20, .25, .29, .34, .38]) {
          expect(
            brightness(CafePoint(x, .811, .49)),
            lessThan(350),
            reason: 'pencil hidden at x=$x',
          );
        }
        for (final z in [.67, .74, .83]) {
          expect(
            brightness(CafePoint(.32, .8005, z)),
            greaterThan(650),
            reason: 'paper hidden at z=$z',
          );
        }
        expect(brightness(const CafePoint(-.2, .87, .18)), greaterThan(580));
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
  );
}
