import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/cafe_ambience.dart';
import '../audio/cafe_soundscape.dart';
import '../cafe/cafe_atmosphere.dart';
import 'cafe_atmosphere_sheet.dart';

import '../cafe/cafe_visit.dart';
import '../cafe/cafe_world.dart';
import '../cafe/cafe_camera.dart';
import '../cafe/cafe_space.dart';
import '../cafe/cafe_home.dart';
import 'cafe_ritual.dart';
import '../cafe/cafe_view_controller.dart';
import '../data/model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cafe_scene.dart';
import 'paper.dart';
import 'paper_panel.dart';

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
    this.moment,
    this.lastSentence = '',
    this.pastWriting,
    this.onOpenPastWriting,
    this.onTranscribe,
    this.soundscape,
  });
  final CafeSoundOutput? soundscape;
  final Future<void> Function(String name)? playCalmSound;
  final CafeSpaceStore? spaceStore;
  final DateTime? moment;
  final String lastSentence;
  final CafePastWriting? pastWriting;
  final Future<bool> Function(String pageId)? onOpenPastWriting;
  final Future<bool> Function(
    CafeSeat seat,
    String? bookId,
    CafeSentence sentence,
  )?
  onTranscribe;
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
  late final ambience = widget.soundscape ?? createCafeSoundscape(_soundFailed);
  final calmAudio = CafeCalmAudio();
  bool lastCourtyard = false;
  bool showIntro = true;
  bool ritualOpening = false;
  CafeSentence? retrySentence;
  late final moment = widget.moment ?? DateTime.now();
  String? calmHint;
  bool sound = false, soundBusy = false;
  final soundState = ValueNotifier(false);
  void _setSound(bool value) {
    sound = value;
    soundState.value = value;
  }

  int soundGeneration = 0;
  void _soundFailed(Object error) {
    soundGeneration++;
    unawaited(ambience.stop());
    if (mounted) {
      setState(() {
        _setSound(false);
        calmHint = '소리를 재생하지 못했어요. 소리를 다시 켜 주세요.';
      });
    }
  }

  void _updateSound([CafeAtmosphere? mix]) => ambience.update(
    CafeSoundFrame.at(
      mix: mix ?? view.space.atmosphere,
      camera: view.camera,
      courtyard: view.inCourtyard,
      doorOpen: true,
      weather: view.world.weather,
      step: view.walkSpeed > .02 ? (view.walkPhase / math.pi).floor() : null,
    ),
  );
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
      if (mounted) setState(() => _setSound(false));
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
        await calmAudio.stop();
      } else {
        _updateSound();
        await ambience.start();
      }
      if (mounted && generation == soundGeneration) {
        setState(() => _setSound(desired));
      }
    } catch (error) {
      if (mounted && generation == soundGeneration) _soundFailed(error);
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
    soundState.dispose();
    view.removeListener(_viewChanged);
    view.dispose();
    super.dispose();
  }

  double? brightnessPreview, itemLightPreview;
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
      // Schema and storage errors still fail the load. Preserve a prior valid
      // saved arrangement if newer item footprints require a small adjustment.
      view.applySpace(value, validate: false);
      final layoutError =
          view.world.validateLayout() ??
          view.world.linkedWorld.validateLayout();
      if (layoutError != null) {
        roomError =
            '\uC800\uC7A5\uD55C \uBC30\uCE58\uB97C \uBD88\uB7EC\uC654\uC5B4\uC694. \uAFB8\uBBF8\uAE30\uC5D0\uC11C \uC0C1\uD310 \uB05D\uACFC \uD1B5\uB85C\uB97C \uD655\uC778\uD574 \uC8FC\uC138\uC694.';
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
      itemLightPreview = null;
    });
  }

  Future<void> _editRoom() async {
    if (!await _putDown() || !mounted) return;
    view.inspect(null);
    if (roomLoading || roomLoadFailed || roomSaving || view.travelling) return;
    if (view.seat != null) {
      final point = view.world.targetApproach(CafeTarget.forSeat(view.seat!));
      view.seat = null;
      view.activeChairId = null;
      view.updateCamera(
        CafeCamera(position: point, yaw: view.camera.yaw, pitch: -.12),
      );
    }
    if (view.resting) {
      final point = view.world.targetApproach(
        view.restingTarget ?? CafeTarget.bench,
      );
      view.updateCamera(
        CafeCamera(position: point, yaw: view.camera.yaw, pitch: -.12),
      );
    }
    view.resting = false;
    view.look(0, 0);
    setState(() {
      editing = true;
      selectedObject = null;
      roomError = null;
    });
  }

  Future<void> _finishRoom() async {
    if (await _saveRoom() && mounted) {
      view.look(0, 0);
      setState(() {
        editing = false;
        placing = false;
        selectedObject = null;
      });
    }
  }

  void _discardRoom() {
    view.applySpace(savedRoom, validate: false);
    view.look(0, 0);
    setState(() {
      editing = false;
      placing = false;
      selectedObject = null;
      roomError = null;
    });
  }

  Future<void> _requestClose({bool leaving = false}) async {
    if (view.using || !await _putDown() || !mounted) return;
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

  void _focusRoomObject(String id) {
    final object = view.world.objects[id];
    if (object == null) return;
    final p = object.pivot;
    final direction = (view.camera.position - p);
    final yaw = math.atan2(direction.x, direction.z);
    for (final distance in [.70, 1.0, 1.4, 1.8]) {
      for (final turn in [0.0, math.pi / 2, -math.pi / 2, math.pi]) {
        final eye = CafePoint(
          p.x + math.sin(yaw + turn) * distance,
          1.62,
          p.z + math.cos(yaw + turn) * distance,
        );
        if (!view.world.canStand(eye)) continue;
        view.updateCamera(
          CafeCamera(
            position: eye,
            yaw: math.atan2(p.x - eye.x, eye.z - p.z),
            pitch:
                (math.atan2(
                          p.y +
                              switch (object.type) {
                                CafeItemType.chair => .55,
                                CafeItemType.table || CafeItemType.group => .76,
                                CafeItemType.plant
                                    when object.kind == CafeObjectKind.garden =>
                                  object.id.startsWith('garden.tree')
                                      ? 1.1
                                      : .25,
                                _ => .08,
                              } -
                              eye.y,
                          distance,
                        ) -
                        .30)
                    .clamp(-1.15, .4),
          ),
        );
        return;
      }
    }
  }

  Future<void> _chooseRoomObject() async {
    var category = '전체';
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SimpleDialog(
          title: const Text('꾸밀 물건'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final label in ['전체', '가구', '소품', '책', '조명', '식물', '그림'])
                    ChoiceChip(
                      label: Text(label),
                      selected: category == label,
                      onSelected: (_) => update(() => category = label),
                    ),
                ],
              ),
            ),
            for (final obj in view.world.objects.values.where(
              (o) => category == '전체' || o.type.category == category,
            ))
              SimpleDialogOption(
                key: ValueKey('room-object-${obj.id}'),
                onPressed: () => Navigator.pop(context, obj.id),
                child: Text(obj.label),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      if (view.world.objects[chosen]?.kind == CafeObjectKind.frame) {
        _focusRoomObject(chosen);
      }
      setState(() {
        selectedObject = chosen;
        placing = false;
      });
    }
  }

  Future<void> _openRitual(String page) async {
    if (roomLoading ||
        roomSaving ||
        roomLoadFailed ||
        opening ||
        dialogOpen ||
        view.travelling ||
        view.using ||
        ritualOpening) {
      return;
    }
    if (!await _putDown() || !mounted) return;
    view.inspect(null);
    setState(() => dialogOpen = true);
    Widget buildRitual(BuildContext routeContext) => page == 'ambience'
        ? CafeAtmosphereSheet(
            value: view.space.atmosphere,
            legacyRain: view.space.home.mood == 2,
            playing: soundState,
            onPreview: (mix) {
              if (sound) _updateSound(mix);
              unawaited(
                calmAudio.setVolume(mix.actionVolume).catchError(_soundFailed),
              );
            },
            onSave: (mix) => _storeUse(view.space.copy(atmosphere: mix)),
            onToggle: () async {
              await _toggleSound();
              return sound;
            },
          )
        : CafeRitualSheet(
            page: page,
            home: view.space.home,
            moment: moment,
            currentSeat: view.seat,
            chair: view.activeChairId,
            lastSentence: widget.lastSentence,
            pastWriting: widget.pastWriting,
            canTranscribe: widget.onTranscribe != null,
            onSave: (home) => _storeUse(
              view.space.copy(
                home: home,
                atmosphere: view.space.atmosphere.copy(
                  weather: view.world.weather,
                ),
              ),
            ),
          );
    if (!context.mounted) return;
    final pending = page == 'ambience' || page == 'memory'
        ? Navigator.of(context).push<Object>(paperSheetRoute(buildRitual))
        : showDialog<Object>(context: context, builder: buildRitual);
    final result = await pending;
    if (!mounted) return;
    setState(() => dialogOpen = false);
    if (sound) _updateSound();
    if (result is CafeSentence) {
      await _startSentence(result);
    } else if (result == CafeRitualAction.openPastWriting) {
      final past = widget.pastWriting;
      final open = widget.onOpenPastWriting;
      if (past == null || open == null) return;
      setState(() => ritualOpening = true);
      try {
        if (!await open(past.pageId) && mounted) {
          setState(() => calmHint = '필사한 쪽을 열지 못했어요. 다시 열어 주세요.');
        }
      } finally {
        if (mounted) setState(() => ritualOpening = false);
      }
    } else if (result == CafeRitualAction.rainWindow) {
      if (await _storeUse(
            view.space.copy(
              home: view.space.home.copy(mood: 2),
              atmosphere: view.space.atmosphere.copy(weather: CafeWeather.rain),
            ),
          ) &&
          mounted) {
        await _goToSeat(CafeSeat.window);
      }
    } else if (result == CafeRitualAction.returnSeat) {
      final seat =
          CafeSeat.values
              .where((s) => s.name == view.space.home.seat)
              .firstOrNull ??
          CafeSeat.window;
      await _goToSeat(seat, chair: view.space.home.chair);
    }
  }

  Future<bool> _goToSeat(CafeSeat seat, {String? chair}) async {
    if (view.using || view.travelling || !await _putDown() || !mounted) {
      return false;
    }
    Future<bool> travel(CafeTarget target) async {
      if (!view.visit(target)) return false;
      return view.travelFinished;
    }

    if ((seat == CafeSeat.garden) != view.inCourtyard) {
      if (!await travel(
            view.inCourtyard ? CafeTarget.cafeReturn : CafeTarget.courtyard,
          ) ||
          !mounted) {
        return false;
      }
    }
    final defaultChair = seat.name.startsWith('window')
        ? 'desk.${seat.name}.chair'
        : seat == CafeSeat.quiet
        ? 'quiet.chair'
        : null;
    final chairId = chair ?? defaultChair;
    final saved = view.world.objects[chairId];
    final okay = saved?.seat == seat
        ? view.visitChair(chairId!)
        : view.visit(CafeTarget.forSeat(seat));
    if (!okay) {
      setState(() => calmHint = '그 자리까지 걸어갈 수 없어요. 가까운 빈 바닥을 눌러 주세요.');
      return false;
    }
    final complete = await view.travelFinished;
    if (mounted && complete) setState(() => calmHint = '아무것도 쓰지 않고 머물러도 좋아요.');
    return mounted && complete;
  }

  Future<void> _startSentence(CafeSentence sentence) async {
    if (ritualOpening ||
        opening ||
        widget.saveFailed ||
        widget.onTranscribe == null) {
      return;
    }
    ritualOpening = true;
    try {
      if (view.seat == null &&
          !await _goToSeat(
            CafeSeat.values
                    .where((s) => s.name == view.space.home.seat)
                    .firstOrNull ??
                CafeSeat.window,
            chair: view.space.home.chair,
          )) {
        return;
      }
      if (!mounted || view.seat == null) return;
      setState(() => opening = true);
      if (view.space.home.seat == null) {
        view.applySpace(
          view.space.copy(
            home: view.space.home.copy(
              seat: view.seat!.name,
              chair: view.activeChairId,
            ),
          ),
          validate: false,
        );
      }
      if (roomDirty && !await _saveRoom()) return;
      final okay = await widget.onTranscribe!(view.seat!, bookId, sentence);
      if (okay) {
        retrySentence = null;
      } else if (mounted) {
        setState(() {
          retrySentence = sentence;
          error = '글을 열지 못했어요. 다시 눌러 주세요.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          retrySentence = sentence;
          error = '글을 열지 못했어요. 다시 눌러 주세요.';
        });
      }
    } finally {
      ritualOpening = false;
      if (mounted) setState(() => opening = false);
    }
  }

  Widget _arrivalNote() {
    if (editing ||
        opening ||
        dialogOpen ||
        view.travelling ||
        view.using ||
        view.heldId != null ||
        view.contextId != null ||
        view.seat != null ||
        !showIntro) {
      return const SizedBox.shrink();
    }
    final favorite = CafeSeat.values
        .where((s) => s.name == view.space.home.seat)
        .firstOrNull;
    return Wrap(
      children: [
        TextButton(
          key: const ValueKey('cafe-homecoming'),
          onPressed: roomLoading || roomLoadFailed || roomSaving
              ? null
              : () => _openRitual('arrival'),
          child: Text(
            favorite == null
                ? '오늘은 한 줄만 남겨도 좋아요.'
                : '${favorite.label}에 다시 앉아봐요.',
          ),
        ),
        TextButton(
          key: const ValueKey('cafe-today'),
          onPressed: roomLoading || roomLoadFailed || roomSaving
              ? null
              : () => _openRitual('today'),
          child: const Text('오늘의 문장'),
        ),
      ],
    );
  }

  bool _activateItem(String id) {
    if (editing ||
        roomLoading ||
        roomSaving ||
        opening ||
        dialogOpen ||
        widget.saveFailed ||
        view.travelling ||
        roomLoadFailed ||
        view.using) {
      return true;
    }
    final object = view.world.objects[id];
    if (object == null) return false;
    if (id == 'sound.musicbox') {
      if ((object.pivot - view.camera.position).length > 2.5) {
        setState(() => calmHint = '가까이 다가와 음악 상자를 눌러 보세요.');
      } else {
        unawaited(_openRitual('ambience'));
      }
      return true;
    }
    if (id.startsWith('ritual.')) {
      if ((object.pivot - view.camera.position).length > 2) {
        setState(() => calmHint = '가까이 다가와 쪽지를 눌러 보세요.');
        return true;
      }
      unawaited(
        _openRitual(
          id == 'ritual.memory'
              ? 'memory'
              : id == 'ritual.letter'
              ? 'letter'
              : 'today',
        ),
      );
      return true;
    }
    if (object.type == CafeItemType.chair) {
      unawaited(_useItem(id));
      return true;
    }
    if ((object.pivot - view.camera.position).length > 2.0 &&
        view.heldId != id) {
      return false;
    }
    if (const {
      CafeItemType.cup,
      CafeItemType.volume,
      CafeItemType.pencil,
      CafeItemType.notebook,
      CafeItemType.lamp,
      CafeItemType.plant,
      CafeItemType.vase,
      CafeItemType.frame,
      CafeItemType.stack,
      CafeItemType.cloth,
      CafeItemType.fixture,
    }.contains(object.type)) {
      unawaited(_useItem(id));
      return true;
    }
    return false;
  }

  Future<void> _playCalm(String name) async {
    final volume = view.space.atmosphere.actionVolume;
    if (volume == 0) return;
    if (widget.playCalmSound case final play?) {
      await play(name);
    } else {
      await calmAudio.play(name, volume: volume);
    }
  }

  Future<bool> _gesture(String id, CafeUseKind kind) async {
    if (sound) {
      final name = switch (kind) {
        CafeUseKind.sip => 'sip',
        CafeUseKind.open || CafeUseKind.close => 'page',
        CafeUseKind.refill || CafeUseKind.water => 'tea',
        CafeUseKind.putDown => 'place',
        _ => 'touch',
      };
      unawaited(
        _playCalm(name).catchError((Object _) {
          if (mounted) {
            setState(() => calmHint = '소리를 재생하지 못했어요. 소리를 다시 켜 주세요.');
          }
        }),
      );
    }
    final completed = await view.performUse(id, kind);
    return mounted && completed;
  }

  Future<bool> _putDown() async {
    if (view.using) return false;
    final id = view.heldId;
    if (id == null) return true;
    // Returning to the remembered support never changes the saved pose.
    return _gesture(id, CafeUseKind.putDown);
  }

  Future<void> _walk(CafePoint point) async {
    if (await _putDown() && mounted) {
      view.inspect(null);
      view.walkTo(point);
    }
  }

  Future<bool> _storeUse(CafeSpace next) async {
    // Use changes do not move anything: retain valid old layouts that newer
    // placement rules would flag, rather than blocking drinking or lighting.
    final camera = view.camera;
    view.applySpace(next, validate: false);
    view.updateCamera(
      CafeCamera(
        position: view.camera.position,
        yaw: camera.yaw,
        pitch: camera.pitch,
      ),
      face: false,
    );
    return _saveRoom();
  }

  Future<void> _useItem(String id) async {
    if (view.using || roomSaving || roomLoadFailed || editing) return;
    final obj = view.world.objects[id];
    if (obj == null) return;
    if (view.contextId != id) calmHint = null;
    if (view.heldId != null && view.heldId != id && !await _putDown()) return;
    if (!mounted) return;
    switch (obj.type) {
      case CafeItemType.chair:
        view.inspect(id);
        if (view.activeChairId == id && view.seat != null) {
          view.stand();
          return;
        }
        if ((obj.pivot - view.camera.position).length < 2 &&
            view.space.uses[id] != true) {
          if (!await _moveChair(id, push: false)) return;
        }
        if (!view.visitChair(id)) {
          setState(() => calmHint = '의자 뒤의 통로를 비워 주세요.');
        }
      case CafeItemType.cup:
        if (view.heldId != id) {
          await _gesture(id, CafeUseKind.pickUp);
        } else {
          await _drink(id);
        }
      case CafeItemType.volume:
        if (view.heldId != id) {
          await _gesture(id, CafeUseKind.pickUp);
        } else {
          await _gesture(
            id,
            view.heldBookOpen ? CafeUseKind.close : CafeUseKind.open,
          );
        }
      case CafeItemType.pencil:
        if (view.heldId != id) {
          await _gesture(id, CafeUseKind.pickUp);
        } else {
          await _writeWith(id);
        }
      case CafeItemType.notebook:
        final open = view.space.state(
          id,
          fallback: id == 'shared.book' ? view.space.bookOpen : true,
        );
        if (!open) {
          if (await _gesture(id, CafeUseKind.open)) {
            await _storeUse(view.space.withState(id, true));
          }
        } else if (view.seat != null) {
          await _writeWith(id);
        } else {
          final target = _itemSeat(id);
          if (target != null) view.visit(CafeTarget.forSeat(target));
          view.inspect(id);
        }
      case CafeItemType.lamp:
        if (await _gesture(id, CafeUseKind.touch)) {
          await _storeUse(view.space.withState(id, !view.space.state(id)));
        }
      case CafeItemType.plant:
        view.inspect(id);
        setState(
          () => calmHint = view.space.uses[id] == true
              ? '물을 주었어요. 잠시 잎을 바라봐요.'
              : '잎을 바라보거나 물을 줄 수 있어요.',
        );
      case CafeItemType.vase:
        if (await _gesture(id, CafeUseKind.touch)) {
          await _storeUse(
            view.space
                .withState(id, true)
                .withAccent(id, (view.space.accent(id) + 1) % 3),
          );
        }
      case CafeItemType.frame:
        view.inspect(id);
        setState(() => calmHint = '그림을 천천히 바라봐요. 길게 누르면 바꿀 수 있어요.');
      default:
        await _gesture(id, CafeUseKind.touch);
        setState(() => calmHint = '길게 누르면 내 취향으로 꾸밀 수 있어요.');
    }
  }

  CafeSeat? _itemSeat(String id) {
    if (id.startsWith('shared.')) return CafeSeat.shared;
    if (id.startsWith('quiet.')) return CafeSeat.quiet;
    if (id.startsWith('garden.')) return CafeSeat.garden;
    for (final seat in CafeSeat.values) {
      if (id.startsWith('desk.${seat.name}.')) return seat;
    }
    return view.seat;
  }

  Future<void> _drink(String id) async {
    final obj = view.world.objects[id]!;
    final amount = view.space.amount(id, fallback: obj.defaultState ? 3 : 0);
    if (amount == 0) {
      await _refill(id);
      return;
    }
    if (await _gesture(id, CafeUseKind.sip)) {
      await _storeUse(view.space.withAmount(id, amount - 1));
      if (mounted) {
        setState(
          () => calmHint = amount == 1
              ? '차를 다 마셨어요. 다시 따를 수 있어요.'
              : '따뜻한 한 모금. 잠시 쉬어 가요.',
        );
      }
    }
  }

  Future<void> _refill(String id) async {
    if (await _gesture(id, CafeUseKind.refill)) {
      await _storeUse(view.space.withAmount(id, 3));
      if (mounted) setState(() => calmHint = '따뜻한 차를 채웠어요.');
    }
  }

  Future<void> _writeWith(String id) async {
    if (await _gesture(id, CafeUseKind.write) && await _putDown() && mounted) {
      if (view.seat != null) {
        await _write();
      } else {
        final seat = _itemSeat(id);
        if (seat != null) {
          view.visit(CafeTarget.forSeat(seat));
          setState(() => calmHint = '자리에 앉은 뒤 노트를 눌러 써요.');
        }
      }
    }
  }

  Future<void> _readHeldBook() async {
    final id = view.heldId;
    if (id == null || view.using) return;
    if (!view.heldBookOpen && !await _gesture(id, CafeUseKind.open)) return;
    if (!mounted) return;
    if (id.startsWith('shelf.recommendations')) {
      await _recommendations();
    } else {
      await _chooseBook();
    }
  }

  Future<bool> _moveChair(String id, {required bool push}) async {
    final obj = view.world.objects[id]!;
    final delta =
        CafePoint(-math.sin(obj.yaw) * .06, 0, math.cos(obj.yaw) * .06) *
        (push ? -1 : 1);
    final next = view.world.placed(id, obj.pivot + delta).withUse(id, !push);
    if (next.pose(id).x.abs() > 1.5 || next.pose(id).z.abs() > 1.5) {
      return !push;
    }
    final trial = CafeWorld(space: next);
    if (trial.validateLayout() != null ||
        trial.linkedWorld.validateLayout() != null) {
      // If a nearby wall prevents pulling, use the existing accessible seat.
      if (push) {
        setState(() => calmHint = '의자 뒤의 통로를 비워 주세요.');
      }
      return !push;
    }
    if (!await _gesture(id, push ? CafeUseKind.push : CafeUseKind.pull)) {
      return false;
    }
    return _storeUse(next);
  }

  Future<void> _water(String id) async {
    if (await _gesture(id, CafeUseKind.water)) {
      await _storeUse(view.space.withUse(id, true));
      if (mounted) setState(() => calmHint = '물을 주었어요. 잠시 잎을 바라봐요.');
    }
  }

  Widget _useControls() {
    final id = view.heldId ?? view.contextId;
    final obj = view.world.objects[id];
    if (obj == null || editing || view.travelling || opening || dialogOpen) {
      return const SizedBox.shrink();
    }
    final busy =
        view.using ||
        roomSaving ||
        roomLoading ||
        roomLoadFailed ||
        widget.saveFailed;
    Widget action(String label, Future<void> Function() run, String key) =>
        TextButton(
          key: ValueKey('cafe-use-$key'),
          onPressed: busy ? null : run,
          child: Text(label),
        );
    final cup = obj.type == CafeItemType.cup;
    final amount = view.space.amount(id!, fallback: obj.defaultState ? 3 : 0);
    return Card(
      key: const ValueKey('cafe-use-controls'),
      color: const Color(0xf5faf5eb),
      margin: const EdgeInsets.only(top: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cup
                        ? '${obj.label} · ${['빈 잔', '한 모금 남음', '두 모금 남음', '가득'][amount]}'
                        : obj.label,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (view.heldId == null)
                  IconButton(
                    tooltip: '물건 사용 닫기',
                    onPressed: busy ? null : () => view.inspect(null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
            Wrap(
              children: [
                if (view.heldId != null) ...[
                  if (cup) ...[
                    action(
                      amount == 0 ? '차 따르기' : '한 모금 마시기',
                      () => _drink(id),
                      'sip',
                    ),
                    if (amount > 0 && amount < 3)
                      action('차 채우기', () => _refill(id), 'refill'),
                  ],
                  if (obj.type == CafeItemType.volume) ...[
                    action(view.heldBookOpen ? '책 덮기' : '책 펼치기', () async {
                      await _gesture(
                        id,
                        view.heldBookOpen
                            ? CafeUseKind.close
                            : CafeUseKind.open,
                      );
                    }, 'open'),
                    action('책 살펴보기', _readHeldBook, 'read'),
                  ],
                  if (obj.type == CafeItemType.pencil)
                    action('필사하기', () => _writeWith(id), 'write'),
                  action(
                    obj.type == CafeItemType.volume ? '책 꽂기' : '제자리에 놓기',
                    () async {
                      await _putDown();
                    },
                    'put-down',
                  ),
                ] else ...[
                  if (obj.type == CafeItemType.notebook) ...[
                    action('필사하기', () => _writeWith(id), 'write'),
                    action(view.space.state(id) ? '노트 덮기' : '노트 펼치기', () async {
                      final next = !view.space.state(id);
                      if (await _gesture(
                        id,
                        next ? CafeUseKind.open : CafeUseKind.close,
                      )) {
                        await _storeUse(view.space.withState(id, next));
                      }
                    }, 'note'),
                  ],
                  if (obj.type == CafeItemType.plant)
                    action('물 주기', () => _water(id), 'water'),
                  if (obj.type == CafeItemType.vase) ...[
                    action('가지 바꾸기', () => _useItem(id), 'arrange'),
                    action(view.space.state(id) ? '가지 비우기' : '가지 꽂기', () async {
                      if (await _gesture(id, CafeUseKind.touch)) {
                        await _storeUse(
                          view.space.withState(id, !view.space.state(id)),
                        );
                      }
                    }, 'branches'),
                  ],
                  if (obj.type == CafeItemType.lamp) ...[
                    action(
                      view.space.state(id) ? '조명 끄기' : '조명 켜기',
                      () => _useItem(id),
                      'light',
                    ),
                    action('밝기 바꾸기', () async {
                      await _storeUse(
                        view.space
                            .withState(id, true)
                            .withLight(
                              id,
                              (view.space.lights[id] ?? 1) > .7 ? .5 : 1,
                            ),
                      );
                    }, 'brightness'),
                  ],
                  if (obj.type == CafeItemType.chair)
                    action(
                      view.seat == null ? '앉기' : '일어나기',
                      () => _useItem(id),
                      'chair',
                    ),
                ],
              ],
            ),
            if (obj.type == CafeItemType.chair &&
                view.seat == null &&
                view.space.uses[id] == true)
              action('의자 넣기', () async {
                await _moveChair(id, push: true);
              }, 'push-chair'),
          ],
        ),
      ),
    );
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
                key: ValueKey('room-option-${object?.id}-$label-$i'),
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
                    if (object.id != 'ritual.memory')
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
                  if (object != null) ...[
                    action(
                      '가까이 보기',
                      roomSaving ? null : () => _focusRoomObject(object.id),
                      key: 'room-inspect',
                    ),
                    if ([
                      CafeItemType.cup,
                      CafeItemType.notebook,
                      CafeItemType.pencil,
                      CafeItemType.vase,
                      CafeItemType.plant,
                      CafeItemType.table,
                      CafeItemType.chair,
                      CafeItemType.volume,
                      CafeItemType.cloth,
                      CafeItemType.stack,
                    ].contains(object.type))
                      options(
                        switch (object.type) {
                          CafeItemType.table || CafeItemType.chair => '원목',
                          CafeItemType.notebook || CafeItemType.volume => '표지',
                          CafeItemType.pencil => '연필',
                          CafeItemType.plant =>
                            object.id.startsWith('garden.tree')
                                ? '잎'
                                : object.id.startsWith('garden.flowers')
                                ? '꽃'
                                : '화분',
                          CafeItemType.cloth => '천',
                          _ => '색',
                        },
                        space.finish(
                          object.id,
                          fallback: object.type == CafeItemType.cup
                              ? space.mug
                              : object.type == CafeItemType.plant &&
                                    object.id.startsWith('plant.')
                              ? space.pot
                              : object.defaultFinish,
                        ),
                        switch (object.type) {
                          CafeItemType.table => ['오크', '월넛'],
                          CafeItemType.chair => ['월넛', '오크', '먹갈색'],
                          CafeItemType.pencil => ['원목', '먹갈색', '올리브'],
                          CafeItemType.plant
                              when object.id.startsWith('garden.tree') =>
                            ['올리브', '연녹', '회녹'],
                          CafeItemType.plant
                              when object.id.startsWith('garden.flowers') =>
                            ['미색', '분홍', '연노랑'],
                          CafeItemType.plant => ['토분', '올리브', '미색'],
                          CafeItemType.notebook ||
                          CafeItemType.volume => ['올리브', '흙빛', '회녹색'],
                          _ => ['미색', '흙빛', '올리브'],
                        },
                        (v) => _changeRoom(space.withFinish(object.id, v)),
                      ),
                    if ([
                      CafeItemType.cup,
                      CafeItemType.vase,
                      CafeItemType.chair,
                    ].contains(object.type))
                      options(
                        object.type == CafeItemType.cup
                            ? '담을 차'
                            : object.type == CafeItemType.vase
                            ? '잎의 색'
                            : '방석',
                        space.accent(
                          object.id,
                          fallback: object.type == CafeItemType.chair
                              ? space.cushion
                              : 0,
                        ),
                        object.type == CafeItemType.cup
                            ? ['홍차', '커피', '연한 차']
                            : ['올리브', '흙빛', '미색'],
                        (v) => _changeRoom(space.withAccent(object.id, v)),
                      ),
                    if ([
                      CafeItemType.cup,
                      CafeItemType.notebook,
                      CafeItemType.vase,
                      CafeItemType.chair,
                      CafeItemType.volume,
                      CafeItemType.lamp,
                    ].contains(object.type))
                      SwitchListTile(
                        key: const ValueKey('room-item-state'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(switch (object.type) {
                          CafeItemType.cup => '잔 채워 두기',
                          CafeItemType.notebook => '노트 펼쳐 두기',
                          CafeItemType.vase => '가지 꽂아 두기',
                          CafeItemType.chair => '방석 놓기',
                          CafeItemType.volume => '표지 보이게 두기',
                          _ => '불 켜 두기',
                        }),
                        value: space.state(
                          object.id,
                          fallback: object.id == 'shared.book'
                              ? space.bookOpen
                              : object.id == 'shared.cup'
                              ? space.cupFull
                              : object.defaultState,
                        ),
                        onChanged: roomSaving
                            ? null
                            : (v) => _changeRoom(space.withState(object.id, v)),
                      ),
                    if (object.type == CafeItemType.lamp) ...[
                      const Text('이 조명의 밝기'),
                      Slider(
                        key: const ValueKey('room-item-light'),
                        value: itemLightPreview ?? space.lights[object.id] ?? 1,
                        min: .2,
                        max: 1.25,
                        divisions: 7,
                        onChanged: roomSaving
                            ? null
                            : (v) => setState(() => itemLightPreview = v),
                        onChangeEnd: roomSaving
                            ? null
                            : (v) {
                                itemLightPreview = null;
                                _changeRoom(space.withLight(object.id, v));
                              },
                      ),
                    ],
                    action(
                      '이 물건만 처음처럼',
                      roomSaving
                          ? null
                          : () => _changeRoom(space.resetItem(object.id)),
                      key: 'room-reset-item',
                    ),
                  ],
                  if (object == null ||
                      object.type == CafeItemType.group ||
                      object.id == 'garden.door') ...[
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
                  ],
                  if (view.inCourtyard &&
                      (object == null || object.type == CafeItemType.group))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '\uB730\uC758 \uCC3B\uC794 \uCC44\uC6B0\uAE30',
                      ),
                      value: space.gardenTea,
                      onChanged: roomSaving
                          ? null
                          : (v) =>
                                _changeRoom(space.withState('garden.cup', v)),
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
    if (oldWidget.saveFailed && !widget.saveFailed) {
      error = null;
      final sentence = retrySentence;
      if (sentence != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !opening && !ritualOpening) {
            unawaited(_startSentence(sentence));
          }
        });
      }
    }
  }

  void _viewChanged() {
    if (!mounted) return;
    if (!roomLoading) showIntro = false;
    if (lastCourtyard != view.inCourtyard) {
      lastCourtyard = view.inCourtyard;
      unawaited(calmAudio.stop());
      calmHint = null;
    }
    if (sound) _updateSound();
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
      });
    }
  }

  void _activate(CafeTarget target) {
    if (view.using) return;
    if (view.heldId != null) {
      unawaited(
        _putDown().then((ok) {
          if (ok && mounted) _activate(target);
        }),
      );
      return;
    }
    view.inspect(null);
    if (opening ||
        widget.saveFailed ||
        dialogOpen ||
        view.travelling ||
        roomLoading ||
        roomSaving ||
        editing) {
      return;
    }
    if (target == CafeTarget.trail) {
      pending = null;
      if (view.startStroll()) {
        setState(() => calmHint = null);
      } else {
        setState(() => calmHint = '빈 바닥을 눌러 길 가까이로 와 주세요.');
      }
      return;
    }
    if (target == CafeTarget.barefoot) {
      final distance =
          (view.camera.position - view.world.targetAnchor(target)).length;
      pending = null;
      if (distance < 2.0) {
        view.toggleBarefoot();
        setState(
          () => calmHint = view.barefoot
              ? '신발을 벗었어요. 황토길을 눌러 걸어요.'
              : '신발을 신었어요. 편하게 둘러보세요.',
        );
      } else if (view.visit(target)) {
        setState(() => calmHint = '벤치에 도착하면 한 번 더 눌러 주세요.');
      }
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
          view.applySpace(view.space.withState('garden.cup', true));
          unawaited(_saveRoom());
        }
        setState(() => calmHint = bell ? '종소리가 천천히 잦아들어요.' : '따뜻한 차를 놓아 두었어요.');
        unawaited(
          _playCalm(bell ? 'bell' : 'tea').catchError((Object _) {
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
    calmHint = null;
    if (target == CafeTarget.shared &&
        view.seat == CafeSeat.shared &&
        !view.space.bookOpen) {
      view.applySpace(view.space.withState('shared.book', true));
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
    if (!await _putDown() || !mounted) return;
    final seat = view.seat;
    if (opening || widget.saveFailed || seat == null) return;
    setState(() {
      opening = true;
      error = null;
    });
    try {
      if (view.space.home.seat == null) {
        view.applySpace(
          view.space.copy(
            home: view.space.home.copy(
              seat: seat.name,
              chair: view.activeChairId,
            ),
          ),
          validate: false,
        );
      }
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
    final target = await showDialog<Object>(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 4,
              children: [
                for (final entry in const {
                  'arrival': '나의 자리',
                  'mood': '공간의 시간',
                  'ambience': '빛과 소리',
                  'today': '오늘의 문장',
                  'memory': '내가 남긴 문장',
                  'letter': '쓰는 인간의 쪽지',
                }.entries)
                  TextButton(
                    key: ValueKey('cafe-ritual-${entry.key}'),
                    onPressed: () =>
                        Navigator.pop(context, 'home:${entry.key}'),
                    child: Text(entry.value),
                  ),
              ],
            ),
          ),
          for (final obj in view.world.objects.values.where(
            (o) =>
                const {
                  CafeItemType.cup,
                  CafeItemType.volume,
                  CafeItemType.pencil,
                  CafeItemType.notebook,
                  CafeItemType.lamp,
                  CafeItemType.plant,
                  CafeItemType.vase,
                  CafeItemType.frame,
                }.contains(o.type) &&
                (o.pivot - view.camera.position).length < 2,
          ))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, obj.id),
              child: Text('${obj.label} · 사용하기'),
            ),
          for (final target in view.world.targets)
            SimpleDialogOption(
              key: target.seat == null
                  ? ValueKey('cafe-guide-${target.name}')
                  : ValueKey('cafe-seat-${target.seat!.name}'),
              onPressed: () => Navigator.pop(context, target),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  target == CafeTarget.barefoot
                      ? '${target.label} · ${view.barefoot ? '신발 신기' : '신발 벗기'}'
                      : '${target.label} · ${target.action}',
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    if (mounted) {
      if (target is CafeTarget) {
        _activate(target);
      } else if (target is String) {
        if (target.startsWith('home:')) {
          await _openRitual(target.substring(5));
        } else {
          _activateItem(target);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    PaperNavigationScope.maybeOf(context)?.name(context, '카페');
    return PopScope<void>(
      canPop:
          !opening &&
          !widget.saveFailed &&
          !roomSaving &&
          !roomDirty &&
          !view.using,
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
              moment: moment,
              interactive:
                  !opening && !widget.saveFailed && !roomLoading && !roomSaving,
              editing: editing,
              placingId: placing ? selectedObject : null,
              onObjectSelected: (id) async {
                if (view.using) return;
                if (!editing) await _editRoom();
                if (mounted && editing) setState(() => selectedObject = id);
              },
              onWalk: _walk,
              onPutDown: () {
                unawaited(_putDown());
              },
              onObjectPlaced: (point) {
                if (selectedObject != null) {
                  _changeRoom(view.world.placed(selectedObject!, point));
                }
              },
              onItemActivated: _activateItem,
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
                          child: PaperHeaderRow(
                            children: [
                              IconButton(
                                tooltip:
                                    PaperNavigationScope.maybeOf(
                                      context,
                                    )?.parentLabel(context) ??
                                    '뒤로',
                                key: const ValueKey('paper-back'),
                                onPressed: opening || widget.saveFailed
                                    ? null
                                    : _requestClose,
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: brandInk,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  MediaQuery.textScalerOf(context).scale(16) >
                                          22
                                      ? (view.inCourtyard ? '고요한 뜰' : '필사 카페')
                                      : view.inCourtyard
                                      ? '쓰는 인간 · 고요한 뜰'
                                      : '쓰는 인간 · 필사 카페',
                                  style: TextStyle(
                                    color: brandInk,
                                    fontSize: 16,
                                  ),
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
                                        view.travelling ||
                                        view.using
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
                                tooltip: sound ? '소리 끄기' : '소리 켜기',
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
                                        view.travelling ||
                                        view.using
                                    ? null
                                    : _guide,
                                icon: const Icon(
                                  Icons.explore_outlined,
                                  color: brandInk,
                                ),
                              ),
                              if (!editing && !roomSaving && !widget.saveFailed)
                                PaperWritingReturn(
                                  enabled:
                                      !opening && !roomDirty && !view.using,
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
                          child: ColoredBox(
                            color: const Color(0xccfaf5eb),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                opening
                                    ? '글 여는 중'
                                    : view.travelling
                                    ? (view.strolling
                                          ? '황토길을 천천히 걷는 중'
                                          : '천천히 걸어가는 중')
                                    : calmHint != null
                                    ? calmHint!
                                    : view.resting
                                    ? (view.meditating
                                          ? '명상 자리 · 편하게 숨을 쉬어요.'
                                          : '잠시 머물러도 좋아요.')
                                    : view.seat != null
                                    ? (view.space.home.mood > 0
                                          ? '${view.space.home.mood == 2 ? '비 오는 저녁' : '해 질 무렵'} · 잠시 머물러도 좋아요.'
                                          : '${view.seat!.label} · 노트를 눌러 써요')
                                    : '바닥을 눌러 걷고, 끌어 둘러봐요',
                                style: const TextStyle(
                                  color: Color(0xff62503f),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      _arrivalNote(),
                      _useControls(),
                      if (view.strolling)
                        TextButton(
                          key: const ValueKey('cafe-stroll-stop'),
                          onPressed: () {
                            pending = null;
                            view.look(0, 0);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: brandInk,
                            backgroundColor: const Color(0xccfaf5eb),
                          ),
                          child: const Text('산책 멈추기'),
                        ),
                      if ((view.seat != null || view.resting) &&
                          !view.travelling &&
                          !view.using)
                        TextButton(
                          key: const ValueKey('cafe-stand'),
                          onPressed: opening
                              ? null
                              : () async {
                                  if (!await _putDown() || !mounted) return;
                                  pending = null;
                                  view.stand();
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: brandInk,
                            backgroundColor: const Color(0xccfaf5eb),
                          ),
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
                            style: const TextStyle(
                              height: 1.6,
                              color: burgundy,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.saveFailed
                              ? widget.onRetry
                              : () => setState(() {
                                  error = null;
                                  retrySentence = null;
                                }),
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
