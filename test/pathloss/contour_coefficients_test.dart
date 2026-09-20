import 'dart:convert' show utf8;
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/contour_coefficients.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Reads the bundled asset with dart:io rather than as a Flutter asset bundle, since plain
/// `flutter test` has no asset bundle -- paths are relative to the package root, which is the
/// cwd under `flutter test` (see test/docs/user_guide_html_test.dart for the same pattern).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContourCoefficientsTest', () {
    late String rawAssetText;
    late ContourCoefficients bundled;

    setUpAll(() {
      rawAssetText = File(ContourCoefficients.bundledAssetPath).readAsStringSync();
      bundled = ContourCoefficients.parse(rawAssetText);
    });

    test('parses all 15 classes (5 densities x 3 bands)', () {
      final Set<String> expectedKeys = <String>{
        for (final CityDensity density in CityDensity.values)
          for (final String band in <String>['LOW', 'MID', 'HIGH']) '${density.name}|$band',
      };
      expect(bundled.classes.keys.toSet(), expectedKeys);
      expect(bundled.classes, hasLength(15));
    });

    test('parses 3 pooled rows and 3 NR offsets, one per band', () {
      expect(bundled.pooled.keys.toSet(), <String>{'LOW', 'MID', 'HIGH'});
      expect(bundled.nrOffsetByBand.keys.toSet(), <String>{'LOW', 'MID', 'HIGH'});
    });

    test('parses both typical-power maps (LTE and NR), one entry per band', () {
      expect(bundled.typicalPerReEirpDbmByTech.keys.toSet(), <String>{'LTE', 'NR'});
      expect(bundled.typicalPerReEirpDbmByTech['LTE']!.keys.toSet(), <String>{'LOW', 'MID', 'HIGH'});
      expect(bundled.typicalPerReEirpDbmByTech['NR']!.keys.toSet(), <String>{'LOW', 'MID', 'HIGH'});
    });

    test('every class and pooled slope (k * hataSlopeDb(30m)) is at least 22 dB/decade', () {
      final double slopeAt30m = AnalyticPathLossModel.hataSlopeDb(30.0);
      for (final MapEntry<String, ContourClassRow> entry in bundled.classes.entries) {
        expect(entry.value.k * slopeAt30m, greaterThanOrEqualTo(22.0),
            reason: 'class ${entry.key}');
      }
      for (final MapEntry<String, ContourClassRow> entry in bundled.pooled.entries) {
        expect(entry.value.k * slopeAt30m, greaterThanOrEqualTo(22.0),
            reason: 'pooled ${entry.key}');
      }
    });

    test('evidence.gate_passed is true for the shipped table', () {
      expect(bundled.gatePassed, isTrue);
    });

    test('the hard-coded fallback equals the bundled table\'s pooled rows, NR offsets and '
        'typical powers, so it cannot silently drift', () {
      final ContourCoefficients fallback = ContourCoefficients.fallback();
      expect(fallback.pooled, bundled.pooled);
      expect(fallback.nrOffsetByBand, bundled.nrOffsetByBand);
      expect(fallback.typicalPerReEirpDbmByTech, bundled.typicalPerReEirpDbmByTech);
      // The fallback deliberately has no per-class rows -- every density falls back to pooled.
      expect(fallback.classes, isEmpty);
    });

    test('the bundled asset\'s SHA-256, with every carriage return removed, matches the '
        'recorded constant (this is what keeps the Android and Flutter copies identical)', () {
      final String withoutCr = rawAssetText.replaceAll('\r', '');
      final String hash = sha256.convert(utf8.encode(withoutCr)).toString();
      expect(hash, ContourCoefficients.bundledTableSha256);
    });

    test('forClass returns the exact class entry when the table has one', () {
      expect(bundled.forClass(CityDensity.SUBURBAN, 'MID'), bundled.classes['SUBURBAN|MID']);
      expect(bundled.forClass(CityDensity.URBAN, 'HIGH'), bundled.classes['URBAN|HIGH']);
    });

    test('forClass falls back to the band\'s pooled row for a class the table does not model', () {
      const ContourCoefficients sparse = ContourCoefficients(
        classes: <String, ContourClassRow>{},
        pooled: <String, ContourClassRow>{'MID': ContourClassRow(0.9, -1.0)},
        nrOffsetByBand: <String, double>{},
        typicalPerReEirpDbmByTech: <String, Map<String, double>>{},
        gatePassed: false,
      );
      expect(sparse.forClass(CityDensity.URBAN, 'MID'), const ContourClassRow(0.9, -1.0));
    });

    test('nrOffsetDb and typicalPerReEirpDbm default to zero for an unmodelled band', () {
      const ContourCoefficients empty = ContourCoefficients(
        classes: <String, ContourClassRow>{},
        pooled: <String, ContourClassRow>{},
        nrOffsetByBand: <String, double>{},
        typicalPerReEirpDbmByTech: <String, Map<String, double>>{},
        gatePassed: false,
      );
      expect(empty.nrOffsetDb('MID'), 0.0);
      expect(empty.typicalPerReEirpDbm(NetworkType.LTE, 'MID'), 0.0);
      expect(empty.typicalPerReEirpDbm(NetworkType.NR, 'MID'), 0.0);
    });

    test('parse throws FormatException when "format" is not pathloss-v2', () {
      expect(() => ContourCoefficients.parse('{"format": "something-else"}'),
          throwsFormatException);
    });

    test('parse throws FormatException on non-JSON input', () {
      expect(() => ContourCoefficients.parse('not json at all'), throwsFormatException);
    });

    test('parse throws FormatException when a required section is missing', () {
      expect(() => ContourCoefficients.parse('{"format": "pathloss-v2"}'), throwsFormatException);
    });

    test('parseOrFallback returns fallback() and records a non-null bundledLoadError on '
        'malformed JSON', () {
      final ContourCoefficients result =
          ContourCoefficients.parseOrFallback('{"format": "wrong-format"}');
      expect(result.pooled, ContourCoefficients.fallback().pooled);
      expect(result.classes, isEmpty);
      expect(ContourCoefficients.bundledLoadError, isNotNull);
    });

    test('parseOrFallback returns the parsed table and clears bundledLoadError on valid JSON', () {
      final ContourCoefficients result = ContourCoefficients.parseOrFallback(rawAssetText);
      expect(result.gatePassed, isTrue);
      expect(ContourCoefficients.bundledLoadError, isNull);
    });

    test('loadBundled reads the real bundled asset via rootBundle, and current reflects it', () async {
      final ContourCoefficients loaded = await ContourCoefficients.loadBundled();
      expect(loaded.gatePassed, isTrue);
      expect(loaded.pooled, bundled.pooled);
      expect(ContourCoefficients.current.pooled, loaded.pooled);
    });
  });
}
