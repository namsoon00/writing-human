part of 'cafe_renderer.dart';

/// An original triangle and its interpolation basis. Cached cuts retain the
/// original UV/lighting samples instead of changing the appearance of a face.
class _SceneTriangle {
  _SceneTriangle(this.face, this.b, this.c)
    : a = face.points[0],
      u = face.points[b] - face.points[0],
      v = face.points[c] - face.points[0] {
    uu = u.dot(u);
    uv = u.dot(v);
    vv = v.dot(v);
    denominator = uu * vv - uv * uv;
  }
  final CafeFace face;
  final int b, c;
  final CafePoint a, u, v;
  late final double uu, uv, vv, denominator;
  (double, double) blend(CafePoint p) {
    final d = p - a, du = d.dot(u), dv = d.dot(v);
    return (
      (vv * du - uv * dv) / denominator,
      (uu * dv - uv * du) / denominator,
    );
  }
}

class _SceneFace extends CafeFace {
  _SceneFace(this.triangle, List<CafePoint> points)
    : super(
        points,
        triangle.face.color,
        layer: triangle.face.layer,
        objectId: triangle.face.objectId,
      );
  final _SceneTriangle triangle;
  late final blends = points.map((point) {
    for (var i = 1; i + 1 < triangle.face.points.length; i++) {
      final basis = _SceneTriangle(triangle.face, i, i + 1);
      if (basis.denominator.abs() < 1e-18) continue;
      final (b, c) = basis.blend(point);
      if (b >= -1e-6 && c >= -1e-6 && b + c <= 1.000001) {
        return (i, i + 1, b, c);
      }
    }
    final (b, c) = triangle.blend(point);
    return (triangle.b, triangle.c, b, c);
  }).toList();
  Object? attributeKey;
  List<_Vertex>? prepared;
  Object? projectionKey;
  _ProjectedFace? projection;
  late final bool movingShadow = List.generate(triangle.face.points.length, (
    i,
  ) {
    final face = triangle.face, p = face.points[i];
    final n = face.vertexNormals?[i] ?? face.normal;
    return !face.unlit &&
        face.vertexColors == null &&
        n.y >= .8 &&
        p.x >= -4.4 &&
        p.x <= -1.8 &&
        (p.y < .025 || (p.y > .70 && p.y < .85));
  }).any((v) => v);
  late final _SceneBounds bounds = _SceneBounds.of([this]);
}

class _SceneBounds {
  const _SceneBounds(this.minimum, this.maximum, [this.detailId]);
  final CafePoint minimum, maximum;
  final String? detailId;
  factory _SceneBounds.of(List<_SceneFace> faces) {
    var x = double.infinity,
        y = x,
        z = x,
        xx = double.negativeInfinity,
        yy = xx,
        zz = xx;
    final firstId = faces.first.objectId;
    final detailId =
        firstId != null &&
            (firstId.startsWith('garden.tree.') ||
                firstId.startsWith('garden.flowers.')) &&
            faces.every((f) => f.objectId == firstId)
        ? firstId
        : null;
    for (final face in faces) {
      for (final p in face.points) {
        x = math.min(x, p.x);
        y = math.min(y, p.y);
        z = math.min(z, p.z);
        xx = math.max(xx, p.x);
        yy = math.max(yy, p.y);
        zz = math.max(zz, p.z);
      }
    }
    return _SceneBounds(CafePoint(x, y, z), CafePoint(xx, yy, zz), detailId);
  }
  bool visible(List<_FacePlane> frustum) {
    for (final p in frustum) {
      final n = p.normal;
      final d =
          n.x * (n.x >= 0 ? maximum.x : minimum.x) +
          n.y * (n.y >= 0 ? maximum.y : minimum.y) +
          n.z * (n.z >= 0 ? maximum.z : minimum.z);
      if (d < p.offset - .00001) return false;
    }
    return true;
  }
}

class _SceneNode {
  _SceneNode(this.plane, this.faces, this.front, this.back, this.bounds);
  _SceneNode.pending(this.pending, this.bounds) : faces = [];
  _FacePlane? plane;
  List<_SceneFace> faces;
  _SceneNode? front, back;
  List<_SceneFace>? pending;
  final _SceneBounds bounds;

  void expand() {
    final source = pending;
    if (source == null) return;
    pending = null;
    final built = _sceneTree(source, expandLeaf: true);
    if (built == null) return;
    plane = built.plane;
    faces = built.faces;
    front = built.front;
    back = built.back;
  }
}

int _sceneSide(_SceneFace face, _FacePlane plane) {
  var front = false, back = false;
  for (final p in face.points) {
    final d = plane.normal.dot(p) - plane.offset;
    front |= d > _planeEpsilon;
    back |= d < -_planeEpsilon;
    if (front && back) return 2;
  }
  return front
      ? 1
      : back
      ? -1
      : 0;
}

