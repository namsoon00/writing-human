import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class WritingSound {
  AudioPlayer? _player;
  final _interval = Stopwatch();
  bool _busy = false, _disposed = false;

  Future<void> stroke(bool Function() isFocused) async {
    // Coalesce bursts and keep only one playback in flight.
    if (_disposed ||
        _busy ||
        (_interval.isRunning && _interval.elapsedMilliseconds < 130)) {
      return;
    }
    _busy = true;
    _interval
      ..reset()
      ..start();
    try {
      var player = _player;
      if (player == null) {
        player = _player = AudioPlayer();
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.none,
              usageType: AndroidUsageType.assistanceSonification,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        );
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(.68);
        await player.setSource(AssetSource('audio/pencil-stroke.wav'));
      }
      if (!_disposed && isFocused()) await player.resume();
    } catch (error) {
      debugPrint('Writing sound unavailable: $error');
      final player = _player;
      _player = null;
      await _disposePlayer(player);
    } finally {
      _busy = false;
      if (_disposed) await _disposePlayer(_player);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (!_busy) await _disposePlayer(_player);
  }

  Future<void> _disposePlayer(AudioPlayer? player) async {
    try {
      await player?.dispose();
    } catch (error) {
      debugPrint('Could not release writing audio: $error');
    }
  }
}
