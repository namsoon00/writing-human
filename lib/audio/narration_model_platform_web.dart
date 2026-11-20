import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:crypto/crypto.dart' as crypto;
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

  Future<String> readText(
    ModelAsset asset,
    void Function(int) progress,
  ) async => (await (await _blob(asset, progress)).text().toDart).toDart;

  Future<OrtSession> openSession(
    ModelAsset asset,
    void Function(int) progress,
  ) async {
    final url = web.URL.createObjectURL(await _blob(asset, progress));
    try {
      return await OnnxRuntime().createSession(url);
    } finally {
      web.URL.revokeObjectURL(url);
    }
  }

  Future<web.Blob?> _cached(web.Cache cache, JSString url, int size) async {
    final response = await cache.match(url).toDart;
    if (response == null) return null;
    final blob = await response.blob().toDart;
    if (blob.size == size) return blob;
    await cache.delete(url).toDart;
    return null;
  }

  Future<web.Blob> _blob(ModelAsset asset, void Function(int) progress) async {
    final url = narrationModelUri(asset).toString().toJS;
    web.Cache? cache;
    try {
      cache = await web.window.caches
          .open('writing-human-supertonic3-aafc6e3')
          .toDart;
      final existing = await _cached(cache, url, asset.size);
      if (existing != null) return existing;
      if (narrationOriginalSizes[asset.path] case final originalSize?) {
        final originalUrl = narrationModelUri(
          asset,
          original: true,
        ).toString().toJS;
        final original = await _cached(cache, originalUrl, originalSize);
        if (original != null) return original;
      }
    } catch (_) {
      // Private browsing and low disk space can disable the browser cache.
    }
    final abort = web.AbortController();
    unawaited(stopped.then((_) => abort.abort()));
    final web.Blob blob;
    try {
      final response = await web.window
          .fetch(
            url,
            web.RequestInit(signal: abort.signal, credentials: 'omit'),
          )
          .toDart
          .timeout(const Duration(seconds: 30));
      if (!response.ok) throw StateError('Model download failed');
      final reader =
          response.body?.getReader() as web.ReadableStreamDefaultReader?;
      if (reader == null) throw StateError('Model download has no body');
      final parts = <web.BlobPart>[];
      var received = 0;
      try {
        while (true) {
          final chunk = await reader.read().toDart.timeout(
            const Duration(seconds: 45),
          );
          if (chunk.done) break;
          final bytes = chunk.value as JSUint8Array;
          received += bytes.toDart.length;
          if (received > asset.size) {
            throw const FormatException('Invalid model file');
          }
          parts.add(bytes);
          progress(received);
        }
      } finally {
        reader.releaseLock();
      }
      if (received != asset.size) {
        throw const FormatException('Invalid model file');
      }
      blob = web.Blob(parts.toJS);
      parts.clear();
      final data = await blob.arrayBuffer().toDart;
      final String checksum;
      if (web.window.isSecureContext) {
        final digest =
            await web.window.crypto.subtle.digest('SHA-256'.toJS, data).toDart
                as JSArrayBuffer;
        checksum = digest.toDart
            .asUint8List()
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
      } else {
        checksum = crypto.sha256.convert(data.toDart.asUint8List()).toString();
      }
      if (checksum != asset.sha256) {
        throw const FormatException('Invalid model file');
      }
    } finally {
      abort.abort();
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
