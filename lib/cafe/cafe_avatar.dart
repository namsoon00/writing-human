import 'dart:math' as math;
import 'dart:ui';

import 'cafe_camera.dart';
import 'cafe_body.dart';
import 'cafe_world.dart';

part 'cafe_cozy_avatar.dart';

/// The approved A outfit. All dimensions are metres; the mesh shares the room's
/// lighting and depth ordering. No character state is written into a record.
class CafeAvatar {
  CafeAvatar({
    required this.eye,
    required this.yaw,
    this.phase = 0,
    this.stride = 0,
    this.use,
    this.object,
    this.barefoot = false,
    this.meditation = 0,
  });
  static const id = 'avatar.a.male';
  final CafeCamera eye;
  final double yaw, phase, stride;
  final CafeUseFrame? use;
  final CafeObject? object;
  final bool barefoot;
  final double meditation;
  bool get meditating => meditation > 0;
  late final double seated = CafeBody.seated(eye);
  late final CafePoint origin = CafePoint(eye.position.x, 0, eye.position.z);
  late final List<CafeFace> faces = _build();
  late final double _cos = math.cos(yaw), _sin = math.sin(yaw);
  CafePoint _rotate(CafePoint p) =>
      CafePoint(p.x * _cos - p.z * _sin, p.y, p.x * _sin + p.z * _cos);
  CafePoint _local(CafePoint p) {
    final d = p - origin;
    return CafePoint(d.x * _cos + d.z * _sin, d.y, -d.x * _sin + d.z * _cos);
  }

  List<CafeFace> _build() => _cozyBuild();
}

/// Two-bone IK; unreachable targets are clamped instead of stretching limbs.
CafePoint _joint(
  CafePoint a,
  CafePoint b,
  double upper,
  double lower,
  CafePoint bend,
) {
  final axis = (b - a).normalized;
  final d = (b - a).length.clamp(.025, upper + lower - .001);
  final along = (upper * upper - lower * lower + d * d) / (2 * d);
  final perpendicular = (bend - axis * bend.dot(axis)).normalized;
  return a +
      axis * along +
      perpendicular * math.sqrt(math.max(0, upper * upper - along * along));
}

class _AvatarMesh {
  _AvatarMesh(this.at, this.normal);
  final CafePoint Function(CafePoint) at, normal;
  final faces = <CafeFace>[];
  void patch(
    List<CafePoint> points,
    Color color,
    String part, {
    List<CafePoint>? normals,
  }) {
    final outward =
        normals ?? List.filled(points.length, const CafePoint(0, 0, -1));
    if ((points[1] - points[0]).cross(points[2] - points[0]).dot(outward[0]) <
        0) {
      points = points.reversed.toList();
      normals = outward.reversed.toList();
    } else {
      normals = outward;
    }
    if ((points[1] - points[0]).cross(points[2] - points[0]).length < 1e-10) {
      return;
    }
    faces.add(
      CafeFace(
        points.map(at).toList(),
        color,
        objectId: CafeAvatar.id,
        part: part,
        surface: (part.startsWith('linen') || part.startsWith('knit'))
            ? CafeSurface.cord
            : CafeSurface.plain,
        materialTint: color,
        vertexNormals: normals.map((n) => normal(n).normalized).toList(),
        textureCoordinates: points
            .map(
              (p) => part.startsWith('knit')
                  ? Offset(p.x * 1.2 + p.z * .4, p.y * 2)
                  : Offset(p.x * 5 + p.z * 2, p.y * 5),
            )
            .toList(),
      ),
    );
  }

  void ellipsoid(
    CafePoint center,
    CafePoint radii,
    Color color,
    String part, {
    int slices = 10,
    int rings = 6,
    List<CafePoint>? axes,
  }) {
    // Fine facial features and cloth trim need their shape, not dozens of
    // sub-pixel patches. Keep the head silhouette and articulated fingers.
    final budget = switch (part) {
      'face' => (24, 12),
      'iris' => (8, 5),
      'eye.glint' => (4, 2),
      'nose' => (10, 5),
      'ear' => (10, 5),
      'knit.pocket' => (10, 4),
      'knit.hem' => (16, 3),
      'knit.shoulder' => (8, 4),
      'shirt' => (12, 5),
      'neck' => (10, 4),
      'hand' => (8, 5),
      'hand.web' => (6, 4),
      'shoe.sole' => (12, 4),
      'shoe' => (12, 5),
      'trousers' => (12, 4),
      'knit.button' => (8, 3),
      'button.hole' => (3, 2),
      _ => (slices, rings),
    };
    slices = budget.$1;
    rings = budget.$2;
    CafePoint orient(CafePoint q) =>
        axes == null ? q : axes[0] * q.x + axes[1] * q.y + axes[2] * q.z;
    CafePoint n(int i, int j) {
      final v = math.pi * (i + .001) / (rings + .002),
          u = 2 * math.pi * j / slices;
      return CafePoint(
        math.sin(v) * math.cos(u),
        math.cos(v),
        math.sin(v) * math.sin(u),
      );
    }

    CafePoint p(CafePoint q) =>
        center + orient(CafePoint(q.x * radii.x, q.y * radii.y, q.z * radii.z));
    for (var i = 0; i < rings; i++) {
      for (var j = 0; j < slices; j++) {
        final ns = [n(i, j), n(i + 1, j), n(i + 1, j + 1), n(i, j + 1)];
        patch(
          ns.map(p).toList(),
          color,
          part,
          normals: ns
              .map(
                (q) => orient(
                  CafePoint(
                    q.x / radii.x,
                    q.y / radii.y,
                    q.z / radii.z,
                  ).normalized,
                ),
              )
              .toList(),
        );
      }
    }
  }

