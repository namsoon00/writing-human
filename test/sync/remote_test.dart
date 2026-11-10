import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/sync/remote.dart';

void main() {
  final origin = Uri.parse('https://writing-human.test/');
  test(
    'HTTP client binds requests to the authenticated account and omits local sync metadata',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode({'userId': 'a', 'email': 'a@example.test'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.headers['x-writing-human-account'], 'a');
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map;
          expect((body['library'] as Map).containsKey('sync'), isFalse);
          expect(body['baseRevision'], 0);
          return http.Response(
            jsonEncode({
              'revision': 1,
              'library': body['library'],
              'updatedAt': 'now',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"revision":0,"library":null,"updatedAt":null}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final remote = HttpCloudRemote(client, origin);
      await remote.session();
      await remote.read();
      final cloud = await remote.write(
        0,
        const Library(sync: SyncMetadata(accountId: 'local-only-account')),
      );
      expect(cloud.revision, 1);
      remote.close();
    },
  );
  test(
    'A changed browser session and a mid-request identity change both stop the client',
    () async {
      var user = 'a';
      var switchedDuringWrite = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode({'userId': user, 'email': ''}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (switchedDuringWrite) {
          return http.Response(
            '{"error":"account_changed"}',
            412,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"revision":0,"library":null,"updatedAt":null}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final remote = HttpCloudRemote(client, origin);
      await remote.session();
      user = 'b';
      await expectLater(
        remote.session(),
        throwsA(
          isA<CloudFailure>().having((e) => e.code, 'code', 'account_changed'),
        ),
      );
      user = 'a';
      switchedDuringWrite = true;
      await expectLater(
        remote.write(0, const Library()),
        throwsA(
          isA<CloudFailure>().having((e) => e.code, 'code', 'account_changed'),
        ),
      );
      remote.close();
    },
  );
}
