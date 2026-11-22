const _requestLifetimeMs = 240;
const _pencilGlideMs = 1640;
const _requestLifetime = Duration(milliseconds: _requestLifetimeMs);
const pencilGlideDuration = Duration(milliseconds: _pencilGlideMs);

enum PaperSoundEffect {
  // Leave room for delayed audio activation so two glides cannot stack.
  pencil(
    'pencil-slow-settle.wav',
    1,
    Duration(milliseconds: _pencilGlideMs + _requestLifetimeMs),
  ),
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

  bool get canPlay => _age.elapsed < _requestLifetime && isCurrent();
}
