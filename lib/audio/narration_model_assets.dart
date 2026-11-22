typedef ModelAsset = ({String path, int size, String sha256});

// These three ONNX files have compatible, weight-only int8 replacements.
// Keep recognizing the original files already saved by earlier versions.
const narrationOriginalSizes = {
  'onnx/text_encoder.onnx': 36416150,
  'onnx/vector_estimator.onnx': 256534781,
  'onnx/vocoder.onnx': 101424195,
};

Uri narrationModelUri(ModelAsset asset, {bool original = false}) {
  final revision = !original && narrationOriginalSizes.containsKey(asset.path)
      ? 'askurios8/supertonic-3-int8/resolve/'
            '95618f5d61cef4923c3b802a332fd603723718f7'
      : 'supertone-oss-archive/supertonic-3/resolve/'
            'aafc6e32416a594460b32413efc49d7fe4ce6d46';
  return Uri.parse(
    'https://huggingface.co/$revision/${asset.path}?download=true',
  );
}

final narrationDownloadMegabytes =
    (narrationAssets.fold(0, (sum, asset) => sum + asset.size) / 1000000)
        .round();

const narrationAssets = <ModelAsset>[
  (
    path: 'onnx/tts.json',
    size: 8253,
    sha256: '42078d3aef1cd43ab43021f3c54f47d2d75ceb4e75f627f118890128b06a0d09',
  ),
  (
    path: 'onnx/unicode_indexer.json',
    size: 277676,
    sha256: '9bf7346e43883a81f8645c81224f786d43c5b57f3641f6e7671a7d6c493cb24f',
  ),
  (
    path: 'voice_styles/F1.json',
    size: 292046,
    sha256: 'bbdec6ee00231c2c742ad05483df5334cab3b52fda3ba38e6a07059c4563dbc2',
  ),
  (
    path: 'onnx/duration_predictor.onnx',
    size: 3700147,
    sha256: 'c3eb91414d5ff8a7a239b7fe9e34e7e2bf8a8140d8375ffb14718b1c639325db',
  ),
  (
    path: 'onnx/text_encoder.onnx',
    size: 9734378,
    sha256: '67b0975e50689f599a7834255d53a7cfd72a9f028b0f56e0040ba7dc5007d9cf',
  ),
  (
    path: 'onnx/vector_estimator.onnx',
    size: 65769855,
    sha256: 'f903a5ed046bb92cf1e557393623d7e709b527d338b042cc0bf9bce417185e5a',
  ),
  (
    path: 'onnx/vocoder.onnx',
    size: 25820373,
    sha256: 'ab337d1a10ed54c24cb42e0ea9be3733603149517fa0a8f54d07ef816cb766df',
  ),
];
