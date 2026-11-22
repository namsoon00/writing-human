import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'paper_sound_effect.dart';

class PaperSoundOutput {
  PaperSoundOutput(this.effect) {
    _pool = _preload();
  }

  final PaperSoundEffect effect;
  Future<AudioPool?>? _pool;
  Future<void>? _starting;
  PaperSoundRequest? _pending;
  bool _closed = false;

  Future<AudioPool?> _preload() async {
    try {
      return await AudioPool.create(
        source: AssetSource(effect.asset),
        minPlayers: 2,
        maxPlayers: effect == PaperSoundEffect.pencil ? 3 : 6,
        audioContext: AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.assistanceSonification,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
    } catch (error) {
      if (!_closed) debugPrint('Could not prepare paper sound: $error');
      return null;
    }
  }

  void play(PaperSoundRequest request) {
    if (_closed) return;
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

  Future<void> dispose() async {
    _closed = true;
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
