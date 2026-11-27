import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../audio/user_audio_context.dart';
import 'paper_sound_effect.dart';

class PaperSoundOutput implements PaperSoundPlayback {
  PaperSoundOutput(List<PaperSoundEffect> effects) {
    for (final effect in effects) {
      _pools[effect] = _preload(effect);
    }
  }

  final _pools = <PaperSoundEffect, Future<AudioPool?>>{};
  Future<void>? _starting;
  Future<void>? _silencing;
  PaperSoundRequest? _pending;
  StopFunction? _stopPencil;
  bool _closed = false;
  int _revision = 0;

  Future<AudioPool?> _preload(PaperSoundEffect effect) async {
    try {
      final isPage = effect == PaperSoundEffect.pageTurn;
      return await AudioPool.create(
        source: AssetSource(effect.asset),
        minPlayers: isPage ? 2 : 1,
        maxPlayers: isPage ? 6 : 1,
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
    _pending = request;
    _starting ??= _start();
  }

  Future<void> _start() async {
    try {
      while (!_closed && _pending != null) {
        final request = _pending!;
        final effect = request.effect;
        final pool = await (_pools[effect] ??= _preload(effect));
        if (!identical(_pending, request)) continue;
        _pending = null;
        if (pool == null) {
          _pools.remove(effect);
          continue;
        }
        if (!request.canPlay) continue;
        final revision = _revision;
        final isPencil = effect != PaperSoundEffect.pageTurn;
        if (isPencil) {
          await _silencing;
          await _stopPencil?.call();
          _stopPencil = null;
          if (revision != _revision || !request.canPlay) continue;
        }
        final stop = await pool.start(volume: effect.volume);
        if (isPencil) {
          if (revision == _revision) {
            _stopPencil = stop;
          } else {
            await stop();
          }
        }
      }
    } catch (error) {
      if (!_closed) debugPrint('Paper sound unavailable: $error');
    } finally {
      _starting = null;
      if (!_closed && _pending != null) _starting = _start();
    }
  }

  @override
  void pause() {
    _revision++;
    _pending = null;
    final stop = _stopPencil;
    _stopPencil = null;
    if (stop != null) _silencing = _stop(stop);
  }

  Future<void> _stop(StopFunction stop) async {
    try {
      await stop();
    } catch (error) {
      if (!_closed) debugPrint('Could not stop writing sound: $error');
    }
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    _pending = null;
    _revision++;
    final stop = _stopPencil;
    _stopPencil = null;
    if (stop != null) await _stop(stop);
    await _starting;
    await _silencing;
    for (final pending in _pools.values) {
      try {
        final pool = await pending;
        await pool?.dispose();
      } catch (error) {
        debugPrint('Could not release paper sound: $error');
      }
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
