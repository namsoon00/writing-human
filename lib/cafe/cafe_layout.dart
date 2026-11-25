import 'cafe_camera.dart';

/// Approved central garden opening and furniture base positions. Saved item
/// offsets still travel with their original parent and are never rewritten.
abstract final class CafeLayout {
  static const openingHalfWidth = 2.10;
  static const openingHeight = 2.74;
  static const entrance = CafePoint(0, 1.62, 0);
  static const gardenEntry = CafePoint(0, 1.62, 2.35);
  static const pond = CafePoint(-2.05, .095, 1.0);
  static CafePoint offset(String id) => switch (id) {
    'shared' => const CafePoint(.8, 0, -2.6),
    'desk.window' => const CafePoint(0, 0, 1.35),
    'desk.windowMiddle' => const CafePoint(0, 0, -3.05),
    'desk.windowRear' => const CafePoint(2.6, 0, 5.45),
    _ => const CafePoint(0, 0, 0),
  };
}
