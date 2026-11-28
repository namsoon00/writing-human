import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'cafe_camera.dart';
import 'cafe_world.dart';
import 'cafe_visit.dart';
import 'cafe_atmosphere.dart';

part 'cafe_depth_order.dart';
part 'cafe_scene_mesh.dart';
part 'cafe_gpu_geometry.dart';

// Lightweight, camera-facing foliage while CPU watercolor images are loading.
// This is display LOD only; picking and GPU rendering keep the original solids.
Iterable<CafeFace> _pendingPlant(CafePlant plant, CafeCamera camera) sync* {
  final right = CafePoint(camera.right.x, 0, camera.right.z).normalized;
  final tree = plant.surface == CafeSurface.tree;
  CafeFace patch(List<CafePoint> points, Color color) => CafeFace(
    points,
    color,
    objectId: plant.objectId,
    part: 'plant.loading',
    doubleSided: true,
    unlit: true,
  );
  final base = plant.base, radius = tree ? plant.width * .018 : .007;
  yield patch([
    base - right * radius,
    base + right * radius,
    base + right * radius + CafePoint(0, plant.height * .85, 0),
    base - right * radius + CafePoint(0, plant.height * .85, 0),
  ], tree ? CafeWorld.dark : CafeWorld.sage);
  for (var i = 0; i < 3; i++) {
    final center =
        base +
        right * ((i - 1) * plant.width * (tree ? .12 : .23)) +
        CafePoint(
          0,
          plant.height * (tree ? .56 + i * .12 : .65 + (i % 2) * .23),
          0,
        );
    final width = plant.width * (tree ? .42 - i * .06 : .12);
    final height = plant.height * (tree ? .24 - i * .025 : .13);
    yield patch(
      [
        for (var j = 0; j < 16; j++)
          center +
              right *
                  (math.cos(j * math.pi / 8) *
                      width *
                      (1 + .07 * math.sin(j * 2.4))) +
              CafePoint(0, math.sin(j * math.pi / 8) * height, 0),
      ],
      tree
          ? const [Color(0xff8f9c78), Color(0xffa1ac88), Color(0xffb2bb9a)][i]
          : const [Color(0xffeee9d6), Color(0xffdac1c6), Color(0xfff3eedf)][i],
    );
  }
}

class _Vertex {
  const _Vertex(this.point, this.u, this.v, this.color);
  final CafePoint point;
  final double u, v;
  final Color color;
  static _Vertex lerp(_Vertex a, _Vertex b, double t) => _Vertex(
    CafePoint.lerp(a.point, b.point, t),
    a.u + (b.u - a.u) * t,
    a.v + (b.v - a.v) * t,
    Color.lerp(a.color, b.color, t)!,
  );
}

class _ProjectedFace {
  _ProjectedFace(this.face, this.vertices, this.depth);
  List<Offset>? screen;
  Rect? screenBounds;
  final CafeFace face;
  final List<_Vertex> vertices;
  final double depth;
}

class _Illumination {
  const _Illumination(this.ambient, this.lamp);
  final CafePoint ambient, lamp;
}

/// Optional CPU measurements; no record or room state is changed.
class CafeRenderTiming {
  const CafeRenderTiming({
    required this.courtyard,
    required this.projectMicros,
    required this.orderMicros,
    required this.submitMicros,
    required this.linkedMicros,
    required this.visibleFaces,
    required this.orderedFaces,
    required this.cacheHit,
  });
  final bool courtyard, cacheHit;
  final int projectMicros,
      orderMicros,
      submitMicros,
      linkedMicros,
      visibleFaces,
      orderedFaces;
}

/// Perspective projection of 3D mesh surfaces into Flutter's Canvas renderer.
/// Near-plane clipping prevents faces behind the eye from folding across view.
class CafeRenderer extends CustomPainter {
  CafeRenderer({
    required this.world,
    required this.camera,
    this.wood,
    this.sign,
    this.walnut,
    this.limestone,
    this.woven,
    this.knit,
    this.plaster,
    this.artwork,
    this.gravel,
    this.earth,
    this.fieldstone,
    this.tree,
    this.flowers,
    this.blossom,
    this.lawn,
    this.framedArt = const [],
    this.use,
    this.useCamera,
    this.avatar = const [],
    this.letterAtlas,
    this.time = 0,
    this.lightTime = 0,
    this.teaFilled = false,
    this.bellAt,
    this.teaAt,
    this.allowPortal = true,
    this.onTiming,
    this.cacheGeometry = true,
    this.detailCulling = true,
    this.viewportClip,
  });
  final ui.Image? letterAtlas;
  final CafeUseFrame? use;
  final CafeCamera? useCamera;
  final List<CafeFace> avatar;
  final CafeWorld world;
  final CafeCamera camera;
  final ui.Image? wood,
      sign,
      walnut,
      limestone,
      woven,
      knit,
      plaster,
      artwork,
      gravel,
      earth,
      fieldstone,
      tree,
      flowers;
  final List<ui.Image?> framedArt;
  final bool allowPortal;
  final bool cacheGeometry;
  final bool detailCulling;
  final ui.Image? blossom, lawn;
  final Rect? viewportClip;
  final void Function(CafeRenderTiming)? onTiming;
  static final _meshes = Expando<_SceneMesh>();
  final double time;
  final double lightTime;
  late final _lightFrame = CafeLightFrame(
    seconds: lightTime,
    flow: world.space.atmosphere.flow,
    mood: world.space.home.mood,
  );
  final bool teaFilled;
  final double? bellAt, teaAt;
  static const near = .075;
  static final _daylightDirection = const CafePoint(-.78, .58, .22).normalized;

