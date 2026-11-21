import 'package:flutter/foundation.dart';

import 'cafe_camera.dart';
import 'cafe_visit.dart';
import 'cafe_world.dart';

class CafeViewController extends ChangeNotifier {
  CafeViewController({this.seat})
    : camera = seat == null ? CafeCamera.entrance : CafeCamera.seated(seat);
  final world = CafeWorld();
  CafeSeat? seat;
  CafeCamera camera;
  CafeCamera? destination;
  int request = 0;
  void sit(CafeSeat value) {
    seat = value;
    destination = CafeCamera.seated(value);
    request++;
    notifyListeners();
  }

  void stand() {
    seat = null;
    destination = CafeCamera.entrance;
    request++;
    notifyListeners();
  }

  void look(double dx, double dy) {
    destination = null;
    request++;
    camera = camera.look(dx, dy);
    notifyListeners();
  }

  void updateCamera(CafeCamera value) {
    camera = value;
    notifyListeners();
  }

  void step(double sideways, double ahead) {
    if (seat != null) return;
    destination = null;
    request++;
    final next = camera.moved(sideways, ahead);
    if (world.canStand(next.position)) camera = next;
    notifyListeners();
  }
}
