import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/model.dart';

class CloudSession {
  const CloudSession(this.userId, this.email);
  final String userId, email;
}

class CloudSnapshot {
  const CloudSnapshot(this.revision, this.library, this.updatedAt);
  final int revision;
  final Library? library;
  final String? updatedAt;
  factory CloudSnapshot.fromJson(Json j) => CloudSnapshot(
    j['revision'] as int,
    j['library'] == null ? null : Library.decode(jsonEncode(j['library'])),
    j['updatedAt'] as String?,
  );
}

class CloudFailure implements Exception {
  const CloudFailure(this.code);
  final String code;
}

class RevisionConflict implements Exception {}

abstract interface class CloudRemote {
  Future<CloudSession> session();
  Future<CloudSnapshot> read();
  Future<CloudSnapshot> write(int revision, Library library);
  void close();
}

class HttpCloudRemote implements CloudRemote {
  HttpCloudRemote(this.client, this.origin);
  final http.Client client;
  final Uri origin;
  String? _expectedAccount;
  Future<Json> _json(String path, {Library? library, int? revision}) async {
    final uri = origin.resolve(path);
    final response =
        await (library == null
                ? client.get(
                    uri,
                    headers: {
                      'Accept': 'application/json',
                      'X-Writing-Human-Account': _expectedAccount ?? '',
                    },
                  )
                : client.put(
                    uri,
                    headers: {
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                      'X-Writing-Human-Sync': '1',
                      'X-Writing-Human-Account': _expectedAccount ?? '',
                    },
                    body: jsonEncode({
                      'baseRevision': revision,
                      'library': library.toCloudJson(),
                    }),
                  ))
            .timeout(const Duration(seconds: 8));
    if (response.statusCode == 412) {
      throw const CloudFailure('account_changed');
    }
    if (response.statusCode == 409) {
      throw RevisionConflict();
    }
    if (response.statusCode == 401 ||
        !response.headers['content-type'].toString().contains(
          'application/json',
        )) {
      throw const CloudFailure('sign_in_required');
    }
    if (response.statusCode != 200) {
      if (response.statusCode == 413) {
        throw const CloudFailure('too_large');
      }
      throw CloudFailure(
        response.statusCode == 400 ? 'invalid_library' : 'unavailable',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Json;
  }

  @override
  Future<CloudSession> session() async {
    final j = await _json('/api/sync/session');
    final account = j['userId'] as String;
    if (_expectedAccount != null && _expectedAccount != account) {
      throw const CloudFailure('account_changed');
    }
    _expectedAccount = account;
    return CloudSession(account, j['email'] as String? ?? '');
  }

  @override
  Future<CloudSnapshot> read() async =>
      CloudSnapshot.fromJson(await _json('/api/sync/library'));
  @override
  Future<CloudSnapshot> write(int revision, Library library) async =>
      CloudSnapshot.fromJson(
        await _json('/api/sync/library', library: library, revision: revision),
      );
  @override
  void close() => client.close();
}
