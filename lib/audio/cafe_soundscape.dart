import '../cafe/cafe_atmosphere.dart';
import 'cafe_sound_output.dart';
export 'cafe_sound_output.dart';

// Ambient loops were removed after the continuous synthetic hiss was reported.
// Keep the output contract so lifecycle/optional action-sound controls stay
// independent of old saved mix values. No player, asset or audio context opens.
CafeSoundOutput createCafeSoundscape(void Function(Object) onError) =>
    _SilentCafeSoundscape();

class _SilentCafeSoundscape implements CafeSoundOutput {
  @override
  Future<void> start() async {}
  @override
  void update(CafeSoundFrame frame) {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
