import 'dart:convert';
import 'package:http/browser_client.dart';
import 'package:web/web.dart' as web;
import '../data/web_store.dart';
import 'context.dart';
import 'remote.dart';

const _lastAccount = 'writing-human.last-account.v1';
String _accountKey(String id) =>
    '${WebLibraryStore.key}.account.${base64Url.encode(utf8.encode(id))}';

Future<SyncContext> openSyncContext() async {
  // Static hosts have no account/session API. Keep the same local persistence
  // without polling a nonexistent server or offering a broken sign-in route.
  if (const bool.fromEnvironment('WRITING_HUMAN_LOCAL_ONLY')) {
    return SyncContext(store: WebLibraryStore());
  }
  final client = BrowserClient()..withCredentials = true;
  final remote = HttpCloudRemote(client, Uri.base);
  CloudSession? session;
  var offline = false;
  // Storage access failures must reach the recovery UI, never fall back to empty.
  final cachedId = web.window.localStorage.getItem(_lastAccount);
  try {
    session = await remote.session();
    web.window.localStorage.setItem(_lastAccount, session.userId);
  } on CloudFailure catch (e) {
    if (e.code == 'sign_in_required') {
      web.window.localStorage.removeItem(_lastAccount);
    } else {
      offline = true;
    }
  } catch (_) {
    offline = true;
  }
  if (session == null && offline && cachedId != null) {
    session = CloudSession(cachedId, '');
  }
  return SyncContext(
    store: WebLibraryStore(
      storageKey: session == null
          ? WebLibraryStore.key
          : _accountKey(session.userId),
    ),
    remote: remote,
    account: session,
    legacy: session == null ? null : WebLibraryStore(),
    offline: offline,
    signIn: () =>
        web.window.location.assign('/signin-with-chatgpt?return_to=%2F'),
    reload: () => web.window.location.reload(),
  );
}
