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
          part: 'yard.wall.plaster',
        ),
      );
      final delta = b - a, length = delta.length, axis = delta.normalized;
      final horizontal = axis.x.abs() > .5;
      void stone(CafePoint p, double w, double h, double depth, Color color) {
        box(
          p.x,
          p.y,
          p.z,
          horizontal ? w : depth,
          h,
          horizontal ? depth : w,
          color,
          surface: CafeSurface.limestone,
          layer: 1,
        );
      }

      // Two staggered courses, individual coping stones, and shallow piers
      // give the enclosure thickness without putting dense brickwork on it.
      for (var row = 0; row < 2; row++) {
        var start = 0.0;
        while (start < length - .01) {
          final w = math.min(
            row == 1 && start == 0 ? .56 : 1.12,
            length - start,
          );
          stone(
            a + axis * (start + w / 2) + CafePoint(0, .075 + row * .135, 0),
            math.max(.02, w - .018),
            .126,
            .23,
            Color.lerp(
              const Color(0xffc4b69d),
              const Color(0xffdbcfb7),
              ((start * 3 + row).floor() % 4) / 4,
            )!,
          );
          start += w;
        }
      }
      final count = (length / .95).ceil();
      for (var i = 0; i < count; i++) {
        final w = length / count, p = a + axis * ((i + .5) * w);
        stone(
          p + const CafePoint(0, 1.16, 0),
          w - .012,
          .09,
          .32,
          const Color(0xffd5c6aa),
        );
        stone(
          p + const CafePoint(0, 1.21, 0),
          w - .020,
          .035,
          .26,
          const Color(0xffe1d5bf),
        );
      }
      for (var d = 0.0; d < length; d += 3.0) {
        final p = a + axis * d;
        box(
          p.x,
          .63,
          p.z,
          .26,
          1.26,
          .26,
          CafeWorld.wall,
          surface: CafeSurface.plaster,
          layer: 1,
        );
        stone(
          p + const CafePoint(0, 1.28, 0),
          .34,
          .09,
          .34,
          const Color(0xffd5c6aa),
        );
      }
    }

    final left = CafeYard.bounds.left - .2,
        right = CafeYard.bounds.right + .2,
        top = CafeYard.bounds.top - .2;
    panel(left, top, -7.25, top);
    panel(-4.75, top, right, top);
    panel(left, top, left, 3.165);
    panel(right, top, right, 3.165);
    panel(left, 3.165, -4.65, 3.165);
    panel(4.65, 3.165, right, 3.165);
    for (final x in [-7.25, -4.75]) {
      box(
        x,
        .68,
        top + .05,
        .30,
        1.36,
        .32,
        CafeWorld.wall,
        surface: CafeSurface.plaster,
      );
      box(
        x,
        1.37,
        top + .05,
        .38,
        .08,
        .40,
        const Color(0xffd8cbb2),
        surface: CafeSurface.limestone,
        layer: 1,
      );
      // Open gate leaves stay inside the garden; there is no exterior road.
      for (var j = 0; j < 6; j++) {
        box(
          x,
          .60,
          top + .15 + j * .16,
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
    for (final x in [-5.08, 5.08]) {
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
          CafePoint(-5.08, 0, 11.95),
          CafePoint(5.08, 0, 11.95),
          CafePoint(5.08, 3.02, 11.95),
          CafePoint(-5.08, 3.02, 11.95),
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
            CafePoint(s * 5.3, 3.0, 2.95),
            CafePoint(s * 5.3, 3.0, 12.2),
            CafePoint(0, 4.05, 12.2),
          ],
          const Color(0xff716657),
          doubleSided: true,
          layer: 1,
          part: 'yard.roof',
        ),
      );
      for (var i = 1; i < 12; i++) {
        final x = s * i * .42, y = 4.05 - x.abs() * .198 + .012;
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
          CafePoint(-5.08, 3.0, 3.17),
          CafePoint(5.08, 3.0, 3.17),
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
    for (
      var x = CafeYard.bounds.left - .2;
      x < CafeYard.bounds.right + .2;
      x += 1.4
    ) {
      for (var z = CafeYard.bounds.top - .2; z < -2.95; z += 1.4) {
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
            surface: CafeSurface.lawn,
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
      (-20.5, -18.6, 3.3),
      (-21.2, -10.7, 3.4),
      (.5, -20.0, 2.9),
    ]) {
      _yardTree(tree.$1, tree.$2, tree.$3, (tree.$1 * 17).round());
    }
    // Planted borders and curved islands leave both routes visibly open.
    final banks = <CafePoint>[
      for (var z = -19.8; z < 2.4; z += 1.05) CafePoint(-21.25, 0, z),
      for (var x = -20.8; x < 6.7; x += 1.15) CafePoint(x, 0, -20.1),
      for (var z = -18.8; z < 1.5; z += 1.3) CafePoint(7.25, 0, z),
      for (var x = -20.2; x < -5.8; x += 1.15) CafePoint(x, 0, 2.05),
      for (final center in [
        const CafePoint(-8.5, 0, -5.8),
        const CafePoint(-12.8, 0, -10.4),
        const CafePoint(2.4, 0, -5.5),
        const CafePoint(-1.4, 0, -11.7),
      ])
        for (var i = 0; i < 10; i++)
          center +
              CafePoint(
                math.cos(i * 2.4) * (.7 + (i % 3) * .22),
                0,
                math.sin(i * 2.4) * (.6 + (i % 3) * .16),
              ),
    ];
    for (var i = 2; i + 1 < CafeYard.trail.length; i += 5) {
      final p = CafeYard.trail[i],
          d = (CafeYard.trail[i + 1] - CafeYard.trail[i - 1]).normalized;
      banks.add(p + CafePoint(d.z, 0, -d.x) * 1.25);
    }
    for (var i = 0; i < banks.length; i++) {
      final p = banks[i];
      if (CafeYard.distanceToTrail(p) < 1.0 ||
          CafeYard.distanceToStone(p) < 1.10 ||
          (p.x > 1.1 && p.z > -10.6 && p.z < -6.8) ||
          (p.x > -13 && p.x < -9.8 && p.z > -10 && p.z < -7.2)) {
        continue;
      }
      plants.add(
        CafePlant(
          p,
          .95 + random.nextDouble() * .35,
          .36 + random.nextDouble() * .20,
          CafeSurface.flowers,
          flip: i.isEven,
        ),
      );
      if (i % 9 == 0) {
        _oval(
          p + const CafePoint(.22, .09, .1),
          const CafePoint(.30, .15, .22),
          const Color(0xffc5bda6),
          segments: 8,
          rings: 4,
          surface: CafeSurface.limestone,
        );
      }
    }
    for (final p in [
      const CafePoint(-6.7, 0, -1.1),
      const CafePoint(-11.8, 0, -.5),
    ]) {
      _yardTree(p.x, p.z, 3.4, 135);
      plants.add(
        CafePlant(p + const CafePoint(0, .6, 0), 3.1, 2.9, CafeSurface.blossom),
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
