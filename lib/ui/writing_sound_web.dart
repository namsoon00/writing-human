import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'paper_sound_effect.dart';
import '../audio/user_audio.dart';

class PaperSoundOutput implements PaperSoundPlayback {
  PaperSoundOutput(this.effect) {
    _bytes = _readAsset();
    for (final event in _activationEvents) {
      web.document.addEventListener(event, _interaction, true.toJS);
    }
  }

  final PaperSoundEffect effect;
  final _session = UserAudioSession();
  final _voices = <web.AudioBufferSourceNode>{};
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
  web.AudioBufferSourceNode? _rhythm;
  Timer? _fadeStop;
  bool _resuming = false, _closed = false;
  double _offset = writingPencilLeadIn.inMicroseconds / 1000000;
  double _startedAt = 0;
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
      if (_pending?.canPlay == true || _rhythm != null) _session.activate();
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

  Future<void> _decode(web.AudioContext context) async {
    try {
      final bytes = await _bytes;
      if (_closed || bytes == null) {
        if (_voices.isEmpty) _session.release();
        return;
      }
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
      _session.release();
      if (!_closed) debugPrint('Could not decode paper sound: $error');
    }
  }

  @override
  void play(PaperSoundRequest request) {
    if (_closed || !request.canPlay) return;
    _session.activate();
    if (_rhythm != null) {
      if (_fadeStop != null) {
        _fadeStop?.cancel();
        _fadeStop = null;
        _rampRhythm(effect.volume, writingRhythmResumeFade);
      }
      return;
    }
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
    if (request == null || !request.canPlay) {
      if (_voices.isEmpty) _session.release();
      return;
    }
    web.AudioBufferSourceNode? created;
    try {
      _session.activate();
      final source = created = context.createBufferSource();
      source.buffer = buffer;
      if (effect.loops) {
        source.loop = true;
        _gain!.gain.cancelScheduledValues(context.currentTime);
        _gain!.gain.setValueAtTime(0, context.currentTime);
      }
      source.connect(_gain!);
      source.onended = ((web.Event _) {
        source.disconnect();
        if (_rhythm == source) _rhythm = null;
        _voices.remove(source);
        if (_voices.isEmpty) _session.release();
      }).toJS;
      _voices.add(source);
      if (effect.loops) {
        _startedAt = context.currentTime;
        source.start(0, _offset);
        _rhythm = source;
        _rampRhythm(effect.volume, writingRhythmResumeFade);
      } else {
        source.start();
      }
    } catch (error) {
      if (created != null) {
        _voices.remove(created);
        created.disconnect();
      }
      if (_voices.isEmpty) _session.release();
      debugPrint('Paper sound unavailable: $error');
    }
  }

  void _rampRhythm(double volume, Duration duration) {
    final context = _context;
    final gain = _gain?.gain;
    if (context == null || gain == null) return;
    final at = context.currentTime;
    final from = gain.value;
    gain.cancelScheduledValues(at);
    gain.setValueAtTime(from, at);
    gain.linearRampToValueAtTime(volume, at + duration.inMilliseconds / 1000);
  }

  @override
  void pause() {
    _pending = null;
    final source = _rhythm;
    if (source == null) {
      if (_voices.isEmpty) _session.release();
      return;
    }
    if (_closed || _fadeStop != null) return;
    _rampRhythm(0, writingRhythmFade);
    _fadeStop = Timer(writingRhythmFade, () {
      _fadeStop = null;
      final context = _context;
      final buffer = _buffer;
      if (context != null && buffer != null) {
        _offset =
            (_offset + context.currentTime - _startedAt) % buffer.duration;
      }
      _rhythm = null;
      source.stop();
    });
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    _pending = null;
    _fadeStop?.cancel();
    for (final event in _activationEvents) {
      web.document.removeEventListener(event, _interaction, true.toJS);
    }
    try {
      if (_rhythm != null && _context?.state == 'running') {
        _rampRhythm(0, writingRhythmExitFade);
        await Future<void>.delayed(writingRhythmExitFade);
      }
      await _context?.close().toDart;
    } catch (error) {
      debugPrint('Could not release paper sound: $error');
    } finally {
      _session.release();
    }
  }
}
