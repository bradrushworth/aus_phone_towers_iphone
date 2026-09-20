import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/contour_coefficients.dart';
import 'package:phonetowers/pathloss/contour_model.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Behaviour tests for the path-loss model v2 solver (spec section 2). Uses small synthetic
/// [ContourCoefficients] fixtures throughout, rather than the bundled table, so each test's
/// numbers are self-contained and don't move if the table is recalibrated -- the bundled table's
/// own shape and hash are covered by contour_coefficients_test.dart, and the exact arithmetic is
/// cross-checked against an independent Python port in shared_vectors_test.dart.
void main() {
  group('ContourModelTest', () {
    late ContourModel model;

    setUp(() {
      final ContourCoefficients coefficients = ContourCoefficients(
        classes: const <String, ContourClassRow>{
          'SUBURBAN|MID': ContourClassRow(0.85, -4.0),
        },
        pooled: const <String, ContourClassRow>{
          'LOW': ContourClassRow(0.78, 3.78),
          'MID': ContourClassRow(0.85, -4.0),
          'HIGH': ContourClassRow(0.82, -8.18),
        },
        nrOffsetByBand: const <String, double>{'LOW': 0.0, 'MID': 5.0, 'HIGH': 9.0},
        typicalPerReEirpDbmByTech: const <String, Map<String, double>>{},
        gatePassed: true,
      );
      model = ContourModel(coefficients);
    });

    test('supports is true for LTE and NR only', () {
      expect(ContourModel.supports(NetworkType.LTE), isTrue);
      expect(ContourModel.supports(NetworkType.NR), isTrue);
      expect(ContourModel.supports(NetworkType.GSM), isFalse);
      expect(ContourModel.supports(NetworkType.UMTS), isFalse);
      expect(ContourModel.supports(NetworkType.CDMA), isFalse);
      expect(ContourModel.supports(NetworkType.NB_IOT), isFalse);
      expect(ContourModel.supports(NetworkType.OTHER), isFalse);
      expect(ContourModel.supports(NetworkType.UNKNOWN), isFalse);
    });

    test('lossDb and distanceKm are inverses of each other', () {
      const double distance = 5.0;
      final double budgetDb =
          model.lossDb(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, distance);
      final double roundTripped =
          model.distanceKm(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, budgetDb);
      expect(roundTripped, closeTo(distance, 1e-9));
    });

    test('A_urban and the slope come from AnalyticPathLossModel, not a re-derived formula', () {
      // At distance 1 km, log10(d) == 0, so lossDb reduces to aUrban + offset + nrOffset.
      final double aUrban = AnalyticPathLossModel.hataInterceptDb(CityDensity.URBAN, 1865.0, 30.0);
      final double actual =
          model.lossDb(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, 1.0);
      expect(actual, closeTo(aUrban + (-4.0), 1e-9));
    });

    test('a null density is treated as SUBURBAN', () {
      final double withNull = model.distanceKm(NetworkType.LTE, null, 1865.0, 30.0, 100.0);
      final double withSuburban =
          model.distanceKm(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, 100.0);
      expect(withNull, withSuburban);
    });

    test('distanceKm is monotonic in the rung: a weaker (more negative) rung is drawn further '
        'out for the same transmit power', () {
      const double perReEirpDbm = 40.0;
      double distanceForRung(double rungDbm) => model.distanceKm(
          NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, perReEirpDbm - rungDbm);

      final double strongRung = distanceForRung(-85.0);
      final double weakRung = distanceForRung(-115.0);
      expect(weakRung, greaterThan(strongRung));
    });

    test('distanceKm is monotonic in pattern loss: more pattern loss leaves less power for the '
        'same rung, so a shorter reach', () {
      const double perReEirpDbm = 40.0;
      const double rungDbm = -95.0;
      double distanceForPatternLoss(double patternLossDb) => model.distanceKm(
          NetworkType.LTE,
          CityDensity.SUBURBAN,
          1865.0,
          30.0,
          (perReEirpDbm - patternLossDb) - rungDbm);

      final double lightPatternLoss = distanceForPatternLoss(3.0);
      final double heavyPatternLoss = distanceForPatternLoss(12.0);
      expect(heavyPatternLoss, lessThan(lightPatternLoss));
    });

    test('distanceKm is monotonic in the class offset: more offset (dB) is more loss, so a '
        'shorter reach for the same budget', () {
      ContourModel modelWithOffset(double offsetDb) => ContourModel(ContourCoefficients(
            classes: <String, ContourClassRow>{'SUBURBAN|MID': ContourClassRow(0.85, offsetDb)},
            pooled: const <String, ContourClassRow>{},
            nrOffsetByBand: const <String, double>{},
            typicalPerReEirpDbmByTech: const <String, Map<String, double>>{},
            gatePassed: true,
          ));

      final double lessOffset = modelWithOffset(-10.0)
          .distanceKm(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, 130.0);
      final double moreOffset = modelWithOffset(5.0)
          .distanceKm(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, 130.0);
      expect(moreOffset, lessThan(lessOffset));
    });

    test('the NR offset changes NR\'s distance but leaves LTE\'s distance unchanged', () {
      ContourModel modelWithNrOffset(double nrOffsetDb) => ContourModel(ContourCoefficients(
            classes: <String, ContourClassRow>{
              'SUBURBAN|MID': const ContourClassRow(0.85, -4.0),
            },
            pooled: const <String, ContourClassRow>{},
            nrOffsetByBand: <String, double>{'MID': nrOffsetDb},
            typicalPerReEirpDbmByTech: const <String, Map<String, double>>{},
            gatePassed: true,
          ));

      final ContourModel zeroOffset = modelWithNrOffset(0.0);
      final ContourModel fiveDbOffset = modelWithNrOffset(5.0);

      final double lteWithZero = zeroOffset.distanceKm(
          NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, 130.0);
      final double lteWithFive = fiveDbOffset.distanceKm(
          NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, 130.0);
      expect(lteWithFive, lteWithZero);

      final double nrWithZero =
          zeroOffset.distanceKm(NetworkType.NR, CityDensity.SUBURBAN, 1865.0, 30.0, 130.0);
      final double nrWithFive =
          fiveDbOffset.distanceKm(NetworkType.NR, CityDensity.SUBURBAN, 1865.0, 30.0, 130.0);
      expect(nrWithFive, lessThan(nrWithZero));
    });

    test('distanceKm clamps to [0.01, 100] km', () {
      final double veryShort =
          model.distanceKm(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, -1000.0);
      expect(veryShort, 0.01);

      final double veryLong =
          model.distanceKm(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 30.0, 1000.0);
      expect(veryLong, 100.0);
    });

    test('effective height is floored at 1 metre', () {
      final double atHalfMetre =
          model.distanceKm(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 0.5, 130.0);
      final double atOneMetre =
          model.distanceKm(NetworkType.LTE, CityDensity.SUBURBAN, 1865.0, 1.0, 130.0);
      expect(atHalfMetre, atOneMetre);
    });

    test('picks the coefficients row for the frequency\'s band (LOW/MID/HIGH)', () {
      final ContourCoefficients bandCoefficients = ContourCoefficients(
        classes: const <String, ContourClassRow>{},
        pooled: const <String, ContourClassRow>{
          'LOW': ContourClassRow(0.70, 1.0),
          'MID': ContourClassRow(0.80, 2.0),
          'HIGH': ContourClassRow(0.90, 3.0),
        },
        nrOffsetByBand: const <String, double>{},
        typicalPerReEirpDbmByTech: const <String, Map<String, double>>{},
        gatePassed: true,
      );
      final ContourModel bandModel = ContourModel(bandCoefficients);
      const double h = 30.0;
      double aUrbanFor(double freqMHz) =>
          AnalyticPathLossModel.hataInterceptDb(CityDensity.URBAN, freqMHz, h);

      // At distance 1 km, log10(d) == 0, so lossDb reduces to aUrban + offset (an empty
      // `classes` map means every density falls back to the pooled row for the band).
      expect(bandModel.lossDb(NetworkType.LTE, CityDensity.URBAN, 700.0, h, 1.0),
          closeTo(aUrbanFor(700.0) + 1.0, 1e-9)); // LOW: < 1000 MHz
      expect(bandModel.lossDb(NetworkType.LTE, CityDensity.URBAN, 1865.0, h, 1.0),
          closeTo(aUrbanFor(1865.0) + 2.0, 1e-9)); // MID: 1000-2500 MHz
      expect(bandModel.lossDb(NetworkType.LTE, CityDensity.URBAN, 2650.0, h, 1.0),
          closeTo(aUrbanFor(2650.0) + 3.0, 1e-9)); // HIGH: >= 2500 MHz
    });
  });
}
