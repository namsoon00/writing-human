import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_materials.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_watercolor.dart';

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
    'Framed wall art stays visible from straight and oblique first-person views',
    () async {
      final world = CafeWorld(), art = await CafeMaterials.artwork();
      try {
        for (final position in [
          const CafePoint(2.44, 1.62, 3.1),
          const CafePoint(1.8, 1.62, 2.2),
        ]) {
          final camera = CafeCamera(
            position: position,
            yaw: 3.14159265,
            pitch: -.05,
          );
          const size = ui.Size(800, 600);
          final recorder = ui.PictureRecorder();
          CafeRenderer(
            world: world,
            camera: camera,
            artwork: art,
          ).paint(ui.Canvas(recorder), size);
          final picture = recorder.endRecording();
          final image = await picture.toImage(800, 600);
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            final matPoint = CafeRenderer.project(
              const CafePoint(2.02, 1.86, 4.818),
              camera,
              size,
            )!;
            final m = (matPoint.dy.round() * 800 + matPoint.dx.round()) * 4;
            final matBrightness = pixels[m] + pixels[m + 1] + pixels[m + 2];
            // Sample painted terrain, above the blank paper margin. Compare
            // against the nearby mat so the check survives brighter lighting.
            for (final x in [2.32, 2.44, 2.56]) {
              final point = CafeRenderer.project(
                CafePoint(x, 1.86, 4.819),
                camera,
                size,
              )!;
              final i = (point.dy.round() * 800 + point.dx.round()) * 4;
              expect(
                pixels[i] + pixels[i + 1] + pixels[i + 2],
                lessThan(matBrightness - 85),
                reason: 'walnut/mat backing must not hide landscape at $x',
              );
            }
          } finally {
            image.dispose();
            picture.dispose();
          }
        }
      } finally {
        art.dispose();
      }
    },
  );

  test(
    'Tabletop does not paint across the seated notebook, pencil or cup',
    () async {
      final world = CafeWorld();
      final camera = world.seatedCamera(CafeSeat.shared);
      final base = world.objects['shared']!.pivot;
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

        // Check both ends as well as the middle of the dark shaft. The brass
        // ferrule at x=.1915..2185 is deliberately brighter than the lacquer.
        for (final x in [.23, .25, .29, .34, .38]) {
          final spot = CafeRenderer.project(
            base + CafePoint(x, .811, .49),
            camera,
            size,
          )!;
          final hit = CafeRenderer.pick(
            ui.Offset(spot.dx.roundToDouble(), spot.dy.roundToDouble()),
            camera,
            size,
            world,
          );
          expect(hit?.objectId, 'shared.pen');
          expect(
            brightness(base + CafePoint(x, .811, .49)),
            lessThan(350),
            reason: 'pencil hidden at x=$x',
          );
        }
        expect(
          brightness(base + const CafePoint(.205, .814, .49)),
          greaterThan(brightness(base + const CafePoint(.25, .811, .49)) + 90),
          reason:
              'the visible brass ferrule must not be covered by dark lacquer',
        );
        for (final z in [.64, .67, .83]) {
          expect(
            brightness(base + CafePoint(.32, .8005, z)),
            greaterThan(650),
            reason: 'paper hidden at z=$z',
          );
        }
        // Sample inside the narrow ring; its outside silhouette is antialiased.
        final rim = brightness(base + const CafePoint(-.155, .869, .18));
        final tea = brightness(base + const CafePoint(-.2, .866, .18));
        expect(
          rim,
          greaterThan(480),
          reason: 'ceramic rim must remain visible',
        );
        expect(
          tea,
          lessThan(rim - 90),
          reason: 'tea must be visible below the hollow rim',
        );
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
  );
  test(
    'A charcoal chair remains visibly different with a real timber shader',
    () async {
      const id = 'shared.chair.right.1', size = ui.Size(240, 240);
      final worlds = [
        CafeWorld(),
        CafeWorld(space: const CafeSpace(finishes: {id: 2})),
      ];
      final wood = await CafeWatercolor.wood(walnut: true);
      final camera = CafeCamera(
        position:
            worlds.first.objects[id]!.pivot + const CafePoint(.55, 1.10, .8),
        yaw: -.602,
        pitch: -.45,
      );
      final pixels = <List<int>>[];
      try {
        for (final world in worlds) {
          world.faces.removeWhere(
            (f) => f.objectId != id || f.surface != CafeSurface.walnut,
          );
          final recorder = ui.PictureRecorder();
          CafeRenderer(
            world: world,
            camera: camera,
            walnut: wood,
            allowPortal: false,
          ).paint(ui.Canvas(recorder), size);
          final picture = recorder.endRecording();
          final image = await picture.toImage(240, 240);
          try {
            pixels.add(
              (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List(),
            );
          } finally {
            image.dispose();
            picture.dispose();
          }
        }
        var before = 0, after = 0, samples = 0;
        for (var y = 18; y < 222; y += 3) {
          for (var x = 18; x < 222; x += 3) {
            final hit = CafeRenderer.pick(
              ui.Offset(x.toDouble(), y.toDouble()),
              camera,
              size,
              worlds.first,
            );
            if (hit?.objectId != id) continue;
            final index = (y * 240 + x) * 4;
            for (var c = 0; c < 3; c++) {
              before += pixels[0][index + c];
              after += pixels[1][index + c];
            }
            samples++;
          }
        }
        expect(samples, greaterThan(30));
        expect(
          after,
          lessThan(before * .86),
          reason:
              'The third finish must tint the timber texture as well as the untextured model.',
        );
      } finally {
        wood.dispose();
      }
    },
  );
}
