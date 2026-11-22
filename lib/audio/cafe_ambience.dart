import 'package:audioplayers/audioplayers.dart';

/// Quiet, opt-in synthetic rain. It never starts on opening or resuming a room.
class CafeAmbience {
  AudioPlayer? _player;
  int _generation = 0;
  Future<void> start({bool courtyard = false}) async {
    final request = ++_generation;
    final player = _player ??= AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    if (request != _generation) return;
    await player.play(
      AssetSource(courtyard ? 'audio/cafe-water.wav' : 'audio/cafe-rain.wav'),
      volume: .28,
      ctx: AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.game,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ),
    );
    if (request != _generation) await player.stop();
  }

  Future<void> stop() async {
    _generation++;
    await _player?.stop();
  }

  Future<void> dispose() async {
    _generation++;
    await _player?.dispose();
    _player = null;
  }
}

/// Short sounds require an explicit tap; app backgrounding cancels pending work.
class CafeCalmAudio {
  AudioPlayer? _player;
  int _generation = 0;
  Future<void> play(String name) async {
    final request = ++_generation;
    final player = _player ??= AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    if (request != _generation) return;
    await player.play(
      AssetSource('audio/cafe-$name.wav'),
      volume: .32,
      ctx: AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.game,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ),
    );
    if (request != _generation) await player.stop();
  }

  Future<void> stop() async {
    _generation++;
    await _player?.stop();
  }

  Future<void> dispose() async {
    _generation++;
    final p = _player;
    _player = null;
    await p?.dispose();
  }
}
