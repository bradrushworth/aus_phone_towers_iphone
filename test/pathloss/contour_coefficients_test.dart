import 'dart:convert' show jsonEncode, utf8;
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

    test('parses 3 pooled rows and a default TDD loss', () {
      expect(bundled.pooled.keys.toSet(), <String>{'LOW', 'MID', 'HIGH'});
      expect(bundled.nrTddOffsetByMnc, contains('default'));
    });

    test('nr_tdd_offset_db: every value (including default) is between 0 and 20 dB', () {
      for (final MapEntry<String, double> entry in bundled.nrTddOffsetByMnc.entries) {
        expect(entry.value, inInclusiveRange(0.0, 20.0), reason: entry.key);
      }
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

    test('the hard-coded fallback equals the bundled table\'s pooled rows, its default TDD '
        'loss and its typical powers, so none of them can silently drift', () {
      final ContourCoefficients fallback = ContourCoefficients.fallback();
      expect(fallback.pooled, bundled.pooled);
      expect(fallback.nrTddOffsetByMnc['default'], bundled.nrTddOffsetByMnc['default']);
      expect(fallback.typicalPerReEirpDbmByTech, bundled.typicalPerReEirpDbmByTech);
      // The fallback deliberately has no per-class rows -- every density falls back to pooled --
      // and no per-carrier TDD losses, only default -- an unknown carrier gets that anyway.
      expect(fallback.classes, isEmpty);
      expect(fallback.nrTddOffsetByMnc.keys, hasLength(1));
      expect(fallback.nrTddOffsetByMnc, contains('default'));
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
        nrTddOffsetByMnc: <String, double>{},
        typicalPerReEirpDbmByTech: <String, Map<String, double>>{},
        gatePassed: false,
      );
      expect(sparse.forClass(CityDensity.URBAN, 'MID'), const ContourClassRow(0.9, -1.0));
    });

    test('nrTddOffsetDb: carrier value if present, else default, else zero if the table has '
        'neither', () {
      const ContourCoefficients carrierAndDefault = ContourCoefficients(
        classes: <String, ContourClassRow>{},
        pooled: <String, ContourClassRow>{},
        nrTddOffsetByMnc: <String, double>{'default': 9.2, '1': 13.2},
        typicalPerReEirpDbmByTech: <String, Map<String, double>>{},
        gatePassed: false,
      );
      expect(carrierAndDefault.nrTddOffsetDb(1), 13.2); // Telstra's own value.
      expect(carrierAndDefault.nrTddOffsetDb(2), 9.2); // unknown carrier -> default.
      expect(carrierAndDefault.nrTddOffsetDb(0), 9.2); // conventional "unknown" sentinel.

      const ContourCoefficients neither = ContourCoefficients(
        classes: <String, ContourClassRow>{},
        pooled: <String, ContourClassRow>{},
        nrTddOffsetByMnc: <String, double>{},
        typicalPerReEirpDbmByTech: <String, Map<String, double>>{},
        gatePassed: false,
      );
      expect(neither.nrTddOffsetDb(1), 0.0);
    });

    test('typicalPerReEirpDbm throws StateError when the table has no entry for it (a hand-built '
        'table that bypassed the validation parse() enforces)', () {
      const ContourCoefficients missingNr = ContourCoefficients(
        classes: <String, ContourClassRow>{},
        pooled: <String, ContourClassRow>{},
        nrTddOffsetByMnc: <String, double>{'default': 9.2},
        typicalPerReEirpDbmByTech: <String, Map<String, double>>{
          'LTE': <String, double>{'LOW': 36.1, 'MID': 34.6, 'HIGH': 30.6},
        },
        gatePassed: false,
      );
      expect(() => missingNr.typicalPerReEirpDbm(NetworkType.LTE, 'MID'), returnsNormally);
      expect(() => missingNr.typicalPerReEirpDbm(NetworkType.NR, 'MID'), throwsStateError);
      expect(() => missingNr.typicalPerReEirpDbm(NetworkType.LTE, 'NONEXISTENT_BAND'),
          throwsStateError);
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

    test('parse throws FormatException when nr_tdd_offset_db has no "default"', () {
      final Map<String, dynamic> json = _validTableJson();
      (json['nr_tdd_offset_db'] as Map<String, dynamic>).remove('default');
      expect(() => ContourCoefficients.parse(jsonEncode(json)), throwsFormatException);
    });

    test('parse throws FormatException when typical_per_re_eirp_dbm is missing a technology or '
        'a band (a missing entry would otherwise silently draw a bogus contour)', () {
      final Map<String, dynamic> missingTech = _validTableJson();
      (missingTech['typical_per_re_eirp_dbm'] as Map<String, dynamic>).remove('NR');
      expect(() => ContourCoefficients.parse(jsonEncode(missingTech)), throwsFormatException);

      final Map<String, dynamic> missingBand = _validTableJson();
      ((missingBand['typical_per_re_eirp_dbm'] as Map<String, dynamic>)['LTE']
              as Map<String, dynamic>)
          .remove('MID');
      expect(() => ContourCoefficients.parse(jsonEncode(missingBand)), throwsFormatException);
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

/// A minimal but structurally complete table, for tests that break exactly one piece of it and
/// confirm [ContourCoefficients.parse] rejects the result. A fresh, independent set of nested
/// maps every call, so callers can mutate their own copy freely.
Map<String, dynamic> _validTableJson() {
  return <String, dynamic>{
    'format': 'pathloss-v2',
    'classes': <String, dynamic>{
      'SUBURBAN|MID': <String, dynamic>{'k': 0.85, 'offset_db': -4.0},
    },
    'pooled': <String, dynamic>{
      'LOW': <String, dynamic>{'k': 0.78, 'offset_db': 3.78},
      'MID': <String, dynamic>{'k': 0.82, 'offset_db': -5.09},
      'HIGH': <String, dynamic>{'k': 0.82, 'offset_db': -8.18},
    },
    'nr_tdd_offset_db': <String, dynamic>{'default': 9.2, '1': 13.2, '3': 4.3},
    'typical_per_re_eirp_dbm': <String, dynamic>{
      'LTE': <String, dynamic>{'LOW': 36.1, 'MID': 34.6, 'HIGH': 30.6},
      'NR': <String, dynamic>{'LOW': 36.5, 'MID': 30.5, 'HIGH': 46.2},
    },
    'evidence': <String, dynamic>{'gate_passed': true},
  };
}
