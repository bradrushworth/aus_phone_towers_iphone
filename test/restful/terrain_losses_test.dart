import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/model/height_distance_pair.dart';

/// GitHub issue #56: with terrain on, every signal-strength contour of a site was drawn at the
/// same radius. calculateTerrainLosses used to walk an obstructed bearing down the fixed
/// GetElevation.SAMPLE_DISTANCES ladder until the path was clear, and that ladder does not depend
/// on the signal level — so MAX, STRONG, GOOD and WEAK all landed on the same rung and the user's
/// choice made no visible difference.
///
/// Mirrors GetLicenceHRPTest in the Android app; keep the two in lockstep.
void main() {
  const double bearing = 45.0;
  const double lat = -32.0, lon = 151.0;

  late Site site;

  setUp(() {
    site = Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN);
    site.siteId = '9011112';
    site.latitude = lat;
    site.longitude = lon;
  });

  /// A stand-in for the app's trained path-loss model: plain Okumura-Hata over open country,
  /// monotonically increasing in the link budget, which is all these tests need of it.
  double Function(double) solver(double freqInMHz, int towerHeight) {
    return (double budgetDb) => GetLicenceHRP.calculateDistance(
        CityDensity.OPEN, budgetDb, freqInMHz, towerHeight.toDouble());
  }

  /// The link budget whose terrain-free distance is [distanceKm], found by bisection.
  double budgetForDistance(double Function(double) solve, double distanceKm) {
    double low = 50, high = 250;
    for (int i = 0; i < 200; i++) {
      double mid = (low + high) / 2;
      if (solve(mid) < distanceKm) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  void addProfile(Map<double, double> distanceToElevation) {
    distanceToElevation.forEach((distance, elevation) {
      site.addElevation(
          GetLicenceHRP.travel(LatLng(lat, lon), bearing, distance), elevation);
    });
  }

  /// A ridge at 1.5 km that blocks the line of sight from a low tower.
  Set<HeightDistancePair> obstructedProfile() {
    addProfile({
      0.00: 0,
      0.50: 10,
      1.00: 20,
      1.25: 30,
      1.50: 40,
      2.50: 30,
      3.50: 20,
      4.50: 10,
      5.50: 0,
      7.00: 0,
    });
    return site.getHeightsAlongBearingWithDistanceAndBearing(7.0, bearing);
  }

  group('calculateTerrainLosses', () {
    test('a clear path is not shortened at all', () {
      addProfile({
        0.0: 0,
        0.5: 0,
        1.5: 0,
        2.5: 0,
        3.5: 0,
        4.5: 0,
        5.5: 0,
        7.0: 0,
      });
      final heights =
          site.getHeightsAlongBearingWithDistanceAndBearing(7.0, bearing);

      final solve = solver(1865.0, 10);
      final budget = budgetForDistance(solve, 5.5);
      expect(
          GetLicenceHRP.calculateTerrainLosses(
              site, heights, budget, solve, bearing, 1865.0, 10),
          closeTo(5.5, 0.01));
    });

    test('an obstructed path is shortened but not wiped out', () {
      final heights = obstructedProfile();

      final solve = solver(1865.0, 10);
      final budget = budgetForDistance(solve, 5.5);
      final reached = GetLicenceHRP.calculateTerrainLosses(
          site, heights, budget, solve, bearing, 1865.0, 10);
      expect(reached, lessThan(5.5));
      expect(reached, greaterThan(0));
    });

    test('weaker contours must still reach further through terrain', () {
      final heights = obstructedProfile();

      final solve = solver(1865.0, 10);
      const double transmittedPowerDbm = 57;
      // Strongest first, weakest last.
      final bars = NetworkTypeHelper.getNetworkBars(NetworkType.LTE);

      double previous = 0;
      for (int i = 0; i < bars.length; i++) {
        final reached = GetLicenceHRP.calculateTerrainLosses(site, heights,
            transmittedPowerDbm - bars[i], solve, bearing, 1865.0, 10);
        expect(reached, greaterThan(previous),
            reason: 'contour ${bars[i]} dBm reached $reached km, no further '
                'than the stronger contour at $previous km');
        previous = reached;
      }
    });
  });

  group('knifeEdgeLossDb', () {
    test('grows with obstruction', () {
      expect(GetLicenceHRP.knifeEdgeLossDb(-0.78), closeTo(0, 0.001));
      expect(GetLicenceHRP.knifeEdgeLossDb(-5.0), closeTo(0, 0.001));
      expect(GetLicenceHRP.knifeEdgeLossDb(0.0), closeTo(6.03, 0.01));
      expect(GetLicenceHRP.knifeEdgeLossDb(2.0),
          greaterThan(GetLicenceHRP.knifeEdgeLossDb(1.0)));
      expect(GetLicenceHRP.knifeEdgeLossDb(1.0),
          greaterThan(GetLicenceHRP.knifeEdgeLossDb(0.0)));
    });
  });
}
