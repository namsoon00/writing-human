part of 'cafe_world.dart';

extension _FrontYardGeometry on CafeWorld {
  void _yardRibbon(
    List<CafePoint> points,
    double width,
    Color color,
    String part, {
    bool closed = false,
    double height = .014,
    CafeSurface surface = CafeSurface.plain,
  }) {
    final n = points.length - (closed ? 1 : 0);
    CafePoint side(int i) {
      final a = points[closed ? (i - 1) % n : math.max(0, i - 1)];
      final b = points[closed ? (i + 1) % n : math.min(n - 1, i + 1)];
      final d = (b - a).normalized;
      return CafePoint(d.z, 0, -d.x) * (width / 2);
    }

    CafePoint at(int i, double sign) {
      final p = points[i] + side(i) * sign;
      return CafePoint(p.x, height, p.z);
    }

    for (var i = 0; i + 1 < points.length; i++) {
      final p = [at(i, -1), at(i + 1, -1), at(i + 1, 1), at(i, 1)];
      faces.add(
        CafeFace(
          p,
          color,
          surface: surface,
          layer: 1,
          part: part,
          textureCoordinates: p
              .map((q) => Offset(q.x / 1.8, q.z / 1.8))
              .toList(),
        ),
      );
      if (part == 'yard.stone' && i.isEven) {
        final a = at(i, -1),
            b = at(i, 1),
            d = (points[i + 1] - points[i]).normalized * .008;
        faces.add(
          CafeFace(
            [a, a + d, b + d, b],
            const Color(0xffc1b59d),
            layer: 1,
            part: 'yard.stone.joint',
          ),
        );
      }
    }
  }

  void _yardTree(double x, double z, double h, int seed) {
    final p = CafePoint(x, 0, z);
    obstacles.add(
      Rect.fromCenter(center: Offset(x, z), width: .42, height: .42),
    );
    _rod(
      p,
      p + CafePoint(.04, h * .58, .01),
      .065,
      const Color(0xff7c6852),
      sides: 10,
      surface: CafeSurface.walnut,
    );
    for (var i = 0; i < 5; i++) {
      final a = seed + i * 2.4;
      _rod(
        p + CafePoint(0, h * .38, 0),
        p +
            CafePoint(
              math.cos(a) * .45,
              h * (.55 + i * .04),
              math.sin(a) * .42,
            ),
        .018,
        const Color(0xff7c6852),
        sides: 6,
      );
    }
    plants.add(CafePlant(p, h * .75, h, CafeSurface.tree, flip: seed.isEven));
    shadow(x + .3, z - .1, h * .38, h * .3, strength: .10, y: .018);
  }

  void _yardSeat(double x, double z, {CafeTarget? target, double width = 1.8}) {
    _target = target;
    for (var i = 0; i < 4; i++) {
      _roundedSlab(
        x,
        z + (i - 1.5) * .13,
        width,
        .12,
        top: .46,
        thickness: .07,
        radius: .025,
      );
    }
    for (final dx in [-width * .36, width * .36]) {
      for (final dz in [-.19, .19]) {
        _rod(
          CafePoint(x + dx, .025, z + dz),
          CafePoint(x + dx, .43, z + dz),
          .04,
          CafeWorld.dark,
          surface: CafeSurface.walnut,
          sides: 8,
        );
      }
    }
    obstacles.add(
      Rect.fromCenter(center: Offset(x, z), width: width, height: .58),
    );
    _target = null;
  }

  void _yardBoundary() {
    void panel(double x1, double z1, double x2, double z2) {
      final a = CafePoint(x1, 0, z1), b = CafePoint(x2, 0, z2);
      faces.add(
        CafeFace(
          [
            a,
            b,
            b + const CafePoint(0, 1.15, 0),
            a + const CafePoint(0, 1.15, 0),
          ],
          CafeWorld.wall,
          doubleSided: true,
          surface: CafeSurface.plaster,
          layer: 0,
        ),
      );
      _rod(
        a + const CafePoint(0, 1.17, 0),
        b + const CafePoint(0, 1.17, 0),
        .055,
        const Color(0xffd9cdb5),
        surface: CafeSurface.limestone,
        sides: 6,
      );
    }

    panel(-18.2, -17.2, -7.25, -17.2);
    panel(-4.75, -17.2, 6.2, -17.2);
    panel(-18.2, -17.2, -18.2, 3.165);
    panel(6.2, -17.2, 6.2, 3.165);
    panel(-18.2, 3.165, -4.65, 3.165);
    panel(4.65, 3.165, 6.2, 3.165);
    for (final x in [-7.25, -4.75]) {
      box(
        x,
        .68,
        -17.15,
        .30,
        1.36,
        .32,
        CafeWorld.wall,
        surface: CafeSurface.plaster,
      );
      box(
        x,
        1.37,
        -17.15,
        .38,
        .08,
        .40,
        const Color(0xffd8cbb2),
        surface: CafeSurface.limestone,
      );
      // Open gate leaves stay inside the garden; there is no exterior road.
      for (var j = 0; j < 6; j++) {
        box(
          x,
          .60,
          -17.05 + j * .16,
          .065,
          1.14,
          .125,
          CafeWorld.oak,
          wood: true,
        );
      }
    }
  }

