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
    _tableDetails();
    // Window hardware, recessed seals and a narrow rail above the glazing.
    for (final z in [-3.35, -1.05, 1.25, 3.55]) {
      box(-4.185, 1.37, z + .07, .025, .14, .018, CafeWorld.brass);
      box(-4.17, 1.43, z + .105, .025, .025, .08, CafeWorld.brass);
      box(-4.31, 2.90, z, .15, .07, 2.26, CafeWorld.dark, wood: true);
      box(-4.15, .595, z, .20, .014, 2.14, const Color(0xff765d42));
    }
    // Real shelf backs and a few horizontal volumes break identical rows.
    for (final z in [-2.25, .3]) {
      for (var row = 0; row < 3; row++) {
        final y = .64 + row * .55;
        for (var book = 0; book < 3; book++) {
          box(
            3.85,
            y + .065 + book * .035,
            z + .65,
            .24,
            .029,
            .29,
            [CafeWorld.sage, CafeWorld.cream, const Color(0xff9c715b)][book],
          );
          box(
            3.718,
            y + .065 + book * .035,
            z + .65,
            .006,
            .016,
            .25,
            CafeWorld.cream,
          );
        }
      }
    }
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
    for (final x in [-2.65, 2.65]) {
      box(x, .46, 4.94, 3.35, .90, .07, CafeWorld.dark, wood: true);
      box(x, .94, 4.90, 3.38, .065, .12, CafeWorld.oak, wood: true);
      for (var i = 0; i < 5; i++) {
        final xx = x - 1.34 + i * .67;
        box(xx, .46, 4.893, .59, .68, .022, CafeWorld.dark, wood: true);
        box(xx, .80, 4.874, .59, .018, .014, CafeWorld.oak, wood: true);
        box(xx, .12, 4.874, .59, .018, .014, CafeWorld.oak, wood: true);
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
    final s = front ? 1.0 : -1.0;
    for (final xx in [x - w / 2 - .014, x + w / 2 + .014]) {
      box(xx, y, z, .028, h + .055, .045, CafeWorld.dark, wood: true);
    }
    for (final yy in [y - h / 2 - .014, y + h / 2 + .014]) {
      box(x, yy, z, w, .028, .045, CafeWorld.dark, wood: true);
    }
    // The mat is a true border with an opening; no opaque backing overlaps art.
    for (final xx in [x - w * .45, x + w * .45]) {
      box(xx, y, z + s * .013, w * .10, h, .012, CafeWorld.cream);
    }
    for (final yy in [y - h * .45, y + h * .45]) {
      box(x, yy, z + s * .013, w * .80, h * .10, .012, CafeWorld.cream);
    }
    final l = x - w * .40, r = x + w * .40;
    final b = y - h * .40, t = y + h * .40;
    faces.add(
      CafeFace(
        [
          CafePoint(front ? l : r, b, z + s * .021),
          CafePoint(front ? r : l, b, z + s * .021),
          CafePoint(front ? r : l, t, z + s * .021),
          CafePoint(front ? l : r, t, z + s * .021),
        ],
        CafeWorld.cream,
        surface: CafeSurface.artwork,
        textureCoordinates: [
          Offset(0, (row + 1) / 3),
          Offset(1, (row + 1) / 3),
          Offset(1, row / 3),
          Offset(0, row / 3),
        ],
      ),
    );
  }

  void _sconce(double x, double y, double z, {bool front = true}) {
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
      const Color(0xffffe1ab),
      sides: 16,
      unlit: true,
    );
    // A feathered, wall-bound light pool drawn beneath solid fixtures.
    for (var band = 6; band > 0; band--) {
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
          const Color(0xffffdda0).withValues(alpha: .018),
          unlit: true,
          layer: 1,
          doubleSided: true,
        ),
      );
    }
  }

  void _counterDetails() {
    const metal = Color(0xffaaa79a), ink = Color(0xff333934);
    // Espresso machine: drip tray, two group heads, gauges, steam wand.
    box(1.05, 1.075, -4.36, .79, .035, .43, metal);
    box(1.05, 1.26, -4.301, .64, .19, .015, ink);
    for (final x in [.84, 1.22]) {
      box(x, 1.27, -4.26, .09, .045, .09, metal);
      box(x + .065, 1.24, -4.21, .18, .018, .025, CafeWorld.dark);
      _cup(x, 1.096, -4.25, radius: .032, filled: false);
    }
    for (var i = 0; i < 12; i++) {
      box(.70 + i * .061, 1.098, -4.19, .007, .003, .15, ink);
    }
    box(1.39, 1.23, -4.25, .012, .19, .012, metal);
    box(1.42, 1.145, -4.25, .07, .012, .012, metal);
    for (final x in [.87, 1.09, 1.31]) {
      _cup(x, 1.515, -4.55, radius: .035, filled: false);
    }
    // Coffee grinder has a separate bean hopper and dose chute.
    cylinder(
      1.95,
      1.425,
      -4.5,
      .11,
      .15,
      const Color(0xff77694f),
      sides: 16,
      topRadius: .085,
    );
    cylinder(1.95, 1.505, -4.5, .09, .018, ink, sides: 16);
    box(1.95, 1.22, -4.36, .045, .15, .06, metal);
    // Folded linen, saucers, water carafe and a short stack of menus.
    box(-.33, 1.061, -4.37, .31, .013, .24, const Color(0xffb0a58c));
    for (var i = 0; i < 3; i++) {
      cylinder(
        -.28,
        1.075 + i * .014,
        -4.38,
        .079,
        .012,
        CafeWorld.cream,
        sides: 18,
      );
    }
    cylinder(
      2.25,
      1.20,
      -4.47,
      .057,
      .28,
      const Color(0xffadb9a7),
      sides: 16,
      topRadius: .04,
    );
    cylinder(2.25, 1.344, -4.47, .039, .012, CafeWorld.dark, sides: 12);
    for (var i = 0; i < 3; i++) {
      box(2.28, 1.063 + i * .009, -4.21, .25, .007, .20, CafeWorld.cream);
    }
  }

  void _cup(
    double x,
    double bottom,
    double z, {
    double radius = .052,
    bool filled = true,
  }) {
    cylinder(
      x,
      bottom + .006,
      z,
      radius * 1.40,
      .012,
      CafeWorld.cream,
      sides: 20,
    );
    cylinder(
      x,
      bottom + .054,
      z,
      radius * .78,
      .086,
      CafeWorld.cream,
      topRadius: radius,
      topFace: false,
      sides: 20,
    );
    cylinder(
      x,
      bottom + .099,
      z,
      radius * .87,
      .004,
      filled ? const Color(0xff684b32) : const Color(0xffc6bba6),
      sides: 20,
    );
    for (var i = 0; i < 20; i++) {
      final a = i * math.pi / 10, b = (i + 1) * math.pi / 10;
      CafePoint edge(double t, double r) =>
          CafePoint(x + math.cos(t) * r, bottom + .102, z + math.sin(t) * r);
      quad(
        edge(a, radius),
        edge(a, radius * .87),
        edge(b, radius * .87),
        edge(b, radius),
        CafeWorld.cream,
      );
    }
    // A vertical elliptical handle, aligned away from the writing page.
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6, b = (i + 1) * math.pi / 6;
      quad(
        CafePoint(
          x + radius + math.cos(a) * .026,
          bottom + .055 + math.sin(a) * .032,
          z,
        ),
        CafePoint(
          x + radius + math.cos(b) * .026,
          bottom + .055 + math.sin(b) * .032,
          z,
        ),
        CafePoint(
          x + radius + math.cos(b) * .018,
          bottom + .055 + math.sin(b) * .023,
          z,
        ),
        CafePoint(
          x + radius + math.cos(a) * .018,
          bottom + .055 + math.sin(a) * .023,
          z,
        ),
        CafeWorld.cream,
      );
    }
  }

  void _pencil(double x, double y, double z) {
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
        CafeWorld.dark,
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
    box(x - .085, y + .007, z, .027, .002, .012, CafeWorld.brass);
  }

  void _tableDetails() {
    for (final seat in [
      CafeSeat.windowRear,
      CafeSeat.windowMiddle,
      CafeSeat.window,
    ]) {
      final z = CafeWorld.desk(seat).z;
      _target = CafeTarget.forSeat(seat);
      cylinder(
        -3.80,
        .760,
        z - .40,
        .10,
        .014,
        const Color(0xffa18c65),
        sides: 18,
      );

      box(-3.46, .765, z + .33, .015, .012, .22, CafeWorld.dark);
      box(-3.46, .772, z + .25, .019, .008, .035, CafeWorld.brass);
    }
    _target = CafeTarget.shared;
    cylinder(-.2, .759, .18, .093, .01, const Color(0xff9b805a), sides: 20);
    cylinder(-.2, .873, .18, .049, .004, const Color(0xff796345), sides: 18);
    // Two cloth books and bookmarks at the unused end of the communal table.
    for (var i = 0; i < 2; i++) {
      box(
        .21,
        .769 + i * .032,
        -1.27,
        .31,
        .026,
        .22,
        i.isEven ? CafeWorld.sage : const Color(0xffae8166),
      );
      box(.21, .767 + i * .032, -1.151, .275, .016, .004, CafeWorld.cream);
    }
    box(.29, .799, -1.13, .017, .002, .08, CafeWorld.brass);
    // Thin warm linen runner beneath the vase, with no collision or UI layer.
    for (var i = 0; i < 9; i++) {
      quad(
        CafePoint(-.16, .754, -.53 + i * .052),
        CafePoint(.16, .754, -.53 + i * .052),
        CafePoint(.16, .754, -.48 + i * .052),
        CafePoint(-.16, .754, -.48 + i * .052),
        const Color(0xffc5b89b),
        surface: CafeSurface.cord,
      );
    }
    // The small vase now contains restrained branches rather than an empty cone.
    for (var i = 0; i < 3; i++) {
      final x = (i - 1) * .025;
      box(x, 1.02 + i * .023, -.30, .006, .23 + i * .045, .006, CafeWorld.sage);
      for (var j = 0; j < 3; j++) {
        final y = .99 + j * .055 + i * .025;
        quad(
          CafePoint(x, y, -.30),
          CafePoint(x + .06, y + .015, -.29),
          CafePoint(x + .08, y + .045, -.30),
          CafePoint(x + .018, y + .035, -.31),
          const Color(0xff7f896b),
        );
      }
    }
    _target = null;
  }

  void _entranceDetails() {
    _target = CafeTarget.exit;
    for (final x in [-.80, .80]) {
      box(x, 1.32, 4.87, .08, 2.65, .11, CafeWorld.dark, wood: true);
    }
    box(0, 2.67, 4.87, 1.68, .08, .11, CafeWorld.dark, wood: true);
    box(0, .015, 4.80, 1.52, .025, .19, CafeWorld.brass);
    box(.52, 1.13, 4.785, .06, .23, .015, CafeWorld.brass);
    box(-.48, 2.54, 4.80, .23, .06, .06, const Color(0xff86755a));
    // An inset plaque uses the existing brand font atlas rather than a UI card.
    faces.add(
      CafeFace(
        const [
          CafePoint(.48, 1.67, 4.84),
          CafePoint(-.48, 1.67, 4.84),
          CafePoint(-.48, 2.09, 4.84),
          CafePoint(.48, 2.09, 4.84),
        ],
        CafeWorld.cream,
        sign: true,
        unlit: true,
        target: _target,
      ),
    );
    _target = null;
  }
}
