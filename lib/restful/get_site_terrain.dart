import 'package:logger/logger.dart';

import '../helpers/polygon_helper.dart';
import '../model/site.dart';
import '../networking/api.dart';
import '../pathloss/terrain_height.dart';
import 'get_elevation.dart';
import 'rest_filter.dart';

/// Loads the nightly `site_terrain` row for a site (ground elevation, per-bearing median terrain
/// and, when present, the full 24 x 19 elevation profile). Requested in both modes because the
/// effective antenna height ([TerrainHeight]) is used in both. A missing row (site not yet
/// computed, or the table not yet exposed by RESTify) degrades to the plain antenna height, and
/// in terrain mode to the Google Elevation download as before. Mirrors the Java app's
/// GetSiteTerrain / Site.applyTerrain.
class GetSiteTerrain {
  /// Raw (unencoded) column list; see [urlFor] for the `%2C`-joined form actually sent.
  static const String fields = 'site_id,ground_m,bearing_median_m,profile_m';

  final Site site;
  final Api api;
  final Logger logger;

  GetSiteTerrain({required this.site, required this.api, Logger? logger})
      : logger = logger ?? Logger();

  /// The site_terrain endpoint URL for [site], filtered to its own site_id. %3D%3D is an
  /// encoded "==" and %2C an encoded comma, matching the pattern the other REST calls in this
  /// file's package use (e.g. PolygonHelper's licence_hrp filter/fields).
  static String urlFor(Site site) {
    // Minor 4: percent-encode the site id rather than interpolating it raw, matching the
    // Android app's intent. site_id is numeric in practice so this is a no-op today, but a
    // server-side change should not be trusted to only ever hand back URL-safe characters.
    final String encodedSiteId = Uri.encodeComponent('${site.siteId}');
    final String filter = 'site_id%3D%3D$encodedSiteId';
    final String encodedFields = fields.replaceAll(',', '%2C');
    return '/towers/site_terrain/?_view=json&_expand=no&_count=1&_filter=$filter&_fields=$encodedFields';
  }

  /// "b0s0,b0s1,...;b1s0,..." -> 24 groups of [GetElevation.SAMPLE_DISTANCES.length] ints; null
  /// when absent, empty, or malformed in any way (wrong bearing count, a group with the wrong
  /// sample count, or a non-numeric sample). Pure and static so it is unit-testable without a
  /// network round-trip.
  static List<List<int>>? parseProfile(String? text) {
    if (text == null || text.isEmpty) {
      return null;
    }
    final List<String> groups = text.split(';');
    if (groups.length != TerrainHeight.bearings) {
      return null;
    }
    final List<List<int>> out = [];
    for (final String group in groups) {
      final List<int>? samples =
          TerrainHeight.parseCsv(group, GetElevation.SAMPLE_DISTANCES.length);
      if (samples == null) {
        return null;
      }
      out.add(samples);
    }
    return out;
  }

  /// Reads a RESTify `values.<key>.value` string out of a decoded row's `values` map, or null
  /// when the field/column/value is absent — see the RESTify JSON shape in the Global
  /// Constraints (`{"values": {"col": {"value": "..."}}}`). Minor 3: a JSON number (e.g. a
  /// server-side type change that stops quoting `ground_m`) is accepted too, stringified so the
  /// existing int.tryParse/TerrainHeight.parseCsv callers keep working unchanged — a `String`
  /// requirement here would otherwise fail closed (silently disabling terrain) instead of
  /// failing loudly in tests.
  static String? _value(Map<dynamic, dynamic> values, String key) {
    final dynamic field = values[key];
    if (field is! Map) return null;
    final dynamic raw = field['value'];
    if (raw is String) return raw;
    if (raw is num) return '$raw';
    return null;
  }

  /// Requests the row, applies it to [site] when usable, and always finishes by setting
  /// [Site.terrainLoaded] and — only in terrain mode, and only when nothing has finished the
  /// elevation download yet — starting the Google Elevation fallback via
  /// [PolygonHelper.startGoogleElevation]. Every failure mode (network error, non-2xx/no
  /// response, an empty `rows` array, or a malformed row) ends up here exactly the same way, so
  /// GetLicenceHRP's bounded waits can never hang on this request.
  Future<void> fetch() async {
    try {
      if (!RestFilter.isUsableValue(site.siteId)) {
        // No siteId to filter on — RestFilter.isUsableValue would reject the resulting
        // clause server-side anyway (HTTP 412); don't bother firing the request.
        logger.w('GetSiteTerrain: site has no usable siteId, skipping site_terrain request');
        return;
      }

      final Map<String, dynamic>? json = await api.getSiteTerrainData(urlFor(site));

      final dynamic restify = json?['restify'];
      final dynamic rows = (restify is Map) ? restify['rows'] : null;
      if (rows is! List || rows.isEmpty) {
        logger.i('GetSiteTerrain: no site_terrain row for site ${site.siteId}');
        return;
      }

      final dynamic firstRow = rows.first;
      final dynamic values = (firstRow is Map) ? firstRow['values'] : null;
      if (values is! Map) {
        logger.w('GetSiteTerrain: malformed site_terrain row for site ${site.siteId}');
        return;
      }

      final String? groundStr = _value(values, 'ground_m');
      final int? ground = groundStr == null ? null : int.tryParse(groundStr);
      final List<int>? medians =
          TerrainHeight.parseCsv(_value(values, 'bearing_median_m'), TerrainHeight.bearings);
      final List<List<int>>? profile = parseProfile(_value(values, 'profile_m'));

      if (ground == null || medians == null) {
        logger.w('GetSiteTerrain: malformed ground_m/bearing_median_m for site ${site.siteId}');
        return;
      }

      site.applyTerrain(ground, medians, profile);
    } catch (e, stack) {
      logger.e(
          'GetSiteTerrain: error loading site_terrain for site ${site.siteId}: $e\n$stack');
    } finally {
      site.terrainLoaded = true;
      // Terrain mode without a served profile: fall back to the Google Elevation download.
      if (PolygonHelper.calculateTerrain && !site.finishedDownloadingElevations) {
        PolygonHelper.startGoogleElevation(site);
      }
    }
  }
}
