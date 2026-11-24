part of 'cafe_world.dart';

extension _CafeInterior on CafeWorld {
  /// Small coplanar patches avoid an entire wall print sharing one depth key.
  /// UVs are interpolated with the mesh so signs stay intact at oblique angles.
  void _subdividePrints() {
    final prints = faces
        .where((f) => f.sign || f.surface == CafeSurface.artwork)
        .toList();
    faces.removeWhere((f) => f.sign || f.surface == CafeSurface.artwork);
    for (final face in prints) {
      if (face.points.length != 4) {
        faces.add(face);
        continue;
      }
      final p = face.points;
      final uv =
          face.textureCoordinates ??
          [
            Offset(0, (face.signRow + 1) / 5),
            Offset(1, (face.signRow + 1) / 5),
            Offset(1, face.signRow / 5),
            Offset(0, face.signRow / 5),
          ];
      final patch = face.normal.y.abs() > .8 ? .025 : .10;
      final nx = ((p[1] - p[0]).length / patch).ceil();
      final ny = ((p[3] - p[0]).length / patch).ceil();
      CafePoint at(double u, double v) => CafePoint.lerp(
        CafePoint.lerp(p[0], p[1], u),
        CafePoint.lerp(p[3], p[2], u),
        v,
      );
      Offset tex(double u, double v) => Offset.lerp(
        Offset.lerp(uv[0], uv[1], u),
        Offset.lerp(uv[3], uv[2], u),
        v,
      )!;
      for (var x = 0; x < nx; x++) {
        for (var y = 0; y < ny; y++) {
          final u = x / nx, v = y / ny, uu = (x + 1) / nx, vv = (y + 1) / ny;
          faces.add(
            CafeFace(
              [at(u, v), at(uu, v), at(uu, vv), at(u, vv)],
              face.color,
              sign: face.sign,
              surface: face.surface,
              signRow: face.signRow,
              objectId: face.objectId,
              artIndex: face.artIndex,
              target: face.target,
              unlit: face.unlit,
              layer: face.layer,
              doubleSided: face.doubleSided,
              textureCoordinates: [
                tex(u, v),
                tex(uu, v),
                tex(uu, vv),
                tex(u, vv),
              ],
            ),
          );
        }
      }
    }
  }

  // All additions stay inside existing furniture or within the wall reveal.
  // Furniture collision bounds and every approach point remain unchanged.
  void _interiorDetails() {
    _target = null;
    _wallFinishes();
    _counterDetails();
    _entranceDetails();

    // Window hardware, recessed seals and a narrow rail above the glazing.
    for (final z in [-3.35, -1.05, 1.25, 3.55]) {
      if (z == -3.35) continue;
      box(-4.185, 1.37, z + .07, .025, .14, .018, CafeWorld.brass);
      box(-4.17, 1.43, z + .105, .025, .025, .08, CafeWorld.brass);
      box(-4.31, 2.90, z, .15, .07, 2.26, CafeWorld.dark, wood: true);
      box(-4.15, .595, z, .20, .014, 2.14, const Color(0xff765d42));
    }
    // Each low stack belongs to a shelf slot, with the same parent selection
    // and support rules as the upright volumes.
    for (final z in [-2.25, .3]) {
      for (var row = 0; row < 3; row++) {
        final y = .64 + row * .55, id = 'shelf.stack.${z}_$row';
        _target = z < 0 ? CafeTarget.recommendations : CafeTarget.bookshelf;
        _object(
          id,
          '${z < 0 ? '추천 서가' : '책장'} ${row + 1}단의 포개 둔 책',
          CafeObjectKind.prop,
          CafePoint(3.85, y + .03, z + .78),
          () {
            for (var book = 0; book < 3; book++) {
              box(
                3.85,
                y + .065 + book * .035,
                z + .78,
                .24,
                .029,
                .16,
                [
                  CafeWorld.sage,
                  CafeWorld.cream,
                  const Color(0xff9c715b),
                ][(book + space.finish(id)) % 3],
              );
              box(
                3.718,
                y + .065 + book * .035,
                z + .78,
                .006,
                .016,
                .13,
                CafeWorld.cream,
              );
            }
          },
          support: Rect.fromLTWH(3.71, z - 1.08, .43, 2.16),
          footprint: Rect.fromCenter(
            center: Offset(3.85, z + .78),
            width: .26,
            height: .16,
          ),
          type: CafeItemType.stack,
        );
      }
    }
    _target = null;
    // Bench seat seams and a piped cushion, below the private bookshelf.
    for (final z in [-.29, .29, .88]) {
      box(3.86, .558, z, .59, .018, .012, const Color(0xff747b61));
    }
    box(3.81, .58, .85, .37, .07, .45, const Color(0xffb5a586));
  }

