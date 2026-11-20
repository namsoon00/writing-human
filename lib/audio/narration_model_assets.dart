typedef ModelAsset = ({String path, int size, String sha256});

Uri narrationModelUri(ModelAsset asset) => Uri.parse(
  'https://huggingface.co/supertone-oss-archive/supertonic-3/resolve/'
  'aafc6e32416a594460b32413efc49d7fe4ce6d46/${asset.path}?download=true',
);

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
    path: 'voice_styles/F3.json',
    size: 290794,
    sha256: '12f6ef2573baa2defa1128069cb59f203e3ab67c92af77b42df8a0e3a2f7c6ab',
  ),
  (
    path: 'voice_styles/M2.json',
    size: 292055,
    sha256: 'b76cbf62bac707c710cf0ae5aba5e31eea1a6339a9734bfae33ab98499534a50',
  ),
  (
    path: 'onnx/duration_predictor.onnx',
    size: 3700147,
    sha256: 'c3eb91414d5ff8a7a239b7fe9e34e7e2bf8a8140d8375ffb14718b1c639325db',
  ),
  (
    path: 'onnx/text_encoder.onnx',
    size: 36416150,
    sha256: 'c7befd5ea8c3119769e8a6c1486c4edc6a3bc8365c67621c881bbb774b9902ff',
  ),
  (
    path: 'onnx/vector_estimator.onnx',
    size: 256534781,
    sha256: '883ac868ea0275ef0e991524dc64f16b3c0376efd7c320af6b53f5b780d7c61c',
  ),
  (
    path: 'onnx/vocoder.onnx',
    size: 101424195,
    sha256: '085de76dd8e8d5836d6ca66826601f615939218f90e519f70ee8a36ed2a4c4ba',
  ),
];
