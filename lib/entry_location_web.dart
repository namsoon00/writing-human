import 'package:web/web.dart';

void replaceEntryLocation(Uri Function(Uri) normalizer) {
  final current = Uri.parse(window.location.href);
  final next = normalizer(current);
  if (next == current) return;
  // Cosmetic URL cleanup must not prevent opening the real record store.
  try {
    window.history.replaceState(null, '', next.toString());
  } catch (_) {
    // Restricted history access leaves the URL unchanged, not the store.
  }
}
