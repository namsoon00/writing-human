import 'dart:io';
import 'package:writing_human/audio/narration_voice_profile.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) throw ArgumentError('input.wav output.wav');
  final profile = NarrationVoiceProfile();
  try {
    final wav = await profile.process(await File(args[0]).readAsBytes(), () {});
    await File(args[1]).writeAsBytes(wav);
    final (samples, rate) = readVoiceWav(wav);
    stdout.writeln('${samples.length / rate} seconds');
  } finally {
    await profile.close();
  }
}
