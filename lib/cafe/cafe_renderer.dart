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
    this.garden,
    this.sign,
    this.walnut,
    this.limestone,
    this.woven,
    this.plaster,
    this.artwork,
    this.time = 0,
    this.teaFilled = false,
    this.bellAt,
    this.teaAt,
  });
  final CafeWorld world;
  final CafeCamera camera;
  final ui.Image? wood,
      garden,
      sign,
      walnut,
      limestone,
      woven,
      plaster,
      artwork;
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
          hit.y.abs() < .025 && face.normal.y > .9,
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
    if (face.garden) return garden;
    if (face.sign) return sign;
    return switch (face.surface) {
      CafeSurface.oak => wood,
      CafeSurface.walnut => walnut ?? wood,
      CafeSurface.limestone => limestone,
      CafeSurface.cord => woven,
      CafeSurface.plaster => plaster,
      CafeSurface.artwork => artwork,
      _ => null,
    };
  }

  /// Physical repeat lengths keep long grain aligned with each timber member.
  /// End faces use two cross-grain axes instead of a collapsed UV coordinate.
  static Offset materialUv(CafeFace face, CafePoint p) {
    final n = face.normal;
    if (face.surface == CafeSurface.plaster) {
      if (n.y.abs() > .8) return Offset(p.x / 1.4, p.z / 1.4);
      return Offset((n.x.abs() > .8 ? p.z : p.x) / 1.4, -p.y / 1.4);
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

  static const _lamps = [
    CafePoint(0, 2.175, -.83),
    CafePoint(0, 2.175, .68),
    CafePoint(-3.68, 2.175, -2.5),
    CafePoint(-3.68, 2.175, -.3),
    CafePoint(-3.68, 2.175, 1.9),
    CafePoint(-2.25, 2.175, -3.95),
    CafePoint(-3.60, 2.10, -4.68),
    CafePoint(-3.72, 2.25, 4.67),
    CafePoint(3.61, 2.25, 4.67),
    CafePoint(.70, 2.73, -4.68),
  ];
  // Geometry and diffuse light are static; retain only weak face references.
  static final _illumination = Expando<List<CafePoint>>();
  List<CafePoint> _diffuse(
    CafeFace face,
  ) => _illumination[face] ??= List.generate(face.points.length, (i) {
    final p = face.points[i], n = face.vertexNormals?[i] ?? face.normal;
    final window = (1 - (p.x + 4.4) / 15).clamp(.35, 1.0);
    final fill =
        .80 +
        .20 * math.max(0, n.dot(_daylightDirection)) * window +
        .09 * math.max(0, n.y);
    var warm = 0.0;
    for (final lamp in _lamps) {
      final delta = lamp - p, distance = delta.length;
      warm +=
          .29 *
          math.max(0, n.dot(delta * (1 / distance))) /
          (1 + .65 * distance * distance);
    }
    // Cabinet strips: a local warm fill in the shelf recess, not a screen tint.
    if (p.x > 3.6 && p.z < 1.45) warm += .07;
    warm = math.min(.32, warm);
    // A narrow ambient contact falloff grounds plaster and cabinet recesses.
    var contact = 1.0;
    if (face.surface == CafeSurface.plaster && n.y.abs() < .8) {
      contact -= .085 * math.exp(-p.y * 5);
      contact -= .035 * math.exp(-(2.95 - p.y).abs() * 6);
    }
    return CafePoint(
      (fill + warm) * contact,
      (fill + warm * .84) * contact,
      (fill + warm * .60) * contact,
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
    if ((face.garden || face.sign) && textured) return Colors.white;
    if (face.unlit) return face.color;
    final light = _diffuse(face)[i];
    final base = textured && face.surface != CafeSurface.limestone
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
    canvas.drawColor(const Color(0xfff3eadb), BlendMode.srcOver);
    final faces = <_ProjectedFace>[];
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
      ...world.animatedFaces(
        time,
        teaFilled: teaFilled,
        bellAt: bellAt,
        teaAt: teaAt,
      ),
    ]) {
      // Closed solid meshes face outward. Thin leaves and translucent light
      // surfaces remain double-sided, so they work from every standing angle.
      if (face.color.a > .99 &&
          !face.unlit &&
          !face.doubleSided &&
          face.normal.dot(camera.position - face.center) < -.015) {
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
      garden,
      sign,
    }) {
      if (image == null) continue;
      // Flutter 3.41.2 CanvasKit's CkImageShader.dispose() also disposes the
      // exact Image handle passed to its constructor. Give it a dedicated
      // clone so repaint cleanup cannot destroy CafeScene's original assets.
      // Native dart:ui borrows the image and keeps its own underlying reference.
      shaders[image] = ui.ImageShader(
        kIsWeb ? image.clone() : image,
        image == garden || image == sign || image == artwork
            ? TileMode.clamp
            : TileMode.repeated,
        image == garden || image == sign || image == artwork
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

    for (final face in faces) {
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
    paint.shader = null;
    for (final shader in shaders.values) {
      shader.dispose();
    }
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(CafeRenderer oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.teaFilled != teaFilled ||
      oldDelegate.bellAt != bellAt ||
      oldDelegate.teaAt != teaAt ||
      oldDelegate.camera != camera ||
      oldDelegate.wood != wood ||
      oldDelegate.garden != garden ||
      oldDelegate.sign != sign ||
      oldDelegate.walnut != walnut ||
      oldDelegate.limestone != limestone ||
      oldDelegate.woven != woven ||
      oldDelegate.plaster != plaster ||
      oldDelegate.artwork != artwork ||
      oldDelegate.world != world;
}

class CafeHit {
  const CafeHit(this.position, this.target, this.floor);
  final CafePoint position;
  final CafeTarget? target;
  final bool floor;
}
