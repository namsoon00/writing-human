import '../data/store_factory.dart';
import 'context.dart';

Future<SyncContext> openSyncContext() async =>
    SyncContext(store: await openStore());
