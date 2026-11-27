import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../audio/user_audio.dart';
import 'paper_sound_effect.dart';

class PaperSoundOutput implements PaperSoundPlayback {
  PaperSoundOutput(List<PaperSoundEffect> effects)
    : _volume = effects.first.volume {
    for (final effect in effects) {
      _bytes[effect] = _readAsset(effect);
    }
    for (final event in _activationEvents) {
      web.document.addEventListener(event, _interaction, true.toJS);
    }
  }

  final double _volume;
  final _session = UserAudioSession();
  final _voices = <web.AudioBufferSourceNode>{};
  final _bytes = <PaperSoundEffect, Future<ByteData?>>{};
  final _buffers = <PaperSoundEffect, web.AudioBuffer>{};

  static const _activationEvents = [
    'pointerdown',
    'pointerup',
    'touchend',
    'keydown',
  ];
  static const _exitFade = Duration(milliseconds: 18);
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
  bool _resuming = false, _closed = false;
  PaperSoundRequest? _pending;
  Timer? _pendingExpiry;

  Future<ByteData?> _readAsset(PaperSoundEffect effect) async {
    try {
      return await rootBundle.load('assets/${effect.asset}');
    } catch (error) {
      if (!_closed) debugPrint('Could not load paper sound: $error');
      return null;
    }
  }

  void _activate() {
    try {
      if (_pending?.canPlay == true) _session.activate();
      var context = _context;
      if (context == null) {
        context = _context = web.AudioContext();
        final gain = _gain = context.createGain();
        gain.gain.value = _volume;
        gain.connect(context.destination);
        for (final entry in _bytes.entries) {
          unawaited(_decode(context, entry.key, entry.value));
        }
      }
      // Resume inside the trusted event, before storage or IME awaits.
      if (context.state != 'running' && !_resuming) {
        unawaited(_resume(context));
      }
    } catch (error) {
      _session.release();
      debugPrint('Paper audio activation failed: $error');
    }
  }

  Future<void> _resume(web.AudioContext context) async {
    _resuming = true;
    try {
      await context.resume().toDart;
      _playPending();
    } catch (error) {
      _session.release();
      if (!_closed) debugPrint('Paper audio activation failed: $error');
    } finally {
      _resuming = false;
    }
  }

  Future<void> _decode(
    web.AudioContext context,
    PaperSoundEffect effect,
    Future<ByteData?> loaded,
  ) async {
    try {
      final bytes = await loaded;
      if (_closed || bytes == null) return;
      final data = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      final buffer = await context
          .decodeAudioData(Uint8List.fromList(data).buffer.toJS)
          .toDart;
      if (!_closed) {
        _buffers[effect] = buffer;
        _playPending();
      }
    } catch (error) {
      if (!_closed) debugPrint('Could not decode paper sound: $error');
    }
  }

  @override
  void play(PaperSoundRequest request) {
    if (_closed || !request.canPlay) return;
    _pending = request;
    _session.activate();
    _pendingExpiry?.cancel();
    _pendingExpiry = Timer(PaperSoundRequest.lifetime, () {
      _clearPending();
      if (_voices.isEmpty) _session.release();
    });
    _playPending();
  }

  void _clearPending() {
    _pending = null;
    _pendingExpiry?.cancel();
    _pendingExpiry = null;
  }

  void _playPending() {
    final context = _context;
    final request = _pending;
    if (_closed || context == null || context.state != 'running') return;
    if (request == null || !request.canPlay) {
      _clearPending();
      if (_voices.isEmpty) _session.release();
      return;
    }
    final buffer = _buffers[request.effect];
    if (buffer == null) return;
    _clearPending();
    web.AudioBufferSourceNode? created;
    try {
      _session.activate();
      final source = created = context.createBufferSource();
      source.buffer = buffer;
      final gain = _gain!;
      gain.gain.cancelScheduledValues(context.currentTime);
      gain.gain.setValueAtTime(_volume, context.currentTime);
      source.connect(gain);
      source.onended = ((web.Event _) {
        source.disconnect();
        _voices.remove(source);
        if (_voices.isEmpty) _session.release();
      }).toJS;
      _voices.add(source);
      source.start();
    } catch (error) {
      if (created != null) {
        _voices.remove(created);
        created.disconnect();
      }
      if (_voices.isEmpty) _session.release();
      debugPrint('Paper sound unavailable: $error');
    }
  }

  @override
  void pause() {
    _clearPending();
    final context = _context;
    if (_voices.isEmpty || context?.state != 'running') {
      _session.release();
      return;
    }
    final at = context!.currentTime;
    final end = at + _exitFade.inMilliseconds / 1000;
    final gain = _gain!.gain;
    gain.cancelScheduledValues(at);
    gain.setValueAtTime(gain.value, at);
    gain.linearRampToValueAtTime(0, end);
    for (final source in _voices) {
      source.stop(end);
    }
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    for (final event in _activationEvents) {
      web.document.removeEventListener(event, _interaction, true.toJS);
    }
    try {
      pause();
      if (_voices.isNotEmpty && _context?.state == 'running') {
        await Future<void>.delayed(_exitFade);
      }
      await _context?.close().toDart;
    } catch (error) {
      debugPrint('Could not release paper sound: $error');
    } finally {
      _session.release();
    }
  }
}
