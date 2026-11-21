import 'dart:async';
import 'package:flutter/material.dart';
import '../audio/cafe_ambience.dart';

import '../cafe/cafe_visit.dart';
import '../cafe/cafe_view_controller.dart';
import '../data/model.dart';
import 'cafe_scene.dart';
import 'paper.dart';

/// A private, eye-height 3D room connected to the existing writing editor.
class CafeScreen extends StatefulWidget {
  const CafeScreen({
    super.key,
    required this.books,
    required this.currentWritingLabel,
    required this.onWrite,
    required this.onLeave,
    required this.onRetry,
    this.initialSeat,
    this.saveFailed = false,
  });
  final List<Book> books;
  final String currentWritingLabel;
  final CafeSeat? initialSeat;
  final bool saveFailed;
  final Future<bool> Function(CafeSeat seat, String? bookId) onWrite;
  final VoidCallback onLeave, onRetry;
  @override
  State<CafeScreen> createState() => _CafeScreenState();
}

class _CafeScreenState extends State<CafeScreen> with WidgetsBindingObserver {
  final ambience = CafeAmbience();
  bool sound = false, soundBusy = false;
  int soundGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      soundGeneration++;
      unawaited(ambience.stop());
      if (mounted) setState(() => sound = false);
    }
  }

  Future<void> _toggleSound() async {
    if (soundBusy) return;
    final generation = ++soundGeneration;
    final desired = !sound;
    setState(() => soundBusy = true);
    try {
      if (sound) {
        await ambience.stop();
      } else {
        await ambience.start();
      }
      if (mounted && generation == soundGeneration) {
        setState(() => sound = desired);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('빗소리를 재생하지 못했어요. 다시 켜 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => soundBusy = false);
    }
  }

  late final view = CafeViewController(seat: widget.initialSeat);
  String? bookId;
  bool opening = false;
  String? error;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ambience.dispose());
    view.dispose();
    super.dispose();
  }

  void _select(CafeSeat seat) {
    if (opening) return;
    view.sit(seat);
    setState(() {});
  }

  Future<void> _write() async {
    final seat = view.seat;
    if (opening || widget.saveFailed || seat == null) return;
    setState(() {
      opening = true;
      error = null;
    });
    try {
      final opened = await widget.onWrite(seat, bookId);
      if (mounted && !opened) setState(() => error = '글을 열지 못했어요. 다시 눌러 주세요.');
    } catch (_) {
      if (mounted) setState(() => error = '글을 열지 못했어요. 다시 눌러 주세요.');
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> _chooseBook() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('펼칠 글과 책', style: TextStyle(fontSize: 22)),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _CafeChoice(
                        key: const ValueKey('cafe-current-writing'),
                        selected: bookId == null,
                        label: widget.currentWritingLabel,
                        description: '지금 펼쳐 둔 쪽에서 이어 써요.',
                        onTap: () {
                          setState(() => bookId = null);
                          update(() {});
                        },
                      ),
                      for (final book in widget.books)
                        _CafeChoice(
                          key: ValueKey('cafe-book-${book.id}'),
                          selected: bookId == book.id,
                          label: book.title,
                          onTap: () {
                            setState(() => bookId = book.id);
                            update(() {});
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('고르기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final selected = view.seat;
    final book = widget.books.where((b) => b.id == bookId).firstOrNull;
    final panelHeight = (size.height * (widget.saveFailed ? .57 : .38)).clamp(
      200.0,
      380.0,
    );
    return PopScope<void>(
      canPop: !opening && !widget.saveFailed,
      child: ColoredBox(
        color: const Color(0xff392e25),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CafeScene(
              controller: view,
              interactive: !opening,
              onSeatSelected: _select,
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x990e160f),
                      Color(0x000e160f),
                      Color(0x000e160f),
                      Color(0x66180f06),
                    ],
                    stops: [0, .24, .58, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: _header(context),
                ),
              ),
            ),
            if (selected == null)
              Positioned(
                left: 20,
                bottom: panelHeight + MediaQuery.paddingOf(context).bottom + 32,
                child: Semantics(
                  label: '카페 안에서 걷기',
                  child: Column(
                    children: [
                      _walk(
                        Icons.keyboard_arrow_up,
                        '앞으로 걷기',
                        () => view.step(0, .32),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _walk(
                            Icons.keyboard_arrow_left,
                            '왼쪽으로 걷기',
                            () => view.step(-.32, 0),
                          ),
                          _walk(
                            Icons.keyboard_arrow_down,
                            '뒤로 걷기',
                            () => view.step(0, -.32),
                          ),
                          _walk(
                            Icons.keyboard_arrow_right,
                            '오른쪽으로 걷기',
                            () => view.step(.32, 0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight: panelHeight,
                  ),
                  child: Material(
                    color: const Color(0xf2f7f0e3),
                    borderRadius: BorderRadius.circular(20),
                    elevation: 8,
                    shadowColor: const Color(0x55362415),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selected == null
                                              ? '어느 자리에 앉을까요?'
                                              : selected.label,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: brandInk,
                                          ),
                                        ),
                                      ),
                                      if (selected != null)
                                        TextButton(
                                          key: const ValueKey('cafe-stand'),
                                          onPressed: opening
                                              ? null
                                              : () {
                                                  view.stand();
                                                  setState(() {});
                                                },
                                          child: const Text('일어나기'),
                                        ),
                                    ],
                                  ),
                                  const Text(
                                    '끌어 둘러보고, 책상을 눌러 앉아요.',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      for (final seat in CafeSeat.values)
                                        ChoiceChip(
                                          key: ValueKey(
                                            'cafe-seat-${seat.name}',
                                          ),
                                          label: Text(seat.label),
                                          selected: selected == seat,
                                          onSelected: opening
                                              ? null
                                              : (_) => _select(seat),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.padded,
                                          visualDensity: VisualDensity.standard,
                                          selectedColor: const Color(
                                            0xffdfceb4,
                                          ),
                                          backgroundColor: const Color(
                                            0xfff6f0e6,
                                          ),
                                        ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    key: const ValueKey('cafe-choose-book'),
                                    onPressed: opening ? null : _chooseBook,
                                    icon: const Icon(
                                      Icons.menu_book_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      book?.title ?? widget.currentWritingLabel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (widget.initialSeat != null)
                                    TextButton(
                                      key: const ValueKey('leave-cafe'),
                                      onPressed: opening || widget.saveFailed
                                          ? null
                                          : widget.onLeave,
                                      child: const Text('카페 나가기'),
                                    ),
                                  if (widget.saveFailed) ...[
                                    Semantics(
                                      liveRegion: true,
                                      child: const Text(
                                        '글을 저장하지 못했어요.\n앱을 닫기 전에 ‘다시 저장’을 눌러 주세요.',
                                        style: TextStyle(
                                          color: burgundy,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: widget.onRetry,
                                      child: const Text('다시 저장'),
                                    ),
                                  ] else if (error != null)
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(error!),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            key: const ValueKey('cafe-start-writing'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 52),
                            ),
                            onPressed:
                                opening || widget.saveFailed || selected == null
                                ? null
                                : _write,
                            icon: const Icon(
                              Icons.menu_book_outlined,
                              size: 20,
                            ),
                            label: Text(
                              opening
                                  ? '글 여는 중'
                                  : selected == null
                                  ? '자리를 골라 주세요'
                                  : '${selected.label}에서 쓰기',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    const brand = Text(
      '쓰는 인간',
      style: TextStyle(color: Color(0xffece4d2), fontSize: 14),
    );
    final title = Semantics(
      header: true,
      child: const Text(
        '필사 카페',
        style: TextStyle(color: Color(0xfffff6e5), fontSize: 25, height: 1.4),
      ),
    );
    const caption = Text(
      '혼자 머무는 카페',
      style: TextStyle(color: Color(0xffece4d2), fontSize: 12),
    );
    final actions = <Widget>[
      IconButton(
        tooltip: sound ? '빗소리 끄기' : '빗소리 켜기',
        onPressed: soundBusy ? null : _toggleSound,
        icon: Icon(
          sound ? Icons.volume_up_outlined : Icons.volume_off_outlined,
          color: const Color(0xfffff6e5),
        ),
      ),
      IconButton(
        tooltip: '닫기',
        onPressed: opening || widget.saveFailed
            ? null
            : () => Navigator.pop(context),
        icon: const Icon(Icons.close, color: Color(0xfffff6e5)),
      ),
    ];
    if (MediaQuery.textScalerOf(context).scale(25) > 35) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: brand),
              ...actions,
            ],
          ),
          title,
          if (MediaQuery.sizeOf(context).height >= 600) caption,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              brand,
              SizedBox(height: 3),
              title,
              SizedBox(height: 6),
              caption,
            ],
          ),
        ),
        ...actions,
      ],
    );
  }

  Widget _walk(IconData icon, String label, VoidCallback action) => Padding(
    padding: const EdgeInsets.all(2),
    child: Material(
      color: const Color(0x8841342a),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: label,
        onPressed: opening ? null : action,
        icon: Icon(icon, color: const Color(0xfff8f0df)),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    ),
  );
}

class _CafeChoice extends StatelessWidget {
  const _CafeChoice({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    this.description,
  });
  final bool selected;
  final String label;
  final String? description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xffe5d6c2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: selected ? brandInk : muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 16)),
                        if (description != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            description!,
                            style: const TextStyle(color: muted, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
