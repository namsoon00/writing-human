import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'paper_sound_effect.dart';

class PaperSoundOutput {
  PaperSoundOutput(this.effect) {
    _bytes = _readAsset();
    for (final event in _activationEvents) {
      web.document.addEventListener(event, _interaction, true.toJS);
    }
  }

  final PaperSoundEffect effect;
  late final Future<ByteData?> _bytes;

  static const _activationEvents = [
    'pointerdown',
    'pointerup',
    'touchend',
    'keydown',
  ];
  late final JSFunction _interaction = ((web.Event event) {
    if (_closed || !event.isTrusted) return;
    if (event.type == 'pointerdown' &&
        (event as web.PointerEvent).pointerType != 'mouse') {
      return;
    }
    _activate();
  }).toJS;

  web.AudioContext? _context;
  web.GainNode? _gain;
  web.AudioBuffer? _buffer;
  bool _resuming = false, _closed = false;
  PaperSoundRequest? _pending;

  Future<ByteData?> _readAsset() async {
    try {
      return await rootBundle.load('assets/${effect.asset}');
    } catch (error) {
      if (!_closed) debugPrint('Could not load paper sound: $error');
      return null;
    }
  }

  void _activate() {
    try {
      var context = _context;
      if (context == null) {
        context = _context = web.AudioContext();
        final gain = _gain = context.createGain();
        gain.gain.value = effect.volume;
        gain.connect(context.destination);
        unawaited(_decode(context));
      }
      // Resume inside the trusted event, before page storage or IME awaits.
      if (context.state != 'running' && !_resuming) {
        unawaited(_resume(context));
      }
    } catch (error) {
      debugPrint('Paper audio activation failed: $error');
    }
  }

  Future<void> _resume(web.AudioContext context) async {
    _resuming = true;
    try {
      await context.resume().toDart;
      _playPending();
    } catch (error) {
      if (!_closed) debugPrint('Paper audio activation failed: $error');
    } finally {
      _resuming = false;
    }
  }

  Future<void> _decode(web.AudioContext context) async {
    try {
      final bytes = await _bytes;
      if (_closed || bytes == null) return;
      final data = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      final buffer = await context
          .decodeAudioData(Uint8List.fromList(data).buffer.toJS)
          .toDart;
      if (!_closed) {
        _buffer = buffer;
        _playPending();
      }
    } catch (error) {
      if (!_closed) debugPrint('Could not decode paper sound: $error');
    }
  }

  void play(PaperSoundRequest request) {
    if (_closed) return;
    _pending = request;
    _playPending();
  }

  void _playPending() {
    final context = _context;
    final buffer = _buffer;
    if (_closed ||
        context == null ||
        context.state != 'running' ||
        buffer == null) {
      return;
    }
    final request = _pending;
    _pending = null;
    if (request == null || !request.canPlay) return;
    try {
      final source = context.createBufferSource();
      source.buffer = buffer;
      source.connect(_gain!);
      source.onended = ((web.Event _) => source.disconnect()).toJS;
      source.start();
    } catch (error) {
      debugPrint('Paper sound unavailable: $error');
    }
  }

  Future<void> dispose() async {
    _closed = true;
    _pending = null;
    for (final event in _activationEvents) {
      web.document.removeEventListener(event, _interaction, true.toJS);
    }
    try {
      await _context?.close().toDart;
    } catch (error) {
      debugPrint('Could not release paper sound: $error');
    }
  }
}
