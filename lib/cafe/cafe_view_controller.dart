import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'cafe_camera.dart';
import 'cafe_visit.dart';
import 'cafe_world.dart';

class CafeViewController extends ChangeNotifier {
  CafeViewController({this.seat})
    : camera = seat == null ? CafeCamera.entrance : CafeCamera.seated(seat),
      inCourtyard = seat == CafeSeat.garden;
  double walkSpeed = 0;
  CafeSeat? _pendingSeat;
  CafeTarget? _departure;
  void advanceCamera(
    CafeCamera value, {
    required double dt,
    required bool walking,
  }) {
    if (!value.isFinite || !dt.isFinite || dt <= 0) return;
    final delta = value.position - camera.position;
    camera = value;
    walkSpeed = walking ? CafePoint(delta.x, 0, delta.z).length / dt : 0;
    notifyListeners();
  }

  final _cafe = CafeWorld();
  late final _courtyard = _cafe.linkedWorld;
  bool inCourtyard;
  bool resting = false, teaFilled = false;
  double effectTime = 0;
  double? bellAt, teaAt;
  void ring() {
    bellAt = effectTime;
    notifyListeners();
  }

  void pourTea() {
    teaFilled = true;
    teaAt = effectTime;
    notifyListeners();
  }

  CafeTarget? arrival;
  CafeWorld get world => inCourtyard ? _courtyard : _cafe;
  CafeSeat? seat;
  CafeCamera camera;
  CafeCamera? destination;
  List<CafeCamera> journey = [];
  int request = 0;
  bool travelling = false;

  CafeCamera _facing(CafePoint p, CafePoint target, {double pitch = -.10}) =>
      CafeCamera(
        position: p,
        yaw: math.atan2(target.x - p.x, p.z - target.z),
        pitch: pitch,
      );

  CafePoint get _origin {
    if (resting) return CafeWorld.approach(CafeTarget.bench);
    if (seat != null) return CafeWorld.approach(CafeTarget.forSeat(seat!));
    if (!world.canStand(camera.position) && _departure != null) {
      return CafeWorld.approach(_departure!);
    }
    return camera.position;
  }

  bool visit(CafeTarget target) {
    if (target.inCourtyard != inCourtyard) return false;
    final next = target.seat;
    final approach = CafeWorld.approach(target);
    final origin = _origin;
    final path = world.path(origin, approach);
    if (path.isEmpty) return false;
    _departure = resting
        ? CafeTarget.bench
        : seat == null
        ? _departure
        : CafeTarget.forSeat(seat!);
    arrival = target;
    resting = false;
    final gaze = CafeWorld.anchor(target);
    journey = [
      if (seat != null) _facing(origin, gaze),
      for (final p in path) _facing(p, gaze),
      if (next != null) CafeCamera.seated(next),
      if (target == CafeTarget.bench) CafeCamera.gardenRest,
      if (target == CafeTarget.pond) _facing(approach, gaze, pitch: -.55),
    ];
    _pendingSeat = next;
    seat = null;
    _begin();
    return true;
  }

  void sit(CafeSeat value) => visit(CafeTarget.forSeat(value));

  void stand() {
    final selected = seat;
    if (selected == null && !resting) return;
    final p = CafeWorld.approach(
      selected == null ? CafeTarget.bench : CafeTarget.forSeat(selected),
    );
    _departure = selected == null
        ? CafeTarget.bench
        : CafeTarget.forSeat(selected);
    resting = false;
    arrival = null;
    _pendingSeat = null;
    seat = null;
    journey = [CafeCamera(position: p, yaw: camera.yaw, pitch: -.10)];
    _begin();
  }

  bool walkTo(CafePoint point) {
    final origin = _origin;
    final target = CafePoint(point.x, 1.62, point.z);
    final path = world.path(origin, target);
    if (path.isEmpty) return false;
    _departure = resting
        ? CafeTarget.bench
        : seat == null
        ? _departure
        : CafeTarget.forSeat(seat!);
    seat = null;
    _pendingSeat = null;
    resting = false;
    arrival = null;
    journey = [
      if ((origin - camera.position).length > .1)
        CafeCamera(position: origin, yaw: camera.yaw, pitch: -.10),
      for (final p in path)
        CafeCamera(
          position: p,
          yaw: camera.yaw,
          pitch: camera.pitch.clamp(-.22, .12),
        ),
    ];
    _begin();
    return true;
  }

  void _begin() {
    destination = journey.last;
    travelling = true;
    request++;
    notifyListeners();
  }

  void finishTravel() {
    seat = _pendingSeat;
    _pendingSeat = null;
    walkSpeed = 0;
    if (arrival == CafeTarget.courtyard) {
      inCourtyard = true;
      camera = CafeCamera.courtyardEntrance;
      seat = null;
    } else if (arrival == CafeTarget.cafeReturn) {
      inCourtyard = false;
      camera = CafeCamera(
        position: CafeWorld.approach(CafeTarget.courtyard),
        yaw: math.pi / 2,
        pitch: -.1,
      );
      seat = null;
    }
    _departure = null;
    resting = arrival == CafeTarget.bench;
    arrival = null;
    travelling = false;
    destination = null;
    journey = [];
    notifyListeners();
  }

  void look(double dx, double dy) {
    if (!dx.isFinite || !dy.isFinite) return;
    if (travelling && !world.canStand(camera.position) && _departure != null) {
      camera = CafeCamera(
        position: CafeWorld.approach(_departure!),
        yaw: camera.yaw,
        pitch: camera.pitch,
      );
    }
    if (travelling) seat = null;
    walkSpeed = 0;
    _pendingSeat = null;
    _departure = null;
    destination = null;
    journey = [];
    arrival = null;
    travelling = false;
    request++;
    camera = camera.look(dx, dy);
    notifyListeners();
  }

  void updateCamera(CafeCamera value) {
    if (!value.isFinite) return;
    camera = value;
    notifyListeners();
  }

  void stopWalking() {
    walkSpeed = 0;
    notifyListeners();
  }

  bool freeStep(
    double sideways,
    double ahead,
    double dt, {
    bool animate = true,
  }) {
    if (seat != null ||
        resting ||
        !sideways.isFinite ||
        !ahead.isFinite ||
        !dt.isFinite ||
        dt <= 0) {
      return false;
    }
    final next = camera.moved(sideways, ahead);
    if (!world.clearSegment(camera.position, next.position)) {
      stopWalking();
      return false;
    }
    advanceCamera(next, dt: dt, walking: animate);
    return true;
  }

  void step(double sideways, double ahead) {
    if (resting || seat != null || !sideways.isFinite || !ahead.isFinite) {
      return;
    }
    if (travelling) look(0, 0);
    final next = camera.moved(sideways, ahead);
    if (!world.clearSegment(camera.position, next.position)) return;
    destination = null;
    travelling = false;
    journey = [];
    arrival = null;
    _pendingSeat = null;
    request++;
    advanceCamera(next, dt: .2, walking: true);
    walkSpeed = 0;
  }
}