  void loft(
    List<(CafePoint, double, double)> rings,
    Color color,
    String part, {
    int sides = 12,
  }) {
    for (var i = 0; i < rings.length - 1; i++) {
      CafePoint p(int k, int j) {
        final (c, rx, rz) = rings[k];
        final t = j * 2 * math.pi / sides;
        return c + CafePoint(rx * math.cos(t), 0, rz * math.sin(t));
      }

      CafePoint n(int k, int j) {
        final t = j * 2 * math.pi / sides;
        final previous = math.max(0, k - 1),
            next = math.min(rings.length - 1, k + 1);
        final tangent = CafePoint(
          -rings[k].$2 * math.sin(t),
          0,
          rings[k].$3 * math.cos(t),
        );
        final axial = p(next, j) - p(previous, j);
        return axial.cross(tangent).normalized;
      }

      for (var j = 0; j < sides; j++) {
        patch(
          [p(i, j), p(i + 1, j), p(i + 1, j + 1), p(i, j + 1)],
          color,
          part,
          normals: [n(i, j), n(i + 1, j), n(i + 1, j + 1), n(i, j + 1)],
        );
      }
    }
  }

  void tube(
    List<CafePoint> centers,
    List<double> radii,
    Color color,
    String part, {
    int sides = 8,
    double flatten = 1,
  }) {
    final axes = <(CafePoint, CafePoint)>[];
    for (var i = 0; i < centers.length; i++) {
      final direction =
          (centers[math.min(i + 1, centers.length - 1)] -
                  centers[math.max(0, i - 1)])
              .normalized;
      // Parallel transport keeps adjacent rings aligned through an elbow.
      // Switching reference axes per ring twists the sleeve into spikes.
      final reference = axes.isEmpty
          ? (direction.y.abs() > .85
                ? const CafePoint(1, 0, 0)
                : const CafePoint(0, 1, 0))
          : axes.last.$1;
      final u = axes.isEmpty
          ? direction.cross(reference).normalized
          : (reference - direction * reference.dot(direction)).normalized;
      axes.add((u, direction.cross(u).normalized));
    }
    CafePoint n(int i, int j) {
      final t = j * 2 * math.pi / sides;
      return axes[i].$1 * math.cos(t) + axes[i].$2 * (math.sin(t) * flatten);
    }

    for (var i = 0; i < centers.length - 1; i++) {
      for (var j = 0; j < sides; j++) {
        final ns = [n(i, j), n(i + 1, j), n(i + 1, j + 1), n(i, j + 1)];
        patch(
          [
            centers[i] + ns[0] * radii[i],
            centers[i + 1] + ns[1] * radii[i + 1],
            centers[i + 1] + ns[2] * radii[i + 1],
            centers[i] + ns[3] * radii[i],
          ],
          color,
          part,
          normals: ns,
        );
      }
    }
    for (final end in [0, centers.length - 1]) {
      final ns = end == 0
          ? (centers[0] - centers[1]).normalized
          : (centers.last - centers[centers.length - 2]).normalized;
      for (var j = 0; j < sides; j++) {
        patch(
          [
            centers[end],
            centers[end] + n(end, j) * radii[end],
            centers[end] + n(end, j + 1) * radii[end],
          ],
          color,
          part,
          normals: List.filled(3, ns),
        );
      }
    }
  }

  void hairCap(CafePoint center, Color color) {
    const slices = 20, rings = 6;
    CafePoint p(int i, int j) {
      final u = j * math.pi * 2 / slices;
      final back = (math.sin(u) + 1) / 2;
      final v = (.001 + i / rings * (1.20 + back * .95));
      return center +
          CafePoint(
            .116 * math.sin(v) * math.cos(u),
            .137 * math.cos(v),
            .110 * math.sin(v) * math.sin(u),
          );
    }

    for (var i = 0; i < rings; i++) {
      for (var j = 0; j < slices; j++) {
        final ps = [p(i, j), p(i + 1, j), p(i + 1, j + 1), p(i, j + 1)];
        patch(
          ps,
          color,
          'hair',
          normals: ps.map((q) => (q - center).normalized).toList(),
        );
      }
    }
  }
}