  void _wallFinishes() {
    // A recessed perimeter joint lets ceiling and plaster read separately.
    for (final x in [-4.375, 4.375]) {
      box(x, 2.905, 0, .035, .028, 9.96, const Color(0xffb5a48b));
      box(x, .173, 0, .04, .012, 9.96, const Color(0xff9a7955));
    }
    for (final z in [-4.975, 4.975]) {
      box(0, 2.905, z, 8.75, .028, .035, const Color(0xffb5a48b));
    }
    // Inset panels below the glazing: real shadow gaps and oak rails at the
    // junctions, rather than a single flat strip painted the same wall colour.
    for (final z in [-3.35, -1.05, 1.25, 3.55]) {
      if (z == -3.35) continue;
      for (final dz in [-.53, .53]) {
        box(
          -4.32,
          .36,
          z + dz,
          .05,
          .32,
          .96,
          CafeWorld.wall,
          surface: CafeSurface.plaster,
        );
        box(-4.27, .535, z + dz, .045, .022, 1.0, CafeWorld.oak, wood: true);
        box(-4.27, .185, z + dz, .045, .022, 1.0, CafeWorld.dark, wood: true);
      }
    }
    // The entrance wall has solid walnut wainscot rather than an empty plane.
    for (final x in [-2.82, 2.82]) {
      box(x, .46, 4.94, 2.98, .90, .07, CafeWorld.dark, wood: true);
      box(x, .94, 4.90, 3.05, .065, .12, CafeWorld.oak, wood: true);
      for (var i = 0; i < 5; i++) {
        final xx = x - 1.19 + i * .595;
        box(xx, .46, 4.893, .51, .68, .022, CafeWorld.dark, wood: true);
        box(xx, .80, 4.874, .51, .018, .014, CafeWorld.oak, wood: true);
        box(xx, .12, 4.874, .51, .018, .014, CafeWorld.oak, wood: true);
      }
    }
    _framedPrint(-2.83, 1.94, 4.84, .69, .91, 0, front: false);
    _framedPrint(-1.78, 1.94, 4.84, .59, .79, 2, front: false);
    _framedPrint(2.44, 1.97, 4.84, .96, 1.04, 1, front: false);
    _sconce(-3.72, 2.06, 4.83, front: false);
    _sconce(3.61, 2.06, 4.83, front: false);
    // A tile splashback gives the coffee counter its own material and scale.
    for (var i = 0; i < 16; i++) {
      for (var j = 0; j < 3; j++) {
        box(
          -.53 + i * .196,
          1.15 + j * .156,
          -4.953,
          .19,
          .15,
          .023,
          j.isEven ? const Color(0xffa7aa91) : const Color(0xffb5b79f),
        );
      }
    }
    box(.94, 1.04, -4.91, 3.18, .035, .10, CafeWorld.cream);
    // Sign frame, its real wall stand-off and two warm picture lights.
    for (final x in [-.29, 1.69]) {
      box(x, 2.235, -4.904, .035, .90, .055, CafeWorld.dark, wood: true);
    }
    for (final y in [1.795, 2.675]) {
      box(.70, y, -4.904, 2.02, .035, .055, CafeWorld.dark, wood: true);
    }
    for (final x in [-.08, 1.48]) {
      box(x, 2.78, -4.84, .035, .045, .19, CafeWorld.brass);
      box(x, 2.76, -4.72, .28, .035, .055, CafeWorld.brass);
      box(x, 2.742, -4.72, .23, .004, .04, const Color(0xffffe5b8));
    }
    _sconce(-3.60, 1.91, -4.86);
    // Switch/outlet plates have separate sockets and screws, not wall stickers.
    for (final x in [-3.42, 2.23]) {
      box(x, .39, -4.91, .14, .085, .022, const Color(0xffd5cbb6));
      for (final dx in [-.03, .03]) {
        box(x + dx, .39, -4.895, .014, .027, .005, CafeWorld.dark);
      }
    }
    box(.98, 1.20, 4.88, .085, .13, .03, CafeWorld.cream);
    box(.98, 1.20, 4.858, .041, .068, .012, const Color(0xffc4b79e));
    // Soft contact shading along wall feet; no global dark overlay.
    for (final x in [-4.25, 4.25]) {
      shadow(x, 0, .22, 4.95, strength: .15);
    }
    shadow(0, -4.88, 4.35, .22, strength: .16);
    shadow(0, 4.88, 4.35, .22, strength: .16);
  }

