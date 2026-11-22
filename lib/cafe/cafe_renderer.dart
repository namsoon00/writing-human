import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'cafe_camera.dart';
import 'cafe_world.dart';
import 'cafe_visit.dart';

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
  const _ProjectedFace(this.face, this.vertices, this.depth);
  final CafeFace face;
  final List<_Vertex> vertices;
  final double depth;
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
    this.plaster,
    this.artwork,
    this.gravel,
    this.tree,
    this.flowers,
    this.time = 0,
    this.teaFilled = false,
    this.bellAt,
    this.teaAt,
    this.allowPortal = true,
  });
  final CafeWorld world;
  final CafeCamera camera;
  final ui.Image? wood,
      sign,
      walnut,
      limestone,
      woven,
      plaster,
      artwork,
      gravel,
      tree,
      flowers;
  final bool allowPortal;
  final double time;
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
    final f = focalLength(size);
    return Offset(
      size.width / 2 + view.x * f / view.z,
      size.height / 2 - view.y * f / view.z,
    );
  }

  static CafePoint ray(Offset point, CafeCamera camera, Size size) {
    final f = focalLength(size);
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
    CafeWorld world,
  ) {
    if (!camera.isFinite ||
        size.isEmpty ||
        !point.dx.isFinite ||
        !point.dy.isFinite) {
      return null;
    }
    final direction = ray(point, camera, size);
    var closest = double.infinity;
    CafeHit? result;
    for (final face in world.faces) {
      // Floor light/shadow decals do not obstruct the physical surface.
      if (face.color.a < .99) continue;
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
        if (distance < near || distance >= closest) continue;
        closest = distance;
        final hit = camera.position + direction * distance;
        result = CafeHit(
          hit,
          face.target,
          hit.y >= -.025 &&
              hit.y < .065 &&
              face.normal.y > .9 &&
              world.canStand(CafePoint(hit.x, 1.62, hit.z)),
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
    if (face.sign) return sign;
    return switch (face.surface) {
      CafeSurface.oak => wood,
      CafeSurface.walnut => walnut ?? wood,
      CafeSurface.limestone => limestone,
      CafeSurface.cord => woven,
      CafeSurface.plaster => plaster,
      CafeSurface.artwork => artwork,
      CafeSurface.gravel => gravel,
      CafeSurface.tree => tree,
      CafeSurface.flowers => flowers,
      CafeSurface.water => gravel,
      _ => null,
    };
  }

  /// Physical repeat lengths keep long grain aligned with each timber member.
  /// End faces use two cross-grain axes instead of a collapsed UV coordinate.
  static Offset materialUv(CafeFace face, CafePoint p) {
    final n = face.normal;
    if (face.surface == CafeSurface.water) return Offset(p.x / 2.8, p.z / 2.8);
    if (face.surface == CafeSurface.gravel) return Offset(p.x / .6, p.z / .6);
    if (face.surface == CafeSurface.plaster) {
      if (n.y.abs() > .8) return Offset(p.x / .72, p.z / .72);
      return Offset((n.x.abs() > .8 ? p.z : p.x) / .72, -p.y / .72);
    }
    switch (face.grain) {
      case CafeGrain.x:
        if (n.x.abs() > .8) return Offset(p.z / .6, -p.y / .6);
        return Offset((n.y.abs() > .6 ? p.z : p.y) / .62, -p.x / 2.4);
      case CafeGrain.y:
        if (n.y.abs() > .8) return Offset(p.x / .6, -p.z / .6);
        return Offset((n.x.abs() > .6 ? p.z : p.x) / .62, -p.y / 2.4);
      case CafeGrain.z:
        if (n.z.abs() > .8) return Offset(p.x / .6, -p.y / .6);
        return Offset((n.y.abs() > .6 ? p.x : p.y) / .62, -p.z / 2.4);
    }
  }

  static const _wallLights = [
    CafePoint(-3.60, 2.10, -4.68),
    CafePoint(-3.72, 2.25, 4.67),
    CafePoint(3.61, 2.25, 4.67),
    CafePoint(.70, 2.73, -4.68),
  ];
  static final _illumination = Expando<List<CafePoint>>();
  List<CafePoint> _diffuse(CafeFace face) =>
      _illumination[face] ??= List.generate(face.points.length, (i) {
        final p = face.points[i], n = face.vertexNormals?[i] ?? face.normal;
        if (world.courtyard) {
          final fill =
              .76 +
              .23 * math.max(0, n.dot(_daylightDirection)) +
              .08 * math.max(0, n.y);
          return CafePoint(fill, fill * .985, fill * .94);
        }
        final window = math.exp(-(p.x + 4.4).clamp(0, 12) / 4.5);
        final fill =
            .64 +
            .13 * math.max(0, n.dot(_daylightDirection)) * window +
            .035 * math.max(0, n.y);
        var warm = 0.0;
        for (final lamp in world.pendantLights) {
          final delta = lamp - p, distance = delta.length;
          final down = math.max(0, delta.y);
          final radial = math.sqrt(delta.x * delta.x + delta.z * delta.z);
          final cone = (1 - radial / (.40 + down * .75)).clamp(0.0, 1.0);
          warm +=
              1.55 *
              cone *
              cone *
              math.max(0, n.dot(delta.normalized)) /
              (1 + .45 * distance * distance);
        }
        for (final lamp in _wallLights) {
          final delta = lamp - p;
          warm +=
              .70 *
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
        return CafePoint(
          (fill + warm) * contact,
          (fill * .94 + warm * .82) * contact,
          (fill * .84 + warm * .58) * contact,
        );
      });

  double _specular(CafeFace face) {
    final metal = face.surface == CafeSurface.brass;
    final stone = face.surface == CafeSurface.limestone;
    if (!metal &&
        !stone &&
        face.surface != CafeSurface.oak &&
        face.surface != CafeSurface.walnut) {
      return 0;
    }
    final view = (camera.position - face.center).normalized;
    final halfVector = (view + _daylightDirection).normalized;
    return math.pow(
          math.max(0, face.normal.dot(halfVector)),
          metal
              ? 22
              : stone
              ? 48
              : 35,
        ) *
        (metal
            ? .26
            : stone
            ? .024
            : .055);
  }

  Color _light(CafeFace face, int i, bool textured, double specular) {
    if (face.vertexColors != null) return face.vertexColors![i];

    if (face.unlit && !face.sign) return face.color;
    final light = _diffuse(face)[i];
    final base =
        textured &&
            face.surface != CafeSurface.limestone &&
            face.surface != CafeSurface.plaster &&
            face.surface != CafeSurface.water
        ? Colors.white
        : face.color;
    int channel(double value, double factor) =>
        ((value * factor + specular) * 255).round().clamp(0, 255);
    return Color.fromARGB(
      (base.a * 255).round(),
      channel(base.r, light.x),
      channel(base.g, light.y),
      channel(base.b, light.z),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !camera.isFinite) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(
      world.courtyard ? const Color(0xffdce5df) : const Color(0xfff3eadb),
      BlendMode.srcOver,
    );
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

    for (final face in [
      ...world.faces,
      ...world.plantFaces(camera),
      ...world.lightFaces(camera),
      ...world.animatedFaces(
        time,
        teaFilled: teaFilled,
        bellAt: bellAt,
        teaAt: teaAt,
      ),
    ]) {
      if ((face.surface == CafeSurface.tree && tree == null) ||
          (face.surface == CafeSurface.flowers && flowers == null)) {
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
            final f = focalLength(size);
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
      var vertices = <_Vertex>[];
      for (var i = 0; i < face.points.length; i++) {
        final p = face.points[i];
        var uv = materialUv(face, p);
        var u = uv.dx * (image?.width ?? 1), v = uv.dy * (image?.height ?? 1);
        if (image != null && face.textureCoordinates != null) {
          u = face.textureCoordinates![i].dx * (image.width - 1);
          v = face.textureCoordinates![i].dy * (image.height - 1);
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
        vertices.add(
          _Vertex(toView(p), u, v, _light(face, i, image != null, specular)),
        );
      }
      if (vertices.every((p) => p.point.z < near)) continue;
      if (vertices.any((p) => p.point.z < near)) vertices = _clip(vertices);
      if (vertices.length < 3 ||
          vertices.any(
            (v) => !v.point.isFinite || !v.u.isFinite || !v.v.isFinite,
          )) {
        continue;
      }
      final depth =
          vertices.fold<double>(0, (sum, v) => sum + v.point.z) /
          vertices.length;
      faces.add(_ProjectedFace(face, vertices, depth));
    }
    hasPortal = hasPortal && portal.getBounds().overlaps(Offset.zero & size);
    faces.sort(
      (a, b) => a.face.layer == b.face.layer
          ? b.depth.compareTo(a.depth)
          : a.face.layer.compareTo(b.face.layer),
    );
    final f = focalLength(size);
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;
    final shaders = <ui.Image, ui.ImageShader>{};
    for (final image in {
      wood,
      walnut,
      limestone,
      woven,
      plaster,
      artwork,
      gravel,
      tree,
      flowers,
      sign,
    }) {
      if (image == null) continue;
      // Flutter 3.41.2 CanvasKit's CkImageShader.dispose() also disposes the
      // exact Image handle passed to its constructor. Give it a dedicated
      // clone so repaint cleanup cannot destroy CafeScene's original assets.
      // Native dart:ui borrows the image and keeps its own underlying reference.
      shaders[image] = ui.ImageShader(
        kIsWeb ? image.clone() : image,
        image == sign || image == artwork || image == tree || image == flowers
            ? TileMode.clamp
            : TileMode.repeated,
        image == sign || image == artwork || image == tree || image == flowers
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
    void flush() {
      if (positions.isEmpty) return;
      paint
        ..shader = batchShader
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
      CafeRenderer(
        world: world.linkedWorld,
        camera: world.linkedCamera(camera),
        wood: wood,
        walnut: walnut,
        limestone: limestone,
        woven: woven,
        plaster: plaster,
        artwork: artwork,
        gravel: gravel,
        tree: tree,
        flowers: flowers,
        sign: sign,
        time: time,
        teaFilled: teaFilled,
        bellAt: bellAt,
        teaAt: teaAt,
        allowPortal: false,
      ).paint(canvas, size);
      canvas.restore();
    }

    for (final face in faces) {
      if (face.face.layer >= 1) paintLinked();
      final projected = <Offset>[];
      for (final v in face.vertices) {
        projected.add(
          Offset(
            size.width / 2 + v.point.x * f / v.point.z,
            size.height / 2 - v.point.y * f / v.point.z,
          ),
        );
      }
      var bounds = Rect.fromPoints(projected.first, projected.first);
      for (final p in projected.skip(1)) {
        bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
      }
      if (!bounds.overlaps(Offset.zero & size)) continue;
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
    paint.shader = null;
    for (final shader in shaders.values) {
      shader.dispose();
    }
    if (allowPortal) {
      // A subtle lens vignette, independent of camera input and mesh lighting.
      final vignette = const RadialGradient(
        colors: [Color(0x00000000), Color(0x080f100b)],
        stops: [.35, 1],
        radius: .86,
      ).createShader(Offset.zero & size);
      paint
        ..shader = vignette
        ..color = Colors.white;
      canvas.drawRect(Offset.zero & size, paint);
      vignette.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CafeRenderer oldDelegate) =>
      oldDelegate.allowPortal != allowPortal ||
      oldDelegate.time != time ||
      oldDelegate.teaFilled != teaFilled ||
      oldDelegate.bellAt != bellAt ||
      oldDelegate.teaAt != teaAt ||
      oldDelegate.camera != camera ||
      oldDelegate.wood != wood ||
      oldDelegate.sign != sign ||
      oldDelegate.walnut != walnut ||
      oldDelegate.limestone != limestone ||
      oldDelegate.woven != woven ||
      oldDelegate.plaster != plaster ||
      oldDelegate.artwork != artwork ||
      oldDelegate.gravel != gravel ||
      oldDelegate.tree != tree ||
      oldDelegate.flowers != flowers ||
      oldDelegate.world != world;
}

class CafeHit {
  const CafeHit(this.position, this.target, this.floor);
  final CafePoint position;
  final CafeTarget? target;
  final bool floor;
}
