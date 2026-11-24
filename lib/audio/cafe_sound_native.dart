import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../cafe/cafe_atmosphere.dart';
import 'cafe_sound_output.dart';

class CafeSoundscape implements CafeSoundOutput {
  CafeSoundscape(this.onError);
  final void Function(Object) onError;
  final _players = <CafeSound, AudioPlayer>{};
  final _levels = <CafeSound, double>{};
  CafeSoundFrame? _target;
  Timer? _fade;
  Future<void> _stopping = Future.value();
  bool _closed = false, _updating = false;
  int _generation = 0;

  @override
  Future<void> start() async {
    final request = ++_generation;
    await _stopping;
    if (_closed || request != _generation) return;
    try {
      await Future.wait(
        CafeSound.values.map((sound) async {
          final player = _players.putIfAbsent(sound, AudioPlayer.new);
          await player.setReleaseMode(ReleaseMode.loop);
          if (_closed || request != _generation) return;
          _levels[sound] = 0;
          await player.play(
            AssetSource(cafeSoundAssets[sound]!.substring(7)),
            volume: 0,
            ctx: AudioContext(
              android: const AudioContextAndroid(
                audioFocus: AndroidAudioFocus.none,
                usageType: AndroidUsageType.game,
              ),
              iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
            ),
          );
          if (_closed || request != _generation) await player.stop();
        }),
      );
      if (_closed || request != _generation) return;
      _fade?.cancel();
      _fade = Timer.periodic(
        const Duration(milliseconds: 80),
        (_) => _advance(),
      );
      _advance();
    } catch (_) {
      if (request == _generation) await stop();
      rethrow;
    }
  }

  @override
  void update(CafeSoundFrame frame) => _target = frame;
  Future<void> _advance() async {
    if (_updating || _closed || _target == null) return;
    _updating = true;
    final generation = _generation;
    try {
      for (final sound in CafeSound.values) {
        if (_closed || generation != _generation) return;
        final player = _players[sound];
        if (player == null) continue;
        final target = _target!.levels[sound]!;
        final old = _levels[sound] ?? 0;
        final next = (target.volume - old).abs() < .00001
            ? target.volume
            : old + (target.volume - old) * .28;
        if (next != old) {
          _levels[sound] = next;
          await player.setVolume(next);
        }
        if ((player.balance - target.pan).abs() > .015) {
          await player.setBalance(target.pan);
        }
      }
    } catch (error) {
      if (!_closed && generation == _generation) onError(error);
    } finally {
      _updating = false;
    }
  }

  @override
  Future<void> stop() {
    _generation++;
    _fade?.cancel();
    _fade = null;
    return _stopping = Future.wait(
      _players.values.map((p) => p.stop()),
    ).then((_) {});
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await stop();
    await Future.wait(_players.values.map((p) => p.dispose()));
    _players.clear();
  }
}
