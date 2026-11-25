part of 'cafe_world.dart';

extension _ClearCafeEntrance on CafeWorld {
  void _clearEntrance() {
    // The old street exit is closed. App back navigation remains in the header.
    box(0, .08, 4.96, 8.8, .16, .08, CafeWorld.dark, wood: true);
  }
}
