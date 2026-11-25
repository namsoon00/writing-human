import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../source/source_scan.dart';
import 'paper_panel.dart';

Future<List<double>?> chooseOriginalPhotoRegion(
  BuildContext context,
  Uint8List bytes, {
  required Color color,
  required List<double>? current,
}) => Navigator.of(context).push<List<double>>(
  paperPanelRoute(
    (_) => _OriginalPhotoCrop(bytes: bytes, color: color, current: current),
    color: color,
  ),
);

class _OriginalPhotoCrop extends StatefulWidget {
  const _OriginalPhotoCrop({
    required this.bytes,
    required this.color,
    required this.current,
  });

  final Uint8List bytes;
  final Color color;
  final List<double>? current;

  @override
  State<_OriginalPhotoCrop> createState() => _OriginalPhotoCropState();
}

class _OriginalPhotoCropState extends State<_OriginalPhotoCrop> {
  late final _image = ScanImage.decode(widget.bytes);
  late Rect? _region = widget.current == null
      ? null
      : Rect.fromLTRB(
          widget.current![0],
          widget.current![1],
          widget.current![2],
          widget.current![3],
        );
  Offset? _start;

  Offset _point(Offset offset, Size size) => Offset(
    (offset.dx / size.width).clamp(0, 1),
    (offset.dy / size.height).clamp(0, 1),
  );

  @override
  Widget build(BuildContext context) => PaperPanel(
    color: widget.color,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 12, 0),
          child: PaperPanelHeader('사진 범위', allowWritingReturn: false),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('원하는 범위를 대각선으로 그려 주세요.'),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder(
              future: _image,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('이 사진을 표시할 수 없어요.'));
                }
                final image = snapshot.data;
                if (image == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Center(
                  child: AspectRatio(
                    aspectRatio: image.width / image.height,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        final region = _region;
                        return GestureDetector(
                          onPanDown: (event) =>
                              _start = _point(event.localPosition, size),
                          onPanUpdate: (event) {
                            final origin = _start;
                            if (origin == null) return;
                            setState(
                              () => _region = Rect.fromPoints(
                                origin,
                                _point(event.localPosition, size),
                              ),
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(image.bytes, fit: BoxFit.fill),
                              if (region != null)
                                Positioned.fromRect(
                                  rect: Rect.fromLTRB(
                                    region.left * size.width,
                                    region.top * size.height,
                                    region.right * size.width,
                                    region.bottom * size.height,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xff70472f),
                                        width: 2,
                                      ),
                                      color: const Color(0x26c48732),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, <double>[]),
              child: const Text('사진 전체'),
            ),
            FilledButton(
              onPressed:
                  _region == null ||
                      _region!.width < .02 ||
                      _region!.height < .02
                  ? null
                  : () {
                      final region = _region!;
                      Navigator.pop(context, [
                        region.left,
                        region.top,
                        region.right,
                        region.bottom,
                      ]);
                    },
              child: const Text('이 부분 사용'),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}
