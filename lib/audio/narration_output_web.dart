import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'user_audio.dart';

class NarrationOutput {
  web.AudioContext? _context;
  final _session = UserAudioSession();

  Future<void> ready() async {
    _session.activate();
    try {
      final context = _context ??= web.AudioContext();
      if (context.state != 'running') {
        await context.resume().toDart.timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      _session.release();
      rethrow;
    }
  }

  Future<void> play(
    Uint8List wav,
    Future<void> stopped,
    void Function() onStart,
  ) async {
    _session.activate();
    web.AudioBufferSourceNode? source;
    try {
      final context = _context!;
      final buffer = await context.decodeAudioData(wav.buffer.toJS).toDart;
      if (_context != context) return;
      final ended = Completer<void>();
      source = context.createBufferSource()
        ..buffer = buffer
        ..onended = ((web.Event _) => ended.complete()).toJS
        ..connect(context.destination);
      source.start();
      onStart();
      await Future.any([ended.future, stopped]);
    } finally {
      if (source != null) {
        source.onended = null;
        source.disconnect();
      }
      _session.release();
    }
  }

  Future<void> close() async {
    final context = _context;
    _context = null;
    try {
      await context?.close().toDart;
    } finally {
      _session.release();
    }
  }
}
