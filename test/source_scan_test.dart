import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/source/photo_lines.dart';
import 'package:writing_human/source/source_scan.dart';

void main() {
  test('Original photo focus picks only lines inside the selected range', () {
    const original = RegisteredOriginal(
      'o',
      '머리말\n둘째 줄\n셋째 줄',
      photoId: 'test-photo',
      isFullPage: true,
      writingRange: PencilMark(4, 8),
      photoLines: [
        OriginalPhotoLine(PencilMark(0, 3), 500, 500, 9500, 1500),
        OriginalPhotoLine(PencilMark(4, 8), 2200, 4400, 8000, 4800),
        OriginalPhotoLine(PencilMark(9, 13), 1000, 8900, 9000, 9200),
      ],
    );
    final focus = originalPhotoPreviewRegion(original)!;
    expect(focus[0], closeTo(.208, .0001));
    expect(focus[1], closeTo(.428, .0001));
    expect(focus[2], closeTo(.812, .0001));
    expect(focus[3], closeTo(.492, .0001));
    final manual = original.withDetails(
      writingRange: original.writingRange,
      reflection: null,
      photoRegion: const [.2, .3, .7, .8],
    );
    expect(originalPhotoPreviewRegion(manual), [.2, .3, .7, .8]);
  });

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
