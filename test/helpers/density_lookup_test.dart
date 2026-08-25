import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/density_lookup.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart' show CityDensity;
import 'package:phonetowers/utils/geohash_cell.dart';

/// Mirrors the Android suite's DensityLookupTest. The two apps must resolve identically.
void main() {
  setUp(DensityLookup.clear);
  tearDown(DensityLookup.clear);

  test('longest prefix wins', () {
    // A coarse OPEN cell with a fine METRO cell inside it. The generator emits disjoint cells, but
    // the lookup must not depend on that: a partial fetch can leave exactly this shape cached.
    final String fine = geohashEncode(-33.8568, 151.2153, 7);
    DensityLookup.put(fine.substring(0, 4), CityDensity.OPEN);
    DensityLookup.put(fine, CityDensity.METRO);
    expect(DensityLookup.forPoint(-33.8568, 151.2153), CityDensity.METRO);
  });

  test('unknown point is OPEN rather than an exception', () {
    expect(DensityLookup.forPoint(-25.0, 131.0), CityDensity.OPEN);
  });

  test('a coarse cell covers everything inside it', () {
    DensityLookup.put(geohashEncode(-25.0, 131.0, 4), CityDensity.SUBURBAN);
    expect(DensityLookup.forPoint(-25.001, 131.001), CityDensity.SUBURBAN);
  });

  test('resolves the shape the generator actually produces', () {
    // Levels 4 and 5 only, which is what the sites-only generator emits.
    DensityLookup.put('qgmp', CityDensity.OPEN); // Uluru, level 4
    DensityLookup.put('r3gx2', CityDensity.METRO); // Sydney, level 5
    expect(DensityLookup.forPoint(-33.8568, 151.2153), CityDensity.METRO);
    expect(DensityLookup.forPoint(-25.3444, 131.0369), CityDensity.OPEN);
  });
}
