import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

class WritingSound {
  WritingSound() {
    for (final event in _activationEvents) {
      web.document.addEventListener(event, _interaction, true.toJS);
    }
  }

  static const _activationEvents = [
    'pointerdown',
    'pointerup',
    'touchend',
    'keydown',
  ];
  late final JSFunction _interaction = ((web.Event event) {
    if (!event.isTrusted || _closed || _context?.state == 'running') return;
    if (event.type == 'pointerdown' &&
        (event as web.PointerEvent).pointerType != 'mouse') {
      return;
    }
    _activate();
  }).toJS;

  web.AudioContext? _context;
  web.GainNode? _gain;
  web.AudioBuffer? _buffer;
  web.AudioBufferSourceNode? _playing;
  double _nextStroke = 0;
  bool _closed = false;
  ({bool Function() isFocused, DateTime expires})? _pending;

  void _activate() {
    try {
      var context = _context;
      if (context == null) {
        context = _context = web.AudioContext();
        final gain = _gain = context.createGain();
        gain.gain.value = .68;
        gain.connect(context.destination);
        unawaited(_load(context));
      }
      // Start the resume request in the browser's trusted event handler.
      // Asset loading and IME updates can occur after activation expires.
      if (context.state != 'running') {
        unawaited(_resume(context));
      }
    } catch (error) {
      debugPrint('Writing audio activation failed: $error');
    }
  }

  Future<void> _resume(web.AudioContext context) async {
    try {
      await context.resume().toDart;
      _playPending();
    } catch (error) {
      if (!_closed) debugPrint('Writing audio activation failed: $error');
    }
  }

  Future<void> _load(web.AudioContext context) async {
    try {
      final bytes = await rootBundle.load('assets/audio/pencil-stroke.wav');
      if (_closed) return;
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
      if (!_closed) debugPrint('Writing audio could not be loaded: $error');
    }
  }

  Future<void> stroke(bool Function() isFocused) async {
    if (_closed || !isFocused()) return;
    if (_context?.state != 'running' || _buffer == null) {
      _pending = (
        isFocused: isFocused,
        expires: DateTime.now().add(const Duration(milliseconds: 200)),
      );
      return;
    }
    _play();
  }

  void _playPending() {
    if (_closed || _context?.state != 'running' || _buffer == null) return;
    final pending = _pending;
    _pending = null;
    if (pending != null &&
        DateTime.now().isBefore(pending.expires) &&
        pending.isFocused()) {
      _play();
    }
  }

  void _play() {
    final context = _context!;
    if (context.currentTime < _nextStroke) return;
    try {
      final source = context.createBufferSource();
      source.buffer = _buffer;
      source.connect(_gain!);
      source.onended = ((web.Event _) {
        source.disconnect();
        if (_playing == source) _playing = null;
      }).toJS;
      _nextStroke = context.currentTime + .130;
      _playing = source;
      source.start();
    } catch (error) {
      debugPrint('Writing sound unavailable: $error');
    }
  }

  Future<void> dispose() async {
    _closed = true;
    _pending = null;
    for (final event in _activationEvents) {
      web.document.removeEventListener(event, _interaction, true.toJS);
    }
    final context = _context;
    try {
      _playing?.stop();
      if (context != null) await context.close().toDart;
    } catch (error) {
      debugPrint('Could not release writing audio: $error');
    }
  }
}