  void _framedPrint(
    double x,
    double y,
    double z,
    double w,
    double h,
    int row, {
    bool front = true,
  }) {
    final id = 'frame.${x}_$z';
    _object(
      id,
      '${front ? '\uC548\uCABD \uC561\uC790' : '\uCD9C\uC785\uAD6C \uC561\uC790'} \u00B7 ${['\uC78E\uACFC \uAC00\uC9C0', '\uBB3C\uACB0\uACFC \uBE5B', '\uCC45\uACFC \uC5F0\uD544'][space.art[id] ?? row]}',
      CafeObjectKind.frame,
      CafePoint(x, y, z),
      () {
        final s = front ? 1.0 : -1.0,
            style = space.frames[id] ?? 0,
            matStyle = space.mats[id] ?? 0;
        final index = space.art[id] ?? row,
            aspect = [.75, 4.0 / 3.0, .8][index];
        final rim = .022,
            outer = Rect.fromCenter(center: Offset(x, y), width: w, height: h);
        final inner = outer.deflate(rim);
        final maxW = w * (matStyle == 2 ? .82 : .72),
            maxH = h * (matStyle == 2 ? .82 : .72);
        final aw = math.min(maxW, maxH * aspect), ah = aw / aspect;
        final opening = Rect.fromCenter(
          center: Offset(x, y + .008),
          width: aw,
          height: ah,
        );
        List<Offset> corners(Rect r) => [
          r.topLeft,
          r.topRight,
          r.bottomRight,
          r.bottomLeft,
        ];
        CafePoint point(Offset p, double depth) =>
            CafePoint(p.dx, p.dy, z + s * depth);
        void strip(
          List<CafePoint> p,
          Color color, {
          bool wood = false,
          CafeGrain grain = CafeGrain.x,
          CafeSurface? surface,
        }) {
          faces.add(
            CafeFace(
              front ? p : p.reversed.toList(),
              color,
              wood: wood,
              surface: surface,
              grain: grain,
            ),
          );
        }

        final a = corners(outer), b = corners(inner), c = corners(opening);
        final woodColor = style == 1
            ? CafeWorld.oak
            : style == 2
            ? const Color(0xff483f35)
            : CafeWorld.dark;
        final mat = matStyle == 1
            ? const Color(0xfff2eee4)
            : const Color(0xffe7decc);
        for (var i = 0; i < 4; i++) {
          final j = (i + 1) % 4, grain = i.isEven ? CafeGrain.x : CafeGrain.y;
          // Mitred trapezoids meet exactly at each corner; side returns supply depth.
          strip(
            [
              point(a[i], .034),
              point(a[j], .034),
              point(b[j], .034),
              point(b[i], .034),
            ],
            woodColor,
            wood: style != 2,
            grain: grain,
          );
          strip(
            [
              point(a[i], -.008),
              point(a[j], -.008),
              point(a[j], .034),
              point(a[i], .034),
            ],
            woodColor,
            wood: style != 2,
            grain: grain,
          );
          strip(
            [
              point(b[i], .034),
              point(b[j], .034),
              point(b[j], .023),
              point(b[i], .023),
            ],
            woodColor,
            wood: style != 2,
            grain: grain,
          );
          strip([
            point(b[i], .022),
            point(b[j], .022),
            point(c[j], .022),
            point(c[i], .022),
          ], mat);
          final inset = corners(opening.deflate(.004));
          strip([
            point(c[i], .022),
            point(c[j], .022),
            point(inset[j], .012),
            point(inset[i], .012),
          ], const Color(0xffc9bca5));
        }
        final art = opening.deflate(.004), p = corners(art);
        faces.add(
          CafeFace(
            front
                ? [
                    point(p[0], .011),
                    point(p[1], .011),
                    point(p[2], .011),
                    point(p[3], .011),
                  ]
                : [
                    point(p[1], .011),
                    point(p[0], .011),
                    point(p[3], .011),
                    point(p[2], .011),
                  ],
            CafeWorld.cream,
            surface: CafeSurface.artwork,
            artIndex: index,
            textureCoordinates: const [
              Offset(0, 1),
              Offset(1, 1),
              Offset(1, 0),
              Offset(0, 0),
            ],
          ),
        );
        // Narrow rear shadow strips avoid an opaque backing that could hide the art.
        for (final xx in [x - w / 2 - .009, x + w / 2 + .009]) {
          box(
            xx,
            y - .006,
            z - s * .014,
            .016,
            h + .024,
            .002,
            const Color(0x20453626),
          );
        }
      },
    );
    final pose = space.pose(id);
    objects[id]!.defaultArtwork = row;
    objects[id]!.frameBounds = Rect.fromCenter(
      center: Offset(x + pose.x, y + pose.y),
      width: w,
      height: h,
    );
  }

