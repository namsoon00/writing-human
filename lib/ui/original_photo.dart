import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../data/original_photo_store.dart';
import '../source/source_scan.dart';
import 'paper_panel.dart';

const _missingOriginalPhoto = '이 기기에 원본 사진이 없어요.\n사진을 담은 기기에서 열어 주세요.';

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
    color: color,
  ),
);

class OriginalPhoto extends StatefulWidget {
  const OriginalPhoto({
    super.key,
    required this.id,
    this.region,
    this.fitWidth = false,
    this.compact = false,
  });

  final String id;
  final List<double>? region;
  final bool fitWidth, compact;

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
      preserveRegionDetail: true,
    );
    return image.bytes;
  }

  @override
  void didUpdateWidget(OriginalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        !listEquals(oldWidget.region, widget.region)) {
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
        if (widget.compact) {
          return Tooltip(
            message: _missingOriginalPhoto,
            child: const Icon(
              Icons.broken_image_outlined,
              semanticLabel: _missingOriginalPhoto,
            ),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              snapshot.hasError
                  ? '사진을 열지 못했어요.\n화면을 닫고 다시 열어 주세요.'
                  : _missingOriginalPhoto,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      final photo = Image.memory(
        bytes,
        key: const ValueKey('saved-original-photo'),
        width: widget.fitWidth ? double.infinity : null,
        fit: widget.fitWidth ? BoxFit.fitWidth : BoxFit.contain,
        semanticLabel: '저장한 원본 사진',
        errorBuilder: (_, _, _) => const Text(
          '사진을 표시할 수 없어요. 원본 파일이 열리는지 확인해 주세요.',
          textAlign: TextAlign.center,
        ),
      );
      return widget.fitWidth
          ? SingleChildScrollView(primary: false, child: photo)
          : photo;
    },
  );
}
