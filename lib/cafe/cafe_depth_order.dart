part of 'cafe_renderer.dart';

// Painter's average-Z ordering is invalid for a long surface and a small
// object resting on it. Partition actual polygons by their planes instead.
// Splits interpolate the same lit colours/UVs as near-plane clipping, so no
// material or object geometry is changed to conceal an occlusion error.
class _FacePlane {
  _FacePlane(this.normal, this.offset);
  final CafePoint normal;
  final double offset;
  double distance(_Vertex v) => normal.dot(v.point) - offset;

  static _FacePlane? of(_ProjectedFace face) {
    final v = face.vertices;
    for (var i = 1; i + 1 < v.length; i++) {
      final n = (v[i].point - v[0].point).cross(v[i + 1].point - v[0].point);
      if (n.dot(n) < 1e-18) continue;
      final unit = n.normalized;
      return _FacePlane(unit, unit.dot(v[0].point));
    }
    return null;
  }
}

const _planeEpsilon = 1e-7;

int _planeSide(_ProjectedFace face, _FacePlane plane) {
  var front = false, back = false;
  for (final v in face.vertices) {
    final d = plane.distance(v);
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

List<_ProjectedFace> _depthOrder(List<_ProjectedFace> input) {
  final layers = <int, List<_ProjectedFace>>{};
  for (final face in input) {
    final plane = _FacePlane.of(face);
    if (plane == null) continue;
    final group = layers.putIfAbsent(face.face.layer, () => []);
    if (face.vertices.any((v) => plane.distance(v).abs() > _planeEpsilon)) {
      // A bent quad is actually drawn as a triangle fan; use those same
      // planar pieces for ordering, including during notebook animations.
      for (var i = 1; i + 1 < face.vertices.length; i++) {
        group.add(
          _fragment(face, [
            face.vertices[0],
            face.vertices[i],
            face.vertices[i + 1],
          ]),
        );
      }
    } else {
      group.add(face);
    }
  }
  final ordered = <_ProjectedFace>[];
  void visit(List<_ProjectedFace> faces) {
    if (faces.isEmpty) return;
    if (faces.length == 1) {
      ordered.add(faces.single);
      return;
    }
    // Sample planes across the group rather than recursing down a long row
    // of adjacent planks. Prefer balance and avoid unnecessary splits.
    _FacePlane? chosen;
    var best = double.infinity;
    final samples = math.min(9, faces.length);
    for (var i = 0; i < samples; i++) {
      final plane = _FacePlane.of(
        faces[i * (faces.length - 1) ~/ (samples - 1)],
      );
      if (plane == null) continue;
      var front = 0, back = 0, splits = 0;
      for (final face in faces) {
        switch (_planeSide(face, plane)) {
          case 1:
            front++;
          case -1:
            back++;
          case 2:
            splits++;
            front++;
            back++;
        }
      }
      final cost = (front - back).abs() + splits * 3;
      if (cost < best) {
        chosen = plane;
        best = cost.toDouble();
      }
      if (cost == 0) break;
    }
    if (chosen == null) return;
    final front = <_ProjectedFace>[], back = <_ProjectedFace>[];
    final coplanar = <_ProjectedFace>[];
    for (final face in faces) {
      switch (_planeSide(face, chosen)) {
        case 0:
          coplanar.add(face);
        case 1:
          front.add(face);
        case -1:
          back.add(face);
        case 2:
          final f = <_Vertex>[], b = <_Vertex>[];
          for (var i = 0; i < face.vertices.length; i++) {
            final a = face.vertices[i];
            final next = face.vertices[(i + 1) % face.vertices.length];
            final da = chosen.distance(a), db = chosen.distance(next);
            if (da >= -_planeEpsilon) f.add(a);
            if (da <= _planeEpsilon) b.add(a);
            if ((da > _planeEpsilon && db < -_planeEpsilon) ||
                (da < -_planeEpsilon && db > _planeEpsilon)) {
              final cut = _Vertex.lerp(a, next, da / (da - db));
              f.add(cut);
              b.add(cut);
            }
          }
          if (f.length >= 3) front.add(_fragment(face, f));
          if (b.length >= 3) back.add(_fragment(face, b));
      }
    }
    // The camera is at the origin in view coordinates. Draw the half-space
    // opposite it, then the plane, then the half-space containing the eye.
    final eyeInFront = chosen.offset <= 0;
    visit(eyeInFront ? back : front);
    coplanar.sort((a, b) => b.depth.compareTo(a.depth));
    ordered.addAll(coplanar);
    visit(eyeInFront ? front : back);
  }

  for (final layer in layers.keys.toList()..sort()) {
    visit(layers[layer]!);
  }
  return ordered;
}

_ProjectedFace _fragment(_ProjectedFace source, List<_Vertex> vertices) =>
    _ProjectedFace(
      source.face,
      vertices,
      vertices.fold<double>(0, (sum, v) => sum + v.point.z) / vertices.length,
    );
