import 'entry_location_stub.dart'
    if (dart.library.js_interop) 'entry_location_web.dart'
    as platform;

/// Old demo links now open the same persistent application as the normal URL.
/// Keep unrelated query parameters, fragments and the storage origin intact.
Uri normalEntryLocation(Uri location) {
  if (!const [
    'reference',
    'typeface',
  ].contains(location.queryParameters['demo'])) {
    return location;
  }
  final query = Map<String, List<String>>.from(location.queryParametersAll)
    ..remove('demo');
  if (query.isNotEmpty) {
    return location.replace(queryParameters: query);
  }
  // Uri.replace(query: '') retains a trailing query delimiter. Remove that
  // delimiter; legal path/user-info question marks remain percent-encoded.
  return Uri.parse(
    location.replace(query: '').toString().replaceFirst('?', ''),
  );
}

void normalizeEntryLocation() =>
    platform.replaceEntryLocation(normalEntryLocation);