  void _yardCafeShell() {
    // Same building, with an exterior roof and side walls beyond the glazing.
    for (final x in [-4.68, 4.68]) {
      faces.add(
        CafeFace(
          [
            CafePoint(x, 0, 3.18),
            CafePoint(x, 0, 11.95),
            CafePoint(x, 3.02, 11.95),
            CafePoint(x, 3.02, 3.18),
          ],
          CafeWorld.wall,
          doubleSided: true,
          surface: CafeSurface.plaster,
          layer: 0,
        ),
      );
    }
    faces.add(
      CafeFace(
        const [
          CafePoint(-4.68, 0, 11.95),
          CafePoint(4.68, 0, 11.95),
          CafePoint(4.68, 3.02, 11.95),
          CafePoint(-4.68, 3.02, 11.95),
        ],
        CafeWorld.wall,
        doubleSided: true,
        surface: CafeSurface.plaster,
        layer: 0,
      ),
    );
    for (final s in [-1.0, 1.0]) {
      faces.add(
        CafeFace(
          [
            CafePoint(0, 4.05, 2.95),
            CafePoint(s * 5.0, 3.0, 2.95),
            CafePoint(s * 5.0, 3.0, 12.2),
            CafePoint(0, 4.05, 12.2),
          ],
          const Color(0xff716657),
          doubleSided: true,
          layer: 1,
          part: 'yard.roof',
        ),
      );
      for (var i = 1; i < 12; i++) {
        final x = s * i * .42, y = 4.05 - x.abs() * .21 + .012;
        _rod(
          CafePoint(x, y, 2.94),
          CafePoint(x, y, 12.2),
          .012,
          const Color(0xff8e806c),
          sides: 5,
        );
      }
    }
    faces.add(
      CafeFace(
        const [
          CafePoint(-4.68, 3.0, 3.17),
          CafePoint(4.68, 3.0, 3.17),
          CafePoint(0, 4.02, 3.17),
        ],
        CafeWorld.wall,
        doubleSided: true,
        surface: CafeSurface.plaster,
        layer: 1,
      ),
    );
    box(0, 2.85, 3.10, 1.8, .42, .08, CafeWorld.dark, wood: true);
    faces.add(
      CafeFace(
        const [
          CafePoint(.83, 2.70, 3.04),
          CafePoint(-.83, 2.70, 3.04),
          CafePoint(-.83, 3.01, 3.04),
          CafePoint(.83, 3.01, 3.04),
        ],
        CafeWorld.cream,
        sign: true,
        unlit: true,
        doubleSided: true,
        layer: 2,
      ),
    );
  }

  void _yardLantern(double x, double z) {
    box(x, .18, z, .20, .36, .20, CafeWorld.dark, wood: true);
    faces.add(
      CafeFace(
        [
          CafePoint(x - .07, .17, z - .107),
          CafePoint(x - .07, .33, z - .107),
          CafePoint(x + .07, .33, z - .107),
          CafePoint(x + .07, .17, z - .107),
        ],
        const Color(0xffffd698),
        unlit: true,
        doubleSided: true,
      ),
    );
    box(x, .39, z, .28, .045, .28, const Color(0xff71604c));
    pendantLights.add(CafePoint(x, .28, z));
    pendantGains.add(space.home.mood == 0 ? .18 : .65);
    obstacles.add(
      Rect.fromCenter(center: Offset(x, z), width: .22, height: .22),
    );
  }

