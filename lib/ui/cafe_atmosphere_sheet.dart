import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../cafe/cafe_atmosphere.dart';
import 'paper.dart';

class CafeAtmosphereSheet extends StatefulWidget {
  const CafeAtmosphereSheet({
    super.key,
    required this.value,
    required this.playing,
    required this.onSave,
    required this.onPreview,
    required this.onToggle,
  });
  final CafeAtmosphere value;
  final ValueListenable<bool> playing;
  final Future<bool> Function(CafeAtmosphere) onSave;
  final ValueChanged<CafeAtmosphere> onPreview;
  final Future<bool> Function() onToggle;
  @override
  State<CafeAtmosphereSheet> createState() => _CafeAtmosphereSheetState();
}

class _CafeAtmosphereSheetState extends State<CafeAtmosphereSheet> {
  late var draft = widget.value;
  bool busy = false;
  String? error, notice;
  String? soundError;
  Future<void> save(CafeAtmosphere next) async {
    if (busy) return;
    setState(() {
      draft = next;
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final ok = await widget.onSave(next);
      if (!mounted) return;
      setState(() {
        if (ok) {
          notice = '좋아하는 조합을 기억했어요.';
        } else {
          error = '공간을 저장하지 못했어요. 다시 저장해 주세요.';
        }
      });
    } catch (_) {
      if (mounted) setState(() => error = '공간을 저장하지 못했어요. 다시 저장해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> listen() async {
    if (busy) return;
    // Invoke inside this tap, before any async work (browser audio activation).
    widget.onPreview(draft);
    final wasPlaying = widget.playing.value;
    final result = widget.onToggle();
    setState(() => busy = true);
    try {
      final active = await result;
      if (mounted) {
        setState(
          () => soundError = !wasPlaying && !active
              ? '소리를 재생하지 못했어요. 다시 켜 주세요.'
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      backgroundColor: const Color(0xfff7efdf),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.sizeOf(context).height * .84,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('빛과 소리', style: TextStyle(fontSize: 22)),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        activeTrackColor: brandInk,
                        contentPadding: EdgeInsets.zero,
                        key: const ValueKey('cafe-light-flow'),
                        title: const Text('천천히 흐르는 빛'),
                        subtitle: const Text('고른 시간 안에서 빛과 잎 그림자가 조금씩 달라져요.'),
                        value: draft.flow,
                        onChanged: busy
                            ? null
                            : (v) => save(draft.copy(flow: v)),
                      ),
                      const SizedBox(height: 14),
                      const Text('고요한 공간', style: TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      const Text(
                        '배경음 없이 조용히 머물러요. 소리를 켜면 물건을 사용할 때만 짧게 들려요.',
                        style: TextStyle(height: 1.6, color: muted),
                      ),
                      const SizedBox(height: 12),
                      Text('동작음 음량 · ${(draft.volume * 100).round()}%'),
                      Semantics(
                        label: '동작음 음량',
                        child: Slider(
                          key: const ValueKey('cafe-master-volume'),
                          value: draft.volume,
                          semanticFormatterCallback: (v) =>
                              '${(v * 100).round()}%',
                          onChanged: busy
                              ? null
                              : (v) {
                                  setState(() {
                                    draft = draft.copy(volume: v);
                                    notice = null;
                                  });
                                  widget.onPreview(draft);
                                },
                          onChangeEnd: busy ? null : (_) => save(draft),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (soundError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            soundError!,
                            style: const TextStyle(color: burgundy),
                          ),
                        ),
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.playing,
                        builder: (context, playing, _) => FilledButton.icon(
                          key: const ValueKey('cafe-mix-listen'),
                          onPressed: busy ? null : listen,
                          icon: Icon(
                            playing
                                ? Icons.volume_off_outlined
                                : Icons.volume_up_outlined,
                          ),
                          label: Text(playing ? '동작음 끄기' : '동작음 켜기'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '음량은 기억하고, 동작음은 올 때마다 직접 켜요.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '동작 줄이기에서는 빛과 그림자가 멈춰요.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: burgundy)),
                TextButton(
                  key: const ValueKey('cafe-atmosphere-retry'),
                  onPressed: busy ? null : () => save(draft),
                  child: const Text('다시 저장'),
                ),
              ] else if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(notice!, style: const TextStyle(color: muted)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