void _sceneSplit(
  _SceneFace face,
  _FacePlane plane,
  List<_SceneFace> front,
  List<_SceneFace> back,
) {
  final f = <CafePoint>[], b = <CafePoint>[];
  for (var i = 0; i < face.points.length; i++) {
    final a = face.points[i], next = face.points[(i + 1) % face.points.length];
    final da = plane.normal.dot(a) - plane.offset,
        db = plane.normal.dot(next) - plane.offset;
    if (da >= -_planeEpsilon) f.add(a);
    if (da <= _planeEpsilon) b.add(a);
    if ((da > _planeEpsilon && db < -_planeEpsilon) ||
        (da < -_planeEpsilon && db > _planeEpsilon)) {
      final cut = CafePoint.lerp(a, next, da / (da - db));
      f.add(cut);
      b.add(cut);
    }
  }
  if (f.length >= 3) front.add(_SceneFace(face.triangle, f));
  if (b.length >= 3) back.add(_SceneFace(face.triangle, b));
}

_FacePlane? _scenePlane(_SceneFace face) {
  final p = face.points;
  for (var i = 1; i + 1 < p.length; i++) {
    final n = (p[i] - p[0]).cross(p[i + 1] - p[0]);
    if (n.dot(n) < 1e-18) continue;
    final unit = n.normalized;
    return _FacePlane(unit, unit.dot(p[0]));
  }
  return null;
}

_SceneNode? _sceneTree(
  List<_SceneFace> faces, {
  bool expandLeaf = false,
  bool dynamic = false,
}) {
  if (faces.isEmpty) return null;
  final bounds = _SceneBounds.of(faces);
  // Defer fine partitions outside the view. A turn only expands nearby leaves,
  // rather than compiling every hidden chair spindle on the first paint.
  if (!expandLeaf && faces.length <= 48) {
    return _SceneNode.pending(faces, bounds);
  }
  _FacePlane? chosen;
  var best = double.infinity;
  // Planes need not belong to a surface. Balanced world-axis cuts avoid a
  // deep tree through a row of chair spindles while retaining exact geometry.
  if (faces.length >= 96) {
    final centers = <CafePoint>[];
    for (var i = 0; i < 41; i++) {
      centers.add(faces[i * (faces.length - 1) ~/ 40].center);
    }
    final axes = const [
      CafePoint(1, 0, 0),
      CafePoint(0, 1, 0),
      CafePoint(0, 0, 1),
    ];
    final candidates = <_FacePlane>[], spreads = <double>[];
    for (final axis in axes) {
      final values = centers.map(axis.dot).toList()..sort();
      spreads.add(values.last - values.first);
      candidates.add(_FacePlane(axis, values[20]));
    }
    final order = [0, 1, 2]..sort((a, b) => spreads[b].compareTo(spreads[a]));
    for (final index in order) {
      if (spreads[index] < .0001) continue;
      final p = candidates[index];
      var f = 0, b = 0, cuts = 0;
      for (final face in faces) {
        final s = _sceneSide(face, p);
        if (s == 1 || s == 2) f++;
        if (s == -1 || s == 2) b++;
        if (s == 2) cuts++;
      }
      if (f < faces.length * .78 &&
          b < faces.length * .78 &&
          cuts < faces.length * .12) {
        chosen = p;
        break;
      }
    }
  }
  final samples = chosen != null ? 0 : math.min(9, faces.length);
  for (var i = 0; i < samples; i++) {
    final p = _scenePlane(
      faces[samples == 1 ? 0 : i * (faces.length - 1) ~/ (samples - 1)],
    );
    if (p == null) continue;
    var f = 0, b = 0, cuts = 0;
    for (final face in faces) {
      final s = _sceneSide(face, p);
      if (s == 1 || s == 2) f++;
      if (s == -1 || s == 2) b++;
      if (s == 2) cuts++;
    }
    final cost = (f - b).abs() + cuts * 3;
    if (cost < best) {
      best = cost.toDouble();
      chosen = p;
    }
    if (cost == 0) break;
  }
  if (chosen == null) return null;
  final front = <_SceneFace>[], back = <_SceneFace>[], on = <_SceneFace>[];
  for (final face in faces) {
    switch (_sceneSide(face, chosen)) {
      case 0:
        on.add(face);
      case 1:
        front.add(face);
      case -1:
        back.add(face);
      case 2:
        _sceneSplit(face, chosen, front, back);
    }
  }
  return _SceneNode(
    chosen,
    on,
    _sceneTree(front, dynamic: dynamic),
    _sceneTree(back, dynamic: dynamic),
    bounds,
  );
}

