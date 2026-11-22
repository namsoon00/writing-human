part of 'cafe_world.dart';

/// A second real mesh room; the concept photograph is never used as a backdrop.
extension _CourtyardGeometry on CafeWorld {
  void _arch(double x, double y, double z, double outer, double inner) {
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 24, b = (i + 1) * math.pi / 24;
      CafePoint at(double t, double r) =>
          CafePoint(x + math.cos(t) * r, y + math.sin(t) * r, z);
      quad(
        at(a, outer),
        at(b, outer),
        at(b, inner),
        at(a, inner),
        CafeWorld.dark,
        wood: true,
        grain: CafeGrain.x,
      );
    }
  }

  void _oval(
    CafePoint center,
    CafePoint radius,
    Color color, {
    List<CafeFace>? into,
    double yaw = 0,
    int segments = 12,
    int rings = 6,
    CafeTarget? target,
    int layer = 2,
  }) {
    final output = into ?? faces;
    CafePoint rotate(CafePoint p) => CafePoint(
      p.x * math.cos(yaw) - p.z * math.sin(yaw),
      p.y,
      p.x * math.sin(yaw) + p.z * math.cos(yaw),
    );
    CafePoint at(double u, double v) =>
        center +
        rotate(
          CafePoint(
            math.cos(u) * math.cos(v) * radius.x,
            math.sin(v) * radius.y,
            math.sin(u) * math.cos(v) * radius.z,
          ),
        );
    for (var i = 0; i < segments; i++) {
      for (var j = 0; j < rings; j++) {
        final a = i * 2 * math.pi / segments,
            b = (i + 1) * 2 * math.pi / segments,
            c = -math.pi / 2 + j * math.pi / rings,
            d = -math.pi / 2 + (j + 1) * math.pi / rings;
        var points = [at(a, c), at(a, d), at(b, d), at(b, c)];
        // Keep outward normals even at the poles, where a quad may degenerate.
        final normal =
            (points[0] + points[1] + points[2] + points[3]) * .25 - center;
        if ((points[1] - points[0]).cross(points[2] - points[0]).dot(normal) <
            0) {
          points = points.reversed.toList();
        }
        output.add(
          CafeFace(
            points,
            color,
            doubleSided: true,
            layer: layer,
            target: target ?? _target,
            vertexNormals: points.map((p) => (p - center).normalized).toList(),
          ),
        );
      }
    }
  }

  void _branch(CafePoint a, CafePoint b, double radius) {
    final axis = (b - a).normalized;
    final across = axis.cross(const CafePoint(0, 0, 1)).normalized;
    final other = axis.cross(across).normalized;
    for (var i = 0; i < 8; i++) {
      CafePoint edge(double t) =>
          across * (math.cos(t) * radius) + other * (math.sin(t) * radius);
      final u = edge(i * math.pi / 4), v = edge((i + 1) * math.pi / 4);
      quad(
        a + u,
        b + u * .7,
        b + v * .7,
        a + v,
        const Color(0xff79634b),
        wood: true,
      );
    }
  }

  void _tree(double x, double z, double height, int seed) {
    final random = math.Random(seed);
    final root = CafePoint(x, .08, z),
        crown = CafePoint(x + .12, height * .75, z);
    _branch(root, crown, .075);
    for (var i = 0; i < 9; i++) {
      final angle = i * 2.4, reach = .45 + random.nextDouble() * .4;
      final start = CafePoint.lerp(root, crown, .5 + random.nextDouble() * .45);
      final tip = CafePoint(
        x + math.cos(angle) * reach,
        height * .74 + random.nextDouble() * height * .22,
        z + math.sin(angle) * reach,
      );
      _branch(start, tip, .022);
      for (var j = 0; j < 65; j++) {
        final p =
            tip +
            CafePoint(
              (random.nextDouble() - .5) * .65,
              (random.nextDouble() - .5) * .45,
              (random.nextDouble() - .5) * .65,
            );
        final turn = random.nextDouble() * math.pi,
            length = .045 + random.nextDouble() * .035;
        final u = CafePoint(
          math.cos(turn) * length,
          .025,
          math.sin(turn) * length,
        );
        final v = CafePoint(
          -math.sin(turn) * .045,
          .018,
          math.cos(turn) * .045,
        );
        final color = [
          const Color(0xff6a8551),
          const Color(0xff91a568),
          const Color(0xff4f7046),
          const Color(0xffa2ae73),
        ][j % 4];
        faces.add(
          CafeFace(
            List.generate(8, (k) {
              final t = k * math.pi / 4;
              return p + u * math.cos(t) + v * math.sin(t);
            }),
            color,
            doubleSided: true,
          ),
        );
      }
    }
    shadow(x + .15, z + .1, .75, .7, strength: .08);
  }

  void _flower(double x, double z, Color color) {
    final stem = CafePoint(x, .13, z), top = CafePoint(x + .02, .27, z);
    _branch(stem, top, .004);
    for (var i = 0; i < 5; i++) {
      final angle = i * 2 * math.pi / 5;
      _oval(
        top + CafePoint(math.cos(angle) * .025, 0, math.sin(angle) * .025),
        const CafePoint(.022, .008, .026),
        color,
        segments: 6,
        rings: 3,
      );
    }
    _oval(
      top + const CafePoint(0, .008, 0),
      const CafePoint(.012, .01, .012),
      const Color(0xffc7ae64),
      segments: 6,
      rings: 3,
    );
  }

  void _buildCourtyard() {
    void wall(CafePoint a, CafePoint b, CafePoint c, CafePoint d, Color color) {
      for (var i = 0; i < 12; i++) {
        for (var j = 0; j < 6; j++) {
          CafePoint at(double u, double v) => CafePoint.lerp(
            CafePoint.lerp(a, b, u),
            CafePoint.lerp(d, c, u),
            v,
          );
          quad(
            at(i / 12, j / 6),
            at((i + 1) / 12, j / 6),
            at((i + 1) / 12, (j + 1) / 6),
            at(i / 12, (j + 1) / 6),
            color,
            layer: 0,
          );
        }
      }
    }

    quad(
      const CafePoint(-2.8, -.005, -3),
      const CafePoint(-2.8, -.005, 3.1),
      const CafePoint(2.8, -.005, 3.1),
      const CafePoint(2.8, -.005, -3),
      const Color(0xffcec5b3),
      layer: -1,
    );
    for (var ix = 0; ix < 10; ix++) {
      for (var iz = 0; iz < 7; iz++) {
        final x = -2.8 + ix * .56, z = -3 + iz * .86;
        faces.add(
          CafeFace(
            [
              CafePoint(x, 0, z),
              CafePoint(x, 0, z + .856),
              CafePoint(x + .556, 0, z + .856),
              CafePoint(x + .556, 0, z),
            ],
            const Color(0xfff4eddf),
            surface: CafeSurface.limestone,
            layer: 0,
            textureCoordinates: [
              Offset(ix * .24, iz * .35),
              Offset(ix * .24, (iz + 1) * .35),
              Offset((ix + 1) * .24, (iz + 1) * .35),
              Offset((ix + 1) * .24, iz * .35),
            ],
          ),
        );
      }
    }
    wall(
      const CafePoint(-2.8, 0, -3),
      const CafePoint(2.8, 0, -3),
      const CafePoint(2.8, 2.95, -3),
      const CafePoint(-2.8, 2.95, -3),
      CafeWorld.wall,
    );
    wall(
      const CafePoint(2.8, 0, -3),
      const CafePoint(2.8, 0, 3),
      const CafePoint(2.8, 2.95, 3),
      const CafePoint(2.8, 2.95, -3),
      CafeWorld.wall,
    );
    wall(
      const CafePoint(-2.8, 0, 3),
      const CafePoint(-2.8, 0, -3),
      const CafePoint(-2.8, 2.95, -3),
      const CafePoint(-2.8, 2.95, 3),
      CafeWorld.wall,
    );
    wall(
      const CafePoint(2.8, 0, 3),
      const CafePoint(-2.8, 0, 3),
      const CafePoint(-2.8, 2.95, 3),
      const CafePoint(2.8, 2.95, 3),
      CafeWorld.wall,
    );
    quad(
      const CafePoint(-2.8, 4, -3),
      const CafePoint(-2.8, 4, 3),
      const CafePoint(2.8, 4, 3),
      const CafePoint(2.8, 4, -3),
      const Color(0xffdce5de),
      unlit: true,
      layer: -1,
    );
    for (var i = 0; i < 23; i++) {
      box(
        1.85,
        2.93,
        -2.95 + i * .265,
        1.9,
        .07,
        .07,
        CafeWorld.oak,
        wood: true,
      );
    }
    box(2.65, 1.45, -1.8, .12, 2.9, .12, CafeWorld.dark, wood: true);
    box(2.65, 1.45, 2.4, .12, 2.9, .12, CafeWorld.dark, wood: true);
    // A planted bank and pond are a single blocked region, never a walking tile.
    obstacles.add(const Rect.fromLTWH(-2.65, -2.5, 2.55, 3.8));
    _oval(
      const CafePoint(-1.45, -.02, -.6),
      const CafePoint(1.25, .06, 1.8),
      const Color(0xff7c875c),
      segments: 24,
      rings: 4,
      layer: 0,
    );
    final random = math.Random(22012);
    _target = CafeTarget.pond;
    const center = CafePoint(-1.25, .095, -.3);
    for (var i = 0; i < 36; i++) {
      final a = i * 2 * math.pi / 36, b = (i + 1) * 2 * math.pi / 36;
      CafePoint edge(double t) =>
          center + CafePoint(math.cos(t) * .86, 0, math.sin(t) * 1.12);
      faces.add(
        CafeFace(
          [center, edge(b), edge(a)],
          const Color(0xff9aafa0),
          target: _target,
          layer: 1,
        ),
      );
      if (i % 2 == 0) {
        final p = edge(a);
        _oval(
          p + const CafePoint(0, -.015, 0),
          const CafePoint(.14, .065, .11),
          i % 4 == 0 ? const Color(0xffaaa78d) : const Color(0xff828773),
          segments: 8,
          rings: 4,
        );
      }
    }
    // Small stones visible beneath the water give it depth without a CafeWorld.dark pit.
    for (var i = 0; i < 32; i++) {
      final a = random.nextDouble() * math.pi * 2,
          rr = math.sqrt(random.nextDouble()) * .8;
      _oval(
        center + CafePoint(math.cos(a) * rr, -.015, math.sin(a) * rr * 1.2),
        const CafePoint(.047, .008, .032),
        const Color(0xffa3ad8c),
        segments: 6,
        rings: 3,
      );
    }
    _target = null;
    _tree(-2.02, -.85, 2.7, 18);
    _tree(-.9, -2.05, 1.9, 29);
    for (var i = 0; i < 18; i++) {
      final x = -2.5 + random.nextDouble() * 2.2,
          z = -2.4 + random.nextDouble() * 3.5;
      // Flowers stay on the banks, leaving the water readable.
      if (((x + 1.25) / 1.03) * ((x + 1.25) / 1.03) +
              ((z + .3) / 1.35) * ((z + .3) / 1.35) <
          1) {
        continue;
      }
      _flower(
        x,
        z,
        i % 4 == 0 ? const Color(0xffd6b5c2) : const Color(0xfff0eee0),
      );
      _flower(x + .07, z + .04, const Color(0xfff0eee0));
    }
    _target = CafeTarget.bench;
    box(2.25, .28, -.05, .72, .46, 2.9, CafeWorld.dark, wood: true);
    box(2.2, .53, -.05, .74, .16, 2.87, CafeWorld.sage);
    box(2.63, .91, -.05, .14, .7, 2.9, CafeWorld.sage);
    box(2.48, .82, -.95, .25, .48, .5, CafeWorld.cream);
    obstacles.add(const Rect.fromLTWH(1.83, -1.5, .87, 2.9));
    _target = null;
    _writingSurface(
      CafeWorld.tableBounds(CafeSeat.garden),
      target: CafeTarget.gardenDesk,
    );
    _target = CafeTarget.gardenDesk;
    _book(1.46, .773, .55);
    box(1.38, .805, .36, .22, .012, .015, CafeWorld.dark);
    box(1.6, .795, .18, .23, .045, .22, CafeWorld.sage);
    _target = CafeTarget.tea;
    cylinder(1.42, .82, .93, .07, .11, CafeWorld.cream, sides: 16);
    _target = null;
    _pendant(1.48, .62, radius: .17);
    // Doorway and bell are reachable from the dry path beside the pond.
    _target = CafeTarget.cafeReturn;
    box(0, 1.2, 2.98, 1.25, 2.4, .03, const Color(0xffb9b599));
    for (final x in [-.69, .69]) {
      box(x, 1, 2.9, .09, 2, .15, CafeWorld.dark, wood: true);
    }
    _arch(0, 1.96, 2.84, .74, .64);
    faces.add(
      CafeFace(
        [
          const CafePoint(.52, 1.4, 2.83),
          const CafePoint(-.52, 1.4, 2.83),
          const CafePoint(-.52, 1.92, 2.83),
          const CafePoint(.52, 1.92, 2.83),
        ],
        CafeWorld.cream,
        sign: true,
        signRow: 4,
        unlit: true,
        target: _target,
      ),
    );
    _target = CafeTarget.bell;
    box(-.8, 1.9, 2.84, .14, .08, .22, CafeWorld.dark, wood: true);
    cylinder(
      -.8,
      1.65,
      2.8,
      .075,
      .16,
      CafeWorld.brass,
      topRadius: .025,
      sides: 16,
    );
    cylinder(-.8, 1.5, 2.8, .008, .21, CafeWorld.dark, sides: 6);
    _target = null;
  }
}