  void _buildFrontYard() {
    final random = math.Random(2534);
    for (var x = -18.2; x < 6.2; x += 1.4) {
      for (var z = -17.2; z < -2.95; z += 1.4) {
        faces.add(
          CafeFace(
            [
              CafePoint(x, -.003, z),
              CafePoint(x, -.003, z + 1.4),
              CafePoint(x + 1.4, -.003, z + 1.4),
              CafePoint(x + 1.4, -.003, z),
            ],
            Color.lerp(
              const Color(0xff8f9b75),
              const Color(0xffb1b18b),
              random.nextDouble() * .20,
            )!,
            surface: CafeSurface.plain,
            layer: 0,
            part: 'yard.lawn',
          ),
        );
      }
    }
    _yardRibbon(
      CafeYard.trail,
      1.30,
      const Color(0xffb9825e),
      'yard.earth',
      surface: CafeSurface.plaster,
      closed: true,
    );
    _yardRibbon(
      CafeYard.stone,
      1.35,
      const Color(0xffeee4cf),
      'yard.stone',
      height: .023,
      surface: CafeSurface.limestone,
    );
    _yardBoundary();
    _yardCafeShell();
    for (final p in [
      (-7.2, -15.8),
      (3.3, -6.5),
      (-13.5, -5.5),
      (-14.1, -13.1),
    ]) {
      _yardLantern(p.$1, p.$2);
    }
    for (final tree in [
      (2.4, -5.5, 4.8),
      (-1.4, -11.7, 3.5),
      (-12.8, -10.4, 3.7),
      (-16.9, -14.9, 3.3),
      (-16.8, -2.1, 3.5),
    ]) {
      _yardTree(tree.$1, tree.$2, tree.$3, (tree.$1 * 17).round());
    }
    // Sparse painted flower banks, never across the two walking routes.
    for (var i = 0; i < 28; i++) {
      final p = CafePoint(
        -17.3 + random.nextDouble() * 22.0,
        0,
        -16.3 + random.nextDouble() * 12.0,
      );
      if (CafeYard.distanceToTrail(p) < 1.05 ||
          (p.x > 1.1 && p.z > -10.6 && p.z < -6.8) ||
          (p.x > -13 && p.x < -9.8 && p.z > -10 && p.z < -7.2)) {
        continue;
      }
      plants.add(
        CafePlant(
          p,
          .7 + random.nextDouble() * .20,
          .46,
          CafeSurface.flowers,
          flip: i.isEven,
        ),
      );
    }
    // Shade platform: a rug and one central cushion, outside the through path.
    for (var i = 0; i < 14; i++) {
      _roundedSlab(
        2.8,
        -10.25 + i * .25,
        3.25,
        .235,
        top: .018,
        thickness: .018,
        radius: .03,
      );
    }
    for (final x in [1.3, 4.1]) {
      for (final z in [-10.25, -7.0]) {
        _rod(
          CafePoint(x, 0, z),
          CafePoint(x, 2.35, z),
          .065,
          CafeWorld.dark,
          sides: 8,
          surface: CafeSurface.walnut,
        );
        obstacles.add(
          Rect.fromCenter(center: Offset(x, z), width: .16, height: .16),
        );
      }
      _rod(
        CafePoint(x, 2.35, -10.4),
        CafePoint(x, 2.35, -6.85),
        .065,
        CafeWorld.dark,
        sides: 8,
        surface: CafeSurface.walnut,
      );
    }
    for (var i = 0; i < 11; i++) {
      _rod(
        CafePoint(1.18, 2.40, -10.25 + i * .32),
        CafePoint(4.42, 2.40, -10.25 + i * .32),
        .035,
        CafeWorld.oak,
        sides: 6,
        surface: CafeSurface.oak,
      );
    }
    _target = CafeTarget.meditation;
    cylinder(2.8, .033, -8.5, .70, .026, const Color(0xffb9ad8f), sides: 40);
    _turned(
      2.8,
      -8.5,
      [(.046, .29), (.08, .32), (.13, .27), (.145, .18)],
      const Color(0xffd4c4a5),
      sides: 32,
    );
    cylinder(2.8, .14, -8.5, .18, .01, const Color(0xffd4c4a5), sides: 32);
    _target = null;
    // Shoe bench and closed-tap rinse station sit off the earthen loop.
    _yardSeat(-3.0, -13.6, target: CafeTarget.barefoot, width: 1.55);
    _target = CafeTarget.barefoot;
    for (final x in [-3.25, -3.05]) {
      _oval(
        CafePoint(x, .10, -13.58),
        const CafePoint(.075, .045, .16),
        const Color(0xffa7815d),
        segments: 10,
        rings: 5,
      );
    }
    box(
      -2.55,
      .49,
      -13.6,
      .28,
      .035,
      .38,
      CafeWorld.cream,
      surface: CafeSurface.cord,
    );
    _target = null;
    _turned(
      -1.8,
      -13.6,
      [(0, .22), (.2, .28), (.32, .31), (.36, .28)],
      const Color(0xffb8b09b),
      sides: 20,
    );
    cylinder(-1.8, .36, -13.6, .23, .01, const Color(0xff746e60), sides: 24);
    _rod(
      const CafePoint(-1.8, .36, -13.45),
      const CafePoint(-1.8, .90, -13.45),
      .017,
      CafeWorld.brass,
      sides: 8,
    );
    _rod(
      const CafePoint(-1.8, .90, -13.45),
      const CafePoint(-1.8, .90, -13.65),
      .017,
      CafeWorld.brass,
      sides: 8,
    );
    obstacles.add(const Rect.fromLTWH(-2.15, -13.95, .7, .7));
    _target = CafeTarget.trail;
    _rod(
      const CafePoint(-5.65, 0, -14.5),
      const CafePoint(-5.65, .65, -14.5),
      .04,
      CafeWorld.dark,
      sides: 8,
    );
    box(-5.65, .57, -14.5, .32, .22, .055, CafeWorld.oak, wood: true);
    _target = null;
    // A second shaded rest stop on the long side of the loop.
    _yardSeat(-11.5, -8.55, target: CafeTarget.trailRest, width: 1.9);
    _roundedSlab(-10.2, -8.4, .65, .65, top: .65, thickness: .04, radius: .12);
    _rod(
      const CafePoint(-10.2, 0, -8.4),
      const CafePoint(-10.2, .61, -8.4),
      .05,
      CafeWorld.dark,
      sides: 10,
    );
    obstacles.add(const Rect.fromLTWH(-10.55, -8.75, .7, .7));
  }
}
