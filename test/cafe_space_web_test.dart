@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:writing_human/cafe/cafe_space.dart';
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
          brightness: 1.15,
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
