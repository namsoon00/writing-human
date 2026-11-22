import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'cafe_camera.dart';
import 'cafe_world.dart';
import 'cafe_visit.dart';

class _Vertex {
  const _Vertex(this.point, this.u, this.v);
  final CafePoint point;
  final double u, v;
  static _Vertex lerp(_Vertex a, _Vertex b, double t) => _Vertex(
    CafePoint.lerp(a.point, b.point, t),
    a.u + (b.u - a.u) * t,
    a.v + (b.v - a.v) * t,
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
  });
  final CafeWorld world;
  final CafeCamera camera;
  final ui.Image? wood, garden, sign;
  static const near = .075;
  static final _daylightDirection = const CafePoint(-.78, .58, .22).normalized;

  // Keep useful horizontal context on a phone without changing camera position.
  static double focalLength(Size size) =>
      math.min(size.height * .75, size.width * .95);

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

  Color _light(CafeFace face) {
    if (face.unlit) return face.color;
    final n = face.normal;
    // Broad window light plus warm ceiling fill, baked onto real mesh normals.
    final daylight = math.max(0, n.dot(_daylightDirection));
    final ceiling = math.max(0, n.y);
    final windowFalloff = (1 - (face.center.x + 4.4) / 15).clamp(.35, 1.0);
    final brightness = (.70 + .23 * daylight * windowFalloff + .11 * ceiling)
        .clamp(.25, 1.05);
    final base = face.wood && wood != null
        ? Color.lerp(face.color, Colors.white, .40)!
        : face.color;
    int c(double channel, double warmth) =>
        (channel * 255 * brightness * warmth).round().clamp(0, 255);
    return Color.fromARGB(
      (base.a * 255).round(),
      c(base.r, 1.025),
      c(base.g, 1.0),
      c(base.b, .96),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !camera.isFinite) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(const Color(0xffc9bca5), BlendMode.srcOver);
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

    for (final face in world.faces) {
      // Closed solid meshes face outward. Thin leaves and translucent light
      // surfaces remain double-sided, so they work from every standing angle.
      if (face.color.a > .99 &&
          !face.unlit &&
          !face.doubleSided &&
          face.normal.dot(camera.position - face.center) < -.015) {
        continue;
      }
      final alongZ = face.normal.x.abs() > .6;
      final horizontal = face.normal.y.abs() > .6;
      final image = face.garden
          ? garden
          : face.sign
          ? sign
          : face.wood
          ? wood
          : null;
      var vertices = <_Vertex>[];
      for (var i = 0; i < face.points.length; i++) {
        final p = face.points[i];
        var u = (alongZ ? p.z : p.x) * 190, v = (horizontal ? p.z : p.y) * 190;
        if ((face.garden || face.sign) && image != null) {
          if (face.textureCoordinates != null) {
            u = face.textureCoordinates![i].dx * (image.width - 1);
            v = face.textureCoordinates![i].dy * (image.height - 1);
          } else {
            final a = face.points[0],
                edgeU = face.points[1] - a,
                edgeV = face.points[3] - a;
            final delta = p - a;
            u = delta.dot(edgeU) / edgeU.dot(edgeU) * (image.width - 1);
            v = (1 - delta.dot(edgeV) / edgeV.dot(edgeV)) * (image.height - 1);
            if (face.sign) {
              v = (face.signRow + v / (image.height - 1)) * image.height / 4;
            }
          }
        }
        vertices.add(_Vertex(toView(p), u, v));
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
    final paint = Paint()..isAntiAlias = true;
    final shaders = <ui.Image, ui.ImageShader>{};
    for (final image in [wood, garden, sign]) {
      if (image == null) continue;
      shaders[image] = ui.ImageShader(
        image,
        image == wood ? TileMode.repeated : TileMode.clamp,
        image == wood ? TileMode.repeated : TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
    }
    for (final face in faces) {
      final positions = <Offset>[], uv = <Offset>[];
      for (final v in face.vertices) {
        positions.add(
          Offset(
            size.width / 2 + v.point.x * f / v.point.z,
            size.height / 2 - v.point.y * f / v.point.z,
          ),
        );
        uv.add(Offset(v.u, v.v));
      }
      final bounds = Rect.fromPoints(positions.first, positions.first)
          .expandToInclude(
            positions.fold<Rect>(
              Rect.fromPoints(positions.first, positions.first),
              (r, p) => r.expandToInclude(Rect.fromPoints(p, p)),
            ),
          );
      if (!bounds.overlaps(Offset.zero & size)) continue;
      final texture = face.face.garden
          ? garden
          : face.face.sign
          ? sign
          : face.face.wood
          ? wood
          : null;
      final shader = shaders[texture];
      final color = (face.face.garden || face.face.sign) && texture != null
          ? Colors.white
          : _light(face.face);
      if (shader != null) {
        paint
          ..shader = shader
          ..color = Colors.white;
        final vertices = ui.Vertices(
          VertexMode.triangleFan,
          positions,
          textureCoordinates: uv,
          colors: List.filled(positions.length, color),
        );
        canvas.drawVertices(vertices, BlendMode.modulate, paint);
        vertices.dispose();
        paint.shader = null;
      } else {
        final path = Path()..addPolygon(positions, true);
        paint.color = color;
        canvas.drawPath(path, paint);
      }
    }
    for (final shader in shaders.values) {
      shader.dispose();
    }
    // A subtle lens vignette, independent of camera input and mesh lighting.
    final vignette = const RadialGradient(
      colors: [Color(0x00000000), Color(0x240f100b)],
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
      oldDelegate.camera != camera ||
      oldDelegate.wood != wood ||
      oldDelegate.garden != garden ||
      oldDelegate.sign != sign ||
      oldDelegate.world != world;
}

class CafeHit {
  const CafeHit(this.position, this.target, this.floor);
  final CafePoint position;
  final CafeTarget? target;
  final bool floor;
}
