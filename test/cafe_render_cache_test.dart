import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_world.dart';

const camera = CafeCamera(position: CafePoint(0, 0, 0), pitch: 0);
const size = ui.Size(120, 180);
CafeFace panel(ui.Color color, {double z = -2}) => CafeFace(
  [
    CafePoint(-1, -1, z),
    CafePoint(1, -1, z),
    CafePoint(1, 1, z),
    CafePoint(-1, 1, z),
  ],
  color,
  unlit: true,
);
CafeWorld fixture() {
  final world = CafeWorld();
  world.faces.clear();
  world.pendantLights.clear();
  return world;
}

Future<Uint8List> pixels(CafeRenderer painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  try {
    return Uint8List.fromList(
      (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List(),
    );
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  testWidgets('Reuse static geometry and invalidate replacement faces', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final world = fixture()..faces.add(panel(const ui.Color(0xffff0000)));
      final hits = <bool>[];
      Future<Uint8List> render() => pixels(
        CafeRenderer(
          world: world,
          camera: camera,
          allowPortal: false,
          onTiming: (t) => hits.add(t.cacheHit),
        ),
      );
      final red = await render();
      expect(await render(), red);
      expect(hits, [false, true]);
      world.faces[0] = panel(const ui.Color(0xff0000ff));
      final blue = await render();
      expect(hits.last, isFalse);
      expect(blue, isNot(red));
      expect(await render(), blue);
      world.faces.clear();
      expect(await render(), isNot(blue));
      expect(hits.last, isFalse);
    });
  });

  testWidgets(
    'Cached cuts retain colour, transparency and near-plane ordering',
    (tester) async {
      await tester.runAsync(() async {
        final world = fixture()
          ..faces.addAll([
            panel(const ui.Color(0xffab4115)),
            CafeFace(
              const [
                CafePoint(-.7, -.6, -1),
                CafePoint(.7, -.6, -3),
                CafePoint(.7, .6, -3),
                CafePoint(-.7, .6, -1),
              ],
              const ui.Color(0xff287c65),
              unlit: true,
            ),
            panel(const ui.Color(0x556f87c0), z: -.8),
          ]);
        for (final eye in [
          camera,
          const CafeCamera(
            position: CafePoint(.35, .1, -.74),
            yaw: -.2,
            pitch: .02,
          ),
        ]) {
          final reference = await pixels(
            CafeRenderer(
              world: world,
              camera: eye,
              cacheGeometry: false,
              allowPortal: false,
            ),
          );
          final cached = await pixels(
            CafeRenderer(world: world, camera: eye, allowPortal: false),
          );
          // Shared triangle edges can differ by an 8-bit blend rounding step.
          var differing = 0;
          for (var i = 0; i < cached.length; i++) {
            if ((cached[i] - reference[i]).abs() > 2) differing++;
          }
          expect(differing / cached.length, lessThan(.008));
          expect(
            await pixels(
              CafeRenderer(world: world, camera: eye, allowPortal: false),
            ),
            cached,
          );
        }
      });
    },
  );

  testWidgets('Loading a plant image rebuilds the cached dynamic order', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final world = fixture();
      world.plants.clear();
      world.plants.add(
        const CafePlant(CafePoint(0, -1, -2), 2, 2, CafeSurface.tree),
      );
      final empty = await pixels(
        CafeRenderer(world: world, camera: camera, allowPortal: false),
      );
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xff247a36), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final texture = await picture.toImage(8, 8);
      try {
        final loaded = await pixels(
          CafeRenderer(
            world: world,
            camera: camera,
            tree: texture,
            allowPortal: false,
          ),
        );
        final center = (90 * 120 + 60) * 4;
        expect(loaded, isNot(empty));
        expect(loaded[center + 1], greaterThan(loaded[center]));
        expect(
          await pixels(
            CafeRenderer(
              world: world,
              camera: camera,
              tree: texture,
              allowPortal: false,
            ),
          ),
          loaded,
        );
        expect(
          await pixels(
            CafeRenderer(world: world, camera: camera, allowPortal: false),
          ),
          empty,
        );
      } finally {
        texture.dispose();
        picture.dispose();
      }
    });
  });

  testWidgets(
    'Moving geometry still crosses behind and in front of a cached wall',
    (tester) async {
      await tester.runAsync(() async {
        final world = fixture()..faces.add(panel(const ui.Color(0xff0000ff)));
        Future<Uint8List> frame(double z) => pixels(
          CafeRenderer(
            world: world,
            camera: camera,
            allowPortal: false,
            avatar: [panel(const ui.Color(0xffff0000), z: z)],
          ),
        );
        final behind = await frame(-3);
        final ahead = await frame(-1);
        final center = (90 * 120 + 60) * 4;
        expect(behind[center], 0);
        expect(behind[center + 2], 255);
        expect(ahead[center], 255);
        expect(ahead[center + 2], 0);
        expect(await frame(-3), behind);
      });
    },
  );

  testWidgets(
    'Static projection reuse does not freeze changing light or textures',
    (tester) async {
      await tester.runAsync(() async {
        final world = fixture()
          ..faces.add(
            CafeFace(
              const [
                CafePoint(-1, -1, -2),
                CafePoint(1, -1, -2),
                CafePoint(1, 1, -2),
                CafePoint(-1, 1, -2),
              ],
              CafeWorld.oak,
              surface: CafeSurface.oak,
            ),
          );
        final textureRecorder = ui.PictureRecorder();
        ui.Canvas(
          textureRecorder,
        ).drawColor(const ui.Color(0xffc8a36c), ui.BlendMode.src);
        final picture = textureRecorder.endRecording();
        final texture = await picture.toImage(8, 8);
        try {
          final plain = await pixels(
            CafeRenderer(world: world, camera: camera, allowPortal: false),
          );
          final textured = await pixels(
            CafeRenderer(
              world: world,
              camera: camera,
              wood: texture,
              allowPortal: false,
            ),
          );
          expect(textured, isNot(plain));
          final dusk = await pixels(
            CafeRenderer(
              world: world,
              camera: camera,
              wood: texture,
              lightTime: 360,
              allowPortal: false,
            ),
          );
          expect(dusk, isNot(textured));
          final reference = await pixels(
            CafeRenderer(
              world: world,
              camera: camera,
              wood: texture,
              lightTime: 360,
              cacheGeometry: false,
              allowPortal: false,
            ),
          );
          expect(dusk, reference);
          expect(
            await pixels(
              CafeRenderer(
                world: world,
                camera: camera,
                wood: texture,
                allowPortal: false,
              ),
            ),
            textured,
          );
        } finally {
          texture.dispose();
          picture.dispose();
        }
      });
    },
  );
}
