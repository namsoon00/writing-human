@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_home.dart';
import 'package:writing_human/cafe/cafe_atmosphere.dart';
import 'package:writing_human/cafe/cafe_space_store_web.dart';

void main() {
  test(
    'Web storage restores a fresh room store and preserves per-scope values on malformed data',
    () async {
      final key =
          'writing-human.cafe-test.${DateTime.now().microsecondsSinceEpoch}';
      final a = WebCafeSpaceStore(key), b = WebCafeSpaceStore('$key.other');
      try {
        const expected = CafeSpace(
          atmosphere: CafeAtmosphere(
            flow: false,
            rain: .7,
            water: .2,
            leaves: .8,
            music: 0,
          ),
          brightness: 1.15,
          home: CafeHome(
            mood: 2,
            topic: 1,
            seat: 'windowMiddle',
            chair: 'desk.windowMiddle.chair',
            pinned: '지금의 한 문장.',
          ),
          amounts: {'desk.window.cup': 1},
          uses: {'plant.3.77_-3.9': true},
          finishes: {'shared.cup': 1, 'desk.window.cup': 2},
          accents: {'shared.chair.right.1': 2},
          states: {'quiet.book': false, 'lamp.0.0_0.68': false},
          lights: {'lamp.0.0_-0.83': .5},
          warmth: .25,
          cupFull: false,
          bookOpen: false,
          doorOpen: false,
          selectedBookId: 'private-book',
          poses: {'shared.cup': CafePose(x: .10, z: .05, turn: .2)},
          frames: {'frame.2.44_4.84': 1},
          mats: {'frame.2.44_4.84': 2},
          art: {'frame.2.44_4.84': 2},
        );
        await a.save(expected);
        expect(
          (await WebCafeSpaceStore(key).load()).encode(),
          expected.encode(),
        );
        expect((await b.load()).encode(), const CafeSpace().encode());
        await expectLater(
          a.save(const CafeSpace(brightness: 12)),
          throwsFormatException,
        );
        expect(
          (await WebCafeSpaceStore(key).load()).encode(),
          expected.encode(),
        );
        web.window.localStorage.setItem(key, 'broken');
        await expectLater(a.load(), throwsFormatException);
        expect(web.window.localStorage.getItem(key), 'broken');
      } finally {
        web.window.localStorage.removeItem(key);
        web.window.localStorage.removeItem('$key.other');
      }
    },
  );
}