  void _sconce(double x, double y, double z, {bool front = true}) {
    final id = 'lamp.wall.${x}_$z';
    _object(
      id,
      '벽 조명',
      CafeObjectKind.light,
      CafePoint(x, y, z),
      () => _sconceMesh(x, y, z, front: front),
    );
  }

  void _sconceMesh(double x, double y, double z, {bool front = true}) {
    final gain = space.light(_buildingObject!);
    wallLights.add(CafePoint(x, y + .19, z + (front ? .18 : -.18)));
    wallGains.add(gain);
    final s = front ? 1.0 : -1.0;
    box(x, y, z, .09, .22, .04, CafeWorld.brass);
    box(x, y - .03, z + s * .08, .025, .025, .16, CafeWorld.brass);
    cylinder(
      x,
      y + .04,
      z + s * .16,
      .10,
      .19,
      CafeWorld.cream,
      topRadius: .075,
      sides: 16,
    );
    cylinder(
      x,
      y + .139,
      z + s * .16,
      .073,
      .006,
      gain == 0 ? const Color(0xffa79c81) : const Color(0xffffe1ab),
      sides: 16,
      unlit: gain != 0,
    );
    // A feathered, wall-bound light pool drawn beneath solid fixtures.
    for (var band = gain == 0 ? 0 : 6; band > 0; band--) {
      final radius = band / 6;
      final points = <CafePoint>[];
      for (var i = 0; i < 24; i++) {
        final a = i * math.pi / 12;
        points.add(
          CafePoint(
            x + math.cos(a) * .38 * radius,
            y + .17 + math.sin(a) * .56 * radius,
            front ? -4.992 : 4.992,
          ),
        );
      }
      faces.add(
        CafeFace(
          points,
          const Color(0xffffdda0).withValues(alpha: .018 * gain),
          unlit: true,
          layer: 1,
          doubleSided: true,
        ),
      );
    }
  }

