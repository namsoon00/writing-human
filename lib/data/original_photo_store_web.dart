import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _table = 'photos';

Future<web.IDBDatabase> _open() {
  final request = web.window.indexedDB.open('writing-human.original-photos', 1);
  final result = Completer<web.IDBDatabase>();
  request.onupgradeneeded = ((web.Event _) {
    (request.result as web.IDBDatabase).createObjectStore(_table);
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    if (result.isCompleted) {
      db.close();
    } else {
      result.complete(db);
    }
  }).toJS;
  void fail(web.Event _) {
    if (!result.isCompleted) {
      result.completeError(StateError('사진 보관함을 열지 못했어요.'));
    }
  }

  request.onerror = fail.toJS;
  request.onblocked = fail.toJS;
  return result.future;
}

Future<JSAny?> _request(
  String mode,
  web.IDBRequest Function(web.IDBObjectStore) operation,
) async {
  final db = await _open();
  try {
    final tx = db.transaction(_table.toJS, mode);
    final result = Completer<JSAny?>();
    final request = operation(tx.objectStore(_table));
    tx.oncomplete = ((web.Event _) => result.complete(request.result)).toJS;
    tx.onabort = ((web.Event _) => result.completeError(
      StateError('사진을 보관하지 못했어요.'),
    )).toJS;
    return await result.future;
  } finally {
    db.close();
  }
}

Future<Uint8List?> readPhoto(String id) async {
  final result = await _request('readonly', (store) => store.get(id.toJS));
  return (result as JSUint8Array?)?.toDart;
}

Future<void> writePhoto(String id, Uint8List bytes) async {
  await _request('readwrite', (store) => store.put(bytes.toJS, id.toJS));
}
