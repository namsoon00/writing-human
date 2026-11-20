import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class NarrationOutput {
  web.AudioContext? _context;

  Future<void> ready() async {
    final context = _context ??= web.AudioContext();
    if (context.state != 'running') {
      await context.resume().toDart.timeout(const Duration(seconds: 4));
    }
  }

  Future<void> play(
    Uint8List wav,
    Future<void> stopped,
    void Function() onStart,
  ) async {
    final context = _context!;
    final buffer = await context.decodeAudioData(wav.buffer.toJS).toDart;
    if (_context != context) return;
    final ended = Completer<void>();
    final source = context.createBufferSource()
      ..buffer = buffer
      ..onended = ((web.Event _) => ended.complete()).toJS
      ..connect(context.destination);
    try {
      source.start();
      onStart();
      await Future.any([ended.future, stopped]);
    } finally {
      source.onended = null;
      source.disconnect();
    }
  }

  Future<void> close() async {
    final context = _context;
    _context = null;
    await context?.close().toDart;
  }
}