  // Keep useful horizontal context on a phone without changing camera position.
  static double focalLength(Size size) =>
      math.min(size.height * .75, size.width * 1.25);

  static Offset? project(CafePoint point, CafeCamera camera, Size size) {
    if (!camera.isFinite ||
        !point.isFinite ||
        size.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return null;
    }
    final view = camera.toView(point);
    if (view.z < near) return null;
    final f = focalLength(size) * camera.lens;
    return Offset(
      size.width / 2 + view.x * f / view.z,
      size.height / 2 - view.y * f / view.z,
    );
  }

  static CafePoint ray(Offset point, CafeCamera camera, Size size) {
    final f = focalLength(size) * camera.lens;
    return (camera.forward +
            camera.right * ((point.dx - size.width / 2) / f) +
            camera.up * ((size.height / 2 - point.dy) / f))
        .normalized;
  }

  /// Nearest physical surface wins: objects behind shelves or a table cannot
  /// be selected through them. The same geometry drives rendering and picking.
  static CafeHit? pick(
    Offset point,
    CafeCamera camera,
    Size size,
    CafeWorld world, {
    CafeUseFrame? use,
    CafeCamera? useCamera,
  }) {
    if (!camera.isFinite ||
        size.isEmpty ||
        !point.dx.isFinite ||
        !point.dy.isFinite) {
      return null;
    }
    final direction = ray(point, camera, size);
    var closest = double.infinity;
    var foreground = false;
    CafeHit? result;
    for (final face in world.presentedFaces(
      useCamera ?? camera,
      use,
      thirdPerson: useCamera != null,
    )) {
      // Fine grass is decoration; floor clicks still reach the walking ground.
      if (face.part == 'yard.grass.blade') continue;
      // Floor light/shadow decals do not obstruct the physical surface.
      if (face.color.a < .99 && face.surface != CafeSurface.glass) continue;
      // The chase camera can be across the open bay while the person has
      // already arrived. That intervening portal is behind the person, not a
      // return action in front of them; let the ray reach their room's floor.
      if (face.garden && useCamera != null) {
        final observerSide = (camera.position - face.center).dot(face.normal);
        final actorSide = (useCamera.position - face.center).dot(face.normal);
        if (observerSide * actorSide < -1e-7) continue;
      }
      for (var i = 1; i + 1 < face.points.length; i++) {
        final a = face.points[0], b = face.points[i], c = face.points[i + 1];
        final edge1 = b - a, edge2 = c - a;
        final h = direction.cross(edge2), det = edge1.dot(h);
        if (det.abs() < 1e-9) continue;
        final delta = camera.position - a;
        final u = delta.dot(h) / det;
        if (u < 0 || u > 1) continue;
        final q = delta.cross(edge1), v = direction.dot(q) / det;
        if (v < 0 || u + v > 1) continue;
        final distance = edge2.dot(q) / det;
        if (distance < near) continue;
        final hand = face.layer == 5;
        if (foreground && !hand) continue;
        if (hand == foreground && distance >= closest) continue;
        foreground = hand;
        closest = distance;
        final hit = camera.position + direction * distance;
        result = CafeHit(
          hit,
          face.target,
          hit.y >= -.025 &&
              hit.y < .065 &&
              face.normal.y > .9 &&
              world.canStand(CafePoint(hit.x, 1.62, hit.z)),
          face.objectId,
        );
      }
    }
    return result;
  }

  static CafeSeat? pickSeat(Offset point, CafeCamera camera, Size size) {
    if (size.isEmpty) return null;
    final direction = ray(point, camera, size);
    if (direction.y.abs() < .00001) return null;
    final distance = (.77 - camera.position.y) / direction.y;
    if (distance < near) return null;
    final hit = camera.position + direction * distance;
    for (final seat in CafeSeat.values) {
      if (CafeWorld.tableBounds(seat).contains(Offset(hit.x, hit.z))) {
        return seat;
      }
    }
    return null;
  }