extension CafeCourtyardMotion on CafeWorld {
  List<CafeFace> animatedFaces(
    double time, {
    bool teaFilled = false,
    double? bellAt,
    double? teaAt,
  }) {
    if (!courtyard) return const [];
    final result = <CafeFace>[];
    for (var i = 0; i < 3; i++) {
      final t = time * .17 + i * 2.1;
      final p = CafePoint(
        -1.25 + math.cos(t) * (.4 + i * .04),
        .13,
        -.3 + math.sin(t) * (.72 - i * .12),
      );
      final yaw = math.atan2(math.cos(t) * .72, -math.sin(t) * .44);
      final color = i == 2 ? const Color(0xffe6dfbb) : const Color(0xffd29648);
      _oval(
        p,
        const CafePoint(.105, .023, .035),
        color,
        into: result,
        yaw: yaw,
        segments: 10,
        rings: 4,
      );
      CafePoint rotate(double x, double y, double z) =>
          p +
          CafePoint(
            x * math.cos(yaw) - z * math.sin(yaw),
            y,
            x * math.sin(yaw) + z * math.cos(yaw),
          );
      final swing = math.sin(time * 2 + i) * .015;
      result.add(
        CafeFace(
          [
            rotate(-.075, 0, 0),
            rotate(-.16, .006, .045 + swing),
            rotate(-.15, 0, -.045 + swing),
          ],
          color,
          doubleSided: true,
        ),
      );
      // Two subtle ripples around each fish, in the same 3D plane as the water.
      for (var j = 0; j < 12; j++) {
        final a = j * math.pi / 6,
            b = (j + 1) * math.pi / 6,
            rr = .12 + (time * .018 + i * .04) % .13;
        CafePoint edge(double t, double r) =>
            CafePoint(p.x + math.cos(t) * r, .157, p.z + math.sin(t) * r * .5);
        result.add(
          CafeFace(
            [edge(a, rr), edge(b, rr), edge(b, rr + .003), edge(a, rr + .003)],
            const Color(0x26e8ead5),
            unlit: true,
            doubleSided: true,
          ),
        );
      }
    }
    if (teaFilled) {
      final c = const CafePoint(1.42, .88, .93);
      for (var i = 0; i < 16; i++) {
        final a = i * math.pi / 8, b = (i + 1) * math.pi / 8;
        result.add(
          CafeFace(
            [
              c,
              c + CafePoint(math.cos(b) * .057, 0, math.sin(b) * .057),
              c + CafePoint(math.cos(a) * .057, 0, math.sin(a) * .057),
            ],
            const Color(0xff98704a),
            unlit: true,
          ),
        );
      }
      if (teaAt != null && time - teaAt < 18) {
        for (var i = 0; i < 5; i++) {
          final phase = (time * .15 + i * .2) % 1;
          final p =
              c + CafePoint(math.sin(time + i) * .014, .03 + phase * .2, 0);
          result.add(
            CafeFace(
              [
                p + const CafePoint(-.009, 0, 0),
                p + const CafePoint(.009, 0, 0),
                p + const CafePoint(.005, .04, 0),
                p + const CafePoint(-.005, .04, 0),
              ],
              Color.fromRGBO(245, 239, 221, .15 * (1 - phase)),
              unlit: true,
              doubleSided: true,
            ),
          );
        }
      }
    }
    if (bellAt != null && time - bellAt < 4) {
      final d = time - bellAt;
      _oval(
        CafePoint(-.8 + math.sin(d * 6) * .035 * math.exp(-d), 1.47, 2.8),
        const CafePoint(.013, .018, .013),
        CafeWorld.brass,
        into: result,
        segments: 6,
        rings: 3,
      );
    }
    return result;
  }
}
