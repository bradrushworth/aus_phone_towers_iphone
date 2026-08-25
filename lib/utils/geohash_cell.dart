/// Geohash arithmetic for the authoritative density table.
///
/// A LINE-FOR-LINE port of the Android app's `GeohashCell.java`. The spec requires both apps to
/// return an identical density for the same coordinate, and that begins with both encoders agreeing
/// character for character — so this must not be re-derived or "improved" independently. The same
/// three reference geohashes are asserted in both test suites, so a divergence fails loudly in
/// whichever app introduced it.
library;

const String kGeohashBase32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Coarsest cell the density table holds: ~39 x 20 km.
const int kGeohashMinLevel = 4;

/// Finest cell the density table holds: ~150 m.
const int kGeohashMaxLevel = 7;

/// Encodes a point to [precision] base-32 characters.
String geohashEncode(double lat, double lon, int precision) {
  double latMin = -90, latMax = 90, lonMin = -180, lonMax = 180;
  final StringBuffer out = StringBuffer();
  bool even = true;
  int bit = 0, ch = 0;
  while (out.length < precision) {
    if (even) {
      final double mid = (lonMin + lonMax) / 2;
      if (lon > mid) {
        ch |= 1 << (4 - bit);
        lonMin = mid;
      } else {
        lonMax = mid;
      }
    } else {
      final double mid = (latMin + latMax) / 2;
      if (lat > mid) {
        ch |= 1 << (4 - bit);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    even = !even;
    if (bit < 4) {
      bit++;
    } else {
      out.write(kGeohashBase32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}
