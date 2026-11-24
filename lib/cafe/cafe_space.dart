import 'dart:convert';
import 'dart:math' as math;

class CafePose {
  const CafePose({this.x = 0, this.y = 0, this.z = 0, this.turn = 0});
  final double x, y, z, turn;
  CafePose copy({double? x, double? y, double? z, double? turn}) => CafePose(
    x: x ?? this.x,
    y: y ?? this.y,
    z: z ?? this.z,
    turn: turn ?? this.turn,
  );
  Map<String, Object> toJson() => {'x': x, 'y': y, 'z': z, 'turn': turn};
  factory CafePose.read(Map<String, dynamic> j) {
    double number(String key) {
      final v = j[key];
      if (v is! num || !v.isFinite) {
        throw const FormatException('Invalid room position');
      }
      return v.toDouble();
    }

    final p = CafePose(
      x: number('x'),
      y: number('y'),
      z: number('z'),
      turn: number('turn'),
    );
    if (p.x.abs() > 1.5 ||
        p.z.abs() > 1.5 ||
        p.y.abs() > .5 ||
        p.turn.abs() > math.pi * 2 + .01) {
      throw const FormatException('Room position out of bounds');
    }
    return p;
  }
}

class CafeSpace {
  const CafeSpace({
    this.poses = const {},
    this.amounts = const {},
    this.uses = const {},
    this.finishes = const {},
    this.accents = const {},
    this.states = const {},
    this.lights = const {},
    this.frames = const {},
    this.mats = const {},
    this.art = const {},
    this.brightness = 1,
    this.warmth = .5,
    this.cushion = 0,
    this.mug = 0,
    this.pot = 0,
    this.selectedBookId,
    this.bookOpen = true,
    this.cupFull = true,
    this.gardenTea = false,
    this.doorOpen = true,
  });
  final Map<String, CafePose> poses;
  final Map<String, int> amounts;
  final Map<String, bool> uses;
  int amount(String id, {int fallback = 3}) {
    final full = id == 'shared.cup'
        ? cupFull
        : id == 'garden.cup'
        ? gardenTea
        : fallback > 0;
    return state(id, fallback: full)
        ? amounts[id] ?? (fallback > 0 ? fallback : 3)
        : 0;
  }

  CafeSpace withAmount(String id, int value) =>
      withState(id, value > 0).copy(amounts: {...amounts, id: value});
  CafeSpace withUse(String id, bool value) => copy(uses: {...uses, id: value});
  final Map<String, int> finishes, accents;
  final Map<String, bool> states;
  final Map<String, double> lights;
  int finish(String id, {int fallback = 0}) => finishes[id] ?? fallback;
  int accent(String id, {int fallback = 0}) => accents[id] ?? fallback;
  bool state(String id, {bool fallback = true}) => states[id] ?? fallback;
  double light(String id) => state(id) ? lights[id] ?? 1 : 0;
  CafeSpace withFinish(String id, int value) =>
      copy(finishes: {...finishes, id: value});
  CafeSpace withAccent(String id, int value) =>
      copy(accents: {...accents, id: value});
  CafeSpace withState(String id, bool value) => copy(
    states: {...states, id: value},
    amounts: amounts.containsKey(id) ? {...amounts, id: value ? 3 : 0} : null,
    bookOpen: id == "shared.book" ? value : null,
    cupFull: id == "shared.cup" ? value : null,
    gardenTea: id == "garden.cup" ? value : null,
  );
  CafeSpace withLight(String id, double value) =>
      copy(lights: {...lights, id: value});
  CafeSpace resetItem(String id) => copy(
    poses: {...poses}..remove(id),
    amounts: {...amounts}..remove(id),
    uses: {...uses}..remove(id),
    finishes: {...finishes}..remove(id),
    accents: {...accents}..remove(id),
    states: {...states}..remove(id),
    lights: {...lights}..remove(id),
    frames: {...frames}..remove(id),
    mats: {...mats}..remove(id),
    art: {...art}..remove(id),
    bookOpen: id == 'shared.book' ? true : null,
    cupFull: id == 'shared.cup' ? true : null,
    gardenTea: id == 'garden.cup' ? false : null,
  );
  final Map<String, int> frames, mats, art;
  final String? selectedBookId;
  final double brightness, warmth;
  final int cushion, mug, pot;
  final bool bookOpen, cupFull, gardenTea, doorOpen;
  CafePose pose(String id) => poses[id] ?? const CafePose();
  CafeSpace copy({
    Map<String, CafePose>? poses,
    Map<String, int>? amounts,
    Map<String, bool>? uses,
    Map<String, int>? finishes,
    Map<String, int>? accents,
    Map<String, bool>? states,
    Map<String, double>? lights,
    Map<String, int>? frames,
    Map<String, int>? mats,
    Map<String, int>? art,
    double? brightness,
    double? warmth,
    int? cushion,
    int? mug,
    int? pot,
    String? selectedBookId,
    bool clearBook = false,
    bool? bookOpen,
    bool? cupFull,
    bool? gardenTea,
    bool? doorOpen,
  }) => CafeSpace(
    poses: poses ?? this.poses,
    amounts: amounts ?? this.amounts,
    uses: uses ?? this.uses,
    finishes: finishes ?? this.finishes,
    accents: accents ?? this.accents,
    states: states ?? this.states,
    lights: lights ?? this.lights,
    frames: frames ?? this.frames,
    mats: mats ?? this.mats,
    art: art ?? this.art,
    brightness: brightness ?? this.brightness,
    warmth: warmth ?? this.warmth,
    cushion: cushion ?? this.cushion,
    mug: mug ?? this.mug,
    pot: pot ?? this.pot,
    selectedBookId: clearBook ? null : selectedBookId ?? this.selectedBookId,
    bookOpen: bookOpen ?? this.bookOpen,
    cupFull: cupFull ?? this.cupFull,
    gardenTea: gardenTea ?? this.gardenTea,
    doorOpen: doorOpen ?? this.doorOpen,
  );
  Map<String, dynamic> toJson() => {
    'version': 3,
    'amounts': amounts,
    'uses': uses,
    'finishes': finishes,
    'accents': accents,
    'states': states,
    'lights': lights,
    'poses': poses.map((k, v) => MapEntry(k, v.toJson())),
    'frames': frames,
    'mats': mats,
    'art': art,
    'brightness': brightness,
    'warmth': warmth,
    'cushion': cushion,
    'mug': mug,
    'pot': pot,
    'selectedBookId': selectedBookId,
    'bookOpen': bookOpen,
    'cupFull': cupFull,
    'gardenTea': gardenTea,
    'doorOpen': doorOpen,
  };
  String encode() => jsonEncode(toJson());
  factory CafeSpace.decode(String raw) {
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic> || ![1, 2, 3].contains(j['version'])) {
      throw const FormatException('Invalid room data');
    }
    final selected = j['selectedBookId'];
    if (selected != null && (selected is! String || selected.length > 256)) {
      throw const FormatException('Invalid book reference');
    }
    Map<String, T> map<T>(String key, T Function(dynamic) read) {
      final v =
          j[key] ??
          ((j['version'] < 3 && const {'amounts', 'uses'}.contains(key)) ||
                  j['version'] == 1 &&
                      const {
                        'finishes',
                        'accents',
                        'states',
                        'lights',
                      }.contains(key)
              ? <String, dynamic>{}
              : null);
      if (v is! Map<String, dynamic> || v.length > 256) {
        throw const FormatException('Invalid room objects');
      }
      return Map.unmodifiable(
        v.map((k, v) {
          if (k.length > 100 || !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(k)) {
            throw const FormatException('Invalid room object ID');
          }
          return MapEntry(k, read(v));
        }),
      );
    }

