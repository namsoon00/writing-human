import 'package:web/web.dart' as web;
import 'model.dart';
import 'store.dart';
import '../cafe/cafe_space.dart';
import '../cafe/cafe_space_store_web.dart';

Future<LibraryStore> openStore() async => WebLibraryStore();

class WebLibraryStore implements LibraryStore, CafeSpaceStoreProvider {
  WebLibraryStore({this.storageKey = key});
  final String storageKey;
  @override
  Future<CafeSpaceStore> openSpaceStore(String scope) =>
      openCafeSpaceStore(scope: storageKey + scope);
  static const key = 'writing-human.library.v1';
  @override
  Future<Library> load() async {
    final raw = web.window.localStorage.getItem(storageKey);
    return raw == null ? const Library() : Library.decode(raw);
  }

  @override
  Future<void> save(Library library) async {
    library.validate();
    // setItem is synchronous and atomic. Quota/access exceptions reach the UI.
    web.window.localStorage.setItem(storageKey, library.encode());
  }

  @override
  Future<void> close() async {}
}
