import '../data/store.dart';
import 'remote.dart';

class SyncContext {
  const SyncContext({
    required this.store,
    this.remote,
    this.account,
    this.legacy,
    this.signIn,
    this.reload,
    this.offline = false,
  });
  final LibraryStore store;
  final CloudRemote? remote;
  final CloudSession? account;
  final LibraryStore? legacy;
  final void Function()? signIn, reload;
  final bool offline;
}
