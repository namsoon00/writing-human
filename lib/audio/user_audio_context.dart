import 'package:audioplayers/audioplayers.dart';

/// Explicitly enabled foreground audio may play with the iPhone silent switch on.
AudioContextIOS userAudioIOS() => AudioContextIOS(
  category: AVAudioSessionCategory.playback,
  options: const {AVAudioSessionOptions.mixWithOthers},
);
