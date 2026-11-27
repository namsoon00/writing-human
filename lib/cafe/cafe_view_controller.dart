import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'cafe_camera.dart';
import 'cafe_avatar.dart';
import 'cafe_body.dart';
import 'cafe_chase_camera.dart';
import 'cafe_visit.dart';
import 'cafe_world.dart';
import 'cafe_yard.dart';
import 'cafe_space.dart';

class CafeViewController extends ChangeNotifier {
  CafeViewController({this.seat, CafeSpace space = const CafeSpace()})
    : camera = seat == null ? CafeCamera.entrance : CafeCamera.seated(seat),
      inCourtyard = seat == CafeSeat.garden,
      _cafe = CafeWorld(space: space) {
    bodyYaw = camera.yaw;
    teaFilled = space.gardenTea;
    if (seat != null) {
      camera = world.seatedCamera(seat!, chairId: activeChairId);
    }
    bodyYaw = camera.yaw;
  }
  String? heldId, contextId;
  bool heldBookOpen = false;
  CafeUseFrame? _use;
  Completer<bool>? _useDone;
  CafeCamera? _dropFrom, _dropToward;
  int useRequest = 0;
  bool get using => _useDone != null;
  CafeUseFrame? get useFrame =>
      _use ??
      (heldId == null
          ? null
          : CafeUseFrame(
              heldId!,
              CafeUseKind.hold,
              held: true,
              open: heldBookOpen,
            ));
  void inspect(String? id) {
    contextId = id;
    notifyListeners();
  }

  Future<bool> performUse(String id, CafeUseKind kind) {
    if (using || travelling || !world.objects.containsKey(id)) {
      return Future.value(false);
    }
    if (kind == CafeUseKind.putDown) {
      final delta =
          world.objects[id]!.pivot +
          const CafePoint(0, .06, 0) -
          camera.position;
      _dropFrom = camera;
      _dropToward = CafeCamera(
        position: camera.position,
        yaw: math.atan2(delta.x, -delta.z),
        pitch: math
            .atan2(delta.y, math.sqrt(delta.x * delta.x + delta.z * delta.z))
            .clamp(-.72, .65),
      );
    }
    final done = _useDone = Completer<bool>();
    _use = CafeUseFrame(id, kind, held: heldId == id, open: heldBookOpen);
    contextId = id;
    useRequest++;
    notifyListeners();
    return done.future;
  }

  void advanceUse(double progress) {
    final frame = _use;
    if (frame == null || !progress.isFinite) return;
    if (_dropFrom != null && _dropToward != null) {
      camera = CafeCamera.interpolate(
        _dropFrom!,
        _dropToward!,
        progress.clamp(0, 1),
      );
      bodyYaw = camera.yaw;
    }
    _use = CafeUseFrame(
      frame.id,
      frame.kind,
      progress: progress.clamp(0, 1),
      held: frame.held,
      open: frame.open,
    );
    notifyListeners();
  }

  void finishUse() {
    final frame = _use, done = _useDone;
    if (frame == null || done == null) return;
    if (frame.kind == CafeUseKind.pickUp) {
      heldId = frame.id;
      heldBookOpen = false;
    }
    if (frame.kind == CafeUseKind.putDown) {
      heldId = null;
      heldBookOpen = false;
      contextId = null;
    }
    if (frame.held && frame.kind == CafeUseKind.open) heldBookOpen = true;
    if (frame.held && frame.kind == CafeUseKind.close) heldBookOpen = false;
    _use = null;
    _dropFrom = null;
    _dropToward = null;
    _useDone = null;
    done.complete(true);
    notifyListeners();
  }

  void cancelUse() {
    final done = _useDone;
    _useDone = null;
    _dropFrom = null;
    _dropToward = null;
    _use = null;
    heldId = null;
    heldBookOpen = false;
    contextId = null;
    if (done != null && !done.isCompleted) done.complete(false);
    notifyListeners();
  }

  @override
  void dispose() {
    _travelDone?.complete(false);
    _travelDone = null;
    final done = _useDone;
    _useDone = null;
    if (done != null && !done.isCompleted) done.complete(false);
    super.dispose();
  }

