import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'paper_sound_effect.dart';
import '../audio/user_audio_context.dart';

class PaperSoundOutput implements PaperSoundPlayback {
  PaperSoundOutput(this.effect)
    : _rhythm = effect.loops ? _NativeRhythm(effect) : null {
    if (_rhythm == null) _pool = _preload();
  }

  final PaperSoundEffect effect;
  final _NativeRhythm? _rhythm;
  Future<AudioPool?>? _pool;
  Future<void>? _starting;
  PaperSoundRequest? _pending;
  bool _closed = false;

  Future<AudioPool?> _preload() async {
    try {
      return await AudioPool.create(
        source: AssetSource(effect.asset),
        minPlayers: 2,
        maxPlayers: 6,
        audioContext: _audioContext(),
      );
    } catch (error) {
      if (!_closed) debugPrint('Could not prepare paper sound: $error');
      return null;
    }
  }

  @override
  void play(PaperSoundRequest request) {
    if (_closed) return;
    final rhythm = _rhythm;
    if (rhythm != null) {
      rhythm.play(request);
      return;
    }
    _pending = request;
    _starting ??= _start();
  }

  Future<void> _start() async {
    try {
      final pool = await (_pool ??= _preload());
      final request = _pending;
      _pending = null;
      if (_closed) return;
      if (pool == null) {
        _pool = null;
        return;
      }
      if (request != null && request.canPlay) {
        await pool.start(volume: effect.volume);
      }
    } catch (error) {
      if (!_closed) debugPrint('Paper sound unavailable: $error');
    } finally {
      _starting = null;
      if (!_closed && _pending != null) _starting = _start();
    }
  }

  @override
  void pause() => _rhythm?.pause();

  @override
  Future<void> dispose() async {
    _closed = true;
    final rhythm = _rhythm;
    if (rhythm != null) return rhythm.dispose();
    _pending = null;
    try {
      await _starting;
      final pool = await _pool;
      await pool?.dispose();
    } catch (error) {
      debugPrint('Could not release paper sound: $error');
    }
  }
}

AudioContext _audioContext() => AudioContext(
  android: const AudioContextAndroid(
    audioFocus: AndroidAudioFocus.none,
    usageType: AndroidUsageType.assistanceSonification,
  ),
  iOS: userAudioIOS(),
);

/// A single looping voice. Changes in activity invalidate an in-flight fade.
class _NativeRhythm {
  _NativeRhythm(this.effect) {
    _ready = _prepare();
  }

  final PaperSoundEffect effect;
  Future<AudioPlayer?>? _ready;
  Future<void> _commands = Future<void>.value();
  PaperSoundRequest? _pending;
  bool _wanted = false, _playing = false, _closed = false;
  int _revision = 0;
  double _volume = 1;

  Future<AudioPlayer?> _prepare() async {
    final player = AudioPlayer();
    try {
      await player.setAudioContext(_audioContext());
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(AssetSource(effect.asset));
      await player.seek(writingPencilLeadIn);
      return player;
    } catch (error) {
      if (!_closed) debugPrint('Could not prepare writing rhythm: $error');
      try {
        await player.dispose();
      } catch (_) {
        // Initialization can fail before a platform player is available.
      }
      return null;
    }
  }

  void play(PaperSoundRequest request) {
    if (_closed) return;
    _pending = request;
    if (_wanted) return;
    _wanted = true;
    final revision = ++_revision;
    _schedule(revision, () async {
      final player = await (_ready ??= _prepare());
      if (revision != _revision) return;
      if (player == null) {
        _ready = null;
        _wanted = false;
        return;
      }
      if (_pending?.canPlay != true) {
        _wanted = false;
        if (_playing) pause();
        return;
      }
      if (_playing) {
        await _ramp(player, effect.volume, writingRhythmResumeFade, revision);
      } else {
        await _setVolume(player, 0);
        if (revision != _revision) return;
        await player.resume();
        _playing = true;
        await _ramp(player, effect.volume, writingRhythmResumeFade, revision);
      }
    });
  }

  void pause() {
    if (_closed || (!_wanted && !_playing)) return;
    _pending = null;
    _wanted = false;
    final revision = ++_revision;
    _schedule(revision, () async {
      final player = await _ready;
      if (player == null || !_playing || revision != _revision) return;
      await _ramp(player, 0, writingRhythmFade, revision);
      if (revision != _revision) return;
      // Pause retains the recording position between short writing gestures.
      await player.pause();
      _playing = false;
    });
  }

  Future<void> _setVolume(AudioPlayer player, double level) async {
    await player.setVolume(level);
    _volume = level;
  }

  Future<void> _ramp(
    AudioPlayer player,
    double target,
    Duration duration,
    int revision,
  ) async {
    const steps = 8;
    final from = _volume;
    final step = Duration(microseconds: duration.inMicroseconds ~/ steps);
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(step);
      if (revision != _revision) return;
      await _setVolume(player, from + (target - from) * i / steps);
    }
  }

  void _schedule(int revision, Future<void> Function() action) {
    _commands = _commands.then((_) async {
      if (revision != _revision) return;
      try {
        await action();
      } catch (error) {
        if (revision == _revision) _wanted = false;
        debugPrint('Writing rhythm unavailable: $error');
      }
    });
  }

  Future<void> dispose() {
    _closed = true;
    _pending = null;
    final revision = ++_revision;
    _schedule(revision, () async {
      final player = await _ready;
      if (player == null) return;
      try {
        if (_playing) {
          await _ramp(player, 0, writingRhythmExitFade, revision);
        }
      } finally {
        await player.dispose();
      }
    });
    return _commands;
  }
}
