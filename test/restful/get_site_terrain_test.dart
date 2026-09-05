import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/pathloss/terrain_height.dart';
import 'package:phonetowers/restful/get_elevation.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart' show CityDensity, GetLicenceHRP;
import 'package:phonetowers/restful/get_site_terrain.dart';

/// A fake [Api] returning a canned decoded JSON body (or null, mimicking a Dio error) instead of
/// making a network call. [Api.getSiteTerrainData] is a plain instance method with no interface,
/// so overriding it on a subclass is the direct way to stub it; `super.initialize()` runs the
/// real constructor, which only builds an unused Dio client (gated on AppConstants.isDebug,
/// false by default) and is otherwise side-effect-free — getSiteTerrainData is the only method
/// ever invoked on the instances below.
class _FakeApi extends Api {
  _FakeApi(this._response) : super.initialize();

  final Map<String, dynamic>? _response;

  @override
  Future<Map<String, dynamic>?> getSiteTerrainData(String path) async => _response;
}

/// Tests for [GetSiteTerrain.parseProfile], the pure parser that turns the `profile_m` cell
/// ("b0s0,b0s1,...;b1s0,...", 24 groups of [GetElevation.SAMPLE_DISTANCES.length] samples each)
/// into a `List<List<int>>`, or null when the row is absent or malformed. No network — this
/// exercises only the string parsing, matching the Java app's GetSiteTerrain.parseProfile.
void main() {
  group('GetSiteTerrain.parseProfile', () {
    /// A well-formed 24 x 19 profile string: bearing b, sample k -> value (b * 100 + k).
    String wellFormed() {
      final List<String> groups = [];
      for (int b = 0; b < TerrainHeight.bearings; b++) {
        final List<String> samples = [
          for (int k = 0; k < GetElevation.SAMPLE_DISTANCES.length; k++) '${b * 100 + k}'
        ];
        groups.add(samples.join(','));
      }
      return groups.join(';');
    }

    test('round-trips a well-formed 24 x 19 profile', () {
      final List<List<int>>? profile = GetSiteTerrain.parseProfile(wellFormed());

      expect(profile, isNotNull);
      expect(profile!.length, TerrainHeight.bearings);
      for (int b = 0; b < TerrainHeight.bearings; b++) {
        expect(profile[b].length, GetElevation.SAMPLE_DISTANCES.length);
        for (int k = 0; k < GetElevation.SAMPLE_DISTANCES.length; k++) {
          expect(profile[b][k], b * 100 + k);
        }
      }
    });

    test('23 groups (one bearing missing) is malformed -> null', () {
      final List<String> groups = wellFormed().split(';');
      final String missingOneBearing = groups.sublist(0, 23).join(';');

      expect(GetSiteTerrain.parseProfile(missingOneBearing), isNull);
    });

    test('a non-numeric sample in one group is malformed -> null', () {
      final List<String> groups = wellFormed().split(';');
      // Corrupt one sample in the first group with a non-numeric token.
      final List<String> samples = groups[0].split(',');
      samples[5] = 'oops';
      groups[0] = samples.join(',');

      expect(GetSiteTerrain.parseProfile(groups.join(';')), isNull);
    });

    test('null text is absent, not malformed', () {
      expect(GetSiteTerrain.parseProfile(null), isNull);
    });

    test('empty text is absent, not malformed', () {
      expect(GetSiteTerrain.parseProfile(''), isNull);
    });

    test('a group with the wrong sample count is malformed -> null', () {
      final List<String> groups = wellFormed().split(';');
      // Drop the last sample from the first group.
      final List<String> samples = groups[0].split(',');
      groups[0] = samples.sublist(0, samples.length - 1).join(',');

      expect(GetSiteTerrain.parseProfile(groups.join(';')), isNull);
    });
  });

  /// Tests for [GetSiteTerrain.fetch] (I2): the exact defect class that shipped on Android (a
  /// missing `values` wrapper) — a malformed or absent row must degrade gracefully rather than
  /// throwing, and a well-formed one must reach [Site.applyTerrain] intact.
  group('GetSiteTerrain.fetch', () {
    late Site site;

    setUp(() {
      // PolygonHelper.calculateTerrain defaults to false and nothing in this file ever sets it;
      // pinning it explicitly in setUp/tearDown (rather than trusting the default) documents
      // that dependency and keeps these tests isolated — a true value would make fetch()'s
      // finally block call PolygonHelper.startGoogleElevation, which needs a live map/site
      // position and has no place in these pure request/parsing tests. (`flutter test` gives
      // each test *file* its own isolate, so this static cannot leak in from another file.)
      PolygonHelper.calculateTerrain = false;
      site = Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN)
        ..siteId = '1'
        ..latitude = -35.28
        ..longitude = 149.13;
    });

    tearDown(() {
      PolygonHelper.calculateTerrain = false;
    });

    /// A well-formed 24 x 19 profile CSV; bearing b, sample k -> value (b * 100 + k), matching
    /// the parseProfile tests' wellFormed() above.
    String wellFormedProfile() {
      final List<String> groups = [];
      for (int b = 0; b < TerrainHeight.bearings; b++) {
        final List<String> samples = [
          for (int k = 0; k < GetElevation.SAMPLE_DISTANCES.length; k++) '${b * 100 + k}'
        ];
        groups.add(samples.join(','));
      }
      return groups.join(';');
    }

    String wellFormedMedians() => List.filled(TerrainHeight.bearings, 600).join(',');

    /// Builds the `{"restify": {"rows": [{"values": {...}}]}}` body `fetch()` decodes. [groundM]
    /// is `Object` (a `String` or a `num`) so callers can exercise Minor 3 (a JSON number rather
    /// than a quoted string) with the same builder.
    Map<String, dynamic> rowBody({
      Object groundM = '650',
      String? bearingMedianM,
      String? profileM,
    }) {
      final Map<String, dynamic> values = <String, dynamic>{
        'site_id': {'value': '1'},
        'ground_m': {'value': groundM},
      };
      if (bearingMedianM != null) {
        values['bearing_median_m'] = {'value': bearingMedianM};
      }
      if (profileM != null) {
        values['profile_m'] = {'value': profileM};
      }
      return {
        'restify': {
          'rows': [
            {'values': values}
          ]
        }
      };
    }

    test('happy path: ground, medians and a full profile are all applied', () async {
      final Map<String, dynamic> body = rowBody(
        bearingMedianM: wellFormedMedians(),
        profileM: wellFormedProfile(),
      );

      await GetSiteTerrain(site: site, api: _FakeApi(body)).fetch();

      expect(site.terrainGroundM, 650);
      expect(site.terrainLoaded, isTrue);
      expect(site.finishedDownloadingElevations, isTrue);

      // 19 samples were written along bearing 90 (index 6), at the exact points
      // GetLicenceHRP.travel computes for them.
      final int bearing90Index = 90 ~/ TerrainHeight.bearingStepDegrees.round();
      for (int k = 0; k < GetElevation.SAMPLE_DISTANCES.length; k++) {
        final point =
            GetLicenceHRP.travel(site.getLatLng(), 90, GetElevation.SAMPLE_DISTANCES[k]);
        expect(site.elevations[point], (bearing90Index * 100 + k).toDouble());
      }
    });

    test('rowCount 0 and no rows key: terrainLoaded, but nothing else applied', () async {
      await GetSiteTerrain(
              site: site,
              api: _FakeApi(const {
                'restify': {'rowCount': 0}
              }))
          .fetch();

      expect(site.terrainLoaded, isTrue);
      expect(site.terrainGroundM, isNull);
      expect(site.startedDownloadingElevations, isFalse);
      expect(site.finishedDownloadingElevations, isFalse);
    });

    test('null from the API (a Dio error): the same degrade-gracefully outcome', () async {
      await GetSiteTerrain(site: site, api: _FakeApi(null)).fetch();

      expect(site.terrainLoaded, isTrue);
      expect(site.terrainGroundM, isNull);
      expect(site.startedDownloadingElevations, isFalse);
      expect(site.finishedDownloadingElevations, isFalse);
    });

    test('malformed bearing_median_m: the whole row is rejected, same outcome', () async {
      final Map<String, dynamic> body = rowBody(
        bearingMedianM: '1,2,3', // wrong count: TerrainHeight.bearings is 24
        profileM: wellFormedProfile(),
      );

      await GetSiteTerrain(site: site, api: _FakeApi(body)).fetch();

      expect(site.terrainLoaded, isTrue);
      expect(site.terrainGroundM, isNull);
      expect(site.startedDownloadingElevations, isFalse);
      expect(site.finishedDownloadingElevations, isFalse);
    });

    test('a values row without a profile: medians are set, no elevation download', () async {
      final Map<String, dynamic> body = rowBody(bearingMedianM: wellFormedMedians());

      await GetSiteTerrain(site: site, api: _FakeApi(body)).fetch();

      expect(site.terrainGroundM, 650);
      expect(site.terrainMedians, List.filled(TerrainHeight.bearings, 600));
      expect(site.terrainLoaded, isTrue);
      expect(site.finishedDownloadingElevations, isFalse);
    });

    test('ground_m.value as a JSON number, not a quoted string (Minor 3)', () async {
      // A Dart int here mimics json.decode()'s output for an unquoted JSON number, as opposed
      // to the quoted-string shape the other tests above use.
      final Map<String, dynamic> body =
          rowBody(groundM: 650, bearingMedianM: wellFormedMedians());

      await GetSiteTerrain(site: site, api: _FakeApi(body)).fetch();

      expect(site.terrainGroundM, 650);
    });
  });

  group('GetSiteTerrain.urlFor', () {
    test('percent-encodes the site id (Minor 4)', () {
      final Site site = Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN)
        ..siteId = 'a b&c';

      expect(GetSiteTerrain.urlFor(site), contains('_filter=site_id%3D%3Da%20b%26c'));
    });

    test('a plain numeric site id round-trips unchanged', () {
      final Site site = Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN)
        ..siteId = '12345';

      expect(GetSiteTerrain.urlFor(site), contains('_filter=site_id%3D%3D12345'));
    });
  });
}
