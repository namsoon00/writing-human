import 'dart:async';
import 'package:flutter/material.dart';
import '../audio/cafe_ambience.dart';

import '../cafe/cafe_visit.dart';
import '../cafe/cafe_view_controller.dart';
import '../data/model.dart';
import 'package:url_launcher/url_launcher.dart';
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
    this.onTools,
  });
  final List<Book> books;
  final String currentWritingLabel;
  final CafeSeat? initialSeat;
  final bool saveFailed;
  final Future<bool> Function(CafeSeat seat, String? bookId) onWrite;
  final VoidCallback onLeave, onRetry;
  final Future<void> Function(String? bookId)? onTools;
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
    view.addListener(_viewChanged);
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
    view.removeListener(_viewChanged);
    view.dispose();
    super.dispose();
  }

  CafeTarget? pending;
  int pendingRequest = 0;
  bool dialogOpen = false;

  @override
  void didUpdateWidget(CafeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saveFailed && !widget.saveFailed) error = null;
  }

  void _viewChanged() {
    if (!mounted) return;
    if (pending != null && pendingRequest != view.request) pending = null;
    setState(() {});
    if (!view.travelling && pending != null) {
      final target = pending!;
      pending = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        if (target == CafeTarget.bookshelf) _chooseBook();
        if (target == CafeTarget.recommendations) _recommendations();
        if (target == CafeTarget.stationery) widget.onTools?.call(bookId);
        if (target == CafeTarget.exit && !widget.saveFailed) widget.onLeave();
      });
    }
  }

  void _activate(CafeTarget target) {
    if (opening || widget.saveFailed || dialogOpen || view.travelling) return;
    if (target.seat == view.seat && target.seat != null) {
      _write();
      return;
    }
    pending = target.seat == null ? target : null;
    pendingRequest = view.request + 1;
    if (!view.visit(target)) {
      pending = null;
      setState(() => error = '그곳까지 걸어갈 수 없어요. 가까운 빈 바닥을 눌러 주세요.');
    } else {
      setState(() => error = null);
    }
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
    dialogOpen = true;
    await showDialog<void>(
      context: context,

      builder: (context) => StatefulBuilder(
        builder: (context, update) => Dialog(
          backgroundColor: const Color(0xfff3eadb),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .76,
              maxWidth: 480,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('나의 책장', style: TextStyle(fontSize: 22)),
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
      ),
    );
    dialogOpen = false;
  }

  Future<void> _recommendations() async {
    dialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xfff3eadb),
        title: const Text('쓰는 인간의 추천'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '짧은 시부터 천천히 만나 보세요.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            _recommendation(
              '하늘과 바람과 별과 시',
              '윤동주',
              '「서시」의 짧은 행을 한 줄씩 옮겨 쓰며 시작해 보세요.',
              '공유마당 · 서시',
              'https://gongu.copyright.or.kr/gongu/wrt/wrt/view.do?menuNo=200019&wrtSn=9000779',
            ),
            const SizedBox(height: 20),
            _recommendation(
              '진달래꽃',
              '김소월',
              '소리 내어 읽은 뒤 문장의 리듬을 따라 써 보세요.',
              '국립중앙도서관 · 진달래꽃',
              'https://www.nl.go.kr/NL/contents/N20103000000.do?schIdSub=CO20221104150848575100&schM=contView',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('서가에 놓기'),
          ),
        ],
      ),
    );
    dialogOpen = false;
  }

  Widget _recommendation(
    String title,
    String author,
    String reason,
    String source,
    String url,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 20, color: brandInk)),
      const SizedBox(height: 4),
      Text(author, style: const TextStyle(color: muted)),
      const SizedBox(height: 10),
      Text(reason, style: const TextStyle(height: 1.6)),
      TextButton(
        onPressed: () async {
          try {
            final opened = await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
            if (!opened) throw StateError('Could not open source');
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('원문 페이지를 열지 못했어요. 다시 눌러 주세요.')),
              );
            }
          }
        },
        child: Text(source),
      ),
    ],
  );

  Future<void> _guide() async {
    final target = await showDialog<CafeTarget>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xfff3eadb),
        title: const Text('공간 둘러보기'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              '끌어 둘러보고, 빈 바닥을 눌러 걸어요.\n책상에 앉은 뒤 노트를 누르면 쓸 수 있어요.',
              style: TextStyle(height: 1.6),
            ),
          ),
          for (final target in CafeTarget.values)
            SimpleDialogOption(
              key: target.seat == null
                  ? ValueKey('cafe-guide-${target.name}')
                  : ValueKey('cafe-seat-${target.seat!.name}'),
              onPressed: () => Navigator.pop(context, target),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${target.label} · ${target.action}'),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    if (target != null && mounted) _activate(target);
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !opening && !widget.saveFailed,
    child: ColoredBox(
      color: const Color(0xff392e25),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CafeScene(
            controller: view,
            interactive: !opening && !widget.saveFailed,
            onTargetSelected: _activate,
            onWrite: _write,
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xf2faf5eb), Color(0x00faf5eb)],
                  ),
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
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '쓰는 인간 · 필사 카페',
                            style: TextStyle(color: brandInk, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          tooltip: sound ? '빗소리 끄기' : '빗소리 켜기',
                          onPressed: soundBusy ? null : _toggleSound,
                          icon: Icon(
                            sound
                                ? Icons.volume_up_outlined
                                : Icons.volume_off_outlined,
                            color: brandInk,
                          ),
                        ),
                        IconButton(
                          tooltip: '공간 안내',
                          onPressed:
                              opening || widget.saveFailed || view.travelling
                              ? null
                              : _guide,
                          icon: const Icon(
                            Icons.explore_outlined,
                            color: brandInk,
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: opening || widget.saveFailed
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: brandInk),
                        ),
                      ],
                    ),
                    IgnorePointer(
                      child: Text(
                        opening
                            ? '글 여는 중'
                            : view.travelling
                            ? '자리로 걸어가는 중'
                            : view.seat != null
                            ? '${view.seat!.label} · 노트를 눌러 써요'
                            : '바닥을 눌러 걷고, 끌어 둘러봐요',
                        style: const TextStyle(
                          color: Color(0xff62503f),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (view.seat != null && !view.travelling)
                      TextButton(
                        key: const ValueKey('cafe-stand'),
                        onPressed: opening
                            ? null
                            : () {
                                pending = null;
                                view.stand();
                              },
                        style: TextButton.styleFrom(foregroundColor: brandInk),
                        child: const Text('일어나 둘러보기'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.saveFailed || error != null)
            Center(
              child: Card(
                color: const Color(0xfff3eadb),
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.saveFailed
                              ? '글을 저장하지 못했어요.\n앱을 닫기 전에 ‘다시 저장’을 눌러 주세요.'
                              : error!,
                          style: const TextStyle(height: 1.6, color: burgundy),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.saveFailed
                            ? widget.onRetry
                            : () => setState(() => error = null),
                        child: Text(widget.saveFailed ? '다시 저장' : '둘러보기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
