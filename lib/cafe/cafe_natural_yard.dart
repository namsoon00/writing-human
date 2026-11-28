part of 'cafe_world.dart';

/// Static, seeded detail shared by the window and the visited garden.
extension _NaturalYard on CafeWorld {
  void _yardFieldstone(
    CafePoint center,
    CafePoint axis,
    double width,
    double height,
    double depth,
    math.Random random, {
    bool cap = false,
  }) {
    final across = CafePoint(-axis.z, 0, axis.x);
    // The convex outline and varied widths break the rectangular brick rhythm.
    final corners = <Offset>[
      Offset(-.50, -.25 - random.nextDouble() * .07),
      Offset(-.30, -.50),
      Offset(.28 + random.nextDouble() * .08, -.48),
      Offset(.50, -.24),
      Offset(.48, .24 + random.nextDouble() * .08),
      Offset(.27, .50),
      Offset(-.27 - random.nextDouble() * .08, .48),
      Offset(-.50, .24),
    ];
    const colors = [
      Color(0xffd4cbbd),
      Color(0xffb8b6a9),
      Color(0xffc5bcae),
      Color(0xffddd1bb),
      Color(0xffaaa99f),
    ];
    final color = colors[random.nextInt(colors.length)];
    // Only the garden-facing shell is needed: the camera never leaves the yard.
    // Omit the concealed back and three underside facets, retaining real depth.
    final inward =
        CafePoint(CafeYard.bounds.center.dx, 0, CafeYard.bounds.center.dy) -
        center;
    final innerSign = inward.dot(across) >= 0 ? 1.0 : -1.0;
    for (final sign in [innerSign]) {
      final points = corners
          .map(
            (p) =>
                center +
                axis * (p.dx * width) +
                CafePoint(0, p.dy * height, 0) +
                across * (sign * depth / 2),
          )
          .toList();
      if (sign < 0) {
        points.setAll(0, points.reversed.toList());
      }
      faces.add(
        CafeFace(
          points,
          color,
          surface: CafeSurface.fieldstone,
          layer: 1,
          part: cap ? 'yard.wall.coping' : 'yard.wall.stone',
          vertexNormals: points
              .map(
                (p) =>
                    (across * sign + (p - center).normalized * .28).normalized,
              )
              .toList(),
        ),
      );
    }
    for (var i = 3; i < corners.length; i++) {
      final a = corners[i], b = corners[(i + 1) % corners.length];
      final p = center + axis * (a.dx * width) + CafePoint(0, a.dy * height, 0);
      final q = center + axis * (b.dx * width) + CafePoint(0, b.dy * height, 0);
      faces.add(
        CafeFace(
          [
            p - across * (depth / 2),
            q - across * (depth / 2),
            q + across * (depth / 2),
            p + across * (depth / 2),
          ],
          Color.lerp(color, const Color(0xffeee5d7), .10)!,
          surface: CafeSurface.fieldstone,
          layer: 1,
          part: cap ? 'yard.wall.coping' : 'yard.wall.stone',
        ),
      );
    }
  }

  void _yardNaturalDetails() {
    final random = math.Random(281129);
    void tuft(CafePoint p) {
      if (!CafeYard.bounds.deflate(.4).contains(Offset(p.x, p.z)) ||
          CafeYard.distanceToTrail(p) < .70 ||
          CafeYard.distanceToStone(p) < .82 ||
          (p.x > 1 && p.x < 4.5 && p.z > -10.6 && p.z < -6.8) ||
          (p.x > -4.7 && p.z > -3)) {
        return;
      }
      for (var j = 0; j < 2; j++) {
        final a = random.nextDouble() * math.pi * 2;
        final side = CafePoint(math.cos(a), 0, math.sin(a));
        final base = p + side * ((j - 1) * .018);
        final tip =
            base +
            side * (.018 + random.nextDouble() * .025) +
            CafePoint(0, .035 + random.nextDouble() * .05, 0);
        faces.add(
          CafeFace(
            [base - side * .010, base + side * .010, tip + side * .002, tip],
            const [Color(0xff84965f), Color(0xffa9b77f), Color(0xffb7bc8d)][j],
            doubleSided: true,
            part: 'yard.grass.blade',
            layer: 1,
          ),
        );
      }
    }

    // Clumps sit beyond the clear barefoot lane, never down its centre.
    for (var i = 0; i + 1 < CafeYard.trail.length; i++) {
      final p = CafeYard.trail[i], next = CafeYard.trail[i + 1];
      final along = (next - p).normalized;
      final side = CafePoint(along.z, 0, -along.x);
      for (final sign in [-1.0, 1.0]) {
        tuft(p + side * (sign * (.76 + random.nextDouble() * .17)));
      }
    }
    for (var i = 0; i < 160; i++) {
      tuft(
        CafePoint(
          -21 + random.nextDouble() * 28,
          0,
          -20 + random.nextDouble() * 17,
        ),
      );
    }
  }
}
