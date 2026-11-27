enum PaperSoundEffect {
  pencilShort('pencil-contact-short.wav', 1, Duration(milliseconds: 97)),
  pencilStraight('pencil-contact-straight.wav', 1, Duration(milliseconds: 189)),
  pencilSweep('pencil-contact-sweep.wav', 1, Duration(milliseconds: 205)),
  pencilBend('pencil-contact-bend.wav', 1, Duration(milliseconds: 272)),
  pageTurn('page-turn.mp3', .42, Duration(milliseconds: 105));

  const PaperSoundEffect(this.file, this.volume, this.interval);

  static const pencilContacts = [
    pencilShort,
    pencilStraight,
    pencilSweep,
    pencilBend,
  ];

  final String file;
  final double volume;

  // For pencil contacts, this is the clip length. For pages it is the
  // minimum interval between turning sounds, whose tails can overlap.
  final Duration interval;

  String get asset => 'audio/$file';
}

class PaperSoundRequest {
  PaperSoundRequest(this.effect, this.isCurrent) : _age = Stopwatch()..start();

  static const lifetime = Duration(milliseconds: 240);

  final PaperSoundEffect effect;
  final bool Function() isCurrent;
  final Stopwatch _age;

  bool get canPlay => _age.elapsed < lifetime && isCurrent();
}

abstract interface class PaperSoundPlayback {
  void play(PaperSoundRequest request);
  void pause();
  Future<void> dispose();
}
