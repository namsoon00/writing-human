import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'user_audio.dart';
import 'user_audio_context.dart';

/// Short sounds require an explicit tap; app backgrounding cancels pending work.
class CafeCalmAudio {
  AudioPlayer? _player;
  final _session = UserAudioSession();
  StreamSubscription<void>? _completion;
  int _generation = 0;
  double _volume = .04;
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, .20);
    if (_volume == 0) return stop();
    final player = _player;
    if (player != null) await player.setVolume(_volume);
  }

  Future<void> play(String name, {double volume = .04}) async {
    if (volume <= 0) return;
    _session.activate();
    _volume = volume.clamp(0, .20);
    final request = ++_generation;
    try {
      final player = _player ??= AudioPlayer();
      await _completion?.cancel();
      if (request != _generation) return;
      _completion = player.onPlayerComplete.listen((_) {
        if (request == _generation) _session.release();
      });
      await player.setReleaseMode(ReleaseMode.stop);
      if (request != _generation) return;
      await player.play(
        AssetSource('audio/cafe-$name.wav'),
        volume: _volume,
        ctx: AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.game,
          ),
          iOS: userAudioIOS(),
        ),
      );
      if (request != _generation) await player.stop();
    } catch (_) {
      if (request == _generation) _session.release();
      rethrow;
    }
  }

  Future<void> stop() async {
    _generation++;
    _session.release();
    await _player?.stop();
  }

  Future<void> dispose() async {
    _generation++;
    _session.release();
    await _completion?.cancel();
    final p = _player;
    _player = null;
    await p?.dispose();
  }
}
