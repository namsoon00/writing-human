import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../cafe/cafe_atmosphere.dart';
import 'paper.dart';
import 'paper_panel.dart';

class CafeAtmosphereSheet extends StatefulWidget {
  const CafeAtmosphereSheet({
    super.key,
    required this.value,
    required this.playing,
    required this.onSave,
    required this.onPreview,
    required this.onToggle,
    this.legacyRain = false,
  });
  final CafeAtmosphere value;
  final bool legacyRain;
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
  String? error, notice, soundError;
  Future<void> save(CafeAtmosphere next) async {
    if (busy) return;
    widget.onPreview(next);
    setState(() {
      draft = next;
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final ok = await widget.onSave(next);
      if (mounted) {
        setState(() {
          if (ok) {
            notice = '좋아하는 조합을 기억했어요.';
          } else {
            error = '공간을 저장하지 못했어요. 다시 저장해 주세요.';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = '공간을 저장하지 못했어요. 다시 저장해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> listen() async {
    widget.onPreview(draft);
    final was = widget.playing.value;
    final pending = widget.onToggle();
    setState(() => busy = true);
    try {
      final active = await pending;
      if (mounted) {
        setState(
          () =>
              soundError = !was && !active ? '소리를 재생하지 못했어요. 다시 켜 주세요.' : null,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget volume(
    String label,
    String key,
    double value,
    CafeAtmosphere Function(double) change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label · ${(value * 100).round()}%'),
      Slider(
        key: ValueKey(key),
        label: label,
        value: value,
        semanticFormatterCallback: (v) => '$label ${(v * 100).round()}%',
        onChanged: busy
            ? null
            : (v) {
                setState(() {
                  draft = change(v);
                  notice = null;
                });
                widget.onPreview(draft);
              },
        onChangeEnd: busy ? null : (_) => save(draft),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && error == null,
    child: PaperPanel(
      child: Column(
        children: [
          PaperPanelHeader(
            '빛과 소리',
            backLabel: '카페',
            canClose: !busy && error == null,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(error!, style: const TextStyle(color: burgundy)),
                  TextButton(
                    key: const ValueKey('cafe-atmosphere-retry'),
                    onPressed: busy ? null : () => save(draft),
                    child: const Text('다시 저장'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('고요한 공간', style: TextStyle(fontSize: 21)),
                  const SizedBox(height: 8),
                  const Text(
                    '머물고 싶은 풍경을 골라요. 음악과 환경음은 따로 켤 수 있어요.',
                    style: TextStyle(height: 1.6, color: muted),
                  ),
                  const SizedBox(height: 22),
                  const Text('창밖의 풍경', style: TextStyle(fontSize: 19)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final weather in CafeWeather.values)
                        ChoiceChip(
                          key: ValueKey('cafe-weather-${weather.name}'),
                          label: Text(
                            const ['맑음', '비', '낙엽', '눈'][weather.index],
                          ),
                          selected:
                              (draft.weather ??
                                  (widget.legacyRain
                                      ? CafeWeather.rain
                                      : CafeWeather.clear)) ==
                              weather,
                          onSelected: busy
                              ? null
                              : (_) => save(draft.copy(weather: weather)),
                        ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    activeTrackColor: brandInk,
                    contentPadding: EdgeInsets.zero,
                    key: const ValueKey('cafe-weather-motion'),
                    title: const Text('천천히 움직이는 날씨'),
                    subtitle: const Text('끄면 눈과 낙엽이 머문 풍경으로 보여요.'),
                    value: draft.weatherMotion,
                    onChanged: busy
                        ? null
                        : (v) => save(draft.copy(weatherMotion: v)),
                  ),
                  SwitchListTile.adaptive(
                    activeTrackColor: brandInk,
                    contentPadding: EdgeInsets.zero,
                    key: const ValueKey('cafe-light-flow'),
                    title: const Text('천천히 흐르는 빛'),
                    value: draft.flow,
                    onChanged: busy ? null : (v) => save(draft.copy(flow: v)),
                  ),
                  const Divider(height: 30),
                  const Text('작은 선율', style: TextStyle(fontSize: 19)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final melody in CafeMelody.values)
                        ChoiceChip(
                          key: ValueKey('cafe-melody-${melody.name}'),
                          label: Text(
                            const ['음악 없이', '종이의 여백', '저녁의 쪽지'][melody.index],
                          ),
                          selected: draft.melody == melody,
                          onSelected: busy
                              ? null
                              : (_) => save(draft.copy(melody: melody)),
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '느린 피아노와 부드러운 현의 오리지널 선율이에요.',
                      style: TextStyle(color: muted, height: 1.6),
                    ),
                  ),
                  volume(
                    '음악 음량',
                    'cafe-music-volume',
                    draft.musicVolume,
                    (v) => draft.copy(musicVolume: v),
                  ),
                  volume(
                    '환경음 음량',
                    'cafe-environment-volume',
                    draft.environment,
                    (v) => draft.copy(environment: v),
                  ),
                  const Text(
                    '비에는 처마의 빗방울, 낙엽과 눈에는 걸을 때의 작은 소리가 들려요.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  volume(
                    '동작음 음량',
                    'cafe-actions-volume',
                    draft.actions,
                    (v) => draft.copy(actions: v),
                  ),
                  volume(
                    '전체 음량',
                    'cafe-master-volume',
                    draft.volume,
                    (v) => draft.copy(volume: v),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '고른 조합은 기억하고, 소리는 올 때마다 직접 켜요. 동작 줄이기에서는 풍경이 멈춰요.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                  if (notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        notice!,
                        style: const TextStyle(color: muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (soundError != null)
                    Text(soundError!, style: const TextStyle(color: burgundy)),
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
                      label: Text(playing ? '소리 끄기' : '소리 켜기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
