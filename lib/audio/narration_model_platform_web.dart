import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
// ignore: implementation_imports
import 'package:flutter_onnxruntime/src/flutter_onnxruntime_platform_interface.dart';
import 'package:web/web.dart' as web;

import 'narration_model_assets.dart';

const _runtimeBase =
    'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.22.0/dist/';
Future<void>? _runtime;

@JS('ort.env.wasm')
external JSObject get _wasm;

@JS('BigInt')
external JSBigInt _bigInt(JSAny value);

Future<void> prepareRuntime() => _runtime ??= _loadRuntime().then<void>(
  (_) {},
  onError: (Object error, StackTrace stack) {
    _runtime = null;
    Error.throwWithStackTrace(error, stack);
  },
);

Future<void> _loadRuntime() async {
  final loaded = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = '${_runtimeBase}ort.wasm.min.js'
    ..integrity =
        'sha384-epp8GDQUoLKx5qHa6SoDHKv7fSHILsEYk4uEsHdPRBztXEIVWCe/lhhrQJUBMZcf'
    ..crossOrigin = 'anonymous'
    ..onload = ((web.Event _) => loaded.complete()).toJS
    ..onerror = ((web.Event _) => loaded.completeError(
      StateError('Runtime unavailable'),
    )).toJS;
  web.document.head!.append(script);
  try {
    await loaded.future.timeout(const Duration(seconds: 30));
    _wasm
      ..setProperty('wasmPaths'.toJS, _runtimeBase.toJS)
      ..setProperty('numThreads'.toJS, 1.toJS);
  } finally {
    script.remove();
  }
}

Future<OrtValue> narrationIds(List<int> ids) async {
  final value = await FlutterOnnxruntimePlatform.instance.createOrtValue(
    'int64',
    ids.map((item) => _bigInt(item.toJS)).toList(growable: false),
    [1, ids.length],
  );
  return OrtValue.fromMap(value);
}

class NarrationAssetLoader {
  NarrationAssetLoader(this.stopped);

  final Future<void> stopped;

  Future<String> readText(ModelAsset asset) async =>
      (await (await _blob(asset)).text().toDart).toDart;

  Future<OrtSession> openSession(ModelAsset asset) async {
    final url = web.URL.createObjectURL(await _blob(asset));
    try {
      return await OnnxRuntime().createSession(url);
    } finally {
      web.URL.revokeObjectURL(url);
    }
  }

  Future<web.Blob> _blob(ModelAsset asset) async {
    final url = narrationModelUri(asset).toString().toJS;
    web.Cache? cache;
    try {
      cache = await web.window.caches
          .open('writing-human-supertonic3-aafc6e3')
          .toDart;
      final existing = await cache.match(url).toDart;
      if (existing != null) {
        final blob = await existing.blob().toDart;
        if (blob.size == asset.size) return blob;
        await cache.delete(url).toDart;
      }
    } catch (_) {
      // Private browsing and low disk space can disable the browser cache.
    }
    final abort = web.AbortController();
    unawaited(stopped.then((_) => abort.abort()));
    final response = await web.window
        .fetch(url, web.RequestInit(signal: abort.signal, credentials: 'omit'))
        .toDart;
    if (!response.ok) throw StateError('Model download failed');
    final blob = await response.blob().toDart;
    if (blob.size != asset.size) {
      throw const FormatException('Invalid model file');
    }
    if (cache != null) {
      try {
        await cache.put(url, web.Response(blob)).toDart;
      } catch (_) {
        // This playback can use the downloaded model even without a cache.
      }
    }
    return blob;
  }
}