  Completer<bool>? _travelDone;
  Future<bool> get travelFinished =>
      _travelDone?.future ?? Future.value(!travelling);
  Future<void> roomReady = Future<void>.value();
  double walkSpeed = 0;
  double bodyYaw = 0, walkPhase = 0;
  CafeAvatar? _avatar;
  CafeCamera get actorCamera =>
      CafeCamera(position: camera.position, yaw: bodyYaw, pitch: camera.pitch);
  CafeCamera? _viewSource, _view;
  CafeWorld? _viewWorld;
  double _viewHands = -1;
  CafeCamera get viewCamera {
    final room = world;
    final frame = useFrame;
    final hands = frame == null
        ? 0.0
        : frame.kind == CafeUseKind.pickUp
        ? frame.progress
        : frame.kind == CafeUseKind.putDown
        ? 1 - frame.progress
        : frame.held
        ? 1.0
        : 0.0;
    if (!identical(_viewSource, camera) ||
        !identical(_viewWorld, room) ||
        _viewHands != hands) {
      _viewSource = camera;
      _viewWorld = room;
      _viewHands = hands;
      _view = cafeChaseCamera(camera, room, hands: hands);
    }
    return _view!;
  }

  CafeAvatar get avatar {
    final eye = actorCamera;
    final previous = _avatar;
    final frame = useFrame;
    final meditation =
        inCourtyard &&
            (meditating ||
                arrival == CafeTarget.meditation ||
                _departure == CafeTarget.meditation)
        ? ((1.3 - eye.position.y) / .4).clamp(0.0, 1.0)
        : 0.0;
    if (previous != null &&
        previous.eye.position.x == eye.position.x &&
        previous.eye.position.y == eye.position.y &&
        previous.eye.position.z == eye.position.z &&
        (frame == null || previous.eye.pitch == eye.pitch) &&
        previous.yaw == eye.yaw &&
        previous.object == world.objects[frame?.id] &&
        previous.phase == walkPhase &&
        previous.stride == (walkSpeed / .65).clamp(0.0, 1.0) &&
        previous.barefoot == barefoot &&
        previous.meditation == meditation &&
        previous.use?.id == frame?.id &&
        previous.use?.kind == frame?.kind &&
        previous.use?.progress == frame?.progress &&
        previous.use?.held == frame?.held &&
        previous.use?.open == frame?.open) {
      return previous;
    }
    return _avatar = CafeAvatar(
      eye: eye,
      yaw: eye.yaw,
      phase: walkPhase,
      stride: (walkSpeed / .65).clamp(0.0, 1.0),
      use: frame,
      barefoot: barefoot,
      meditation: meditation,
      object: world.objects[frame?.id],
    );
  }

  CafeSeat? _pendingSeat;
  String? activeChairId, _pendingChairId;
  CafeTarget? _departure;
  void advanceCamera(
    CafeCamera value, {
    required double dt,
    required bool walking,
  }) {
    if (!value.isFinite || !dt.isFinite || dt <= 0) return;
    final delta = value.position - camera.position;
    camera = value;
    final horizontal = CafePoint(delta.x, 0, delta.z).length;
    if (walking && horizontal > .00001) {
      final targetYaw = math.atan2(delta.x, -delta.z);
      final turn = (targetYaw - bodyYaw + math.pi) % (2 * math.pi) - math.pi;
      bodyYaw += turn * (dt * 12).clamp(0, 1);
      walkPhase += horizontal * 2 * math.pi / CafeBody.gaitLength;
    }
    walkSpeed = walking ? CafePoint(delta.x, 0, delta.z).length / dt : 0;
    notifyListeners();
  }

  CafeWorld _cafe;
  CafeWorld get _courtyard => _cafe.linkedWorld;
  CafeSpace get space => _cafe.space;
  bool inCourtyard;
  bool resting = false, teaFilled = false;
  bool barefoot = false, strolling = false;
  CafeTarget? restingTarget;
  CafeTarget get _restTarget => restingTarget ?? CafeTarget.bench;
  bool get meditating => resting && _restTarget == CafeTarget.meditation;
  void toggleBarefoot() {
    if (!inCourtyard || travelling || using || heldId != null) return;
    barefoot = !barefoot;
    notifyListeners();
  }

