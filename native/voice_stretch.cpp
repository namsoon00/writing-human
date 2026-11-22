#include "../third_party/signalsmith/signalsmith-stretch.h"
#include <cmath>
#include <vector>
#include <algorithm>

extern "C" __attribute__((visibility("default")))
int writing_voice_stretch(const float *input, int input_count, float *output,
                         int output_count, int sample_rate, double semitones) {
  if (!input || !output || input_count <= 0 || output_count <= 0 ||
      sample_rate < 8000 || sample_rate > 96000 ||
      input_count > sample_rate*90 || output_count > sample_rate*150 || !std::isfinite(semitones)) return 0;
  try {
    signalsmith::stretch::SignalsmithStretch<float> stretch;
    stretch.presetDefault(1, sample_rate);
    stretch.reset();
    stretch.setTransposeSemitones(semitones);
    stretch.setFormantFactor(1, true);
    stretch.setFormantBase(190.0/sample_rate);
    const int ahead = stretch.inputLatency(), behind = stretch.outputLatency();
    std::vector<float> prime(ahead, 0), padded(input_count, 0), result(output_count + behind, 0);
    std::copy_n(input, std::min(ahead, input_count), prime.data());
    const float *prime_channels[] = {prime.data()};
    stretch.seek(prime_channels, ahead, double(input_count)/output_count);
    if (input_count > ahead) std::copy_n(input+ahead, input_count-ahead, padded.data());
    const float *in_channels[] = {padded.data()};
    float *out_channels[] = {result.data()};
    stretch.process(in_channels, input_count, out_channels, output_count);
    float *tail_channels[] = {result.data()+output_count};
    stretch.flush(tail_channels, behind);
    std::copy_n(result.data()+behind, output_count, output);
    return 1;
  } catch (...) { return 0; }
}
