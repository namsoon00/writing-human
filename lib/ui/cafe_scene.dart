import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import '../cafe/cafe_camera.dart';
import '../cafe/cafe_renderer.dart';
import '../cafe/cafe_view_controller.dart';
import '../cafe/cafe_visit.dart';
import '../cafe/cafe_world.dart';
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
  });
  final CafeViewController controller;
  final bool interactive;
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
  late final Ticker calm;
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
  }

  void _syncCalm() {
    final animate =
        mounted &&
        appActive &&
        widget.controller.inCourtyard &&
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
  ui.Image? wood, garden, sign, walnut, limestone, woven;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  Future<ui.Image?> _texture(String name) async {
    try {
      final data = await rootBundle.load('assets/images/$name');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 768,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (error) {
      debugPrint('Cafe material unavailable: $error');
      return null;
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

  Future<ui.Image?> _makeWovenCord() async {
    final recorder = ui.PictureRecorder(), canvasSize = 256;
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xffc9ab7c), BlendMode.src);
    final paint = Paint()..strokeWidth = 3;
    // A repeatable cord weave, at a 0.62 m physical scale in the renderer.
    for (var i = 0; i < canvasSize; i += 4) {
      paint.color = const Color(0xffab8d60);
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), 256),
        paint,
      );
      paint.color = const Color(0xffe0c698);
      canvas.drawLine(Offset(i + 1.0, 0), Offset(i + 1.0, 256), paint);
      for (var j = 0; j < canvasSize; j += 8) {
        final y = j + ((i ~/ 4).isEven ? 0 : 4);
        paint.color = const Color(0xffdbc092);
        canvas.drawLine(
          Offset(i - 1.0, y.toDouble()),
          Offset(i + 3.0, y.toDouble()),
          paint,
        );
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 256);
    picture.dispose();
    return image;
  }

  Future<void> _loadMaterials() async {
    final images = await Future.wait([
      _texture('cafe-oak-longgrain.jpg'),
      _texture('cafe-garden-view.png'),
      _makeSign(),
      _texture('cafe-walnut-longgrain.jpg'),
      _texture('cafe-limestone-albedo.jpg'),
      _makeWovenCord(),
    ]);
    if (!mounted) {
      for (final image in images) {
        image?.dispose();
      }
      return;
    }
    setState(() {
      wood = images[0];
      garden = images[1];
      sign = images[2];
      walnut = images[3];
      limestone = images[4];
      woven = images[5];
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
      route = [c.camera, ...c.journey];
      if (c.destination != null) {
        if (MediaQuery.disableAnimationsOf(context)) {
          c.updateCamera(c.destination!);
          c.finishTravel();
        } else {
          lengths = [];
          total = 0;
          for (var i = 1; i < route.length; i++) {
            final length = math.max(
              .18,
              (route[i].position - route[i - 1].position).length,
            );
            lengths.add(length);
            total += length;
          }
          travel.duration = Duration(
            milliseconds: (total / 1.85 * 1000).round().clamp(450, 6500),
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
    var distance = Curves.easeInOut.transform(travel.value) * total;
    var segment = 0;
    while (segment < lengths.length - 1 && distance > lengths[segment]) {
      distance -= lengths[segment];
      segment++;
    }
    widget.controller.updateCamera(
      CafeCamera.interpolate(
        route[segment],
        route[segment + 1],
        (distance / lengths[segment]).clamp(0, 1),
      ),
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
    widget.controller.removeListener(_changed);
    travel.dispose();
    focus.dispose();
    wood?.dispose();
    garden?.dispose();
    sign?.dispose();
    walnut?.dispose();
    limestone?.dispose();
    woven?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyboardListener(
    focusNode: focus,
    onKeyEvent: widget.interactive
        ? (event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
            final key = event.logicalKey, c = widget.controller;
            if (key == LogicalKeyboardKey.keyW ||
                key == LogicalKeyboardKey.arrowUp) {
              c.step(0, .24);
            }
            if (key == LogicalKeyboardKey.keyS ||
                key == LogicalKeyboardKey.arrowDown) {
              c.step(0, -.24);
            }
            if (key == LogicalKeyboardKey.keyA) c.step(-.24, 0);
            if (key == LogicalKeyboardKey.keyD) c.step(.24, 0);
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
        final markers = <Widget>[];
        if (widget.interactive && !c.travelling && !c.resting) {
          for (final target in c.world.targets) {
            if (c.seat != null && target.seat != c.seat && !c.inCourtyard) {
              continue;
            }
            final anchor = target.seat == c.seat && c.seat != null
                ? CafeWorld.desk(c.seat!)
                : CafeWorld.anchor(target);
            final point = CafeRenderer.project(anchor, c.camera, size);
            if (point == null ||
                point.dx < 35 ||
                point.dx > size.width - 35 ||
                point.dy < 130 ||
                point.dy > size.height - 56 ||
                (anchor - c.camera.position).length > 6.5) {
              continue;
            }
            final hit = CafeRenderer.pick(point, c.camera, size, c.world);
            if (hit?.target != target) continue;
            final writing = target.seat != null && c.seat == target.seat;
            final label = writing ? '노트 펼치기' : target.label;
            final width = math.min(172.0, size.width - 32);
            markers.add(
              Positioned(
                left: (point.dx - width / 2).clamp(8, size.width - width - 8),
                top: point.dy - 18,
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
                        backgroundColor: const Color(0xbb3d3026),
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
                        if (c.travelling) return;
                        final hit = CafeRenderer.pick(
                          details.localPosition,
                          c.camera,
                          size,
                          c.world,
                        );
                        if (hit?.target != null) {
                          _activate(hit!.target!);
                        } else if (hit?.floor == true) {
                          c.walkTo(hit!.position);
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
                      camera: c.camera,
                      wood: wood,
                      garden: garden,
                      sign: sign,
                      walnut: walnut,
                      limestone: limestone,
                      woven: woven,
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
