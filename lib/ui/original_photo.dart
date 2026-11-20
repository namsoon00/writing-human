import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../data/original_photo_store.dart';
import '../source/source_scan.dart';
import 'original_photo_crop.dart';
import 'paper_panel.dart';

const _missingOriginalPhoto = '이 기기에 원본 사진이 없어요.\n사진을 담은 기기에서 열어 주세요.';

Future<void> showOriginalPhoto(
  BuildContext context,
  String id, {
  required Color color,
  List<double>? region,
  Future<bool> Function(List<double>?)? onSaveRegion,
}) => Navigator.of(context).push<void>(
  paperPanelRoute(
    (_) => _OriginalPhotoPanel(
      id: id,
      color: color,
      region: region,
      onSaveRegion: onSaveRegion,
    ),
    color: color,
  ),
);

class _OriginalPhotoPanel extends StatefulWidget {
  const _OriginalPhotoPanel({
    required this.id,
    required this.color,
    required this.region,
    required this.onSaveRegion,
  });

  final String id;
  final Color color;
  final List<double>? region;
  final Future<bool> Function(List<double>?)? onSaveRegion;

  @override
  State<_OriginalPhotoPanel> createState() => _OriginalPhotoPanelState();
}

class _OriginalPhotoPanelState extends State<_OriginalPhotoPanel> {
  late List<double>? _region = widget.region;
  bool _whole = false;
  bool _working = false;
  String? _error;

  Future<void> _chooseRegion() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final bytes = await const OriginalPhotoStore().load(widget.id);
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _error = _missingOriginalPhoto);
        return;
      }
      final chosen = await chooseOriginalPhotoRegion(
        context,
        bytes,
        color: widget.color,
        current: _region,
      );
      if (!mounted || chosen == null) return;
      final region = chosen.isEmpty ? null : chosen;
      final saved = await widget.onSaveRegion!(region);
      if (!mounted) return;
      setState(() {
        _region = region;
        _whole = false;
        if (!saved) _error = '사진 범위를 저장하지 못했어요.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = '사진 범위를 변경하지 못했어요.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => PaperPanel(
    color: widget.color,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
          child: PaperPanelHeader('원본 사진', canClose: !_working),
        ),
        if (_region != null || widget.onSaveRegion != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                if (_region != null)
                  TextButton(
                    onPressed: _working
                        ? null
                        : () => setState(() => _whole = !_whole),
                    child: Text(_whole ? '글자 부분 보기' : '사진 전체 보기'),
                  ),
                if (widget.onSaveRegion != null)
                  TextButton(
                    onPressed: _working ? null : _chooseRegion,
                    child: const Text('볼 부분 고르기'),
                  ),
              ],
            ),
          ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(error, textAlign: TextAlign.center),
          ),
        Expanded(
          child: InteractiveViewer(
            key: ValueKey(_whole),
            maxScale: 6,
            child: OriginalPhoto(
              id: widget.id,
              region: _whole ? null : _region,
            ),
          ),
        ),
      ],
    ),
  );
}

class OriginalPhoto extends StatefulWidget {
  const OriginalPhoto({
    super.key,
    required this.id,
    this.region,
    this.fitWidth = false,
  });

  final String id;
  final List<double>? region;
  final bool fitWidth;

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