  void _counterDetails() {
    const metal = Color(0xffaaa79a), ink = Color(0xff333934);
    const counter = Rect.fromLTWH(-.65, -4.89, 3.2, .86);
    void item(
      String id,
      String label,
      CafePoint pivot,
      double w,
      double d,
      void Function() build, {
      Rect support = counter,
      CafeItemType type = CafeItemType.fixture,
    }) {
      _object(
        id,
        label,
        CafeObjectKind.prop,
        pivot,
        build,
        support: support,
        footprint: Rect.fromCenter(
          center: Offset(pivot.x, pivot.z),
          width: w,
          height: d,
        ),
        type: type,
      );
    }

    item(
      'counter.machine',
      '에스프레소 머신',
      const CafePoint(1.05, 1.05, -4.44),
      .85,
      .66,
      () {
        box(1.05, 1.29, -4.52, .75, .45, .40, ink);
        box(1.05, 1.26, -4.29, .67, .23, .04, metal);
        box(1.05, 1.075, -4.36, .79, .035, .43, metal);
        box(1.05, 1.26, -4.301, .64, .19, .015, ink);
        for (final x in [.84, 1.22]) {
          box(x, 1.27, -4.26, .09, .045, .09, metal);
          box(x + .065, 1.24, -4.21, .18, .018, .025, CafeWorld.dark);
        }
        for (var i = 0; i < 12; i++) {
          box(.70 + i * .061, 1.098, -4.19, .007, .003, .15, ink);
        }
        box(1.39, 1.23, -4.25, .012, .19, .012, metal);
        box(1.42, 1.145, -4.25, .07, .012, .012, metal);
        const tray = Rect.fromLTWH(.66, -4.72, .78, .43);
        for (var i = 0; i < 3; i++) {
          _cupItem(
            'counter.machine.cup.$i',
            '머신 위 ${i + 1}번째 잔',
            .87 + i * .22,
            1.515,
            -4.55,
            radius: .035,
            filled: false,
            support: tray,
          );
        }
        for (var i = 0; i < 2; i++) {
          _cupItem(
            'counter.machine.serving.$i',
            '추출 잔 ${i + 1}',
            .84 + i * .38,
            1.096,
            -4.25,
            radius: .032,
            filled: false,
            support: const Rect.fromLTWH(.66, -4.45, .78, .32),
          );
        }
      },
    );
    item(
      'counter.grinder',
      '커피 그라인더',
      const CafePoint(1.95, 1.05, -4.48),
      .26,
      .32,
      () {
        cylinder(1.95, 1.21, -4.5, .09, .32, CafeWorld.dark, sides: 20);
        cylinder(
          1.95,
          1.425,
          -4.5,
          .11,
          .15,
          const Color(0xff77694f),
          sides: 20,
          topRadius: .085,
        );
        cylinder(1.95, 1.505, -4.5, .09, .018, ink, sides: 20);
        box(1.95, 1.22, -4.36, .045, .15, .06, metal);
      },
    );
    item(
      'counter.linen',
      '접어 둔 리넨',
      const CafePoint(-.33, 1.05, -4.37),
      .31,
      .24,
      () {
        box(
          -.33,
          1.061,
          -4.37,
          .31,
          .013,
          .24,
          [
            const Color(0xffb0a58c),
            const Color(0xffaa7c62),
            CafeWorld.sage,
          ][space.finish('counter.linen')],
          surface: CafeSurface.cord,
        );
        for (var i = 0; i < 3; i++) {
          cylinder(
            -.28,
            1.075 + i * .014,
            -4.38,
            .079,
            .012,
            CafeWorld.cream,
            sides: 24,
          );
        }
      },
      type: CafeItemType.cloth,
    );
    item(
      'counter.carafe',
      '물병',
      const CafePoint(2.25, 1.05, -4.61),
      .16,
      .16,
      () {
        _turned(2.25, -4.61, [
          (1.06, .05),
          (1.13, .057),
          (1.28, .057),
          (1.32, .035),
          (1.35, .035),
        ], const Color(0xffadb9a7));
        cylinder(2.25, 1.35, -4.61, .039, .012, CafeWorld.dark, sides: 20);
      },
    );
    item(
      'counter.menus',
      '카운터의 작은 책',
      const CafePoint(2.28, 1.05, -4.21),
      .25,
      .20,
      () {
        for (var i = 0; i < 3; i++) {
          box(
            2.28,
            1.063 + i * .009,
            -4.21,
            .25,
            .007,
            .20,
            [CafeWorld.cream, const Color(0xffb18a70), CafeWorld.sage][space
                .finish('counter.menus')],
          );
        }
      },
      type: CafeItemType.stack,
    );
    for (var i = 0; i < 4; i++) {
      _cupItem(
        'counter.cup.$i',
        '카운터 ${i + 1}번째 잔',
        .0 + i * .15,
        1.054,
        -4.45,
        radius: .040,
        filled: false,
        support: counter,
      );
    }
  }

