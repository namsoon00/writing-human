import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../cafe/cafe_atmosphere.dart';
import 'cafe_sound_output.dart';
import 'user_audio.dart';
import 'user_audio_context.dart';
export 'cafe_sound_output.dart';

abstract interface class CafeAmbientVoice {
  Future<void> play(String asset, {required bool loop});
  Future<void> volume(double value);
  Future<void> stop();
  Future<void> dispose();
}

class _PlayerVoice implements CafeAmbientVoice {
  final _player = AudioPlayer();
  @override
  Future<void> play(String asset, {required bool loop}) async {
    await _player.setVolume(0);
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await _player.play(
      AssetSource('audio/$asset'),
      volume: 0,
      ctx: AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.game,
        ),
        iOS: userAudioIOS(),
      ),
    );
  }

  @override
  Future<void> volume(double value) => _player.setVolume(value);
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

CafeSoundOutput createCafeSoundscape(
  void Function(Object) onError, {
  CafeAmbientVoice Function()? voiceFactory,
}) => SeasonalCafeSoundscape(onError, voiceFactory ?? _PlayerVoice.new);

/// Only the new explicit melody/environment choices can open audio assets.
/// Legacy rain/water/leaves/music values never reactivate the removed loops.
class SeasonalCafeSoundscape implements CafeSoundOutput {
  SeasonalCafeSoundscape(this.onError, this.factory);
  final void Function(Object) onError;
  final CafeAmbientVoice Function() factory;
  final _session = UserAudioSession();
  final _voices = <String, CafeAmbientVoice>{};
  final _paths = <String, String>{}, _gains = <String, double>{};
  CafeSoundFrame _frame = const CafeSoundFrame({});
  Future<void> _queue = Future.value();
  Timer? _timer;
  int _generation = 0, _version = 0;
  int? _lastStep, _pendingStep;
  bool _active = false, _disposed = false, _busy = false, _dirty = false;
  @override
  void update(CafeSoundFrame frame) {
    if (_disposed) return;
    if (frame.step == null) {
      _pendingStep = null;
      _lastStep = null;
    }
    if (_active && frame.step != null && frame.step != _lastStep) {
      _lastStep = frame.step;
      if (frame.step!.isEven) _pendingStep = frame.step;
    }
    _frame = frame;
    _version++;
    _dirty = true;
    if (_active && (frame.melody != CafeMelody.none || frame.environment > 0)) {
      _session.activate();
    }
  }

  @override
  Future<void> start() async {
    if (_disposed || _active) return;
    _active = true;
    _generation++;
    _dirty = true;
    if (_frame.melody != CafeMelody.none || _frame.environment > 0) {
      _session.activate();
    }
    await _flush();
    if (!_active || _disposed) return;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_dirty && !_busy) {
        unawaited(
          _flush().catchError((Object e) {
            onError(e);
            unawaited(stop());
          }),
        );
      }
    });
  }

  Future<void> _flush() {
    final generation = _generation;
    _busy = true;
    return _queue = _queue
        .catchError((Object _) {})
        .then((_) async {
          if (!_active || _disposed || generation != _generation) return;
          final frame = _frame, version = _version;
          if (frame.melody != CafeMelody.none || frame.environment > 0) {
            _session.activate();
          }
          final score = frame.melody == CafeMelody.none
              ? null
              : 'cafe-score-${frame.melody.name}.m4a';
          final rain =
              frame.weather == CafeWeather.rain && frame.environment > 0
              ? 'cafe-season-rain.m4a'
              : null;
          var ramp = await _loop('music', score, frame.musicVolume, generation);
          if (!_active || generation != _generation) return;
          ramp =
              await _loop('rain', rain, frame.environment, generation) || ramp;
          if (!_active || generation != _generation) return;
          if (_pendingStep != null &&
              frame.environment > 0 &&
              (frame.weather == CafeWeather.autumn ||
                  frame.weather == CafeWeather.snow)) {
            _pendingStep = null;
            final voice = _voices.putIfAbsent('step', factory);
            await voice.play(
              'cafe-season-${frame.weather == CafeWeather.snow ? 'snow' : 'leaf'}.wav',
              loop: false,
            );
            if (_active && generation == _generation) {
              await voice.volume(frame.environment * .35);
            }
          } else {
            _pendingStep = null;
          }
          _dirty = version != _version || ramp;
        })
        .whenComplete(() => _busy = false);
  }

  Future<bool> _loop(
    String key,
    String? asset,
    double target,
    int generation,
  ) async {
    target = target.clamp(0, .20).toDouble();
    if (asset == null || target <= 0) {
      if (_paths.remove(key) != null) await _voices[key]?.stop();
      _gains[key] = 0;
      return false;
    }
    final voice = _voices.putIfAbsent(key, factory);
    if (_paths[key] != asset) {
      await voice.stop();
      if (!_active || generation != _generation) return false;
      await voice.play(asset, loop: true);
      _paths[key] = asset;
      _gains[key] = 0;
    }
    if (!_active || generation != _generation) return false;
    final before = _gains[key] ?? 0;
    final next = (before + (target - before) * .35).clamp(0, .20).toDouble();
    _gains[key] = next;
    if ((next - before).abs() > .0001) await voice.volume(next);
    return (next - target).abs() > .0002;
  }

  @override
  Future<void> stop() async {
    _active = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _pendingStep = null;
    // Mute existing layers immediately, even if another file is still loading.
    await Future.wait(_voices.values.toList().map((voice) => voice.stop()));
    try {
      await _queue;
    } catch (_) {}
    for (final voice in _voices.values) {
      await voice.stop();
    }
    _paths.clear();
    _gains.clear();
    _session.release();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    for (final voice in _voices.values) {
      await voice.dispose();
    }
    _voices.clear();
  }
}
