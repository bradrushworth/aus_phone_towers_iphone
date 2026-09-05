import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/pathloss/terrain_height.dart';
import 'package:phonetowers/restful/get_elevation.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Tests for [Site.applyTerrain] (Task F6): installing a nightly site_terrain row into a Site,
/// mirroring the Java app's Site.applyTerrain. With a full 24 x 19 profile the samples are fed
/// directly into [Site.elevations] (not via addElevation's putIfAbsent, so a fresh row always
/// wins) at the exact points GetLicenceHRP.travel would compute; without one, only the ground
/// and per-bearing medians are recorded, which is enough for effectiveHeightM.
void main() {
  group('Site.applyTerrain', () {
    late Site site;

    setUp(() {
      site = Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN);
      site.latitude = -35.28;
      site.longitude = 149.13;
    });

    test('with a full profile: ground elevation, samples along bearing 90, flags set', () {
      const int groundM = 750;
      final List<int> medians = List.filled(TerrainHeight.bearings, 600);

      // Bearing 90 is index 6 (6 * 15 degrees). Give it recognisable values, with the
      // last (furthest) sample set to 900 m.
      final int bearing90Index = 90 ~/ TerrainHeight.bearingStepDegrees.round();
      final List<List<int>> profile = List.generate(TerrainHeight.bearings, (b) {
        if (b == bearing90Index) {
          return List.generate(GetElevation.SAMPLE_DISTANCES.length, (k) => 100 + k)
            ..[GetElevation.SAMPLE_DISTANCES.length - 1] = 900;
        }
        return List.filled(GetElevation.SAMPLE_DISTANCES.length, 0);
      });

      site.applyTerrain(groundM, medians, profile);

      expect(site.terrainGroundM, groundM);
      expect(site.terrainMedians, medians);
      expect(site.terrainLoaded, isTrue);
      expect(site.startedDownloadingElevations, isTrue);
      expect(site.finishedDownloadingElevations, isTrue);

      // Ground elevation recorded at the site itself.
      expect(site.elevations[site.getLatLng()], groundM.toDouble());

      // The furthest sample along bearing 90 was written at the exact point
      // GetLicenceHRP.travel computes for it, with value 900.
      final LatLng lastPoint = GetLicenceHRP.travel(
          site.getLatLng(), 90, GetElevation.SAMPLE_DISTANCES.last);
      expect(site.elevations[lastPoint], 900.0);

      // And a near sample along the same bearing too, confirming all 19 were written.
      final LatLng nearPoint = GetLicenceHRP.travel(
          site.getLatLng(), 90, GetElevation.SAMPLE_DISTANCES.first);
      expect(site.elevations[nearPoint], 100.0);
    });

    test('a fresh row overwrites a stale elevation rather than keeping the old value', () {
      final LatLng lastPoint = GetLicenceHRP.travel(
          site.getLatLng(), 90, GetElevation.SAMPLE_DISTANCES.last);
      // Simulate a stale Google-sourced elevation already present at that exact point.
      site.addElevation(lastPoint, 1234.0);
      expect(site.elevations[lastPoint], 1234.0);

      final int bearing90Index = 90 ~/ TerrainHeight.bearingStepDegrees.round();
      final List<List<int>> profile = List.generate(TerrainHeight.bearings, (b) {
        if (b == bearing90Index) {
          return List.filled(GetElevation.SAMPLE_DISTANCES.length, 42);
        }
        return List.filled(GetElevation.SAMPLE_DISTANCES.length, 0);
      });

      site.applyTerrain(750, List.filled(TerrainHeight.bearings, 600), profile);

      expect(site.elevations[lastPoint], 42.0,
          reason: 'applyTerrain must overwrite directly, not putIfAbsent');
    });

    test('without a profile: flags untouched, terrainLoaded true, effectiveHeightM computed', () {
      site.applyTerrain(800, List.filled(TerrainHeight.bearings, 600), null);

      expect(site.terrainGroundM, 800);
      expect(site.terrainLoaded, isTrue);
      expect(site.startedDownloadingElevations, isFalse,
          reason: 'no profile means no elevation data was fed in, so the flags stay untouched');
      expect(site.finishedDownloadingElevations, isFalse);

      // ground 800, median 600 at bearing 45 (index 3) -> 30 + (800 - 600) = 230.
      expect(site.effectiveHeightM(30, 45), 230.0);
    });

    test('a mismatched-length profile (not 24 groups) is treated like no profile', () {
      final List<List<int>> shortProfile =
          List.generate(23, (b) => List.filled(GetElevation.SAMPLE_DISTANCES.length, 5));

      site.applyTerrain(800, List.filled(TerrainHeight.bearings, 600), shortProfile);

      expect(site.terrainLoaded, isTrue);
      expect(site.startedDownloadingElevations, isFalse);
      expect(site.finishedDownloadingElevations, isFalse);
      expect(site.elevations, isEmpty);
    });
  });
}
