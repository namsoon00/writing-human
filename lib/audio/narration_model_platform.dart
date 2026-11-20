import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'narration_model_assets.dart';

Future<void> prepareRuntime() async {}

Future<OrtValue> narrationIds(List<int> ids) =>
    OrtValue.fromList(Int64List.fromList(ids), [1, ids.length]);

class NarrationAssetLoader {
  NarrationAssetLoader(this.stopped);

  final Future<void> stopped;

  Future<String> readText(
    ModelAsset asset,
    void Function(int) progress,
  ) async => (await _file(asset, progress)).readAsString();

  Future<OrtSession> openSession(
    ModelAsset asset,
    void Function(int) progress,
  ) async => OnnxRuntime().createSession(
    (await _file(asset, progress)).path,
    options: OrtSessionOptions(
      intraOpNumThreads: 3,
      interOpNumThreads: 1,
      useArena: false,
    ),
  );

  Future<File> _file(ModelAsset asset, void Function(int) progress) async {
    final directory = await getApplicationCacheDirectory();
    final original = File(
      '${directory.path}/supertonic3-aafc6e3/${asset.path}',
    );
    final originalSize = narrationOriginalSizes[asset.path];
    final file = originalSize == null
        ? original
        : File('${directory.path}/supertonic3-int8-95618f5/${asset.path}');
    if (await file.exists() && await file.length() == asset.size) return file;
    if (originalSize != null &&
        await original.exists() &&
        await original.length() == originalSize) {
      return original;
    }
    await file.parent.create(recursive: true);
    final download = await file.parent.createTemp('.narration-');
    final pending = File('${download.path}/model.part');
    final client = http.Client();
    try {
      final response = await client
          .send(
            http.AbortableRequest(
              'GET',
              narrationModelUri(asset),
              abortTrigger: stopped,
            ),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        throw const HttpException('Model download failed');
      }
      var received = 0;
      await response.stream
          .timeout(const Duration(seconds: 45))
          .map((chunk) {
            received += chunk.length;
            if (received > asset.size) {
              throw const FormatException('Invalid model file');
            }
            progress(received);
            return chunk;
          })
          .pipe(pending.openWrite());
      if (await pending.length() != asset.size ||
          (await sha256.bind(pending.openRead()).first).toString() !=
              asset.sha256) {
        throw const FormatException('Invalid model file');
      }
      return pending.rename(file.path);
    } finally {
      client.close();
      await download.delete(recursive: true);
    }
  }
}
