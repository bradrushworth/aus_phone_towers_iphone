import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/pathloss/terrain_height.dart';
import 'package:phonetowers/restful/get_elevation.dart';
import 'package:phonetowers/restful/get_site_terrain.dart';

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
}
