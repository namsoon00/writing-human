import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import '../cafe/cafe_camera.dart';
import '../cafe/cafe_materials.dart';
import '../cafe/cafe_watercolor.dart';
import '../cafe/cafe_renderer.dart';
import '../cafe/cafe_view_controller.dart';
import '../cafe/cafe_visit.dart';
import '../cafe/cafe_world.dart';
import '../cafe/cafe_walk.dart';
import 'paper.dart';

/// A real, perspective-projected room seen through an eye-height camera.
class CafeScene extends StatefulWidget {
  const CafeScene({
    super.key,
    required this.controller,
    this.interactive = true,
    this.onSeatSelected,
    this.onTargetSelected,
    this.onWrite,
    this.editing = false,
    this.placingId,
    this.onObjectSelected,
    this.onObjectPlaced,
  });
  final CafeViewController controller;
  final bool interactive;
  final bool editing;
  final String? placingId;
  final ValueChanged<String>? onObjectSelected;
  final ValueChanged<CafePoint>? onObjectPlaced;
  final ValueChanged<CafeSeat>? onSeatSelected;
  final ValueChanged<CafeTarget>? onTargetSelected;
  final VoidCallback? onWrite;
  @override
  State<CafeScene> createState() => _CafeSceneState();
}

class _CafeSceneState extends State<CafeScene>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final focus = FocusNode(debugLabel: '카페 둘러보기');
  late final AnimationController travel;
  double lastTravelTime = 0;
  CafeWalkTiming? timing;
  late final Ticker calm;
  late final Ticker keyboard;
  final heldKeys = <LogicalKeyboardKey>{};
  double keySpeed = 0, keyElapsed = 0;
  void _stopKeys() {
    heldKeys.clear();
    keyboard.stop();
    keySpeed = 0;
    keyElapsed = 0;
    if (widget.controller.walkSpeed > 0 && !widget.controller.travelling) {
      widget.controller.stopWalking();
    }
  }

  void _focusChanged() {
    if (!focus.hasFocus) _stopKeys();
  }

  void _keyFrame(Duration elapsed) {
    if (!widget.interactive ||
        widget.editing ||
        !appActive ||
        heldKeys.isEmpty) {
      _stopKeys();
      return;
    }
    final now = elapsed.inMicroseconds / 1000000,
        dt = (now - keyElapsed).clamp(.001, .04);
    keyElapsed = now;
    keySpeed = math.min(1.2, keySpeed + dt * 3);
    bool held(LogicalKeyboardKey a, [LogicalKeyboardKey? b]) =>
        heldKeys.contains(a) || (b != null && heldKeys.contains(b));
    final side =
        (held(LogicalKeyboardKey.keyD) ? 1.0 : 0.0) -
        (held(LogicalKeyboardKey.keyA) ? 1.0 : 0.0);
    final ahead =
        (held(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)
            ? 1.0
            : 0.0) -
        (held(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown)
            ? 1.0
            : 0.0);
    final length = math.sqrt(side * side + ahead * ahead);
    if (length > 0) {
      widget.controller.freeStep(
        side / length * keySpeed * dt,
        ahead / length * keySpeed * dt,
        dt,
        animate: !MediaQuery.disableAnimationsOf(context),
      );
    } else {
      widget.controller.stopWalking();
    }
  }

  double sceneTime = 0, heldTime = 0;
  bool appActive = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCalm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appActive = state == AppLifecycleState.resumed;
    _syncCalm();
    if (!appActive) {
      _stopKeys();
      travel.stop();
      widget.controller.look(0, 0);
    }
  }

  void _syncCalm() {
    final animate =
        mounted &&
        appActive &&
        (widget.controller.inCourtyard ||
            widget.controller.camera.forward.x < -.5) &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !calm.isActive) {
      calm.start();
    }
    if (!animate && calm.isActive) {
      calm.stop();
      heldTime = sceneTime;
    }
  }

  List<CafeCamera> route = [];
  List<double> lengths = [];
  double total = 0;
  int request = 0;
  List<ui.Image?> framedArt = [];
  ui.Image? wood,
      sign,
      walnut,
      limestone,
      woven,
      plaster,
      artwork,
      gravel,
      tree,
      flowers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    focus.addListener(_focusChanged);
    keyboard = createTicker(_keyFrame);
    calm = createTicker((elapsed) {
      final next = heldTime + elapsed.inMicroseconds / 1000000;
      // A quiet 10Hz scene, only while the courtyard is visible.
      if (next - sceneTime >= .1 && mounted) {
        setState(() => sceneTime = next);
        widget.controller.effectTime = sceneTime;
      }
    });
    travel = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(_travelFrame);
    request = widget.controller.request;
    widget.controller.addListener(_changed);
    _loadMaterials();
  }

  Future<ui.Image?> _texture(String name, {int width = 768}) async {
    try {
      final data = await rootBundle.load('assets/images/$name');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: width,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (error) {
      debugPrint('Cafe material unavailable: $error');
      return null;
    }
  }

  Future<ui.Image> _paintedWood({bool walnut = false}) async {
    final source = await _texture('cafe-watercolor-oak.webp', width: 768);
    if (source == null) return CafeWatercolor.wood(walnut: walnut);
    try {
      return await CafeWatercolor.timber(source, walnut: walnut);
    } finally {
      source.dispose();
    }
  }

  Future<ui.Image?> _makeSign() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xffe9dfc9), BlendMode.src);
    const titles = ['쓰는 인간', '쓰는 인간의 추천', '나의 책장', '펜과 노트', '고요한 뜰'];
    const captions = [
      '오늘도, 한 문장',
      '마음에 드는 책을 만나 보세요',
      '지금 펼칠 글과 책',
      '내 취향으로 쓰는 도구',
      '잠시 머물러도 좋아요',
    ];
    for (var row = 0; row < titles.length; row++) {
      final title = TextPainter(
        text: TextSpan(
          text: titles[row],
          style: TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: appFontFallback,
            fontSize: row == 0 ? 105 : 76,
            color: brandInk,
            letterSpacing: 4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      title.paint(canvas, Offset((768 - title.width) / 2, row * 336 + 65));
      final caption = TextPainter(
        text: TextSpan(
          text: captions[row],
          style: const TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: appFontFallback,
            fontSize: 31,
            color: muted,
            letterSpacing: 3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      caption.paint(canvas, Offset((768 - caption.width) / 2, row * 336 + 218));
      title.dispose();
      caption.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(768, 1680);
    picture.dispose();
    return image;
  }

  Future<void> _loadMaterials() async {
    final images = await Future.wait([
      _paintedWood(),
      _makeSign(),
      _paintedWood(walnut: true),
      CafeWatercolor.stone(),
      CafeWatercolor.linen(),
      CafeWatercolor.plaster(),
      CafeMaterials.artwork(),
      CafeWatercolor.gravel(),
      _texture(
        'cafe-watercolor-tree.webp',
        width: 768,
      ).then<ui.Image?>((image) async => image ?? await CafeWatercolor.tree()),
      _texture('cafe-watercolor-flowers.webp', width: 768).then<ui.Image?>(
        (image) async => image ?? await CafeWatercolor.flowers(),
      ),
      _texture('cafe-art-botanical.webp', width: 1024),
      _texture('cafe-art-pond.webp', width: 1024),
      _texture('cafe-art-book.webp', width: 1024),
    ]);
    if (!mounted) {
      for (final image in images) {
        image?.dispose();
      }
      return;
    }
    setState(() {
      wood = images[0];
      sign = images[1];
      walnut = images[2];
      limestone = images[3];
      woven = images[4];
      plaster = images[5];
      artwork = images[6];
      gravel = images[7];
      tree = images[8];
      flowers = images[9];
      framedArt = images.skip(10).toList();
    });
  }

  @override
  void didUpdateWidget(CafeScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      travel.stop();
      request = widget.controller.request;
      widget.controller.addListener(_changed);
    }
  }

  void _changed() {
    final c = widget.controller;
    if (request != c.request) {
      request = c.request;
      travel.stop();
      route = cafeWalkRoute([c.camera, ...c.journey], c.world);
      lastTravelTime = 0;
      if (c.destination != null) {
        if (MediaQuery.disableAnimationsOf(context)) {
          c.updateCamera(c.destination!);
          c.finishTravel();
        } else {
          lengths = [];
          total = 0;
          for (var i = 1; i < route.length; i++) {
            final physical = (route[i].position - route[i - 1].position).length;
            final length = physical > 1e-5 ? physical : .12;
            lengths.add(length);
            total += length;
          }
          timing = CafeWalkTiming(total);
          travel.duration = Duration(
            milliseconds: (timing!.seconds * 1000).round(),
          );
          travel.forward(from: 0);
        }
      }
    }
    if (mounted) {
      setState(() {});
      _syncCalm();
    }
  }

  void _travelFrame() {
    if (route.length < 2 || lengths.isEmpty) return;
    final seconds = travel.value * (travel.duration!.inMicroseconds / 1000000);
    final dt = (seconds - lastTravelTime).clamp(.001, .2);
    lastTravelTime = seconds;
    var distance = timing!.at(travel.value);
    var segment = 0;
    while (segment < lengths.length - 1 && distance > lengths[segment]) {
      distance -= lengths[segment];
      segment++;
    }
    widget.controller.advanceCamera(
      CafeCamera.interpolate(
        route[segment],
        route[segment + 1],
        (distance / lengths[segment]).clamp(0, 1),
      ),
      dt: dt,
      walking:
          (route[segment].position.y - 1.62).abs() < .01 &&
          (route[segment + 1].position.y - 1.62).abs() < .01,
    );
    if (travel.isCompleted) {
      route = [];
      widget.controller.finishTravel();
    }
  }

  void _activate(CafeTarget target) {
    final c = widget.controller;
    c.effectTime = sceneTime;
    if (c.travelling) return;
    if (target.seat != null && c.seat == target.seat) {
      widget.onWrite?.call();
    } else if (widget.onTargetSelected != null) {
      widget.onTargetSelected!(target);
    } else if (target.seat != null) {
      widget.onSeatSelected?.call(target.seat!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    calm.dispose();
    keyboard.dispose();
    focus.removeListener(_focusChanged);
    widget.controller.removeListener(_changed);
    travel.dispose();
    focus.dispose();
    wood?.dispose();
    sign?.dispose();
    walnut?.dispose();
    limestone?.dispose();
    woven?.dispose();
    plaster?.dispose();
    artwork?.dispose();
    gravel?.dispose();
    tree?.dispose();
    flowers?.dispose();
    for (final image in framedArt) {
      image?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyboardListener(
    focusNode: focus,
    onKeyEvent: widget.interactive
        ? (event) {
            final key = event.logicalKey, c = widget.controller;
            final walkingKeys = {
              LogicalKeyboardKey.keyW,
              LogicalKeyboardKey.keyS,
              LogicalKeyboardKey.keyA,
              LogicalKeyboardKey.keyD,
              LogicalKeyboardKey.arrowUp,
              LogicalKeyboardKey.arrowDown,
            };
            if (walkingKeys.contains(key)) {
              if (widget.editing) return;
              if (event is KeyUpEvent) {
                heldKeys.remove(key);
                if (heldKeys.isEmpty) _stopKeys();
              } else if (event is KeyDownEvent &&
                  c.seat == null &&
                  !c.resting) {
                if (heldKeys.isEmpty) {
                  c.look(0, 0);
                  keyElapsed = 0;
                  keySpeed = 0;
                }
                heldKeys.add(key);
                if (!keyboard.isActive) keyboard.start();
              }
              return;
            }
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
            if (key == LogicalKeyboardKey.arrowLeft) c.look(.10, 0);
            if (key == LogicalKeyboardKey.arrowRight) c.look(-.10, 0);
            if (key == LogicalKeyboardKey.escape &&
                (c.seat != null || c.resting)) {
              c.stand();
            }
          }
        : null,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest, c = widget.controller;
        final camera = c.camera;
        final markers = <Widget>[];
        if (widget.interactive &&
            !widget.editing &&
            !c.travelling &&
            !c.resting) {
          CafeTarget? nearest;
          Offset? nearestPoint;
          var best = double.infinity;
          for (final target in c.world.targets) {
            if (c.seat != null && target.seat != c.seat && !c.inCourtyard) {
              continue;
            }
            final writing = target.seat == c.seat && c.seat != null;
            final anchor = writing
                ? c.world.targetDesk(c.seat!)
                : c.world.targetAnchor(target);
            final point = CafeRenderer.project(anchor, camera, size);
            final distance = (anchor - camera.position).length;
            if (point == null ||
                point.dx < 35 ||
                point.dx > size.width - 35 ||
                point.dy < 130 ||
                point.dy > size.height - 56 ||
                (!writing &&
                    (distance > 3.5 ||
                        (point.dx / size.width - .5).abs() > .32))) {
              continue;
            }
            if (CafeRenderer.pick(point, camera, size, c.world)?.target !=
                target) {
              continue;
            }
            final score = writing
                ? -1.0
                : (point.dx / size.width - .5).abs() * 3 + distance / 10;
            if (score < best) {
              best = score;
              nearest = target;
              nearestPoint = point;
            }
          }
          if (nearest != null && nearestPoint != null) {
            final target = nearest, point = nearestPoint;
            final writing = target.seat != null && c.seat == target.seat;
            final label = writing ? '노트 펼치기' : target.label;
            final width = math.min(172.0, size.width - 32);
            markers.add(
              Positioned(
                left: (point.dx - width / 2).clamp(8, size.width - width - 8),
                top: (point.dy + (writing ? 46 : 18)).clamp(
                  130.0,
                  size.height - 62,
                ),
                width: width,
                child: Center(
                  child: Tooltip(
                    message: writing ? '이 자리에서 쓰기' : target.action,
                    child: TextButton(
                      key: writing
                          ? const ValueKey('cafe-start-writing')
                          : ValueKey('cafe-object-${target.name}'),
                      onPressed: () => _activate(target),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xfffff6e8),
                        backgroundColor: const Color(0x993d3026),
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Color(0x66e9d7b5)),
                        ),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.35),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: '1인칭 카페. 끌어 둘러보고, 바닥을 눌러 걷고, 책상과 서가를 눌러 이용해요.',
              child: GestureDetector(
                key: const ValueKey('cafe-first-person-view'),
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.interactive
                    ? (_) => focus.requestFocus()
                    : null,
                onTapUp: widget.interactive
                    ? (details) {
                        _stopKeys();
                        final hit = CafeRenderer.pick(
                          details.localPosition,
                          camera,
                          size,
                          c.world,
                        );
                        if (widget.editing) {
                          final selected = c.world.objects[widget.placingId];
                          if (selected != null) {
                            final dir = CafeRenderer.ray(
                              details.localPosition,
                              camera,
                              size,
                            );
                            final frame = selected.kind == CafeObjectKind.frame;
                            final divisor = frame ? dir.z : dir.y;
                            if (divisor.abs() > .00001) {
                              final distance = frame
                                  ? (selected.pivot.z - camera.position.z) /
                                        divisor
                                  : ((selected.kind == CafeObjectKind.floor
                                                ? 0
                                                : selected.pivot.y) -
                                            camera.position.y) /
                                        divisor;
                              if (distance > .075 && distance < 15) {
                                widget.onObjectPlaced?.call(
                                  camera.position + dir * distance,
                                );
                              }
                            }
                          } else if (hit?.objectId != null) {
                            widget.onObjectSelected?.call(hit!.objectId!);
                          }
                          return;
                        }
                        if (hit?.target != null) {
                          _activate(hit!.target!);
                        } else if (hit?.floor == true) {
                          c.walkTo(hit!.position);
                        }
                      }
                    : null,
                onLongPressStart: widget.interactive && !widget.editing
                    ? (details) {
                        final hit = CafeRenderer.pick(
                          details.localPosition,
                          camera,
                          size,
                          c.world,
                        );
                        if (hit?.objectId != null) {
                          widget.onObjectSelected?.call(hit!.objectId!);
                        }
                      }
                    : null,
                onPanUpdate: widget.interactive
                    ? (details) => c.look(
                        details.delta.dx * .004,
                        details.delta.dy * .003,
                      )
                    : null,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CafeRenderer(
                      world: c.world,
                      camera: camera,
                      wood: wood,
                      sign: sign,
                      walnut: walnut,
                      limestone: limestone,
                      woven: woven,
                      plaster: plaster,
                      artwork: artwork,
                      gravel: gravel,
                      tree: tree,
                      flowers: flowers,
                      framedArt: framedArt,
                      time: sceneTime,
                      teaFilled: c.teaFilled,
                      bellAt: c.bellAt,
                      teaAt: c.teaAt,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            ...markers,
          ],
        );
      },
    ),
  );
}
