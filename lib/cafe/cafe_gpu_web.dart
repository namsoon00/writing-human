import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:web/web.dart' as web;
import 'cafe_renderer.dart';
import 'cafe_world.dart';

@JS('globalThis.writingCafeGpuCreate')
external JSFunction? get _factory;
@JS('globalThis.writingCafeGpuCreate')
external _Gpu? _create(web.HTMLCanvasElement canvas);
extension type _Gpu(JSObject _) implements JSObject {
  external void texture(
    JSString id,
    JSNumber w,
    JSNumber h,
    JSUint8Array bytes,
    JSBoolean clamp,
  );
  external void clear();
  external void keepTextures(JSAny? ids);
  external void batch(
    JSString key,
    JSFloat32Array data,
    JSNumber room,
    JSBoolean alpha,
    JSBoolean cutout,
  );
  external void begin();
  external void dynamic(
    JSString key,
    JSFloat32Array data,
    JSNumber room,
    JSBoolean alpha,
    JSBoolean cutout,
  );
  external void draw(
    JSFloat32Array camera,
    JSNumber width,
    JSNumber height,
    JSNumber ratio,
    JSAny? rooms,
    JSNumber omit,
    JSNumber buildMs,
  );
  external void dispose();
}

Widget cafeSurface(CafeRenderer painter) => _factory == null
    ? CustomPaint(painter: painter, size: Size.infinite)
    : _Surface(painter: painter);

class _Surface extends StatefulWidget {
  const _Surface({required this.painter});
  final CafeRenderer painter;
  @override
  State<_Surface> createState() => _SurfaceState();
}

class _SurfaceState extends State<_Surface> {
  _Gpu? gpu;
  CafeGpuGeometry? geometry;
  CafeWorld? world;
  List<ui.Image?> textures = [];
  final uploaded = <ui.Image>{};
  bool failed = false, busy = false, ready = false;
  Size size = Size.zero;
  List<ui.Image?> imageList(CafeRenderer p) => [
    p.wood,
    p.walnut,
    p.limestone,
    p.woven,
    p.knit,
    p.plaster,
    p.artwork,
    p.gravel,
    p.tree,
    p.flowers,
    p.blossom,
    p.lawn,
    p.sign,
    ...p.framedArt,
    p.letterAtlas,
  ];
  @override
  void didUpdateWidget(_Surface old) {
    super.didUpdateWidget(old);
    sync();
  }

  Future<void> sync() async {
    if (!mounted || gpu == null || failed || size.isEmpty || busy) return;
    final p = widget.painter, images = imageList(p);
    final changed =
        (world != p.world && world?.linkedWorld != p.world) ||
        images.length != textures.length ||
        List.generate(
          images.length,
          (i) => i >= textures.length || !identical(images[i], textures[i]),
        ).any((v) => v);
    if (changed) {
      busy = true;
      world = p.world;
      textures = images;
      final g = CafeGpuGeometry(p);
      final fixed = g.staticBatches();
      // Include dynamic-only materials (body cloth, flowers) before uploading.
      g.moving(p);
      try {
        for (var i = 0; i < g.images.length; i++) {
          final source = g.images[i];
          if (uploaded.contains(source)) continue;
          final clone = source.clone();
          try {
            final data = await clone.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            );
            if (!mounted || gpu == null) return;
            if (data != null) {
              gpu!.texture(
                g.imageId(source).toJS,
                source.width.toJS,
                source.height.toJS,
                data.buffer.asUint8List().toJS,
                [
                  p.sign,
                  p.artwork,
                  p.tree,
                  p.flowers,
                  p.blossom,
                  p.letterAtlas,
                  ...p.framedArt,
                ].contains(source).toJS,
              );
            }
          } finally {
            clone.dispose();
          }
        }
        if (!mounted || gpu == null) return;
        gpu!.clear();
        for (final b in fixed) {
          gpu!.batch(
            b.key.toJS,
            b.data.toJS,
            b.room.toJS,
            b.alpha.toJS,
            b.cutout.toJS,
          );
        }
        gpu!.keepTextures(g.images.map(g.imageId).toList().jsify());
        uploaded
          ..clear()
          ..addAll(g.images);
        geometry = g;
        if (!ready) setState(() => ready = true);
      } catch (_) {
        if (mounted) setState(() => failed = true);
      } finally {
        busy = false;
      }
      if (!mounted) return;
      if (!identical(p.world, widget.painter.world) &&
              !identical(p.world.linkedWorld, widget.painter.world) ||
          imageList(
            widget.painter,
          ).asMap().entries.any((e) => !identical(e.value, images[e.key]))) {
        world = null;
        sync();
        return;
      }
    }
    draw();
  }

  void draw() {
    if (!ready || gpu == null || geometry == null || !mounted || failed) return;
    final watch = Stopwatch()..start();
    final p = widget.painter, g = geometry!, camera = g.cameraFor(p);
    gpu!.begin();
    for (final b in g.moving(p)) {
      gpu!.dynamic(
        b.key.toJS,
        b.data.toJS,
        b.room.toJS,
        b.alpha.toJS,
        b.cutout.toJS,
      );
    }
    final f = CafeRenderer.focalLength(size) * camera.lens;
    final c = <double>[
      camera.position.x,
      camera.position.y,
      camera.position.z,
      camera.right.x,
      camera.right.y,
      camera.right.z,
      camera.up.x,
      camera.up.y,
      camera.up.z,
      camera.forward.x,
      camera.forward.y,
      camera.forward.z,
      2 * f / size.width,
      2 * f / size.height,
    ];
    gpu!.draw(
      Float32List.fromList(c).toJS,
      size.width.toJS,
      size.height.toJS,
      MediaQuery.devicePixelRatioOf(context).toJS,
      g.rooms(p).jsify(),
      g.id(p.use?.id).toJS,
      (watch.elapsedMicroseconds / 1000).toJS,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return CustomPaint(painter: widget.painter, size: Size.infinite);
    }
    return LayoutBuilder(
      builder: (context, box) {
        if (size != box.biggest) {
          size = box.biggest;
          WidgetsBinding.instance.addPostFrameCallback((_) => sync());
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            HtmlElementView.fromTagName(
              tagName: 'canvas',
              // This view only draws; Flutter owns walking and orbit gestures.
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
              onElementCreated: (element) {
                final canvas = element as web.HTMLCanvasElement;
                canvas.style
                  ..width = '100%'
                  ..height = '100%'
                  ..pointerEvents = 'none'
                  ..backgroundColor = '#ece4d4';
                canvas.addEventListener(
                  'webglcontextlost',
                  ((web.Event e) {
                    if (mounted) setState(() => failed = true);
                  }).toJS,
                );
                gpu = _create(canvas);
                if (gpu == null) {
                  if (mounted) setState(() => failed = true);
                  return;
                }
                sync();
              },
            ),
            if (!ready) const Center(child: Text('공간을 준비하고 있어요.')),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    gpu?.dispose();
    gpu = null;
    super.dispose();
  }
}
