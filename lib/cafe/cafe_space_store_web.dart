import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;
import 'cafe_space.dart';

Future<CafeSpaceStore> openCafeSpaceStore({String scope = 'local'}) async =>
    WebCafeSpaceStore(
      'writing-human.cafe.space.v1.${sha256.convert(utf8.encode(scope))}',
    );

class WebCafeSpaceStore implements CafeSpaceStore {
  WebCafeSpaceStore(this.key);
  final String key;
  @override
  Future<CafeSpace> load() async {
    final raw = web.window.localStorage.getItem(key);
    return raw == null ? const CafeSpace() : CafeSpace.decode(raw);
  }

  @override
  Future<void> save(CafeSpace value) async {
    final raw = CafeSpace.decode(value.encode()).encode();
    web.window.localStorage.setItem(key, raw);
  }
}
