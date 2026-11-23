part of 'cafe_world.dart';

extension _SoftCafeGeometry on CafeWorld {
  /// Real rounded members: their same triangles are used by ray picking.
  void _rod(
    CafePoint from,
    CafePoint to,
    double radius,
    Color color, {
    CafeSurface? surface,
    int sides = 10,
  }) {
    final axis = (to - from).normalized;
    final u = axis
        .cross(
          axis.y.abs() < .9
              ? const CafePoint(0, 1, 0)
              : const CafePoint(1, 0, 0),
        )
        .normalized;
    final v = axis.cross(u).normalized;
    CafePoint normal(double a) => u * math.cos(a) + v * math.sin(a);
    for (var i = 0; i < sides; i++) {
      final a = normal(i * math.pi * 2 / sides);
      final b = normal((i + 1) * math.pi * 2 / sides);
      var points = [
        from + a * radius,
        to + a * radius,
        to + b * radius,
        from + b * radius,
      ];
      var normals = [a, a, b, b];
      if ((points[1] - points[0]).cross(points[2] - points[0]).dot(a) < 0) {
        points = points.reversed.toList();
        normals = normals.reversed.toList();
      }
      faces.add(
        CafeFace(
          points,
          color,
          surface: surface,
          grain: CafeGrain.y,
          target: _target,
          vertexNormals: normals,
        ),
      );
    }
  }

  /// Smoothly shaded profile rather than a single straight-sided cone.
  void _turned(
    double x,
    double z,
    List<(double, double)> profile,
    Color color, {
    int sides = 28,
  }) {
    CafePoint normal(int ring, double angle) {
      final before = profile[math.max(0, ring - 1)];
      final after = profile[math.min(profile.length - 1, ring + 1)];
      final slope = (before.$2 - after.$2) / (after.$1 - before.$1);
      return CafePoint(math.cos(angle), slope, math.sin(angle)).normalized;
    }

    CafePoint at(int ring, double angle) => CafePoint(
      x + math.cos(angle) * profile[ring].$2,
      profile[ring].$1,
      z + math.sin(angle) * profile[ring].$2,
    );
    for (var ring = 0; ring + 1 < profile.length; ring++) {
      for (var i = 0; i < sides; i++) {
        final a = i * math.pi * 2 / sides, b = (i + 1) * math.pi * 2 / sides;
        var points = [
          at(ring, a),
          at(ring + 1, a),
          at(ring + 1, b),
          at(ring, b),
        ];
        var normals = [
          normal(ring, a),
          normal(ring + 1, a),
          normal(ring + 1, b),
          normal(ring, b),
        ];
        if ((points[1] - points[0])
                .cross(points[2] - points[0])
                .dot(normals[0]) <
            0) {
          points = points.reversed.toList();
          normals = normals.reversed.toList();
        }
        faces.add(
          CafeFace(points, color, target: _target, vertexNormals: normals),
        );
      }
    }
  }
}
