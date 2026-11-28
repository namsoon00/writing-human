import 'cafe_camera.dart';

/// Physical proportions of small A. The navigation rig remains independent of
/// the visible head: floor picking, existing routes and room data keep metres.
abstract final class CafeBody {
  static const width = .84, torsoScale = .65;
  static const headWidth = 1.27, headScale = .96;
  static const gaitLength = .66;
  static const walkSpeed = .63, strollSpeed = .55;
  static const stance = .53;
  static double ease(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * x * (10 + x * (-15 + x * 6));
  }

  static double seated(CafeCamera rig) =>
      ((1.62 - rig.position.y) / .44).clamp(0.0, 1.0);
  static double meditation(CafeCamera rig) =>
      ((1.18 - rig.position.y) / .40).clamp(0.0, 1.0);
  static double headDrop(CafeCamera rig) =>
      .0245 * seated(rig) * (1 - meditation(rig)) + .252 * meditation(rig);
}
