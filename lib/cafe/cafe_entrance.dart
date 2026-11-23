part of 'cafe_world.dart';

extension _ClearCafeEntrance on CafeWorld {
  void _clearEntrance() {
    // The exterior recess is always behind room surfaces. The front wall has
    // a real opening; no full backing lies beneath these thin glass leaves.
    _target = null;
    for (var row = 0; row < 5; row++) {
      final z = 5.0 + row * .44;
      for (var col = 0; col < 4; col++) {
        final x = -1.20 + col * .60;
        quad(
          CafePoint(x, 0, z),
          CafePoint(x, 0, z + .435),
          CafePoint(x + .595, 0, z + .435),
          CafePoint(x + .595, 0, z),
          const Color(0xffd6cdbb),
          surface: CafeSurface.limestone,
          layer: -1,
        );
      }
    }
    quad(
      const CafePoint(-30, -10, 7.2),
      const CafePoint(30, -10, 7.2),
      const CafePoint(30, 30, 7.2),
      const CafePoint(-30, 30, 7.2),
      const Color(0xffccd9d4),
      unlit: true,
      layer: -2,
    );
    for (final x in [-1.22, 1.22]) {
      quad(
        CafePoint(x, 0, 4.98),
        CafePoint(x, 0, 7.2),
        CafePoint(x, 3.1, 7.2),
        CafePoint(x, 3.1, 4.98),
        const Color(0xffe7dfcf),
        surface: CafeSurface.plaster,
        unlit: true,
        layer: -1,
      );
    }
    // A low planter gives the clear glazing depth without a bright painted
    // curtain. These are background meshes, not another navigable room.
    const x = -.70, z = 6.50;
    quad(
      const CafePoint(x - .24, .10, z - .24),
      const CafePoint(x + .24, .10, z - .24),
      const CafePoint(x + .24, .48, z - .24),
      const CafePoint(x - .24, .48, z - .24),
      const Color(0xffa28b72),
      unlit: true,
      layer: -1,
    );
    for (var i = 0; i < 9; i++) {
      final a = i * 2.4;
      _oval(
        CafePoint(x + math.cos(a) * .17, .55 + i * .055, z + math.sin(a) * .12),
        const CafePoint(.10, .16, .035),
        i.isEven ? const Color(0xff7d8f68) : const Color(0xffa2ae87),
        segments: 16,
        rings: 8,
        layer: -1,
        yaw: a,
      );
    }

    _target = CafeTarget.exit;
    for (final x in [-1.17, 1.17]) {
      box(x, 1.36, 4.94, .065, 2.72, .11, CafeWorld.dark, wood: true);
    }
    box(0, 2.72, 4.94, 2.405, .065, .11, CafeWorld.dark, wood: true);
    box(0, .025, 4.835, 2.34, .04, .12, CafeWorld.brass);
    box(0, .1125, 4.93, 2.26, .135, .055, CafeWorld.oak, wood: true);
    box(0, 1.43, 4.93, .026, 2.50, .045, CafeWorld.dark, wood: true);
    for (final side in [-1.0, 1.0]) {
      final left = side < 0 ? -1.125 : .014;
      final right = side < 0 ? -.014 : 1.125;
      faces.add(
        CafeFace(
          [
            CafePoint(right, .18, 4.91),
            CafePoint(left, .18, 4.91),
            CafePoint(left, 2.675, 4.91),
            CafePoint(right, 2.675, 4.91),
          ],
          const Color(0x075b8177),
          surface: CafeSurface.glass,
          unlit: true,
          doubleSided: true,
          target: CafeTarget.exit,
        ),
      );
      _rod(
        CafePoint(side * .12, 1.07, 4.83),
        CafePoint(side * .12, 1.40, 4.83),
        .012,
        CafeWorld.brass,
      );
    }
    _target = null;
  }
}
