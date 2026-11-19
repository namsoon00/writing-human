import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/original_photo_store.dart';
import '../source/source_scan.dart';
import 'paper_panel.dart';

Future<void> showOriginalPhoto(
  BuildContext context,
  String id, {
  required Color color,
}) => Navigator.of(context).push<void>(
  paperPanelRoute(
    (_) => PaperPanel(
      color: color,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: PaperPanelHeader('원본 사진'),
          ),
          Expanded(
            child: InteractiveViewer(maxScale: 6, child: OriginalPhoto(id: id)),
          ),
        ],
      ),
    ),
  ),
);

class OriginalPhoto extends StatefulWidget {
  const OriginalPhoto({super.key, required this.id, this.region});

  final String id;
  final List<double>? region;

  @override
  State<OriginalPhoto> createState() => _OriginalPhotoState();
}

class _OriginalPhotoState extends State<OriginalPhoto> {
  late var _bytes = _load();

  Future<Uint8List?> _load() async {
    final region = widget.region;
    final bytes = await const OriginalPhotoStore().load(widget.id);
    if (region == null || bytes == null) return bytes;
    final image = await ScanImage.decode(
      bytes,
      region: Rect.fromLTRB(region[0], region[1], region[2], region[3]),
    );
    return image.bytes;
  }

  @override
  void didUpdateWidget(OriginalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.region != widget.region) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final bytes = snapshot.data;
      if (bytes == null) {
        return Center(
          child: Text(
            snapshot.hasError ? '사진을 읽지 못했어요.' : '이 기기에 보관된 사진이 없어요.',
          ),
        );
      }
      return Image.memory(
        bytes,
        key: const ValueKey('saved-original-photo'),
        fit: BoxFit.contain,
        semanticLabel: '저장한 원본 사진',
        errorBuilder: (_, _, _) => const Text('이 사진을 표시할 수 없어요.'),
      );
    },
  );
}
