const _requestLifetime = Duration(milliseconds: 240);
const writingRhythmIdle = Duration(seconds: 3);
const writingRhythmFade = Duration(milliseconds: 850);
const writingRhythmExitFade = Duration(milliseconds: 320);
const writingRhythmResumeFade = Duration(milliseconds: 280);

enum PaperSoundEffect {
  writingRhythm('writing-human-low-rhythm.wav', 1, Duration.zero),
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
