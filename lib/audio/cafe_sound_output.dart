import '../cafe/cafe_atmosphere.dart';

abstract interface class CafeSoundOutput {
  Future<void> start();
  void update(CafeSoundFrame frame);
  Future<void> stop();
  Future<void> dispose();
}

const cafeSoundAssets = {
  CafeSound.rain: 'assets/audio/cafe-rain.wav',
  CafeSound.water: 'assets/audio/cafe-water.wav',
  CafeSound.leaves: 'assets/audio/cafe-leaves.wav',
  CafeSound.music: 'assets/audio/cafe-music.wav',
};