    int index(dynamic v) {
      if (v is! int || v < 0 || v > 2) {
        throw const FormatException('Invalid decoration');
      }
      return v;
    }

    double number(String key, double min, double max) {
      final v = j[key];
      if (v is! num || !v.isFinite || v < min || v > max) {
        throw const FormatException('Invalid lighting');
      }
      return v.toDouble();
    }

    bool flag(String k) {
      if (j[k] is! bool) throw const FormatException('Invalid object state');
      return j[k] as bool;
    }

    return CafeSpace(
      amounts: map('amounts', (v) {
        if (v is! int || v < 0 || v > 3) {
          throw const FormatException('Invalid drink amount');
        }
        return v;
      }),
      uses: map('uses', (v) {
        if (v is! bool) throw const FormatException('Invalid use state');
        return v;
      }),
      finishes: map('finishes', index),
      accents: map('accents', index),
      states: map('states', (v) {
        if (v is! bool) throw const FormatException('Invalid item state');
        return v;
      }),
      lights: map('lights', (v) {
        if (v is! num || !v.isFinite || v < .2 || v > 1.25) {
          throw const FormatException('Invalid item light');
        }
        return v.toDouble();
      }),
      poses: map(
        'poses',
        (v) => CafePose.read(Map<String, dynamic>.from(v as Map)),
      ),
      frames: map('frames', index),
      mats: map('mats', index),
      art: map('art', index),
      brightness: number('brightness', .8, 1.25),
      warmth: number('warmth', 0, 1),
      cushion: index(j['cushion']),
      mug: index(j['mug']),
      pot: index(j['pot']),
      selectedBookId: j['selectedBookId'] is String
          ? j['selectedBookId'] as String
          : null,
      bookOpen: flag('bookOpen'),
      cupFull: flag('cupFull'),
      gardenTea: flag('gardenTea'),
      doorOpen: flag('doorOpen'),
    );
  }
}

abstract interface class CafeSpaceStore {
  Future<CafeSpace> load();
  Future<void> save(CafeSpace value);
}

class MemoryCafeSpaceStore implements CafeSpaceStore {
  CafeSpace value = const CafeSpace();
  @override
  Future<CafeSpace> load() async => value;
  @override
  Future<void> save(CafeSpace v) async {
    value = CafeSpace.decode(v.encode());
  }
}

abstract interface class CafeSpaceStoreProvider {
  Future<CafeSpaceStore> openSpaceStore(String scope);
}