  void _cup(
    double x,
    double bottom,
    double z, {
    double radius = .052,
    bool filled = true,
  }) {
    final id = _buildingObject ?? '';
    filled = space.state(id, fallback: filled);
    final colorIndex = space.finish(id, fallback: space.mug);
    final saucer = [
      CafeWorld.cream,
      const Color(0xffb18a70),
      CafeWorld.sage,
    ][colorIndex];
    shadow(
      x,
      z,
      radius * 1.43,
      radius * 1.43,
      y: bottom + .001,
      strength: .08,
      layer: 2,
    );
    // Only the exposed annulus is opaque: a full cap under the cup can sort
    // across its foot and produce teeth in close painter-order views.
    cylinder(
      x,
      bottom + .006,
      z,
      radius * 1.40,
      .012,
      saucer,
      sides: 28,
      topFace: false,
    );
    for (var i = 0; i < 28; i++) {
      final a = i * math.pi / 14, b = (i + 1) * math.pi / 14;
      CafePoint at(double r, double t) => CafePoint(
        x + math.cos(t) * radius * r,
        bottom + .012,
        z + math.sin(t) * radius * r,
      );
      quad(at(.69, b), at(1.40, b), at(1.40, a), at(.69, a), saucer);
    }
    final ceramic = [
      CafeWorld.cream,
      const Color(0xffb18a70),
      CafeWorld.sage,
    ][colorIndex];
    _turned(x, z, [
      (bottom + .013, radius * .70),
      (bottom + .022, radius * .80),
      (bottom + .055, radius * .94),
      (bottom + .089, radius),
      (bottom + .102, radius),
    ], ceramic);
    cylinder(
      x,
      bottom + (filled ? .099 : .034),
      z,
      radius * .87,
      .004,
      filled
          ? [
              const Color(0xff684b32),
              const Color(0xff49372d),
              const Color(0xffa18c56),
            ][space.accent(id)]
          : const Color(0xffc6bba6),
      sides: 28,
    );
    for (var i = 0; i < 28; i++) {
      final a = i * math.pi / 14, b = (i + 1) * math.pi / 14;
      CafePoint edge(double t, double r) =>
          CafePoint(x + math.cos(t) * r, bottom + .102, z + math.sin(t) * r);
      quad(
        edge(a, radius),
        edge(a, radius * .87),
        edge(b, radius * .87),
        edge(b, radius),
        ceramic,
      );
    }
    for (var i = 0; i < 28; i++) {
      final a = i * math.pi / 14, b = (i + 1) * math.pi / 14;
      CafePoint inner(double t, double h, double r) => CafePoint(
        x + math.cos(t) * radius * r,
        bottom + h,
        z + math.sin(t) * radius * r,
      );
      for (var band = 0; band < 4; band++) {
        final u = band / 4, v = (band + 1) / 4;
        quad(
          inner(a, .102 - u * .067, .87 - u * .22),
          inner(a, .102 - v * .067, .87 - v * .22),
          inner(b, .102 - v * .067, .87 - v * .22),
          inner(b, .102 - u * .067, .87 - u * .22),
          ceramic,
        );
      }
    }
    // A continuous elliptical tube, with matching normals at each joint.
    const count = 24, rings = 8;
    CafePoint normal(double a, double q) =>
        CafePoint(math.cos(a) / .025, math.sin(a) / .030, 0).normalized *
            math.cos(q) +
        const CafePoint(0, 0, 1) * math.sin(q);
    CafePoint handle(double a, double q) =>
        CafePoint(
          x + radius + math.cos(a) * .025,
          bottom + .055 + math.sin(a) * .030,
          z,
        ) +
        normal(a, q) * .0048;
    for (var i = 0; i < count; i++) {
      for (var j = 0; j < rings; j++) {
        final a = i * math.pi * 2 / count, b = (i + 1) * math.pi * 2 / count;
        final u = j * math.pi * 2 / rings, v = (j + 1) * math.pi * 2 / rings;
        var p = [handle(a, u), handle(b, u), handle(b, v), handle(a, v)];
        var n = [normal(a, u), normal(b, u), normal(b, v), normal(a, v)];
        if ((p[1] - p[0]).cross(p[2] - p[0]).dot(n[0]) < 0) {
          p = p.reversed.toList();
          n = n.reversed.toList();
        }
        faces.add(CafeFace(p, ceramic, vertexNormals: n, target: _target));
      }
    }
  }

