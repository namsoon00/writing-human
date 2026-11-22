import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    await CLibrary(
      name: 'writing_voice',
      assetName: 'audio/voice_stretch_native.dart',
      sources: ['native/voice_stretch.cpp'],
      language: Language.cpp,
      std: 'c++17',
    ).build(input: input, output: output);
    output.dependencies.addAll([
      for (final name in [
        'signalsmith-stretch.h',
        'signalsmith-linear/stft.h',
        'signalsmith-linear/fft.h',
        'signalsmith-linear/linear.h',
        'signalsmith-linear/approx.h',
        'signalsmith-linear/platform/fft-linear.h',
      ])
        input.packageRoot.resolve('third_party/signalsmith/$name'),
    ]);
  });
}