  double effectTime = 0;
  double? bellAt, teaAt;
  String? applySpace(CafeSpace next, {bool validate = true}) {
    final cafe = CafeWorld(space: next);
    final error = validate
        ? cafe.validateLayout() ?? cafe.linkedWorld.validateLayout()
        : null;
    if (error != null) return error;
    _cafe = cafe;
    teaFilled = next.gardenTea;
    if (seat != null) {
      camera = world.seatedCamera(seat!, chairId: activeChairId);
      bodyYaw = camera.yaw;
    }
    if (!world.canStand(camera.position) && seat == null && !resting) {
      camera = inCourtyard ? CafeCamera.courtyardEntrance : CafeCamera.entrance;
      bodyYaw = camera.yaw;
    }
    notifyListeners();
    return null;
  }

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
    if (resting) return world.targetApproach(_restTarget);
    if (seat != null) {
      return activeChairId == null
          ? world.targetApproach(CafeTarget.forSeat(seat!))
          : world.chairApproach(activeChairId!);
    }
    if (!world.canStand(camera.position) && _departure != null) {
      return world.targetApproach(_departure!);
    }
    return camera.position;
  }

  bool visitChair(String id) {
    final chair = world.objects[id];
    if (chair?.type != CafeItemType.chair || chair?.seat == null) return false;
    return visit(CafeTarget.forSeat(chair!.seat!), chairId: id);
  }

  bool visit(CafeTarget target, {String? chairId}) {
    if (using || heldId != null || target.inCourtyard != inCourtyard) {
      return false;
    }
    final next = target.seat;
    final approach = chairId == null
        ? world.targetApproach(target)
        : world.chairApproach(chairId);
    final origin = _origin;
    final path = world.path(origin, approach);
    if (path.isEmpty) return false;
    _departure = resting
        ? _restTarget
        : seat == null
        ? _departure
        : CafeTarget.forSeat(seat!);
    arrival = target;
    strolling = false;
    resting = false;
    final gaze = world.targetAnchor(target);
    journey = [
      if (seat != null) _facing(origin, gaze),
      for (final p in path) _facing(p, gaze),
      if (next != null) world.seatedCamera(next, chairId: chairId),
      if (target == CafeTarget.bench) CafeCamera.gardenRest,
      if (target == CafeTarget.meditation) CafeCamera.meditation,
      if (target == CafeTarget.trailRest) CafeCamera.trailRest,
      if (target == CafeTarget.pond) _facing(approach, gaze, pitch: -.55),
    ];
    _pendingSeat = next;
    _pendingChairId = chairId;
    activeChairId = null;
    seat = null;
    _begin();
    return true;
  }

  void sit(CafeSeat value) => visit(CafeTarget.forSeat(value));

  void stand() {
    if (using || heldId != null) return;
    final selected = seat;
    if (selected == null && !resting) return;
    final p = activeChairId == null
        ? world.targetApproach(
            selected == null ? _restTarget : CafeTarget.forSeat(selected),
          )
        : world.chairApproach(activeChairId!);
    _departure = selected == null ? _restTarget : CafeTarget.forSeat(selected);
    resting = false;
    strolling = false;
    arrival = null;
    _pendingSeat = null;
    _pendingChairId = null;
    activeChairId = null;
    seat = null;
    journey = [CafeCamera(position: p, yaw: camera.yaw, pitch: -.10)];
    _begin();
  }

  bool walkTo(CafePoint point) {
    if (using || heldId != null) return false;
    contextId = null;
    final origin = _origin;
    final target = CafePoint(point.x, 1.62, point.z);
    final path = world.path(origin, target);
    if (path.isEmpty) return false;
    _departure = resting
        ? _restTarget
        : seat == null
        ? _departure
        : CafeTarget.forSeat(seat!);
    seat = null;
    _pendingSeat = null;
    _pendingChairId = null;
    activeChairId = null;
    resting = false;
    strolling = false;
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

  bool startStroll() {
    if (!inCourtyard || using || heldId != null) return false;
    final start = CafePoint(
      CafeYard.trail.first.x,
      1.62,
      CafeYard.trail.first.z,
    );
    final lead = world.path(_origin, start);
    if (lead.isEmpty) return false;
    final loop = [for (final p in CafeYard.trail) CafePoint(p.x, 1.62, p.z)];
    for (var i = 1; i < loop.length; i++) {
      if (!world.clearSegment(loop[i - 1], loop[i])) return false;
    }
    final points = [...lead, ...loop.skip(1)];
    _departure = resting
        ? _restTarget
        : seat == null
        ? null
        : CafeTarget.forSeat(seat!);
    seat = null;
    resting = false;
    activeChairId = null;
    _pendingSeat = null;
    _pendingChairId = null;
    arrival = null;
    contextId = null;
    journey = [
      for (var i = 0; i < points.length; i++)
        _facing(points[i], points[math.min(i + 1, points.length - 1)]),
    ];
    // Preserve the incoming heading at the closed loop's final point.
    journey[journey.length - 1] = CafeCamera(
      position: points.last,
      yaw: journey[journey.length - 2].yaw,
      pitch: -.10,
    );
    strolling = true;
    _begin();
    return true;
  }

  void _begin() {
    _travelDone?.complete(false);
    _travelDone = Completer<bool>();
    destination = journey.last;
    travelling = true;
    request++;
    notifyListeners();
  }

  void finishTravel() {
    final done = _travelDone;
    _travelDone = null;
    seat = _pendingSeat;
    activeChairId = _pendingChairId;
    _pendingSeat = null;
    _pendingChairId = null;
    walkSpeed = 0;
    if (arrival == CafeTarget.courtyard) {
      inCourtyard = true;
      camera = CafeCamera.courtyardEntrance;
      seat = null;
    } else if (arrival == CafeTarget.cafeReturn) {
      inCourtyard = false;
      barefoot = false;
      camera = CafeCamera(
        position: _cafe.targetApproach(CafeTarget.courtyard),
        yaw: math.pi / 2,
        pitch: -.1,
      );
      seat = null;
    }
    if (seat != null ||
        arrival == CafeTarget.courtyard ||
        arrival == CafeTarget.cafeReturn ||
        arrival == CafeTarget.bench ||
        arrival == CafeTarget.meditation ||
        arrival == CafeTarget.trailRest) {
      bodyYaw = camera.yaw;
    }
    _departure = null;
    resting = const {
      CafeTarget.bench,
      CafeTarget.meditation,
      CafeTarget.trailRest,
    }.contains(arrival);
    restingTarget = resting ? arrival : null;
    strolling = false;
    arrival = null;
    travelling = false;
    destination = null;
    journey = [];
    done?.complete(true);
    notifyListeners();
  }

  void look(double dx, double dy) {
    if (using || !dx.isFinite || !dy.isFinite) return;
    _travelDone?.complete(false);
    _travelDone = null;
    if (travelling && !world.canStand(camera.position) && _departure != null) {
      camera = CafeCamera(
        position: world.targetApproach(_departure!),
        yaw: camera.yaw,
        pitch: camera.pitch,
      );
    }
    if (travelling) {
      seat = null;
      activeChairId = null;
    }
    walkSpeed = 0;
    strolling = false;
    _pendingSeat = null;
    _pendingChairId = null;
    _departure = null;
    destination = null;
    journey = [];
    arrival = null;
    travelling = false;
    request++;
    camera = camera.look(dx, dy);
    notifyListeners();
  }

  void updateCamera(CafeCamera value, {bool face = true}) {
    if (!value.isFinite) return;
    camera = value;
    if (face) bodyYaw = value.yaw;
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
    if (using ||
        heldId != null ||
        seat != null ||
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
    if (using ||
        heldId != null ||
        resting ||
        seat != null ||
        !sideways.isFinite ||
        !ahead.isFinite) {
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
    _pendingChairId = null;
    activeChairId = null;
    request++;
    advanceCamera(next, dt: .2, walking: true);
    walkSpeed = 0;
  }
}
