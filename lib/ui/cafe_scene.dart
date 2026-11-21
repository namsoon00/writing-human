import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cafe/cafe_camera.dart';
import '../cafe/cafe_renderer.dart';
import '../cafe/cafe_view_controller.dart';
import '../cafe/cafe_visit.dart';
import 'paper.dart';

/// A real, perspective-projected room seen through an eye-height camera.
class CafeScene extends StatefulWidget {
  const CafeScene({
    super.key,
    required this.controller,
    this.interactive = true,
    this.onSeatSelected,
  });
  final CafeViewController controller;
  final bool interactive;
  final ValueChanged<CafeSeat>? onSeatSelected;
  @override
  State<CafeScene> createState() => _CafeSceneState();
}

class _CafeSceneState extends State<CafeScene>
    with SingleTickerProviderStateMixin {
  final focus = FocusNode(debugLabel: '카페 둘러보기');
  late final AnimationController travel;
  late CafeCamera from;
  CafeCamera? to;
  int request = 0;
  ui.Image? wood, garden, sign;

  @override
  void initState() {
    super.initState();
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
    final title = TextPainter(
      text: const TextSpan(
        text: '쓰는 인간',
        style: TextStyle(
          fontFamily: appFontFamily,
          fontFamilyFallback: appFontFallback,
          fontSize: 105,
          color: brandInk,
          letterSpacing: 5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset((768 - title.width) / 2, 65));
    final caption = TextPainter(
      text: const TextSpan(
        text: '오늘도, 한 문장',
        style: TextStyle(
          fontFamily: appFontFamily,
          fontFamilyFallback: appFontFallback,
          fontSize: 33,
          color: muted,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    caption.paint(canvas, Offset((768 - caption.width) / 2, 218));
    final picture = recorder.endRecording();
    final image = await picture.toImage(768, 336);
    picture.dispose();
    title.dispose();
    caption.dispose();
    return image;
  }

  Future<void> _loadMaterials() async {
    final images = await Future.wait([
      _texture('cafe-oak-albedo.png'),
      _texture('cafe-garden-view.png'),
      _makeSign(),
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
      to = c.destination;
      if (to != null) {
        from = c.camera;
        if (MediaQuery.disableAnimationsOf(context)) {
          to = null;
          c.updateCamera(c.destination!);
        } else {
          travel.forward(from: 0);
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _travelFrame() {
    if (to == null) return;
    widget.controller.updateCamera(
      CafeCamera.interpolate(
        from,
        to!,
        Curves.easeInOutCubic.transform(travel.value),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    travel.dispose();
    focus.dispose();
    wood?.dispose();
    garden?.dispose();
    sign?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyboardListener(
    focusNode: focus,
    onKeyEvent: widget.interactive
        ? (event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
            final key = event.logicalKey;
            final c = widget.controller;
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
          }
        : null,
    child: Semantics(
      label: '1인칭 카페, 화면을 끌어 둘러보기',
      child: GestureDetector(
        key: const ValueKey('cafe-first-person-view'),
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.interactive ? (_) => focus.requestFocus() : null,
        onTapUp: widget.interactive
            ? (details) {
                final seat = CafeRenderer.pickSeat(
                  details.localPosition,
                  widget.controller.camera,
                  context.size!,
                );
                if (seat != null) widget.onSeatSelected?.call(seat);
              }
            : null,
        onPanUpdate: widget.interactive
            ? (details) => widget.controller.look(
                details.delta.dx * .004,
                details.delta.dy * .003,
              )
            : null,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: CafeRenderer(
              world: widget.controller.world,
              camera: widget.controller.camera,
              wood: wood,
              garden: garden,
              sign: sign,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    ),
  );
}
