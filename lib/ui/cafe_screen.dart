import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/cafe_ambience.dart';

import '../cafe/cafe_visit.dart';
import '../cafe/cafe_world.dart';
import '../cafe/cafe_camera.dart';
import '../cafe/cafe_space.dart';
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
    this.playCalmSound,
    this.spaceStore,
  });
  final Future<void> Function(String name)? playCalmSound;
  final CafeSpaceStore? spaceStore;
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
  final calmAudio = CafeCalmAudio();
  bool lastCourtyard = false;
  bool showIntro = true;
  String? calmHint;
  bool sound = false, soundBusy = false;
  int soundGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lastCourtyard = view.inCourtyard;
    view.addListener(_viewChanged);
    view.roomReady = _loadRoom();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      soundGeneration++;
      unawaited(ambience.stop());
      unawaited(calmAudio.stop());
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
        await ambience.start(courtyard: view.inCourtyard);
      }
      if (mounted && generation == soundGeneration) {
        setState(() => sound = desired);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소리를 재생하지 못했어요. 다시 켜 주세요.')),
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
    unawaited(calmAudio.dispose());
    view.removeListener(_viewChanged);
    view.dispose();
    super.dispose();
  }

  double? brightnessPreview;
  bool roomSaveFailed = false;
  bool roomLoading = false,
      roomLoadFailed = false,
      roomSaving = false,
      editing = false,
      placing = false;
  String? roomError, selectedObject;
  CafeSpace savedRoom = const CafeSpace();
  bool get roomDirty => view.space.encode() != savedRoom.encode();
  Future<void> _loadRoom() async {
    if (widget.spaceStore == null) return;
    setState(() {
      roomLoading = true;
      roomError = null;
    });
    try {
      final value = await widget.spaceStore!.load();
      if (!mounted) return;
      if (view.applySpace(value) != null) {
        throw const FormatException('Invalid room layout');
      }
      savedRoom = value;
      bookId = widget.books.any((b) => b.id == value.selectedBookId)
          ? value.selectedBookId
          : null;
      roomLoadFailed = false;
    } catch (_) {
      if (mounted) {
        roomLoadFailed = true;
        roomError =
            '\uACF5\uAC04 \uC124\uC815\uC744 \uC5F4\uC9C0 \uBABB\uD588\uC5B4\uC694. \uB2E4\uC2DC \uBD88\uB7EC\uC640 \uC8FC\uC138\uC694.';
      }
    } finally {
      if (mounted) setState(() => roomLoading = false);
    }
  }

  Future<bool> _saveRoom() async {
    if (roomLoadFailed || roomSaving) return false;
    if (!roomDirty) return true;
    setState(() {
      roomSaving = true;
      roomSaveFailed = false;
      roomError = null;
    });
    final value = view.space;
    try {
      await (widget.spaceStore ?? _memoryRoom).save(value);
      if (!mounted) return false;
      savedRoom = value;
      bookId = widget.books.any((b) => b.id == value.selectedBookId)
          ? value.selectedBookId
          : null;
      return true;
    } catch (_) {
      if (mounted) {
        roomSaveFailed = true;
        setState(
          () => roomError =
              '\uACF5\uAC04\uC744 \uC800\uC7A5\uD558\uC9C0 \uBABB\uD588\uC5B4\uC694. \uB2E4\uC2DC \uC800\uC7A5\uC744 \uB20C\uB7EC \uC8FC\uC138\uC694.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => roomSaving = false);
    }
  }

  final _memoryRoom = MemoryCafeSpaceStore();
  void _changeRoom(CafeSpace next) {
    if (roomSaving || roomLoadFailed) return;
    String? error;
    try {
      error = view.applySpace(CafeSpace.decode(next.encode()));
    } catch (_) {
      error = 'range';
    }
    setState(() {
      roomSaveFailed = false;
      roomError = error == null
          ? null
          : '\uADF8\uACF3\uC5D0\uB294 \uB193\uC744 \uC218 \uC5C6\uC5B4\uC694. \uBB38 \uC55E\uACFC \uD1B5\uB85C\uB97C \uBE44\uC6CC \uC8FC\uC138\uC694.';
      placing = false;
    });
  }

  void _editRoom() {
    if (roomLoading || roomLoadFailed || roomSaving || view.travelling) return;
    if (view.seat != null) {
      final point = view.world.targetApproach(CafeTarget.forSeat(view.seat!));
      view.seat = null;
      view.updateCamera(
        CafeCamera(position: point, yaw: view.camera.yaw, pitch: -.12),
      );
    }
    view.look(0, 0);
    setState(() {
      editing = true;
      selectedObject = null;
      roomError = null;
    });
  }

  Future<void> _finishRoom() async {
    if (await _saveRoom() && mounted) {
      setState(() {
        editing = false;
        placing = false;
        selectedObject = null;
      });
    }
  }

  void _discardRoom() {
    view.applySpace(savedRoom, validate: false);
    setState(() {
      editing = false;
      placing = false;
      selectedObject = null;
      roomError = null;
    });
  }

  Future<void> _requestClose({bool leaving = false}) async {
    if (opening || widget.saveFailed || roomSaving) return;
    if (roomDirty) {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            '\uACF5\uAC04 \uBCC0\uACBD\uC744 \uC800\uC7A5\uD560\uAE4C\uC694?',
          ),
          content: const Text(
            '\uC800\uC7A5\uD558\uBA74 \uB2E4\uC74C\uC5D0\uB3C4 \uAC19\uC740 \uBC30\uCE58\uB85C \uB3CC\uC544\uC640\uC694.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('\uACC4\uC18D \uAFB8\uBBF8\uAE30'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('\uBCC0\uACBD \uCDE8\uC18C'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('\uC800\uC7A5\uD558\uACE0 \uB098\uAC00\uAE30'),
            ),
          ],
        ),
      );
      if (save == null || !mounted) return;
      if (save) {
        if (!await _saveRoom()) return;
      } else {
        _discardRoom();
      }
    }
    if (!mounted) return;
    if (leaving) {
      widget.onLeave();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _chooseRoomObject() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('\uAFB8\uBC00 \uBB3C\uAC74'),
        children: [
          for (final obj in view.world.objects.values)
            SimpleDialogOption(
              key: ValueKey('room-object-${obj.id}'),
              onPressed: () => Navigator.pop(context, obj.id),
              child: Text(obj.label),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('\uB2EB\uAE30'),
          ),
        ],
      ),
    );
    if (chosen != null && mounted) {
      final object = view.world.objects[chosen];
      if (object?.kind == CafeObjectKind.frame) {
        final p = object!.pivot;
        final eye = CafePoint(p.x, 1.62, p.z + (p.z > 0 ? -1.6 : 1.6));
        if (view.world.canStand(eye)) {
          view.updateCamera(
            CafeCamera(
              position: eye,
              yaw: p.z > 0 ? math.pi : 0,
              pitch: math.atan2(p.y - eye.y, 1.6),
            ),
          );
        }
      }
      setState(() {
        selectedObject = chosen;
        placing = false;
      });
    }
  }

  Widget _roomControls() {
    final object = view.world.objects[selectedObject];
    Widget action(String label, VoidCallback? run, {String? key}) => TextButton(
      key: key == null ? null : ValueKey(key),
      onPressed: run,
      child: Text(label),
    );
    Widget options(
      String label,
      int value,
      List<String> names,
      void Function(int) changed,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Wrap(
          spacing: 4,
          children: [
            for (var i = 0; i < names.length; i++)
              ChoiceChip(
                label: Text(names[i]),
                selected: value == i,
                onSelected: roomSaving ? null : (_) => changed(i),
              ),
          ],
        ),
      ],
    );
    final space = view.space;
    return Positioned(
      right: 12,
      bottom: 12,
      left: MediaQuery.sizeOf(context).width < 500 ? 12 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 340,
          maxHeight: MediaQuery.sizeOf(context).height * .54,
        ),
        child: Card(
          color: const Color(0xfff4eddf),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        placing
                            ? '\uB193\uC744 \uC704\uCE58\uB97C \uB20C\uB7EC \uC8FC\uC138\uC694'
                            : object?.label ??
                                  '\uBB3C\uAC74\uC744 \uB20C\uB7EC \uAFB8\uBA70 \uBCF4\uC138\uC694',
                      ),
                    ),
                    if (!placing)
                      IconButton(
                        tooltip: '\uAFB8\uBC00 \uBB3C\uAC74 \uBAA9\uB85D',
                        onPressed: roomSaving ? null : _chooseRoomObject,
                        icon: const Icon(Icons.format_list_bulleted),
                      ),
                  ],
                ),
                if (placing)
                  action(
                    '\uC704\uCE58 \uC120\uD0DD \uCDE8\uC18C',
                    () => setState(() => placing = false),
                  )
                else ...[
                  if (object != null && object.kind != CafeObjectKind.light)
                    Wrap(
                      children: [
                        action(
                          '\uC62E\uAE30\uAE30',
                          roomSaving
                              ? null
                              : () => setState(() => placing = true),
                          key: 'room-move',
                        ),
                        if (object.kind != CafeObjectKind.frame)
                          action(
                            '\uB3CC\uB9AC\uAE30',
                            roomSaving
                                ? null
                                : () {
                                    final pose = space.pose(object.id);
                                    _changeRoom(
                                      space.copy(
                                        poses: {
                                          ...space.poses,
                                          object.id: pose.copy(
                                            turn:
                                                (pose.turn + math.pi / 12) %
                                                (math.pi * 2),
                                          ),
                                        },
                                      ),
                                    );
                                  },
                            key: 'room-rotate',
                          ),
                      ],
                    ),
                  if (object != null && object.kind != CafeObjectKind.light)
                    Wrap(
                      children: [
                        for (final direction in [
                          (-.05, 0.0, '\uC67C\uCABD'),
                          (.05, 0.0, '\uC624\uB978\uCABD'),
                          (
                            0.0,
                            -.05,
                            object.kind == CafeObjectKind.frame
                                ? '\uC544\uB798'
                                : '\uC55E',
                          ),
                          (
                            0.0,
                            .05,
                            object.kind == CafeObjectKind.frame
                                ? '\uC704'
                                : '\uB4A4',
                          ),
                        ])
                          action(
                            direction.$3,
                            roomSaving
                                ? null
                                : () {
                                    final delta =
                                        object.kind == CafeObjectKind.frame
                                        ? CafePoint(
                                            (view.camera.right.x < 0 ? -1 : 1) *
                                                direction.$1,
                                            direction.$2,
                                            0,
                                          )
                                        : view.camera.right * direction.$1 +
                                              CafePoint(
                                                    view.camera.forward.x,
                                                    0,
                                                    view.camera.forward.z,
                                                  ).normalized *
                                                  (-direction.$2);
                                    final point = object.pivot + delta;
                                    _changeRoom(
                                      view.world.placed(object.id, point),
                                    );
                                  },
                          ),
                      ],
                    ),
                  if (object?.kind == CafeObjectKind.frame) ...[
                    options(
                      '\uC561\uC790',
                      space.frames[object!.id] ?? 0,
                      ['\uC6D4\uB11B', '\uC624\uD06C', '\uBA39\uAC08\uC0C9'],
                      (v) => _changeRoom(
                        space.copy(frames: {...space.frames, object.id: v}),
                      ),
                    ),
                    options(
                      '\uADF8\uB9BC',
                      space.art[object.id] ?? object.defaultArtwork ?? 0,
                      [
                        '\uC78E\uACFC \uAC00\uC9C0',
                        '\uBB3C\uACB0\uACFC \uBE5B',
                        '\uCC45\uACFC \uC5F0\uD544',
                      ],
                      (v) => _changeRoom(
                        space.copy(art: {...space.art, object.id: v}),
                      ),
                    ),
                    options(
                      '\uC885\uC774 \uC5EC\uBC31',
                      space.mats[object.id] ?? 0,
                      [
                        '\uBBF8\uC0C9',
                        '\uBC1D\uC740 \uC885\uC774',
                        '\uC881\uC740 \uC5EC\uBC31',
                      ],
                      (v) => _changeRoom(
                        space.copy(mats: {...space.mats, object.id: v}),
                      ),
                    ),
                  ],
                  if (object?.id == 'shared.book')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '\uB178\uD2B8 \uD3BC\uCCD0 \uB450\uAE30',
                      ),
                      value: space.bookOpen,
                      onChanged: roomSaving
                          ? null
                          : (v) => _changeRoom(space.copy(bookOpen: v)),
                    ),
                  if (object?.id == 'shared.cup') ...[
                    options(
                      '\uCC3B\uC794',
                      space.mug,
                      ['\uBBF8\uC0C9', '\uD759\uBE5B', '\uC62C\uB9AC\uBE0C'],
                      (v) => _changeRoom(space.copy(mug: v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('\uCC28\uAC00 \uB2F4\uAE34 \uC794'),
                      value: space.cupFull,
                      onChanged: roomSaving
                          ? null
                          : (v) => _changeRoom(space.copy(cupFull: v)),
                    ),
                  ],
                  if (object?.kind == CafeObjectKind.floor &&
                      !object!.id.startsWith('plant.'))
                    options(
                      '\uBC29\uC11D',
                      space.cushion,
                      ['\uC62C\uB9AC\uBE0C', '\uD759\uBE5B', '\uBBF8\uC0C9'],
                      (v) => _changeRoom(space.copy(cushion: v)),
                    ),
                  if (object?.id.startsWith('plant.') == true)
                    options(
                      '\uD654\uBD84 \uC0C9',
                      space.pot,
                      ['\uD1A0\uBD84', '\uC62C\uB9AC\uBE0C', '\uBBF8\uC0C9'],
                      (v) => _changeRoom(space.copy(pot: v)),
                    ),
                  if (object == null ||
                      object.kind == CafeObjectKind.light) ...[
                    const Text('\uC2E4\uB0B4 \uC870\uBA85 \uBC1D\uAE30'),
                    Slider(
                      key: const ValueKey('room-brightness'),
                      value: brightnessPreview ?? space.brightness,
                      min: .8,
                      max: 1.25,
                      divisions: 9,
                      onChanged: roomSaving
                          ? null
                          : (v) => setState(() => brightnessPreview = v),
                      onChangeEnd: roomSaving
                          ? null
                          : (v) {
                              brightnessPreview = null;
                              _changeRoom(space.copy(brightness: v));
                            },
                    ),
                    options(
                      '\uBE5B\uC758 \uC628\uAE30',
                      (space.warmth * 2).round(),
                      [
                        '\uBD80\uB4DC\uB7EC\uC6B4 \uBC31\uC0C9',
                        '\uB530\uB73B\uD558\uAC8C',
                        '\uB354 \uB530\uB73B\uD558\uAC8C',
                      ],
                      (v) => _changeRoom(space.copy(warmth: v / 2)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '\uC815\uC6D0 \uBB38 \uC5F4\uC5B4 \uB450\uAE30',
                      ),
                      value: space.doorOpen,
                      onChanged: roomSaving
                          ? null
                          : (v) => _changeRoom(space.copy(doorOpen: v)),
                    ),
                  ],
                  if (view.inCourtyard)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '\uB730\uC758 \uCC3B\uC794 \uCC44\uC6B0\uAE30',
                      ),
                      value: space.gardenTea,
                      onChanged: roomSaving
                          ? null
                          : (v) => _changeRoom(space.copy(gardenTea: v)),
                    ),
                  Wrap(
                    children: [
                      action(
                        roomSaving
                            ? '\uC800\uC7A5 \uC911'
                            : '\uAFB8\uBBF8\uAE30 \uC644\uB8CC',
                        roomSaving ? null : _finishRoom,
                        key: 'room-finish',
                      ),
                      action(
                        '\uBCC0\uACBD \uCDE8\uC18C',
                        roomSaving ? null : _discardRoom,
                        key: 'room-cancel',
                      ),
                    ],
                  ),
                ],
                if (roomError != null)
                  Text(
                    roomError!,
                    key: const ValueKey('room-error'),
                    style: const TextStyle(color: burgundy),
                  ),
                if (roomSaveFailed && !placing)
                  action(
                    '\uB2E4\uC2DC \uC800\uC7A5',
                    roomSaving ? null : _finishRoom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
    showIntro = false;
    if (lastCourtyard != view.inCourtyard) {
      lastCourtyard = view.inCourtyard;
      soundGeneration++;
      unawaited(ambience.stop());
      unawaited(calmAudio.stop());
      sound = false;
      calmHint = null;
    }
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
        if (target == CafeTarget.exit && !widget.saveFailed) {
          _requestClose(leaving: true);
        }
      });
    }
  }

  void _activate(CafeTarget target) {
    if (opening ||
        widget.saveFailed ||
        dialogOpen ||
        view.travelling ||
        roomLoading ||
        roomSaving ||
        editing) {
      return;
    }
    if (target == CafeTarget.bell || target == CafeTarget.tea) {
      final distance =
          (view.camera.position - view.world.targetAnchor(target)).length;
      if (distance < 2.0) {
        final bell = target == CafeTarget.bell;
        if (bell) {
          view.ring();
        } else {
          view.pourTea();
          view.applySpace(view.space.copy(gardenTea: true));
          unawaited(_saveRoom());
        }
        setState(() => calmHint = bell ? '종소리가 천천히 잦아들어요.' : '따뜻한 차를 놓아 두었어요.');
        unawaited(
          (widget.playCalmSound ?? calmAudio.play)(
            bell ? 'bell' : 'tea',
          ).catchError((Object _) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('소리를 재생하지 못했어요. 다시 눌러 주세요.')),
              );
            }
          }),
        );
      } else {
        pending = null;
        if (view.visit(target)) {
          setState(() => calmHint = '가까이 가면 한 번 더 눌러 주세요.');
        }
      }
      return;
    }
    if ((target == CafeTarget.courtyard || target == CafeTarget.cafeReturn) &&
        !view.space.doorOpen) {
      view.applySpace(view.space.copy(doorOpen: true));
      unawaited(_saveRoom());
      return;
    }
    calmHint = null;
    if (target == CafeTarget.shared &&
        view.seat == CafeSeat.shared &&
        !view.space.bookOpen) {
      view.applySpace(view.space.copy(bookOpen: true));
      unawaited(_saveRoom());
      return;
    }
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
      if (roomDirty && !await _saveRoom()) return;
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
    if (mounted &&
        view.applySpace(
              view.space.copy(
                selectedBookId: bookId,
                clearBook: bookId == null,
              ),
            ) ==
            null) {
      unawaited(_saveRoom());
    }
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
          for (final target in view.world.targets)
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
    canPop: !opening && !widget.saveFailed && !roomSaving && !roomDirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_requestClose());
    },
    child: ColoredBox(
      color: const Color(0xff392e25),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CafeScene(
            controller: view,
            interactive:
                !opening && !widget.saveFailed && !roomLoading && !roomSaving,
            editing: editing,
            placingId: placing ? selectedObject : null,
            onObjectSelected: (id) {
              if (!editing) _editRoom();
              setState(() => selectedObject = id);
            },
            onObjectPlaced: (point) {
              if (selectedObject != null) {
                _changeRoom(view.world.placed(selectedObject!, point));
              }
            },
            onTargetSelected: _activate,
            onWrite: _write,
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
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xeefaf5eb),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                MediaQuery.textScalerOf(context).scale(16) > 22
                                    ? (view.inCourtyard ? '고요한 뜰' : '필사 카페')
                                    : view.inCourtyard
                                    ? '쓰는 인간 · 고요한 뜰'
                                    : '쓰는 인간 · 필사 카페',
                                style: TextStyle(color: brandInk, fontSize: 16),
                              ),
                            ),
                            IconButton(
                              tooltip: editing
                                  ? '\uAFB8\uBBF8\uAE30 \uC644\uB8CC'
                                  : '\uACF5\uAC04 \uAFB8\uBBF8\uAE30',
                              key: const ValueKey('room-edit'),
                              onPressed:
                                  roomLoading ||
                                      roomLoadFailed ||
                                      roomSaving ||
                                      view.travelling
                                  ? null
                                  : editing
                                  ? _finishRoom
                                  : _editRoom,
                              icon: Icon(
                                editing ? Icons.check : Icons.brush_outlined,
                                color: brandInk,
                              ),
                            ),
                            IconButton(
                              tooltip: view.inCourtyard
                                  ? (sound ? '물소리 끄기' : '물소리 켜기')
                                  : (sound ? '빗소리 끄기' : '빗소리 켜기'),
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
                                  opening ||
                                      widget.saveFailed ||
                                      view.travelling
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
                                  : _requestClose,
                              icon: const Icon(Icons.close, color: brandInk),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showIntro ||
                        opening ||
                        view.travelling ||
                        calmHint != null ||
                        view.resting ||
                        view.seat != null)
                      IgnorePointer(
                        child: Text(
                          opening
                              ? '글 여는 중'
                              : view.travelling
                              ? '천천히 걸어가는 중'
                              : calmHint != null
                              ? calmHint!
                              : view.resting
                              ? '잠시 머물러도 좋아요.'
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
                    if ((view.seat != null || view.resting) && !view.travelling)
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
          if (editing) _roomControls(),
          if (!editing && (roomLoading || roomError != null))
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                color: const Color(0xfff3eadb),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        roomLoading
                            ? '\uACF5\uAC04 \uBD88\uB7EC\uC624\uB294 \uC911'
                            : roomError!,
                        key: const ValueKey('room-error'),
                      ),
                      if (!roomLoading)
                        TextButton(
                          onPressed: roomLoadFailed ? _loadRoom : _saveRoom,
                          child: Text(
                            roomLoadFailed
                                ? '\uB2E4\uC2DC \uBD88\uB7EC\uC624\uAE30'
                                : '\uB2E4\uC2DC \uC800\uC7A5',
                          ),
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
