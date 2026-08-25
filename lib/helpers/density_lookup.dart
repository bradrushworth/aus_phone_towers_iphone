import 'package:phonetowers/restful/get_licenceHRP.dart' show CityDensity;
import 'package:phonetowers/utils/geohash_cell.dart';

/// The app's view of the `geohash_density` table: rows fetched in bulk for a region, then resolved
/// locally.
///
/// Mirror of the Android app's `DensityLookup.java`, and deliberately identical in behaviour — the
/// spec requires both apps to return the same density for the same coordinate.
///
/// Replaces `Site.getCityDensityStatic(int)`, which classified a place by how many sites ONE telco
/// happened to return. Telstra operates far more sites than Vodafone everywhere, so the same street
/// corner was handed a different Okumura-Hata environment — and therefore a differently sized
/// coverage polygon — depending on which carrier was being drawn, and a different one again as the
/// user panned.
///
/// Resolution walks the geohash from level [kGeohashMaxLevel] down to [kGeohashMinLevel] and takes
/// the first hit. The generator emits disjoint cells at mixed levels, so the longest match is the
/// most specific truth available — but the walk does not rely on that holding, because a partial
/// fetch can legitimately leave a coarse cell and a fine one cached together.
///
/// Never fetched per point: this runs inside the polygon loop, once per site on screen.
class DensityLookup {
  DensityLookup._();

  static final Map<String, CityDensity> _cells = <String, CityDensity>{};

  static void put(String? geohash, CityDensity? density) {
    if (geohash != null && density != null) {
      _cells[geohash] = density;
    }
  }

  static void clear() => _cells.clear();

  static int get size => _cells.length;

  /// The density covering this point, or [CityDensity.OPEN] when nothing does — the honest answer
  /// for country the generator emitted no row for, and never an exception, because this runs for
  /// every site on screen.
  static CityDensity forPoint(double lat, double lon) {
    final String g = geohashEncode(lat, lon, kGeohashMaxLevel);
    for (int len = kGeohashMaxLevel; len >= kGeohashMinLevel; len--) {
      final CityDensity? hit = _cells[g.substring(0, len)];
      if (hit != null) {
        return hit;
      }
    }
    return CityDensity.OPEN;
  }
}
