import 'dart:math' as math;
import 'dart:ui' as ui;

/// Small, deterministic material atlases; generated once per visit, not frame.
/// The wall art is drawn locally and contains no visitor text or remote images.
abstract final class CafeMaterials {
  static Future<ui.Image> plaster() async {
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xfff4eee2), ui.BlendMode.src);
    final random = math.Random(419), paint = ui.Paint();
    // Periodic broad trowel variation: both tile boundaries meet exactly.
    for (var y = 0; y < 512; y += 4) {
      for (var x = 0; x < 512; x += 4) {
        final wave =
            math.sin(x * math.pi / 256) * math.cos(y * math.pi / 128) +
            .5 * math.cos((x + y) * math.pi / 128);
        final value = (238 + wave * 3).round();
        paint.color = ui.Color.fromARGB(255, value + 8, value + 3, value - 7);
        canvas.drawRect(
          ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 4, 4),
          paint,
        );
      }
    }
    for (var i = 0; i < 18000; i++) {
      final light = i.isEven;
      paint.color = light
          ? const ui.Color(0x12ffffff)
          : const ui.Color(0x0b6e604e);
      canvas.drawCircle(
        ui.Offset(random.nextDouble() * 512, random.nextDouble() * 512),
        .25 + random.nextDouble() * .65,
        paint,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(512, 512);
    picture.dispose();
    return image;
  }

  static Future<ui.Image> artwork() async {
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffeee6d5), ui.BlendMode.src);
    final paint = ui.Paint()..isAntiAlias = true;
    final random = math.Random(97);
    // Three paper prints in one atlas: botanical ink, a quiet landscape,
    // and a page study. Text labels remain in the existing font sign atlas.
    for (var row = 0; row < 3; row++) {
      canvas.save();
      canvas.translate(0, row * 512.0);
      for (var i = 0; i < 3500; i++) {
        paint.color = const ui.Color(0x15786950);
        canvas.drawCircle(
          ui.Offset(random.nextDouble() * 384, random.nextDouble() * 512),
          random.nextDouble() * .8,
          paint,
        );
      }
      if (row == 0) {
        final stem = ui.Path()
          ..moveTo(174, 423)
          ..cubicTo(235, 290, 133, 205, 208, 88);
        paint
          ..color = const ui.Color(0xff65725b)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.4;
        canvas.drawPath(stem, paint);
        paint.style = ui.PaintingStyle.fill;
        for (var i = 0; i < 9; i++) {
          final y = 130.0 + i * 30, x = 193 + math.sin(i * .75) * 17;
          final direction = i.isEven ? -1.0 : 1.0;
          final leaf = ui.Path()
            ..moveTo(x, y + 25)
            ..quadraticBezierTo(
              x + direction * 68,
              y + 18,
              x + direction * 63,
              y - 25,
            )
            ..quadraticBezierTo(x + direction * 18, y - 20, x, y + 25);
          paint.color = i.isEven
              ? const ui.Color(0xff7b8467)
              : const ui.Color(0xff92977a);
          canvas.drawPath(leaf, paint);
        }
      } else if (row == 1) {
        paint.color = const ui.Color(0xffdfd4be);
        canvas.drawCircle(const ui.Offset(258, 157), 43, paint);
        for (var i = 0; i < 4; i++) {
          final path = ui.Path()..moveTo(39, 290 + i * 30.0);
          for (var x = 39; x <= 345; x += 6) {
            path.lineTo(
              x.toDouble(),
              275 + i * 31 + math.sin(x * .018 + i) * 36,
            );
          }
          path
            ..lineTo(345, 425)
            ..lineTo(39, 425)
            ..close();
          paint.color = [
            const ui.Color(0xffbbbda3),
            const ui.Color(0xff969e83),
            const ui.Color(0xff77876e),
            const ui.Color(0xff5c705d),
          ][i];
          canvas.drawPath(path, paint);
        }
      } else {
        paint.color = const ui.Color(0xffac9b80);
        for (var i = 0; i < 16; i++) {
          final width = i == 5 || i == 11
              ? 122.0
              : 205 + random.nextDouble() * 25;
          canvas.drawRect(
            ui.Rect.fromLTWH(72, 98 + i * 20.0, width, 1.5),
            paint,
          );
        }
        paint.color = const ui.Color(0xff905c45);
        canvas.drawRect(const ui.Rect.fromLTWH(267, 429, 23, 23), paint);
        paint.color = const ui.Color(0xffeee6d5);
        canvas.drawRect(const ui.Rect.fromLTWH(273, 434, 2, 13), paint);
        canvas.drawRect(const ui.Rect.fromLTWH(278, 440, 7, 2), paint);
      }
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(384, 1536);
    picture.dispose();
    return image;
  }
}
