import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import '../cafe/cafe_atmosphere.dart';
import 'cafe_sound_output.dart';

/// One AudioContext for all four loops; activation starts inside the user's tap.
class CafeSoundscape implements CafeSoundOutput {
  CafeSoundscape(this.onError);
  final void Function(Object) onError;
  web.AudioContext? _context;
  final _buffers = <CafeSound, web.AudioBuffer>{};
  final _sources = <CafeSound, web.AudioBufferSourceNode>{};
  final _gains = <CafeSound, web.GainNode>{};
  final _pans = <CafeSound, web.StereoPannerNode>{};
  final _filters = <CafeSound, web.BiquadFilterNode>{};
  CafeSoundFrame? _frame;
  int _generation = 0;
  bool _closed = false;

  @override
  Future<void> start() async {
    if (_closed) return;
    final request = ++_generation;
    final context = _context ??= web.AudioContext();
    // Do this before awaiting asset I/O, while browser activation is available.
    final activation = context.resume().toDart;
    try {
      await activation.timeout(const Duration(seconds: 4));
      await Future.wait(
        CafeSound.values.map((sound) async {
          if (_buffers.containsKey(sound)) return;
          final data = await rootBundle.load(cafeSoundAssets[sound]!);
          final bytes = Uint8List.fromList(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          final buffer = await context
              .decodeAudioData(bytes.buffer.toJS)
              .toDart;
          if (!_closed && request == _generation) _buffers[sound] = buffer;
        }),
      );
      if (_closed || request != _generation) return;
      if (context.state != 'running') throw StateError('Audio needs a new tap');
      _disconnect();
      final at = context.currentTime + .025;
      for (final sound in CafeSound.values) {
        final source = context.createBufferSource();
        source.buffer = _buffers[sound]!;
        source.loop = true;
        final gain = context.createGain()..gain.value = 0;
        final pan = context.createStereoPanner();
        final filter = context.createBiquadFilter()..type = 'lowpass';
        filter.frequency.value = 14000;
        source.connect(filter);
        filter.connect(gain);
        gain.connect(pan);
        pan.connect(context.destination);
        _sources[sound] = source;
        _gains[sound] = gain;
        _pans[sound] = pan;
        _filters[sound] = filter;
        source.start(at);
      }
      if (_frame != null) update(_frame!);
    } catch (error) {
      if (request == _generation) {
        _disconnect();
        rethrow;
      }
    }
  }

  @override
  void update(CafeSoundFrame frame) {
    _frame = frame;
    final context = _context;
    if (_closed || context == null || _sources.isEmpty) return;
    final now = context.currentTime;
    void ramp(web.AudioParam param, double value) {
      if (param.value == value) return;
      final from = param.value;
      param.cancelScheduledValues(now);
      param.setValueAtTime(from, now);
      param.linearRampToValueAtTime(value, now + .30);
    }

    try {
      for (final sound in CafeSound.values) {
        final level = frame.levels[sound]!;
        ramp(_gains[sound]!.gain, level.volume);
        ramp(_pans[sound]!.pan, level.pan);
        ramp(_filters[sound]!.frequency, level.cutoff);
      }
    } catch (error) {
      onError(error);
    }
  }

  void _disconnect() {
    for (final source in _sources.values) {
      try {
        source.stop();
      } catch (_) {
        /* A failed start may not have begun. */
      }
      source.disconnect();
    }
    for (final node in _gains.values) {
      node.gain.value = 0;
      node.disconnect();
    }
    for (final node in _pans.values) {
      node.disconnect();
    }
    for (final node in _filters.values) {
      node.disconnect();
    }
    _sources.clear();
    _gains.clear();
    _pans.clear();
    _filters.clear();
  }

  @override
  Future<void> stop() async {
    _generation++;
    _disconnect();
    final context = _context;
    if (context != null && context.state == 'running') {
      await context.suspend().toDart;
    }
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    _disconnect();
    _buffers.clear();
    final context = _context;
    _context = null;
    if (context != null) await context.close().toDart;
  }
}
