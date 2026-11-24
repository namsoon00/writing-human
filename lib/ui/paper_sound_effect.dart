const _requestLifetime = Duration(milliseconds: 240);
const writingPencilLeadIn = Duration(milliseconds: 600);
const writingRhythmIdle = Duration(milliseconds: 120);
const writingRhythmFade = Duration(milliseconds: 60);
const writingRhythmExitFade = Duration(milliseconds: 60);
const writingRhythmResumeFade = Duration(milliseconds: 25);

enum PaperSoundEffect {
  writingRhythm('pencil-on-paper-original.wav', 1, Duration.zero),
  pageTurn('page-turn.mp3', .42, Duration(milliseconds: 105));

  const PaperSoundEffect(this.file, this.volume, this.minimumInterval);

  final String file;
  final double volume;
  final Duration minimumInterval;

  String get asset => 'audio/$file';
  bool get loops => this == writingRhythm;
}

class PaperSoundRequest {
  PaperSoundRequest(this.isCurrent) : _age = Stopwatch()..start();

  final bool Function() isCurrent;
  final Stopwatch _age;

  bool get canPlay => _age.elapsed < _requestLifetime && isCurrent();
}

/// A shared playback boundary lets activity timing be tested without a device.
abstract interface class PaperSoundPlayback {
  void play(PaperSoundRequest request);
  void pause();
  Future<void> dispose();
}