List<_SceneFace> _sceneTriangles(Iterable<CafeFace> source) {
  final triangles = <_SceneFace>[];
  for (final face in source) {
    if (!face.points.every((p) => p.isFinite)) continue;
    final basis = _SceneTriangle(face, 1, 2);
    final normal = basis.u.cross(basis.v).normalized;
    if (basis.denominator.abs() >= 1e-18 &&
        face.points.every(
          (p) => normal.dot(p - basis.a).abs() <= _planeEpsilon,
        )) {
      triangles.add(_SceneFace(basis, face.points));
      continue;
    }
    for (var i = 1; i + 1 < face.points.length; i++) {
      final triangle = _SceneTriangle(face, i, i + 1);
      if (!triangle.denominator.isFinite ||
          triangle.denominator.abs() < 1e-18) {
        continue;
      }
      triangles.add(
        _SceneFace(triangle, [
          face.points[0],
          face.points[i],
          face.points[i + 1],
        ]),
      );
    }
  }
  return triangles;
}

class _SceneMesh {
  _SceneMesh(List<CafeFace> source, {Set<String> omit = const {}})
    : originals = List.of(source),
      omitted = Set.unmodifiable(omit) {
    final layers = <int, List<_SceneFace>>{};
    for (final face in source) {
      // Distant plants already have watercolor substitutes. Exclude their
      // detailed solids before building the BSP, rather than expanding and
      // splitting those hidden branches on every view through the wide bay.
      if (omitted.contains(face.objectId)) continue;
      if (face.garden) {
        portals.add(face);
        continue;
      }
      layers.putIfAbsent(face.layer, () => []).addAll(_sceneTriangles([face]));
    }
    for (final entry in layers.entries) {
      roots[entry.key] = _sceneTree(entry.value);
    }
  }
  final List<CafeFace> originals, portals = [];
  final Set<String> omitted;
  final roots = <int, _SceneNode?>{};
  Object? orderKey;
  List<CafeFace>? order;
  bool matches(List<CafeFace> source, Set<String> exclude) {
    if (exclude.length != omitted.length || !omitted.containsAll(exclude)) {
      return false;
    }
    if (source.length != originals.length) return false;
    for (var i = 0; i < source.length; i++) {
      if (!identical(source[i], originals[i])) return false;
    }
    return true;
  }

  List<CafeFace> ordered(
    CafeCamera camera,
    Rect clip,
    Size size,
    Iterable<CafeFace> dynamicFaces,
    String? omit,
    Set<String> distant,
  ) {
    final result = <CafeFace>[...portals];
    final f = CafeRenderer.focalLength(size) * camera.lens;
    final r = camera.right,
        u = camera.up,
        v = camera.forward,
        eye = camera.position;
    _FacePlane plane(CafePoint n, [double extra = 0]) =>
        _FacePlane(n, n.dot(eye) + extra);
    final frustum = [
      plane(v, CafeRenderer.near),
      plane(r * f + v * (size.width / 2 - clip.left)),
      plane(r * (-f) + v * (clip.right - size.width / 2)),
      plane(u * (-f) + v * (size.height / 2 - clip.top)),
      plane(u * f + v * (clip.bottom - size.height / 2)),
    ];
    final dynamic = <int, List<_SceneFace>>{};
    final facing = dynamicFaces.where(
      (f) =>
          f.doubleSided ||
          f.unlit ||
          f.color.a <= .99 ||
          f.normal.dot(eye - f.center) >= -.015,
    );
    for (final face in _sceneTriangles(facing)) {
      if (face.bounds.visible(frustum)) {
        dynamic.putIfAbsent(face.layer, () => []).add(face);
      }
    }
    void visit(
      _SceneNode? node,
      List<_SceneFace> changing, {
      bool includeStatic = true,
    }) {
      if (node == null ||
          !node.bounds.visible(frustum) ||
          (includeStatic && distant.contains(node.bounds.detailId))) {
        if (changing.isNotEmpty) {
          visit(_sceneTree(changing, dynamic: true), [], includeStatic: false);
        }
        return;
      }
      node.expand();
      final plane = node.plane;
      if (plane == null) return;
      final front = <_SceneFace>[], back = <_SceneFace>[], on = <_SceneFace>[];
      for (final face in changing) {
        switch (_sceneSide(face, plane)) {
          case 0:
            on.add(face);
          case 1:
            front.add(face);
          case -1:
            back.add(face);
          case 2:
            _sceneSplit(face, plane, front, back);
        }
      }
      final ahead = plane.normal.dot(eye) - plane.offset >= 0;
      visit(
        ahead ? node.back : node.front,
        ahead ? back : front,
        includeStatic: includeStatic,
      );
      final coplanar = [
        ...node.faces.where(
          (p) =>
              (!includeStatic ||
                  ((omit == null || p.objectId != omit) &&
                      !distant.contains(p.objectId))) &&
              p.bounds.visible(frustum),
        ),
        ...on,
      ];
      if (coplanar.length > 1) {
        coplanar.sort((a, b) => b.center.dot(v).compareTo(a.center.dot(v)));
      }
      result.addAll(coplanar);
      visit(
        ahead ? node.front : node.back,
        ahead ? front : back,
        includeStatic: includeStatic,
      );
    }

    for (final layer in {...roots.keys, ...dynamic.keys}.toList()..sort()) {
      visit(roots[layer], dynamic[layer] ?? []);
    }
    return result;
  }
}
