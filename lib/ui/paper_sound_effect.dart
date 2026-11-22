enum PaperSoundEffect {
  pencil('pencil-stroke.wav', .68, Duration(milliseconds: 85)),
  pageTurn('page-turn.mp3', .42, Duration(milliseconds: 105));

  const PaperSoundEffect(this.file, this.volume, this.minimumInterval);

  final String file;
  final double volume;
  final Duration minimumInterval;

  String get asset => 'audio/$file';
}

class PaperSoundRequest {
  PaperSoundRequest(this.isCurrent) : _age = Stopwatch()..start();

  final bool Function() isCurrent;
  final Stopwatch _age;

  bool get canPlay =>
      _age.elapsed < const Duration(milliseconds: 240) && isCurrent();
}
