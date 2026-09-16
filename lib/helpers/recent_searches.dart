/// Pure list-management logic for the F6 search sheet's recent searches
/// (`helpers/search_helper.dart`, `ui/widgets/search_sheet.dart`) — ported from the Android app's
/// `utilities/RecentSearches` (Phase 6 of the UI overhaul, PR java#101). Kept free of
/// SharedPreferences/BuildContext so it is unit-testable without a widget tree; [SearchHelper]
/// owns the persistence around this, everything here is plain `List<String>` in,
/// `List<String>` out.
class RecentSearches {
  RecentSearches._();

  /// How many recent searches the sheet remembers, newest first.
  static const int kMaxRecents = 10;

  /// Returns a new list with [query] moved to the front of [existing] (case-insensitive
  /// de-duplication — searching "Dickson" again after "dickson" re-uses the same slot instead of
  /// listing it twice), capped to [kMaxRecents] entries. [existing] is not modified.
  static List<String> withQuery(List<String> existing, String query) {
    final List<String> result = [];
    final String trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      result.add(trimmed);
    }
    for (final candidate in existing) {
      final bool duplicate =
          result.isNotEmpty &&
          candidate.toLowerCase() == result.first.toLowerCase();
      if (!duplicate) {
        result.add(candidate);
      }
    }
    if (result.length > kMaxRecents) {
      return result.sublist(0, kMaxRecents);
    }
    return result;
  }

  /// The empty list, for the "Clear" action — kept here for symmetry with [withQuery].
  static List<String> cleared() => const [];

  /// [recents] with [exclude] removed (case-insensitive), for rendering the recents list
  /// underneath a query that is itself one of the recent searches.
  static List<String> excluding(List<String> recents, String exclude) {
    final String lower = exclude.toLowerCase();
    return recents
        .where((candidate) => candidate.toLowerCase() != lower)
        .toList();
  }
}
