part of 'cafe_avatar.dart';

/// Local, metre-based joints. Pose changes never stretch the two leg bones.
class CafeLegPose {
  const CafeLegPose(
    this.hip,
    this.knee,
    this.ankle,
    this.yaw,
    this.pitch,
    this.roll,
  );
  final CafePoint hip, knee, ankle;
  final double yaw, pitch, roll;
}

class CafeSkeleton {
  CafeSkeleton(this.avatar);
  final CafeAvatar avatar;
  static const thigh = .193, shin = .193;
  late final fold = CafeBody.ease(avatar.meditation);
  late final seated = CafeBody.ease(avatar.seated);
  late final moving = avatar.stride * (1 - fold) * (1 - seated);
  late final drop =
      .0245 * seated + .252 * fold + (avatar.barefoot ? .016 * (1 - fold) : 0);
  late final bob = -moving * (.043 + .0015 * math.cos(avatar.phase * 2));
  late final sway = .003 * moving * math.sin(avatar.phase);
  late final lean = .02 * math.sin(math.pi * fold);
  late final bend = -.12 * math.sin(math.pi * fold) - .025 * moving;
  late final _bendCos = math.cos(bend), _bendSin = math.sin(bend);
  CafePoint torsoNormal(CafePoint p) => CafePoint(
    p.x,
    p.y * _bendCos - p.z * _bendSin,
    p.y * _bendSin + p.z * _bendCos,
  );
  CafePoint torsoPoint(CafePoint p) =>
      torsoNormal(p - const CafePoint(0, .454, 0)) +
      CafePoint(sway, .454 + bob - drop, lean);
  late final legs = [
    for (final side in [-1.0, 1.0]) _leg(side),
  ];

  CafeLegPose _leg(double side) {
    final cycle = (avatar.phase / (math.pi * 2) + (side < 0 ? .5 : 0)) % 1;
    final swing = ((cycle - CafeBody.stance) / (1 - CafeBody.stance)).clamp(
      0.0,
      1.0,
    );
    final span = CafeBody.gaitLength * CafeBody.stance;
    double travel(double weight) =>
        (cycle < CafeBody.stance
            ? -span / 2 + span * cycle / CafeBody.stance
            : span / 2 - span * CafeBody.ease(swing)) *
        weight;
    var z = travel(moving);
    var lift = .022 * math.pow(math.sin(math.pi * swing), 2) * moving;
    var pitch = cycle < CafeBody.stance
        ? .075 * math.sin((cycle / CafeBody.stance - .5) * math.pi) * moving
        : -.055 * math.sin(math.pi * swing) * moving;
    if (avatar.settleFrom > 0 && avatar.settleProgress < 1) {
      final support = (avatar.phase / (math.pi * 2)) % 1 < CafeBody.stance;
      final goesFirst = (side > 0) != support;
      final p = CafeBody.ease(
        (avatar.settleProgress - (goesFirst ? 0 : .5)) * 2,
      );
      z = travel(avatar.settleFrom) * (1 - p);
      lift =
          .014 * math.sin(math.pi * p) +
          .022 *
              math.pow(math.sin(math.pi * swing), 2) *
              avatar.settleFrom *
              (1 - p);
      pitch *= (1 - p);
    }
    final footYaw = -side * 1.22 * fold;
    final roll = (side > 0 ? .35 : -.10) * fold;
    final naked = avatar.barefoot || fold > .01;
    final footHeight = footSupport(naked, pitch, roll);
    final hip = CafePoint(side * .076 + sway, .497 + bob - drop, lean);
    var ankle = CafePoint(side * .081, footHeight + lift, z);
    ankle = CafePoint.lerp(
      ankle,
      CafePoint(side * .087, footHeight, -.125),
      seated,
    );
    ankle = CafePoint.lerp(
      ankle,
      CafePoint(
        side * .008,
        footSupport(true, 0, roll) + .046,
        side < 0 ? -.275 : -.145,
      ),
      fold,
    );
    final pole = CafePoint.lerp(
      const CafePoint(0, 0, -1),
      CafePoint(side * .9, -.65, -.1),
      fold,
    );
    final reach = ankle - hip;
    if (reach.length > thigh + shin - .0001) {
      ankle = hip + reach.normalized * (thigh + shin - .0001);
    }
    final knee = _joint(hip, ankle, thigh, shin, pole);
    return CafeLegPose(hip, knee, ankle, footYaw, pitch, roll);
  }

  /// The lowest point of the rotated sole remains on its support plane.
  static double footSupport(bool barefoot, double pitch, double roll) {
    final c = math.cos(pitch), s = math.sin(pitch);
    final cr = math.cos(roll), sr = math.sin(roll);
    double bottom(
      double y,
      double z,
      double xRadius,
      double yRadius,
      double zRadius,
    ) =>
        y * cr * c -
        z * s -
        math.sqrt(
          math.pow(xRadius * sr * c, 2) +
              math.pow(yRadius * cr * c, 2) +
              math.pow(zRadius * s, 2),
        );
    final low = barefoot
        ? bottom(-.067, -.035, .044, .026, .095)
        : math.min(
            bottom(-.091, -.025, .068, .017, .106),
            bottom(-.066, -.027, .067, .041, .100),
          );
    return .004 - low;
  }
}
