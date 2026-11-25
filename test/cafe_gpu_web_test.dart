@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

@JS('globalThis.writingCafeGpuCreate')
external JSFunction? get _factory;
@JS('globalThis.writingCafeGpuCreate')
external set _factory(JSFunction? value);
@JS('globalThis.writingCafeGpuCreate')
external _Gpu? _create(web.HTMLCanvasElement canvas);
extension type _Gpu(JSObject _) implements JSObject {
  external void texture(
    JSString key,
    JSNumber w,
    JSNumber h,
    JSUint8Array data,
    JSBoolean clamp,
  );
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
    JSNumber w,
    JSNumber h,
    JSNumber ratio,
    JSAny? rooms,
    JSNumber omit,
    JSNumber buildMs,
  );
  external void dispose();
}
extension type _Gl(JSObject _) implements JSObject {
  external void readPixels(
    JSNumber x,
    JSNumber y,
    JSNumber w,
    JSNumber h,
    JSNumber format,
    JSNumber type,
    JSUint8Array destination,
  );
  external JSNumber getError();
}
Float32List panel(double z, List<double> color, double id) =>
    Float32List.fromList([
      for (final p in [
        [-.8, -.8],
        [.8, -.8],
        [.8, .8],
        [-.8, -.8],
        [.8, .8],
        [-.8, .8],
      ]) ...[p[0], p[1], z, 0, 0, 1, .5, .5, ...color, 1, id, 2, 0],
    ]);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  web.HTMLScriptElement? script;
  JSFunction? previous;
  setUpAll(() async {
    previous = _factory;
    final loaded = Completer<void>();
    script = web.HTMLScriptElement()..src = '/support/cafe_gpu.js';
    script!.addEventListener('load', ((web.Event e) => loaded.complete()).toJS);
    script!.addEventListener(
      'error',
      ((web.Event e) => loaded.completeError(
        StateError('Renderer fixture could not load'),
      )).toJS,
    );
    web.document.head!.appendChild(script!);
    await loaded.future.timeout(const Duration(seconds: 15));
  });
  tearDownAll(() {
    script?.remove();
    _factory = previous;
  });
  testWidgets(
    'Real WebGL compiles and preserves depth, held-item visibility and alpha cutouts',
    (tester) async {
      await tester.runAsync(() async {
        final canvas = web.HTMLCanvasElement();
        if (canvas.getContext('webgl2') == null) {
          expect(_create(canvas), isNull);
          markTestSkipped(
            'Flutter headless Chrome disables GPU; actual release GPU is verified separately.',
          );
          return;
        }
        final gpu = _create(canvas);
        expect(gpu, isNotNull);
        final gl = _Gl(canvas.getContext('webgl2')!);
        final camera = Float32List.fromList([
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          -1,
          1,
          1,
        ]).toJS;
        final config = [
          {
            'outside': true,
            'mood': 0,
            'lamps': <double>[],
            'walls': <double>[],
            'tint': [1.0, 1.0, 1.0],
            'lampScale': 1.0,
            'brightness': 1.0,
            'warmth': .5,
          },
        ].jsify();
        void draw([double omit = 0]) => gpu!.draw(
          camera,
          64.toJS,
          64.toJS,
          1.toJS,
          config,
          omit.toJS,
          0.toJS,
        );
        Uint8List pixel() {
          final out = Uint8List(4);
          gl.readPixels(
            32.toJS,
            32.toJS,
            1.toJS,
            1.toJS,
            6408.toJS,
            5121.toJS,
            out.toJS,
          );
          return out;
        }

        try {
          gpu!.batch(
            'none:red'.toJS,
            panel(-2, [1, 0, 0, 1], 1).toJS,
            0.toJS,
            false.toJS,
            false.toJS,
          );
          gpu.batch(
            'none:blue'.toJS,
            panel(-4, [0, 0, 1, 1], 2).toJS,
            0.toJS,
            false.toJS,
            false.toJS,
          );
          draw();
          expect(
            pixel().take(3),
            [255, 0, 0],
            reason: 'Far polygons must not overpaint a nearer object',
          );
          gpu.begin();
          gpu.dynamic(
            'none:held'.toJS,
            panel(-1.5, [0, 1, 0, 1], 0).toJS,
            0.toJS,
            false.toJS,
            false.toJS,
          );
          draw(1);
          expect(
            pixel().take(3),
            [0, 255, 0],
            reason: 'Omitting the static cup must retain its held replacement',
          );
          gpu.begin();
          draw(1);
          expect(pixel().take(3), [0, 0, 255]);
          gpu.texture(
            'mask'.toJS,
            1.toJS,
            1.toJS,
            Uint8List.fromList([255, 255, 0, 0]).toJS,
            true.toJS,
          );
          gpu.batch(
            'mask:foliage'.toJS,
            panel(-1, [1, 1, 1, 1], 0).toJS,
            0.toJS,
            false.toJS,
            true.toJS,
          );
          draw();
          expect(
            pixel().take(3),
            [255, 0, 0],
            reason: 'Transparent foliage pixels must not write depth',
          );
          gpu.texture(
            'mask'.toJS,
            1.toJS,
            1.toJS,
            Uint8List.fromList([255, 255, 0, 255]).toJS,
            true.toJS,
          );
          draw();
          expect(pixel().take(3), [255, 255, 0]);
          expect(gl.getError().toDartInt, 0);
        } finally {
          gpu?.dispose();
        }
      });
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
