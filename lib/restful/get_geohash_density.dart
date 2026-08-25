import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/density_lookup.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart' show CityDensity;

/// Fetches `geohash_density` rows covering one geohash prefix into [DensityLookup].
///
/// Mirror of the Android app's `GetGeohashDensity.java`.
///
/// One request per region, never one per point — this data feeds the polygon loop, and a round-trip
/// in there is exactly what the Android app's REST connection caps had to undo.
///
/// Regions already fetched are remembered for the session, because the table is static by design;
/// refetching as the user pans back and forth would be pure waste.
///
/// Parsed by hand rather than through `SiteResponse`, because that model is typed to the site
/// columns and carries neither `geohash` nor `density`.
class GetGeohashDensity {
  static final Set<String> _fetched = <String>{};
  static final Logger _logger = Logger();

  /// Marks [prefix] as claimed. Returns false if it was already fetched this session.
  static bool claim(String prefix) => _fetched.add(prefix);

  /// Forgets every fetched region. Used when the map is cleared.
  static void reset() => _fetched.clear();

  /// Loads the density cells for the level-4 region containing [geohash], at most once per region.
  ///
  /// Level 4 rather than the caller's own geohash because the table's cells are levels 4 and 5:
  /// asking for a longer prefix could miss the level-4 cell that actually covers the point.
  static Future<void> loadFor(String geohash) async {
    if (geohash.length < 4) return;
    final String prefix = geohash.substring(0, 4);
    if (!claim(prefix)) return;

    final String path = '/towers/geohash_density/?_view=json&_expand=no&_count=500'
        '&_filter=geohash~~$prefix%25&_fields=geohash%2Cdensity';
    try {
      final dynamic data = (await Api.initialize().dio.get(path)).data;
      // Unpacked step by step rather than with a chained ternary: `cond ? a?['x'] : null` is
      // genuinely ambiguous to the Dart parser, which cannot tell the null-aware index from the
      // conditional's colon.
      dynamic rows;
      if (data is Map) {
        final dynamic restify = data['restify'];
        if (restify is Map) {
          rows = restify['rows'];
        }
      }
      if (rows is! List) {
        _logger.i('GetGeohashDensity: no rows for "$prefix"; OPEN applies');
        return;
      }
      int loaded = 0;
      for (final dynamic row in rows) {
        if (row is! Map) continue;
        final dynamic values = row['values'];
        if (values is! Map) continue;
        final dynamic geohashCell = values['geohash'];
        final dynamic densityCell = values['density'];
        if (geohashCell is! Map || densityCell is! Map) continue;
        final String? g = geohashCell['value']?.toString();
        final int? ordinal = int.tryParse(densityCell['value']?.toString() ?? '');
        if (g != null && ordinal != null &&
            ordinal >= 0 && ordinal < CityDensity.values.length) {
          DensityLookup.put(g, CityDensity.values[ordinal]);
          loaded++;
        }
      }
      _logger.i('GetGeohashDensity: loaded $loaded cells for "$prefix";'
          ' cache now ${DensityLookup.size}');
    } catch (e) {
      // Leave the prefix claimed anyway. A retry storm inside the polygon loop would be worse than
      // falling back to OPEN for this region until the next map clear.
      _logger.w('GetGeohashDensity: failed for "$prefix": $e');
    }
  }
}