  List<_Vertex> _clip(List<_Vertex> vertices) {
    final output = <_Vertex>[];
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i], b = vertices[(i + 1) % vertices.length];
      final ai = a.point.z >= near, bi = b.point.z >= near;
      if (ai) output.add(a);
      if (ai != bi) {
        output.add(
          _Vertex.lerp(a, b, (near - a.point.z) / (b.point.z - a.point.z)),
        );
      }
    }
    return output;
  }

  ui.Image? _texture(CafeFace face) {
    if (face.objectId == 'avatar.a.male') {
      if (face.part?.startsWith('knit') == true) return knit ?? woven;
      return face.part?.startsWith('linen') == true ||
              face.part?.startsWith('trousers') == true
          ? woven
          : null;
    }
    if (face.part == 'ritual.print') return letterAtlas;
    if (face.sign) return sign;
    return switch (face.surface) {
      CafeSurface.oak => wood,
      CafeSurface.walnut => walnut ?? wood,
      CafeSurface.limestone => limestone,
      CafeSurface.cord => woven,
      CafeSurface.plaster => plaster,
      CafeSurface.artwork =>
        face.artIndex != null && framedArt.length > face.artIndex!
            ? framedArt[face.artIndex!] ?? artwork
            : artwork,
      CafeSurface.gravel => gravel,
      CafeSurface.earth => earth,
      CafeSurface.fieldstone => fieldstone,
      CafeSurface.tree => tree,
      CafeSurface.flowers => flowers,
      CafeSurface.blossom => blossom,
      CafeSurface.lawn => lawn,
      CafeSurface.water => plaster,
      CafeSurface.glass => null,
      CafeSurface.plain ||
      CafeSurface.brass => face.color.a >= .99 ? plaster : null,
    };
  }

  /// Physical repeat lengths keep long grain aligned with each timber member.
  /// End faces use two cross-grain axes instead of a collapsed UV coordinate.
  static Offset materialUv(CafeFace face, CafePoint p) => face.materialUv(p);

  static final _illumination = Expando<List<_Illumination>>();
  List<_Illumination> _diffuse(CafeFace face) =>
      _illumination[face] ??= List.generate(face.points.length, (i) {
        final p = face.points[i], n = face.vertexNormals?[i] ?? face.normal;
        if (world.courtyard) {
          final fill =
              (world.space.home.mood == 0 ? .80 : .49) +
              .18 * math.max(0, n.dot(_daylightDirection)) +
              .08 * math.max(0, n.y);
          var glow = 0.0;
          for (var i = 0; i < world.pendantLights.length; i++) {
            final delta = world.pendantLights[i] - p;
            glow +=
                world.pendantGains[i] *
                .65 *
                math.max(0, n.dot(delta.normalized)) /
                (1 + delta.dot(delta) * 2.4);
          }
          return _Illumination(
            CafePoint(
              fill * (world.space.home.mood == 0 ? 1 : .93),
              fill * .978,
              fill * (world.space.home.mood == 0 ? .925 : 1.08),
            ),
            CafePoint(glow, glow * .76, glow * .43),
          );
        }
        final window = math.exp(-(p.x + 4.4).clamp(0, 12) / 4.5);
        final fill =
            (world.space.home.mood == 0
                ? .76
                : world.space.home.mood == 1
                ? .58
                : .52) +
            .11 * math.max(0, n.dot(_daylightDirection)) * window +
            .035 * math.max(0, n.y);
        var warm = 0.0;
        for (var i = 0; i < world.pendantLights.length; i++) {
          final lamp = world.pendantLights[i];
          final delta = lamp - p, distance = delta.length;
          final down = math.max(0, delta.y);
          final radial = math.sqrt(delta.x * delta.x + delta.z * delta.z);
          final cone = (1 - radial / (.40 + down * .75)).clamp(0.0, 1.0);
          warm +=
              1.45 *
              world.pendantGains[i] *
              (world.space.home.mood == 0 || lamp.y < 1.8 ? 1 : .45) *
              cone *
              cone *
              math.max(0, n.dot(delta.normalized)) /
              (1 + .45 * distance * distance);
        }
        for (var i = 0; i < world.wallLights.length; i++) {
          final lamp = world.wallLights[i];
          final delta = lamp - p;
          warm +=
              .70 *
              world.wallGains[i] *
              math.max(0, n.dot(delta.normalized)) /
              (1 + 3.2 * delta.dot(delta));
        }
        if (p.x > 3.6 && p.y > .6 && p.z < 1.45 && p.z > -3.45) {
          for (final y in [.70, 1.25, 1.80, 2.35]) {
            warm += .22 * math.exp(-math.pow((p.y - y) / .22, 2));
          }
        }
        var contact = 1.0;
        if (face.surface == CafeSurface.plaster && n.y.abs() < .8) {
          contact -= .12 * math.exp(-p.y * 5);
          contact -= .05 * math.exp(-(2.95 - p.y).abs() * 5);
        }
        final gain = contact * world.space.brightness;
        return _Illumination(
          CafePoint(fill * gain, fill * .96 * gain, fill * .89 * gain),
          CafePoint(
            warm * gain,
            warm * (.86 - world.space.warmth * .08) * gain,
            warm * (.69 - world.space.warmth * .16) * gain,
          ),
        );
      });

  double _specular(CafeFace face) {
    if (face.surface != CafeSurface.brass) return 0;
    final view = (camera.position - face.center).normalized;
    final halfVector = (view + _daylightDirection).normalized;
    // Broad restrained glints, without view-dependent shiny polygon patches.
    return math.pow(math.max(0, face.normal.dot(halfVector)), 8) * .035;
  }

  Color _light(CafeFace face, int i, bool textured, double specular) {
    if (face.vertexColors != null) return face.vertexColors![i];

    if (face.unlit && !face.sign) {
      if (world.courtyard && face.layer == -1) {
        return Color.lerp(
          face.color,
          const Color(0xff617a89),
          _lightFrame.dusk * .7,
        )!;
      }
      return face.color;
    }
    final cached = _diffuse(face)[i];
    final tint = world.courtyard ? _lightFrame.outdoor : _lightFrame.indoor;
    final shade = world.courtyard
        ? 1.0
        : _lightFrame.shadow(
            face.points[i],
            face.vertexNormals?[i] ?? face.normal,
            world.space.atmosphere.flow ? time : 0,
          );
    final light = CafePoint(
      cached.ambient.x * tint.x + cached.lamp.x * _lightFrame.lamps,
      cached.ambient.y * tint.y + cached.lamp.y * _lightFrame.lamps,
      cached.ambient.z * tint.z + cached.lamp.z * _lightFrame.lamps,
    );
    final base =
        textured &&
            face.surface != CafeSurface.limestone &&
            face.surface != CafeSurface.plaster &&
            face.surface != CafeSurface.fieldstone &&
            face.surface != CafeSurface.water &&
            face.surface != CafeSurface.plain &&
            face.surface != CafeSurface.brass
        ? face.materialTint
        : face.color;
    // Apply the watercolor leaf wash after limiting the light range, so a
    // bright desk lamp cannot clip the entire shadow back to uniform white.
    int channel(double value, double factor) =>
        (((value * factor + specular) * 255).clamp(0, 255) * shade).round();
    return Color.fromARGB(
      (base.a * 255).round(),
      channel(base.r, light.x),
      channel(base.g, light.y),
      channel(base.b, light.z),
    );
  }

  List<_Vertex> _attributes(CafeFace face, ui.Image? image, double specular) {
    final vertices = <_Vertex>[];
    for (var i = 0; i < face.points.length; i++) {
      final p = face.points[i];
      var uv = materialUv(face, p);
      var u = uv.dx * (image?.width ?? 1), v = uv.dy * (image?.height ?? 1);
      if (image != null && face.textureCoordinates != null) {
        u = face.textureCoordinates![i].dx * (image.width - 1);
        v = face.textureCoordinates![i].dy * (image.height - 1);
        if (face.artIndex != null &&
            (framedArt.length <= face.artIndex! ||
                framedArt[face.artIndex!] == null)) {
          v =
              (face.textureCoordinates![i].dy + face.artIndex!) /
              3 *
              (image.height - 1);
        }
      } else if ((face.garden || face.sign) && image != null) {
        final a = face.points[0],
            edgeU = face.points[1] - a,
            edgeV = face.points[3] - a,
            delta = p - a;
        u = delta.dot(edgeU) / edgeU.dot(edgeU) * (image.width - 1);
        v = (1 - delta.dot(edgeV) / edgeV.dot(edgeV)) * (image.height - 1);
        if (face.sign) {
          v = (face.signRow + v / (image.height - 1)) * image.height / 5;
        }
      }
      vertices.add(_Vertex(p, u, v, _light(face, i, image != null, specular)));
    }
    return vertices;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !camera.isFinite) return;
    final watch = onTiming == null ? null : (Stopwatch()..start());
    var linkedMicros = 0;
    final clip = (viewportClip ?? (Offset.zero & size)).intersect(
      Offset.zero & size,
    );
    if (clip.isEmpty) return;
    canvas.save();
    canvas.clipRect(clip);
    if (world.courtyard) {
      final mood = world.space.home.mood;
      final dusk = _lightFrame.dusk;
      final top = Color.lerp(
        mood == 0 ? const Color(0xffbdd0d7) : const Color(0xff617a89),
        const Color(0xff536b7b),
        dusk * .7,
      )!;
      final horizon = Color.lerp(
        mood == 0 ? const Color(0xfff4e4c9) : const Color(0xffb7b2a4),
        const Color(0xffb59b87),
        dusk * .6,
      )!;
      canvas.drawRect(
        clip,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, -size.height * .2),
            Offset(0, size.height * .65),
            [top, horizon],
          ),
      );
    } else {
      canvas.drawColor(const Color(0xfff3eadb), BlendMode.srcOver);
    }
    final faces = <_ProjectedFace>[];
    final portal = Path();
    var hasPortal = false;
    final forward = camera.forward,
        right = camera.right,
        up = camera.up,
        eye = camera.position;
    CafePoint toView(CafePoint point) {
      final x = point.x - eye.x, y = point.y - eye.y, z = point.z - eye.z;
      return CafePoint(
        x * right.x + y * right.y + z * right.z,
        x * up.x + y * up.y + z * up.z,
        x * forward.x + y * forward.y + z * forward.z,
      );
    }

    final viewKey = (
      camera.position.x,
      camera.position.y,
      camera.position.z,
      camera.yaw,
      camera.pitch,
      camera.lens,
      size,
      clip,
    );
    final distant = <String>{};
    final substitutes = <CafePlant>[];
    final pendingPlants = <CafeFace>[];
    if (detailCulling && world.courtyard) {
      for (final obj in world.objects.values) {
        final isTree = obj.id.startsWith('garden.tree.');
        final isFlower = obj.id.startsWith('garden.flowers.');
        if (!isTree && !isFlower) continue;
        final delta = obj.pivot - camera.position;
        final distance2 = delta.x * delta.x + delta.z * delta.z;
        if (distance2 <= (isTree ? 4.5 * 4.5 : 2.4 * 2.4)) continue;
        distant.add(obj.id);
        final h = isTree ? (obj.id.endsWith('.18') ? 2.55 : 2.30) : .36;
        final substitute = CafePlant(
          obj.pivot,
          isTree ? h * .85 : .43,
          h,
          isTree ? CafeSurface.tree : CafeSurface.flowers,
          objectId: obj.id,
        );
        if (isTree ? tree == null : flowers == null) {
          pendingPlants.addAll(_pendingPlant(substitute, camera));
        } else {
          substitutes.add(substitute);
        }
      }
    }
    final orderKey = (
      viewKey,
      distant.join(','),
      avatar,
      use?.id,
      use?.kind,
      use?.progress,
      use?.held,
      use?.open,
      useCamera?.position.x,
      useCamera?.position.y,
      useCamera?.position.z,
      useCamera?.yaw,
      useCamera?.pitch,
      world.courtyard || world.space.home.mood == 2 ? time : 0.0,
      teaFilled,
      bellAt,
      teaAt,
      tree != null,
      flowers != null,
      blossom != null,
    );
    var mesh = _meshes[world];
    final cacheHit =
        cacheGeometry && mesh != null && mesh.matches(world.faces, distant);
    if (cacheGeometry && !cacheHit) {
      mesh = _SceneMesh(world.faces, omit: distant);
      _meshes[world] = mesh;
    }
    final orderedHit = cacheGeometry && mesh!.orderKey == orderKey;
    final changing = orderedHit
        ? const <CafeFace>[]
        : <CafeFace>[
            ...pendingPlants,
            ...avatar,
            ...world.weatherFaces(camera, time),
            ...world
                .plantFaces(camera, source: [...world.plants, ...substitutes])
                .where(
                  (face) =>
                      (face.surface != CafeSurface.tree || tree != null) &&
                      (face.surface != CafeSurface.flowers ||
                          flowers != null) &&
                      (face.surface != CafeSurface.blossom || blossom != null),
                ),
            ...world.lightFaces(camera),
            ...world.animatedFaces(
              time,
              teaFilled: teaFilled && use?.id != 'garden.cup',
              bellAt: bellAt,
              teaAt: teaAt,
            ),
          ];
    Iterable<CafeFace> geometry;
    if (cacheGeometry) {
      if (use != null && !orderedHit) {
        changing.addAll(
          world
              .presentedFaces(
                useCamera ?? camera,
                use,
                thirdPerson: useCamera != null,
              )
              .where((f) => f.objectId == use!.id),
        );
      }
      if (!orderedHit) {
        mesh!.order = mesh.ordered(
          camera,
          clip,
          size,
          changing,
          use?.id,
          distant,
        );
        mesh.orderKey = orderKey;
      }
      geometry = mesh.order!;
    } else {
      geometry = [
        ...world.presentedFaces(
          useCamera ?? camera,
          use,
          thirdPerson: useCamera != null,
        ),
        ...changing,
      ];
    }
    final attributes = <CafeFace, List<_Vertex>>{};
    for (final polygon in geometry) {
      final face = polygon is _SceneFace ? polygon.triangle.face : polygon;
      if ((face.surface == CafeSurface.tree && tree == null) ||
          (face.surface == CafeSurface.flowers && flowers == null) ||
          (face.surface == CafeSurface.blossom && blossom == null)) {
        continue;
      }
      // Closed solid meshes face outward. Thin leaves and translucent light
      // surfaces remain double-sided, so they work from every standing angle.
      if (face.color.a > .99 &&
          !face.unlit &&
          !face.doubleSided &&
          face.normal.dot(camera.position - face.center) < -.015) {
        continue;
      }
      if (face.garden) {
        if (allowPortal) {
          var vertices = face.points
              .map((p) => _Vertex(toView(p), 0, 0, Colors.white))
              .toList();
          if (vertices.every((v) => v.point.z < near)) continue;
          if (vertices.any((v) => v.point.z < near)) vertices = _clip(vertices);
          if (vertices.length >= 3) {
            final f = focalLength(size) * camera.lens;
            portal.addPolygon(
              vertices
                  .map(
                    (v) => Offset(
                      size.width / 2 + v.point.x * f / v.point.z,
                      size.height / 2 - v.point.y * f / v.point.z,
                    ),
                  )
                  .toList(),
              true,
            );
            hasPortal = true;
          }
        }
        continue;
      }
      final image = _texture(face);
      final specular = _specular(face);
      final key = (
        identityHashCode(world),
        _lightFrame.seconds,
        polygon is _SceneFace &&
                polygon.movingShadow &&
                !world.courtyard &&
                world.space.home.mood != 2 &&
                world.space.atmosphere.flow
            ? time
            : 0.0,
        image?.width,
        image?.height,
        face.materialTint,
        face.artIndex != null &&
            (framedArt.length <= face.artIndex! ||
                framedArt[face.artIndex!] == null),
        specular,
      );
      final projectionKey = (key, viewKey);
      if (polygon is _SceneFace && polygon.projectionKey == projectionKey) {
        final projected = polygon.projection;
        if (projected != null) faces.add(projected);
        continue;
      }
      if (polygon is _SceneFace) {
        polygon.projectionKey = projectionKey;
        polygon.projection = null;
      }
      List<_Vertex> prepared;
      if (polygon is _SceneFace && polygon.attributeKey == key) {
        prepared = polygon.prepared!;
      } else {
        final source = attributes.putIfAbsent(
          face,
          () => _attributes(face, image, specular),
        );
        if (polygon is _SceneFace) {
          prepared = <_Vertex>[];
          for (var i = 0; i < polygon.points.length; i++) {
            final (bi, ci, wb, wc) = polygon.blends[i];
            final a = source[0], b = source[bi], c = source[ci];
            final wa = 1 - wb - wc;
            double component(double x, double y, double z) =>
                (x * wa + y * wb + z * wc).clamp(0.0, 1.0);
            prepared.add(
              _Vertex(
                polygon.points[i],
                a.u * wa + b.u * wb + c.u * wc,
                a.v * wa + b.v * wb + c.v * wc,
                Color.from(
                  alpha: component(a.color.a, b.color.a, c.color.a),
                  red: component(a.color.r, b.color.r, c.color.r),
                  green: component(a.color.g, b.color.g, c.color.g),
                  blue: component(a.color.b, b.color.b, c.color.b),
                ),
              ),
            );
          }
          polygon.attributeKey = key;
          polygon.prepared = prepared;
        } else {
          prepared = source;
        }
      }
      if (cacheGeometry) {
        // The BSP has already ordered these world polygons. Project directly
        // into screen coordinates; retain UV/colour samples without allocating
        // a second set of view-space points and vertices on every drag frame.
        final screen = <Offset>[];
        var left = double.infinity, top = double.infinity;
        var rightEdge = double.negativeInfinity, bottom = rightEdge;
        var crossesNear = false;
        final focal = focalLength(size) * camera.lens;
        for (final vertex in prepared) {
          final p = vertex.point;
          final x = p.x - eye.x, y = p.y - eye.y, z = p.z - eye.z;
          final depth = x * forward.x + y * forward.y + z * forward.z;
          if (depth < near || !depth.isFinite) {
            crossesNear = true;
            break;
          }
          final sx =
              size.width / 2 +
              (x * right.x + y * right.y + z * right.z) * focal / depth;
          final sy =
              size.height / 2 -
              (x * up.x + y * up.y + z * up.z) * focal / depth;
          screen.add(Offset(sx, sy));
          left = math.min(left, sx);
          rightEdge = math.max(rightEdge, sx);
          top = math.min(top, sy);
          bottom = math.max(bottom, sy);
        }
        if (!crossesNear) {
          final bounds = Rect.fromLTRB(left, top, rightEdge, bottom);
          if (bounds.overlaps(clip)) {
            final projected = _ProjectedFace(face, prepared, 0)
              ..screen = screen
              ..screenBounds = bounds;
            if (polygon is _SceneFace) polygon.projection = projected;
            faces.add(projected);
          }
          continue;
        }
      }
      var vertices = prepared
          .map((v) => _Vertex(toView(v.point), v.u, v.v, v.color))
          .toList();
      if (vertices.every((p) => p.point.z < near)) continue;
      if (vertices.any((p) => p.point.z < near)) vertices = _clip(vertices);
      if (vertices.length < 3 ||
          vertices.any(
            (v) => !v.point.isFinite || !v.u.isFinite || !v.v.isFinite,
          )) {
        continue;
      }
      // Do not partition the thousands of surfaces outside the current view.
      final focal = focalLength(size) * camera.lens;
      var left = double.infinity, top = double.infinity;
      var rightEdge = double.negativeInfinity, bottom = double.negativeInfinity;
      for (final v in vertices) {
        final x = size.width / 2 + v.point.x * focal / v.point.z;
        final y = size.height / 2 - v.point.y * focal / v.point.z;
        left = math.min(left, x);
        rightEdge = math.max(rightEdge, x);
        top = math.min(top, y);
        bottom = math.max(bottom, y);
      }
      if (rightEdge <= 0 ||
          left >= size.width ||
          bottom <= 0 ||
          top >= size.height) {
        continue;
      }
      final depth =
          vertices.fold<double>(0, (sum, v) => sum + v.point.z) /
          vertices.length;
      final projected = _ProjectedFace(face, vertices, depth);
      if (polygon is _SceneFace) polygon.projection = projected;
      faces.add(projected);
    }
    hasPortal = hasPortal && portal.getBounds().overlaps(Offset.zero & size);
    final projectMicros = watch?.elapsedMicroseconds ?? 0;
    final orderedFaces = cacheGeometry ? faces : _depthOrder(faces);
    final orderMicros = (watch?.elapsedMicroseconds ?? 0) - projectMicros;
    final f = focalLength(size) * camera.lens;
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;
    final shaders = <ui.Image, ui.ImageShader>{};
    for (final image in {
      wood,
      walnut,
      limestone,
      woven,
      knit,
      plaster,
      artwork,
      gravel,
      earth,
      fieldstone,
      tree,
      flowers,
      blossom,
      lawn,
      sign,
      ...framedArt,
      letterAtlas,
    }) {
      if (image == null) continue;
      // Flutter 3.41.2 CanvasKit's CkImageShader.dispose() also disposes the
      // exact Image handle passed to its constructor. Give it a dedicated
      // clone so repaint cleanup cannot destroy CafeScene's original assets.
      // Native dart:ui borrows the image and keeps its own underlying reference.
      shaders[image] = ui.ImageShader(
        kIsWeb ? image.clone() : image,
        image == letterAtlas ||
                image == sign ||
                image == artwork ||
                image == tree ||
                image == flowers ||
                image == blossom ||
                framedArt.contains(image)
            ? TileMode.clamp
            : TileMode.repeated,
        image == letterAtlas ||
                image == sign ||
                image == artwork ||
                image == tree ||
                image == flowers ||
                image == blossom ||
                framedArt.contains(image)
            ? TileMode.clamp
            : TileMode.repeated,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
    }
    // Batch only consecutive compatible surfaces, preserving painter order.
    // This avoids one CanvasKit bridge call per small chair/stone triangle.
    final positions = <Offset>[], uv = <Offset>[];
    final colors = <Color>[];
    ui.ImageShader? batchShader;
    bool batchAA = false;
    // Foliage uses a soft alpha mask: retain painted stems/petals, but prevent
    // the very faint wash around a cutout from becoming a floating rectangle.
    final plantMask = ColorFilter.matrix([
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2.8,
      -240,
    ]);
    void flush() {
      if (positions.isEmpty) return;
      paint
        ..shader = batchShader
        ..colorFilter =
            batchShader != null &&
                (batchShader == shaders[tree] ||
                    batchShader == shaders[flowers] ||
                    batchShader == shaders[blossom])
            ? plantMask
            : null
        ..color = Colors.white
        ..isAntiAlias = batchAA;
      final mesh = ui.Vertices(
        VertexMode.triangles,
        positions,
        textureCoordinates: batchShader == null ? null : uv,
        colors: colors,
      );
      canvas.drawVertices(mesh, BlendMode.modulate, paint);
      mesh.dispose();
      positions.clear();
      uv.clear();
      colors.clear();
    }

    var linkedPainted = false;
    void paintLinked() {
      if (linkedPainted || !hasPortal || !allowPortal) return;
      linkedPainted = true;
      flush();
      canvas.save();
      canvas.clipPath(portal, doAntiAlias: false);
      final linkedStart = watch?.elapsedMicroseconds ?? 0;
      CafeRenderer(
        world: world.linkedWorld,
        onTiming: onTiming,
        cacheGeometry: cacheGeometry,
        detailCulling: detailCulling,
        viewportClip: cacheGeometry ? portal.getBounds().intersect(clip) : null,
        letterAtlas: letterAtlas,
        camera: world.linkedCamera(camera),
        wood: wood,
        walnut: walnut,
        limestone: limestone,
        woven: woven,
        knit: knit,
        plaster: plaster,
        artwork: artwork,
        gravel: gravel,
        earth: earth,
        fieldstone: fieldstone,
        tree: tree,
        flowers: flowers,
        blossom: blossom,
        lawn: lawn,
        framedArt: framedArt,
        sign: sign,
        time: time,
        lightTime: lightTime,
        teaFilled: teaFilled,
        bellAt: bellAt,
        teaAt: teaAt,
        allowPortal: false,
      ).paint(canvas, size);
      linkedMicros += (watch?.elapsedMicroseconds ?? 0) - linkedStart;
      canvas.restore();
    }

    for (final face in orderedFaces) {
      if (face.face.layer >= 1) paintLinked();
      final projected = face.screen ??= [
        for (final v in face.vertices)
          Offset(
            size.width / 2 + v.point.x * f / v.point.z,
            size.height / 2 - v.point.y * f / v.point.z,
          ),
      ];
      var bounds = face.screenBounds;
      if (bounds == null) {
        bounds = Rect.fromPoints(projected.first, projected.first);
        for (final p in projected.skip(1)) {
          bounds = bounds!.expandToInclude(Rect.fromPoints(p, p));
        }
        face.screenBounds = bounds;
      }
      if (!bounds!.overlaps(clip)) continue;
      final shader = shaders[_texture(face.face)];
      final aa = face.face.layer >= 2;
      if (shader != batchShader || aa != batchAA || positions.length > 12000) {
        flush();
        batchShader = shader;
        batchAA = aa;
      }
      for (var i = 1; i + 1 < projected.length; i++) {
        for (final index in [0, i, i + 1]) {
          positions.add(projected[index]);
          final v = face.vertices[index];
          uv.add(Offset(v.u, v.v));
          colors.add(v.color);
        }
      }
    }
    flush();
    paintLinked();
    paint
      ..shader = null
      ..colorFilter = null;
    for (final shader in shaders.values) {
      shader.dispose();
    }
    canvas.restore();
    if (watch != null) {
      onTiming!(
        CafeRenderTiming(
          courtyard: world.courtyard,
          projectMicros: projectMicros,
          orderMicros: orderMicros,
          submitMicros:
              watch.elapsedMicroseconds -
              projectMicros -
              orderMicros -
              linkedMicros,
          linkedMicros: linkedMicros,
          visibleFaces: faces.length,
          orderedFaces: orderedFaces.length,
          cacheHit: cacheHit,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(CafeRenderer oldDelegate) =>
      oldDelegate.letterAtlas != letterAtlas ||
      oldDelegate.use != use ||
      oldDelegate.useCamera != useCamera ||
      oldDelegate.avatar != avatar ||
      oldDelegate.allowPortal != allowPortal ||
      oldDelegate.cacheGeometry != cacheGeometry ||
      oldDelegate.viewportClip != viewportClip ||
      oldDelegate.time != time ||
      oldDelegate.lightTime != lightTime ||
      oldDelegate.teaFilled != teaFilled ||
      oldDelegate.bellAt != bellAt ||
      oldDelegate.teaAt != teaAt ||
      oldDelegate.camera != camera ||
      oldDelegate.wood != wood ||
      oldDelegate.sign != sign ||
      oldDelegate.walnut != walnut ||
      oldDelegate.limestone != limestone ||
      oldDelegate.woven != woven ||
      oldDelegate.knit != knit ||
      oldDelegate.plaster != plaster ||
      oldDelegate.artwork != artwork ||
      oldDelegate.gravel != gravel ||
      oldDelegate.earth != earth ||
      oldDelegate.fieldstone != fieldstone ||
      oldDelegate.blossom != blossom ||
      oldDelegate.lawn != lawn ||
      oldDelegate.tree != tree ||
      oldDelegate.flowers != flowers ||
      oldDelegate.world != world;
}

class CafeHit {
  const CafeHit(this.position, this.target, this.floor, [this.objectId]);
  final CafePoint position;
  final CafeTarget? target;
  final bool floor;
  final String? objectId;
}
