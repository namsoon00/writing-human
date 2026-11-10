import 'model.dart';

abstract interface class LibraryStore {
  Future<Library> load();
  Future<void> save(Library library);
  Future<void> close();
}
