part of 'cafe_world.dart';

/// A second real mesh room; the concept photograph is never used as a backdrop.
extension _CourtyardGeometry on CafeWorld {
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
    CafeSurface? surface,
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
            surface: surface,
            target: target ?? _target,
            vertexNormals: points.map((p) => (p - center).normalized).toList(),
            textureCoordinates: points.map((p) {
              final delta = p - center;
              final local = CafePoint(
                delta.x * math.cos(yaw) + delta.z * math.sin(yaw),
                delta.y,
                -delta.x * math.sin(yaw) + delta.z * math.cos(yaw),
              );
              return Offset(
                (local.x + local.z * .37) / .45,
                (local.y + local.z * .29) / .45,
              );
            }).toList(),
          ),
        );
      }
    }
  }

  void _tree(double x, double z, double height, int seed) {
    plants.add(
      CafePlant(
        CafePoint(x, .02, z),
        height * .74,
        height,
        CafeSurface.tree,
        flip: seed.isEven,
      ),
    );
    shadow(x + .06, z + .02, .7, .65, strength: .12);
  }

  void _flower(double x, double z, Color color) {
    plants.add(
      CafePlant(
        CafePoint(x, .025, z),
        .75,
        .55,
        CafeSurface.flowers,
        flip: x < -1,
      ),
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
            surface: CafeSurface.plaster,
            layer: 0,
          );
        }
      }
    }

    quad(
      const CafePoint(-4.65, -.005, -3),
      const CafePoint(-4.65, -.005, 3.1),
      const CafePoint(4.65, -.005, 3.1),
      const CafePoint(4.65, -.005, -3),
      const Color(0xffcec5b3),
      layer: -1,
    );
    for (var ix = 0; ix < 17; ix++) {
      for (var iz = 0; iz < 7; iz++) {
        final x = -4.65 + ix * .56, z = -3 + iz * .86;
        faces.add(
          CafeFace(
            [
              CafePoint(x, 0, z),
              CafePoint(x, 0, z + .86),
              CafePoint(x + .56, 0, z + .86),
              CafePoint(x + .56, 0, z),
            ],
            const Color(0xfff4eddf),
            surface: CafeSurface.gravel,
            layer: 0,
            textureCoordinates: [
              Offset(x / .6, z / .6),
              Offset(x / .6, (z + .86) / .6),
              Offset((x + .56) / .6, (z + .86) / .6),
              Offset((x + .56) / .6, z / .6),
            ],
          ),
        );
      }
    }
    wall(
      const CafePoint(-4.65, 0, -3),
      const CafePoint(4.65, 0, -3),
      const CafePoint(4.65, 2.15, -3),
      const CafePoint(-4.65, 2.15, -3),
      CafeWorld.wall,
    );
    wall(
      const CafePoint(4.65, 0, -3),
      const CafePoint(4.65, 0, 3),
      const CafePoint(4.65, 2.15, 3),
      const CafePoint(4.65, 2.15, -3),
      CafeWorld.wall,
    );
    wall(
      const CafePoint(-4.65, 0, 3),
      const CafePoint(-4.65, 0, -3),
      const CafePoint(-4.65, 2.15, -3),
      const CafePoint(-4.65, 2.15, 3),
      CafeWorld.wall,
    );
    // Limestone coping and a low gravel margin give the plaster wall scale.
    box(
      0,
      2.17,
      -3,
      9.3,
      .07,
      .18,
      const Color(0xffddd2bc),
      surface: CafeSurface.limestone,
    );
    for (final x in [-4.65, 4.65]) {
      box(
        x,
        2.17,
        0,
        .18,
        .07,
        6.0,
        const Color(0xffddd2bc),
        surface: CafeSurface.limestone,
      );
    }
    for (var i = 0; i < 16; i++) {
      final x = -4.5 + i * .56;
      quad(
        CafePoint(x, .006, -2.98),
        CafePoint(x, .006, -2.52),
        CafePoint(x + .56, .006, -2.52),
        CafePoint(x + .56, .006, -2.98),
        const Color(0xffa99e88),
        surface: CafeSurface.gravel,
        layer: 0,
      );
    }
    // Same glazed facade as the cafe, viewed from the garden side.
    wall(
      const CafePoint(-4.65, 0, 3.165),
      const CafePoint(4.65, 0, 3.165),
      const CafePoint(4.65, .61, 3.165),
      const CafePoint(-4.65, .61, 3.165),
      CafeWorld.wall,
    );
    for (final x in [3.35, 1.05, -1.25, -3.55]) {
      for (final dx in [-1.08, 1.08]) {
        if (x == 3.35 && dx > 0) continue;
        box(x + dx, 1.72, 3.165, .07, 2.25, .12, CafeWorld.dark, wood: true);
      }
      if (x != 3.35) {
        box(x, .61, 3.165, 2.20, .07, .12, CafeWorld.dark, wood: true);
      }
      box(x, 2.83, 3.165, 2.20, .07, .12, CafeWorld.dark, wood: true);
      faces.add(
        CafeFace(
          [
            CafePoint(x - 1.02, .66, 3.164),
            CafePoint(x + 1.02, .66, 3.164),
            CafePoint(x + 1.02, 2.78, 3.164),
            CafePoint(x - 1.02, 2.78, 3.164),
          ],
          CafeWorld.cream,
          garden: true,
          unlit: true,
          layer: 1,
        ),
      );
      if (x != 3.35) {
        box(x, 1.70, 3.16, .04, 2.2, .12, CafeWorld.dark, wood: true);
      }
    }
    quad(
      const CafePoint(-4.65, 4, -3),
      const CafePoint(-4.65, 4, 3),
      const CafePoint(4.65, 4, 3),
      const CafePoint(4.65, 4, -3),
      const Color(0xffc5bfbd),
      unlit: true,
      layer: -1,
    );
    for (var i = 0; i < 23; i++) {
      box(
        3.65,
        2.93,
        -2.95 + i * .265,
        1.9,
        .07,
        .07,
        CafeWorld.oak,
        wood: true,
      );
    }
    box(4.45, 1.45, -1.8, .12, 2.9, .12, CafeWorld.dark, wood: true);
    box(4.45, 1.45, 2.4, .12, 2.9, .12, CafeWorld.dark, wood: true);
    // Low stone steps through fine gravel, shared by the window and garden view.
    for (final point in [
      (3.5, 1.9),
      (2.2, 1.65),
      (1.2, 1.15),
      (.48, .45),
      (.40, -.35),
      (.60, -1.20),
      (1.5, -1.9),
    ]) {
      _roundedSlab(
        point.$1,
        point.$2,
        .70,
        .47,
        top: .028,
        thickness: .028,
        radius: .085,
        surface: CafeSurface.limestone,
        color: const Color(0xffe9dfca),
      );
    }
    // A planted bank and pond are a single blocked region, never a walking tile.
    obstacles.add(const Rect.fromLTWH(-2.65, -.9, 2.55, 3.35));
    final random = math.Random(22012);
    _target = CafeTarget.pond;
    const center = CafePoint(-1.25, .095, 1.0);
    for (var i = 0; i < 36; i++) {
      final a = i * 2 * math.pi / 36, b = (i + 1) * 2 * math.pi / 36;
      CafePoint edge(double t) =>
          center + CafePoint(math.cos(t) * .86, 0, math.sin(t) * 1.12);
      faces.add(
        CafeFace(
          [center, edge(b), edge(a)],
          const Color(0xffa2bcab),
          surface: CafeSurface.water,
          target: _target,
          layer: 1,
        ),
      );
      if (i % 2 == 0) {
        final p = edge(a);
        _oval(
          p + const CafePoint(0, -.015, 0),
          CafePoint(
            .11 + random.nextDouble() * .065,
            .045 + random.nextDouble() * .035,
            .085 + random.nextDouble() * .045,
          ),
          i % 4 == 0 ? const Color(0xffc4bcaa) : const Color(0xffa49d8d),
          segments: 16,
          rings: 8,
          surface: CafeSurface.limestone,
          yaw: a * .35,
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
    obstacles.add(const Rect.fromLTWH(-3.36, -1.76, .42, .42));
    obstacles.add(const Rect.fromLTWH(3.04, -2.26, .42, .42));
    _tree(-3.15, -1.55, 2.55, 18);
    _tree(3.25, -2.05, 2.30, 29);
    for (var i = 0; i < 18; i++) {
      final x = -2.9 + random.nextDouble() * 3.2,
          z = -1.3 + random.nextDouble() * 3.7;
      // Flowers stay on the banks, leaving the water readable.
      if (((x + 1.25) / 1.03) * ((x + 1.25) / 1.03) +
              ((z - 1.0) / 1.35) * ((z - 1.0) / 1.35) <
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
    // Low overlapping clumps connect the existing two trees without filling the path.
    for (var i = 0; i < 10; i++) {
      final x = -4.0 + i * .84;
      plants.add(
        CafePlant(
          CafePoint(x, .025, -2.63 + (i % 3) * .07),
          1.02 + (i % 3) * .09,
          .43 + (i % 3) * .065,
          CafeSurface.flowers,
          flip: i.isEven,
        ),
      );
    }
    for (final p in [(-3.8, -1.5), (3.9, -1.7)]) {
      plants.add(
        CafePlant(
          CafePoint(p.$1, .025, p.$2),
          1.10,
          .63,
          CafeSurface.flowers,
          flip: p.$1 < 0,
        ),
      );
    }
    _target = CafeTarget.bench;
    box(4.05, .28, -.05, .72, .46, 2.9, CafeWorld.dark, wood: true);
    box(4.0, .53, -.05, .74, .16, 2.87, CafeWorld.sage);
    box(4.43, .91, -.05, .14, .7, 2.9, CafeWorld.sage);
    box(4.28, .82, -.95, .25, .48, .5, CafeWorld.cream);
    obstacles.add(const Rect.fromLTWH(3.63, -1.5, .87, 2.9));
    _target = null;
    _writingSurface(
      CafeWorld.tableBounds(CafeSeat.garden),
      target: CafeTarget.gardenDesk,
    );
    _target = CafeTarget.gardenDesk;
    _book(3.26, .773, .55);
    box(3.18, .805, .36, .22, .012, .015, CafeWorld.dark);
    box(3.4, .795, .18, .23, .045, .22, CafeWorld.sage);
    _target = CafeTarget.tea;
    cylinder(3.22, .82, .93, .07, .11, CafeWorld.cream, sides: 16);
    _target = null;
    _pendant(3.28, .62, radius: .17);
    // A glass door shares the cafe's rear-left window bay, with matching jambs.
    _target = CafeTarget.cafeReturn;
    for (final x in [2.62, 4.48]) {
      box(x, 1.33, 3.17, .075, 2.66, .12, CafeWorld.dark, wood: true);
    }
    box(3.55, 2.66, 3.17, 1.94, .075, .12, CafeWorld.dark, wood: true);
    faces.add(
      CafeFace(
        const [
          CafePoint(2.65, 0, 3.16),
          CafePoint(4.45, 0, 3.16),
          CafePoint(4.45, 2.62, 3.16),
          CafePoint(2.65, 2.62, 3.16),
        ],
        CafeWorld.cream,
        garden: true,
        unlit: true,
        layer: 1,
        target: _target,
      ),
    );
    final leaf = space.doorOpen ? 1.73 : 3.55;
    quad(
      CafePoint(leaf - .875, .03, 3.115),
      CafePoint(leaf + .875, .03, 3.115),
      CafePoint(leaf + .875, 2.57, 3.115),
      CafePoint(leaf - .875, 2.57, 3.115),
      const Color(0x109bc1b3),
      unlit: true,
    );

    for (final x in [leaf - .9, leaf + .9]) {
      box(x, 1.31, 3.12, .045, 2.62, .055, CafeWorld.dark, wood: true);
    }
    for (final y in [.025, 2.60]) {
      box(leaf, y, 3.12, 1.80, .045, .055, CafeWorld.dark, wood: true);
    }
    box(leaf - .79, 1.12, 3.06, .03, .26, .035, CafeWorld.brass);
    _target = CafeTarget.bell;
    box(2.53, 1.9, 3.05, .30, .08, .22, CafeWorld.dark, wood: true);
    cylinder(
      2.48,
      1.65,
      3.03,
      .075,
      .16,
      CafeWorld.brass,
      topRadius: .025,
      sides: 16,
    );
    cylinder(2.48, 1.5, 3.03, .008, .21, CafeWorld.dark, sides: 6);
    cylinder(2.48, 1.835, 2.99, .006, .09, CafeWorld.brass, sides: 6);
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
        1.0 + math.sin(t) * (.72 - i * .12),
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
      final c = const CafePoint(3.22, .88, .93);
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
        CafePoint(2.48 + math.sin(d * 6) * .035 * math.exp(-d), 1.47, 3.03),
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
