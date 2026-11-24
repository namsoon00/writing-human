import '../cafe/cafe_atmosphere.dart';

abstract interface class CafeSoundOutput {
  Future<void> start();
  void update(CafeSoundFrame frame);
  Future<void> stop();
  Future<void> dispose();
}
