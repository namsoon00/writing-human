import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:flutter/services.dart';

class VoiceStretch {
  web.Worker? _worker;
  Future<web.Worker>? _opening;
  final _urls = <String>[];
  bool _closed = false;
  int _request = 0;
  final _pending = <int, Completer<Float32List>>{};

  Future<Float32List> process(
    Float32List input,
    int rate,
    double speed,
    double pitch,
    void Function() check,
  ) async {
    check();
    if (_closed) throw StateError('Voice processor closed');
    final worker = await (_opening ??= _open());
    check();
    if (_closed) throw StateError('Voice processor closed');
    final id = ++_request;
    final result = Completer<Float32List>();
    _pending[id] = result;
    final samples = Float32List.fromList(input);
    worker.postMessage(
      {
        'id': id,
        'samples': samples.buffer.toJS,
        'rate': rate,
        'speed': speed,
        'pitch': pitch,
      }.jsify(),
    );
    try {
      final value = await result.future.timeout(const Duration(seconds: 60));
      check();
      return value;
    } finally {
      _pending.remove(id);
    }
  }

  Future<web.Worker> _open() async {
    try {
      final sources = await Future.wait([
        rootBundle.loadString('assets/audio/dsp/signalsmith_factory.mjs'),
        rootBundle.loadString('assets/audio/dsp/voice_worker.mjs'),
      ]);
      if (_closed) throw StateError('Voice processor closed');
      String moduleUrl(String source) {
        final url = web.URL.createObjectURL(
          web.Blob(
            [source.toJS].toJS,
            web.BlobPropertyBag(type: 'text/javascript'),
          ),
        );
        _urls.add(url);
        return url;
      }

      final factory = moduleUrl(sources[0]);
      final url = moduleUrl(
        sources[1].replaceFirst('./signalsmith_factory.mjs', factory),
      );
      final worker = web.Worker(url.toJS, web.WorkerOptions(type: 'module'));
      worker.onmessage = ((web.MessageEvent event) {
        final data = event.data as JSObject;
        final id = data.getProperty<JSNumber>('id'.toJS).toDartInt;
        final pending = _pending[id];
        if (pending == null || pending.isCompleted) return;
        final error = data.getProperty<JSAny?>('error'.toJS);
        if (error != null) {
          pending.completeError(StateError((error as JSString).toDart));
        } else {
          pending.complete(
            (data.getProperty<JSArrayBuffer>(
              'samples'.toJS,
            )).toDart.asFloat32List(),
          );
        }
      }).toJS;
      worker.onerror = ((web.Event _) {
        _fail(StateError('Voice worker unavailable'));
      }).toJS;
      _worker = worker;
      return worker;
    } catch (_) {
      _release();
      rethrow;
    }
  }

  void _fail(Object error) {
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
    _release();
  }

  void _release() {
    _worker?.terminate();
    _worker = null;
    _opening = null;
    for (final url in _urls) {
      web.URL.revokeObjectURL(url);
    }
    _urls.clear();
  }

  Future<void> close() async {
    _closed = true;
    _fail(StateError('Voice processor stopped'));
  }
}