  void _pencil(double x, double y, double z) {
    final lacquer = [
      CafeWorld.dark,
      CafeWorld.sage,
      const Color(0xffa07560),
    ][space.finish(_buildingObject ?? '')];
    // Hexagonal lacquered shaft, exposed cedar and a graphite point.
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3, b = (i + 1) * math.pi / 3;
      CafePoint at(double xx, double angle, double radius) => CafePoint(
        xx,
        y + math.cos(angle) * radius,
        z + math.sin(angle) * radius,
      );
      quad(
        at(x - .11, a, .007),
        at(x + .11, a, .007),
        at(x + .11, b, .007),
        at(x - .11, b, .007),
        lacquer,
      );
      quad(
        at(x + .11, a, .007),
        at(x + .13, a, .002),
        at(x + .13, b, .002),
        at(x + .11, b, .007),
        const Color(0xffbea27c),
      );
      faces.add(
        CafeFace(
          [
            at(x + .13, a, .002),
            CafePoint(x + .139, y, z),
            at(x + .13, b, .002),
          ],
          const Color(0xff3c3c34),
          target: _target,
        ),
      );
    }
    _oval(
      CafePoint(x - .122, y, z),
      const CafePoint(.013, .0068, .0068),
      const Color(0xffcbb39a),
      segments: 12,
      rings: 6,
    );
    box(x - .085, y + .007, z, .027, .002, .012, CafeWorld.brass);
  }

  void _sharedDetails() {
    _target = CafeTarget.shared;
    _object(
      'shared.stack',
      '중앙 테이블의 책 두 권',
      CafeObjectKind.prop,
      const CafePoint(.21, .754, -1.27),
      () {
        for (var i = 0; i < 2; i++) {
          box(
            .21,
            .769 + i * .032,
            -1.27,
            .31,
            .026,
            .22,
            [
              CafeWorld.sage,
              const Color(0xffae8166),
              CafeWorld.cream,
            ][(space.finish('shared.stack') + i) % 3],
          );
          box(.21, .767 + i * .032, -1.151, .275, .016, .004, CafeWorld.cream);
        }
        box(.29, .799, -1.13, .017, .002, .08, CafeWorld.brass);
      },
      support: CafeWorld.tableBounds(CafeSeat.shared).deflate(.015),
      footprint: const Rect.fromLTWH(.055, -1.38, .31, .22),
      type: CafeItemType.stack,
    );
    _object(
      'shared.runner',
      '중앙 테이블의 리넨',
      CafeObjectKind.prop,
      const CafePoint(0, .754, -.30),
      () {
        for (var i = 0; i < 9; i++) {
          quad(
            CafePoint(-.16, .754, -.53 + i * .052),
            CafePoint(.16, .754, -.53 + i * .052),
            CafePoint(.16, .754, -.48 + i * .052),
            CafePoint(-.16, .754, -.48 + i * .052),
            [
              const Color(0xffc5b89b),
              const Color(0xffaa7c62),
              CafeWorld.sage,
            ][space.finish('shared.runner')],
            surface: CafeSurface.cord,
          );
        }
      },
      support: CafeWorld.tableBounds(CafeSeat.shared).deflate(.015),
      footprint: const Rect.fromLTWH(-.16, -.53, .32, .47),
      type: CafeItemType.cloth,
    );
  }

  void _entranceDetails() => _clearEntrance();
}
