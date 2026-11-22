import 'dart:math' as math;
import 'dart:ui';
import 'cafe_camera.dart';
import 'cafe_walk.dart';
import 'cafe_world.dart';

/// An articulated, neutral placeholder; no user likeness or persistent profile.
class CafeAvatar {
  const CafeAvatar({
    required this.position,
    required this.yaw,
    required this.gait,
    this.speed = 0,
    this.seated = false,
    this.opacity = 1,
  });
  final CafePoint position;
  final double yaw, speed, opacity;
  final CafeGait gait;
  final bool seated;

  List<CafeFace> build() {
    final output = <CafeFace>[];
    final root = CafePoint(position.x, 0, position.z),
        forward = cafeForward(yaw),
        right = cafeRight(yaw);
    final phase = gait.distance / CafeGait.stride * math.pi * 2;
    final bob = seated
        ? 0.0
        : math.min(speed, 1.2) * .007 * (1 - math.cos(phase * 2));
    final down = seated ? -.20 : bob;
    CafePoint at(double x, double y, double z) =>
        root + right * x + CafePoint(0, y + down, 0) + forward * z;
    Color fade(Color c) => c.withValues(alpha: c.a * opacity);
    void ball(
      CafePoint c,
      CafePoint radius,
      Color color, {
      int sides = 10,
      int rings = 6,
    }) {
      CafePoint p(double a, double b) =>
          c +
          right * (math.cos(a) * math.cos(b) * radius.x) +
          CafePoint(0, math.sin(b) * radius.y, 0) +
          forward * (math.sin(a) * math.cos(b) * radius.z);
      for (var i = 0; i < sides; i++) {
        for (var j = 0; j < rings; j++) {
          final a = i * 2 * math.pi / sides,
              b = (i + 1) * 2 * math.pi / sides,
              u = -math.pi / 2 + j * math.pi / rings,
              v = -math.pi / 2 + (j + 1) * math.pi / rings;
          var points = [p(a, u), p(a, v), p(b, v), p(b, u)];
          final n = (points[0] + points[1] + points[2] + points[3]) * .25 - c;
          if ((points[1] - points[0]).cross(points[2] - points[0]).dot(n) < 0) {
            points = points.reversed.toList();
          }
          output.add(
            CafeFace(
              points,
              fade(color),
              doubleSided: true,
              vertexNormals: points.map((q) => (q - c).normalized).toList(),
            ),
          );
        }
      }
    }

    void limb(CafePoint a, CafePoint b, double ra, double rb, Color color) {
      final axis = (b - a).normalized;
      final u = axis.cross(forward).length > .01
          ? axis.cross(forward).normalized
          : right;
      final v = axis.cross(u).normalized;
      for (var i = 0; i < 8; i++) {
        final t = i * math.pi / 4, tt = (i + 1) * math.pi / 4;
        final n = u * math.cos(t) + v * math.sin(t),
            nn = u * math.cos(tt) + v * math.sin(tt);
        var points = [a + n * ra, b + n * rb, b + nn * rb, a + nn * ra];
        var normals = [n, n, nn, nn];
        if ((points[1] - points[0]).cross(points[2] - points[0]).dot(n) < 0) {
          points = points.reversed.toList();
          normals = normals.reversed.toList();
        }
        output.add(CafeFace(points, fade(color), vertexNormals: normals));
      }
      ball(b, CafePoint(rb, rb, rb), color, sides: 8, rings: 4);
    }

    const cloth = Color(0xffe6ddca),
        pants = Color(0xff8b7a66),
        skin = Color(0xffc4a285),
        hair = Color(0xff514335),
        shoe = Color(0xff665243);
    // Ground contact is part of the mesh, not a moving image overlay.
    final shadow = root + const CafePoint(0, .014, 0);
    for (var i = 0; i < 20; i++) {
      final a = i * math.pi / 10, b = (i + 1) * math.pi / 10;
      output.add(
        CafeFace(
          [
            shadow,
            shadow + CafePoint(math.cos(b) * .31, 0, math.sin(b) * .24),
            shadow + CafePoint(math.cos(a) * .31, 0, math.sin(a) * .24),
          ],
          const Color(0x1f382b20).withValues(alpha: .12 * opacity),
          unlit: true,
          layer: 1,
          vertexColors: [
            Color.fromRGBO(56, 43, 32, .12 * opacity),
            const Color(0x00382b20),
            const Color(0x00382b20),
          ],
        ),
      );
    }
    ball(at(0, .89, 0), const CafePoint(.16, .13, .115), pants);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6, b = (i + 1) * math.pi / 6;
      CafePoint hem(double t) => at(math.cos(t) * .17, .99, math.sin(t) * .125);
      CafePoint chest(double t) =>
          at(math.cos(t) * .20, 1.39, math.sin(t) * .12);
      var points = [hem(a), chest(a), chest(b), hem(b)];
      final outward =
          (points[0] + points[1] + points[2] + points[3]) * .25 - at(0, 1.2, 0);
      if ((points[1] - points[0]).cross(points[2] - points[0]).dot(outward) <
          0) {
        points = points.reversed.toList();
      }
      output.add(CafeFace(points, fade(cloth)));
    }
    ball(
      at(0, 1.38, 0),
      const CafePoint(.20, .105, .12),
      cloth,
      sides: 12,
      rings: 4,
    );
    limb(at(0, 1.43, 0), at(0, 1.49, 0), .055, .052, skin);
    ball(
      at(0, 1.60, 0),
      const CafePoint(.115, .145, .11),
      skin,
      sides: 12,
      rings: 8,
    );
    ball(
      at(0, 1.60, -.063),
      const CafePoint(.119, .125, .063),
      hair,
      sides: 12,
      rings: 6,
    );
    ball(
      at(0, 1.66, -.015),
      const CafePoint(.121, .10, .116),
      hair,
      sides: 12,
      rings: 6,
    );
    ball(
      at(0, 1.60, .112),
      const CafePoint(.018, .026, .023),
      skin,
      sides: 6,
      rings: 4,
    );
    for (final side in [-1, 1]) {
      ball(
        at(side * .04, 1.625, .105),
        const CafePoint(.008, .007, .006),
        hair,
        sides: 6,
        rings: 3,
      );
    }
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final hip = at(side * .095, .87, 0);
      final foot = seated
          ? root +
                right * (side * .105) +
                forward * .36 +
                const CafePoint(0, .06, 0)
          : CafePoint.lerp(
              root + right * (side * .095) + const CafePoint(0, .06, 0),
              gait.foot(i, root, yaw),
              (speed / .3).clamp(0.0, 1.0),
            );
      if (foot.y < .13) {
        final strength = (.13 - foot.y) / .07 * .22 * opacity;
        final ground = CafePoint(foot.x, .016, foot.z);
        for (var j = 0; j < 12; j++) {
          final a = j * math.pi / 6, b = (j + 1) * math.pi / 6;
          output.add(
            CafeFace(
              [
                ground,
                ground +
                    right * (math.cos(b) * .085) +
                    forward * (math.sin(b) * .15),
                ground +
                    right * (math.cos(a) * .085) +
                    forward * (math.sin(a) * .15),
              ],
              Color.fromRGBO(40, 32, 24, strength),
              layer: 1,
              unlit: true,
              vertexColors: [
                Color.fromRGBO(40, 32, 24, strength),
                const Color(0x00282018),
                const Color(0x00282018),
              ],
            ),
          );
        }
      }
      final ankle = foot + const CafePoint(0, .06, 0);
      final axis = (ankle - hip).normalized,
          distance = math.min((ankle - hip).length, .879);
      final bend = (forward - axis * forward.dot(axis)).normalized;
      final knee =
          hip +
          axis * (distance / 2) +
          bend * math.sqrt(math.max(0, .44 * .44 - distance * distance / 4));
      limb(hip, knee, .078, .065, pants);
      limb(knee, ankle, .06, .03, pants);
      ball(
        foot + forward * .035,
        const CafePoint(.062, .046, .13),
        shoe,
        sides: 10,
        rings: 4,
      );
      final swing = seated
          ? .18
          : math.sin(phase + i * math.pi) * .22 * math.min(speed / 1.0, 1);
      final shoulder = at(side * .215, 1.37, 0);
      final elbow = at(side * .24, 1.10, math.sin(swing) * .26);
      final hand = at(side * .23, .86, math.sin(swing) * .48 + .04);
      limb(shoulder, elbow, .075, .059, cloth);
      limb(elbow, hand, .052, .036, cloth);
      ball(hand, const CafePoint(.038, .065, .035), skin, sides: 8, rings: 5);
    }
    return output;
  }
}
