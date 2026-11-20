import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/source/source_scan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'A selected passage keeps more of the original pixels for OCR',
    () async {
      final recorder = PictureRecorder();
      Canvas(recorder).drawColor(const Color(0xff292929), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(4000, 1600);
      final bytes = (await image.toByteData(
        format: ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();

      const region = Rect.fromLTRB(.25, .25, .75, .5);
      final normal = await ScanImage.decode(bytes, region: region);
      final detailed = await ScanImage.decode(
        bytes,
        region: region,
        preserveRegionDetail: true,
      );
      final whole = await ScanImage.decode(bytes, preserveRegionDetail: true);

      expect((normal.width, normal.height), (1200, 240));
      expect((detailed.width, detailed.height), (1800, 360));
      expect((whole.width, whole.height), (2400, 960));
    },
  );
}
