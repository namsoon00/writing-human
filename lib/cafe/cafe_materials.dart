import 'dart:math' as math;
import 'dart:ui' as ui;

/// Small, deterministic material atlases; generated once per visit, not frame.
/// The wall art is drawn locally and contains no visitor text or remote images.
abstract final class CafeMaterials {
  /// Neutral yarn atlas; the garment supplies its own oatmeal tint.
  static Future<ui.Image> knit() async {
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xfff3f0e7), ui.BlendMode.src);
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;
    for (var x = -16.0; x < 528; x += 16) {
      for (var y = -22.0; y < 534; y += 22) {
        final path = ui.Path()
          ..moveTo(x + 2, y)
          ..quadraticBezierTo(x + 7, y + 7, x + 8, y + 17)
          ..quadraticBezierTo(x + 10, y + 7, x + 14, y);
        paint
          ..strokeWidth = 3.1
          ..color = const ui.Color(0x368b806e);
        canvas.drawPath(path.shift(const ui.Offset(.8, 1.0)), paint);
        paint
          ..strokeWidth = 1.8
          ..color = const ui.Color(0x99ffffff);
        canvas.drawPath(path, paint);
      }
    }
    final random = math.Random(516);
    paint.style = ui.PaintingStyle.fill;
    for (var i = 0; i < 11000; i++) {
      paint.color = i.isEven
          ? const ui.Color(0x13ffffff)
          : const ui.Color(0x0c716451);
      canvas.drawCircle(
        ui.Offset(random.nextDouble() * 512, random.nextDouble() * 512),
        .45,
        paint,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(512, 512);
    picture.dispose();
    return image;
  }

  static Future<ui.Image> plaster() async {
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xfff4eee2), ui.BlendMode.src);
    final random = math.Random(419), paint = ui.Paint();
    // Lime plaster: broad, irregular trowel traces plus fine mineral pores.
    // Wrap each mark at texture edges so repeated wall panels have no seams.
    for (var i = 0; i < 1900; i++) {
      final x = random.nextDouble() * 1024, y = random.nextDouble() * 1024;
      final length = 35 + random.nextDouble() * 180,
          rise = (random.nextDouble() - .5) * 28;
      paint
        ..color =
            (i.isEven ? const ui.Color(0xffbdb29e) : const ui.Color(0xffffffff))
                .withValues(alpha: .018 + random.nextDouble() * .025)
        ..style = ui.PaintingStyle.stroke
        ..strokeCap = ui.StrokeCap.round
        ..strokeWidth = 2 + random.nextDouble() * 25;
      for (final dx in [-1024.0, 0.0, 1024.0]) {
        for (final dy in [-1024.0, 0.0, 1024.0]) {
          final path = ui.Path()
            ..moveTo(x + dx, y + dy)
            ..quadraticBezierTo(
              x + dx + length * .45,
              y + dy - rise * .6,
              x + dx + length,
              y + dy + rise,
            );
          canvas.drawPath(path, paint);
        }
      }
    }
    paint.style = ui.PaintingStyle.fill;
    for (var i = 0; i < 42000; i++) {
      paint.color = i.isEven
          ? const ui.Color(0x1affffff)
          : const ui.Color(0x116e604e);
      canvas.drawCircle(
        ui.Offset(random.nextDouble() * 1024, random.nextDouble() * 1024),
        .3 + random.nextDouble() * .65,
        paint,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1024, 1024);
    picture.dispose();
    return image;
  }

  static Future<ui.Image> gravel() async {
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffcbbfa8), ui.BlendMode.src);
    final random = math.Random(617), paint = ui.Paint();
    const colors = [
      ui.Color(0xffd4c8b2),
      ui.Color(0xffe5dbc8),
      ui.Color(0xffb7ad99),
      ui.Color(0xffc4b9a1),
    ];
    for (var i = 0; i < 12500; i++) {
      final x = random.nextDouble() * 512, y = random.nextDouble() * 512;
      final width = 1.4 + random.nextDouble() * 4.0,
          height = 1.2 + random.nextDouble() * 2.5;
      paint.color = const ui.Color(0xffa69b85);
      canvas.drawOval(ui.Rect.fromLTWH(x, y + .8, width, height), paint);
      paint.color = colors[i % colors.length];
      canvas.drawOval(ui.Rect.fromLTWH(x, y, width, height), paint);
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
