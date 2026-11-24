import 'package:audioplayers/audioplayers.dart';

/// Short sounds require an explicit tap; app backgrounding cancels pending work.
class CafeCalmAudio {
  AudioPlayer? _player;
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
    _volume = volume.clamp(0, .20);
    final request = ++_generation;
    final player = _player ??= AudioPlayer();
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
