/// Helpers for building the RESTify `_filter` clauses used by the REST endpoints.
///
/// RESTify rejects a clause whose value is empty — `_filter=model==` — with
/// HTTP 412 "ERROR #120: Invalid number of parameters in _filter clause". (An
/// entirely empty `_filter=` is fine, and a value the server can't match is a
/// harmless empty result set, so an empty *value* is the one shape that faults.)
///
/// An empty value is always a client-side bug: there is no row that could match
/// it, so the request is pointless as well as fatal. Callers check
/// [RestFilter.isUsableValue] and skip the request rather than send a filter the
/// server cannot parse.
///
/// Mirrors the Java app's `au.com.bitbot.phonetowers.restful.RestFilter` — keep
/// the two in sync.
abstract class RestFilter {
  /// Whether [value] can be used on the right-hand side of a `_filter` clause.
  ///
  /// Rejects null (which would be interpolated into the literal string "null"
  /// and quietly match nothing) and blank strings (which produce the ERROR #120
  /// fault above).
  static bool isUsableValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// RESTify (a PHP falsy-string check) rejects a bare `0` filter value with the same HTTP 412
  /// ERROR #120 as an empty one. Zero is legitimate, so it is zero-padded to `00`, which MySQL
  /// compares equal to 0. Every numeric filter value should go through this. Mirrors the Java
  /// app's `RestFilter.zeroSafe`.
  static String zeroSafe(int value) => value == 0 ? '00' : value.toString();
}
