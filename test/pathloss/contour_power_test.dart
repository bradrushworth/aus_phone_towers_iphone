import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/contour_coefficients.dart';
import 'package:phonetowers/pathloss/contour_model.dart';
import 'package:phonetowers/pathloss/contour_power.dart';
import 'package:phonetowers/pathloss/transmit_power.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Unit tests for the Flutter call-site glue that combines [TransmitPower] and the bundled
/// [ContourCoefficients] (F2 brief item 1). Uses a small synthetic table throughout so these
/// numbers don't move if the bundled table is recalibrated; the worked example at the bottom
/// cross-checks against the REAL bundled table as a regression pin (spec section 6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContourPowerTest', () {
    final ContourCoefficients coefficients = ContourCoefficients(
      classes: const <String, ContourClassRow>{},
      pooled: const <String, ContourClassRow>{
        'LOW': ContourClassRow(0.78, 3.78),
        'MID': ContourClassRow(0.82, -5.09),
        'HIGH': ContourClassRow(0.82, -8.18),
      },
      nrTddOffsetByMnc: const <String, double>{'default': 9.2},
      typicalPerReEirpDbmByTech: const <String, Map<String, double>>{
        'LTE': <String, double>{'LOW': 36.1, 'MID': 34.6, 'HIGH': 30.6},
        'NR': <String, double>{'LOW': 36.1, 'MID': 34.6, 'HIGH': 30.6},
      },
      gatePassed: true,
    );

    group('basePowerDbm', () {
      test('usable EIRP with no HRP maximum (the estimated-pattern path) uses perReEirpDbm', () {
        final int subcarriers = TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 20000000);
        final double expected = TransmitPower.perReEirpDbm(13489.6, subcarriers);
        final double actual = ContourPower.basePowerDbm(
            NetworkType.LTE, 1865.0, 20000000, 13489.6, null, coefficients);
        expect(actual, closeTo(expected, 1e-9));
      });

      test('usable EIRP with a maximum HRP power that does not look dB-scale still uses '
          'perReEirpDbm', () {
        final int subcarriers = TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 20000000);
        final double expected = TransmitPower.perReEirpDbm(13489.6, subcarriers);
        final double actual = ContourPower.basePowerDbm(
            NetworkType.LTE, 1865.0, 20000000, 13489.6, 40.0, coefficients);
        expect(actual, closeTo(expected, 1e-9));
      });

      test('EIRP <= 0 (zero) falls back to the table\'s typical value for the technology and '
          'band', () {
        final double actual =
            ContourPower.basePowerDbm(NetworkType.LTE, 1865.0, 20000000, 0.0, null, coefficients);
        expect(actual, coefficients.typicalPerReEirpDbm(NetworkType.LTE, 'MID'));
      });

      test('EIRP <= 0 (negative) falls back to the table\'s typical value for the technology '
          'and band', () {
        final double actual = ContourPower.basePowerDbm(
            NetworkType.LTE, 1865.0, 20000000, -5.0, null, coefficients);
        expect(actual, coefficients.typicalPerReEirpDbm(NetworkType.LTE, 'MID'));
      });

      test('a non-finite EIRP falls back to the typical value', () {
        final double actual = ContourPower.basePowerDbm(
            NetworkType.LTE, 1865.0, 20000000, double.nan, null, coefficients);
        expect(actual, coefficients.typicalPerReEirpDbm(NetworkType.LTE, 'MID'));
      });

      test('bandwidth <= 0 (unusable) falls back to the typical value', () {
        final double actual = ContourPower.basePowerDbm(
            NetworkType.LTE, 1865.0, 0.0, 13489.6, null, coefficients);
        expect(actual, coefficients.typicalPerReEirpDbm(NetworkType.LTE, 'MID'));
      });

      test('an EIRP that looks dB-scale -- only checked when a maximum HRP power is supplied '
          '-- falls back to the typical value', () {
        // 10*log10(10.0) + 30 == 40.0 exactly: reads back as the HRP maximum itself.
        final double actual = ContourPower.basePowerDbm(
            NetworkType.LTE, 1865.0, 20000000, 10.0, 40.0, coefficients);
        expect(actual, coefficients.typicalPerReEirpDbm(NetworkType.LTE, 'MID'));
      });

      test('the SAME dB-scale-shaped eirp is used as perReEirpDbm when no maximum is supplied, '
          'since the estimated-pattern path has no HRP maximum to check against', () {
        final int subcarriers = TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 20000000);
        final double expected = TransmitPower.perReEirpDbm(10.0, subcarriers);
        final double actual = ContourPower.basePowerDbm(
            NetworkType.LTE, 1865.0, 20000000, 10.0, null, coefficients);
        expect(actual, closeTo(expected, 1e-9));
      });

      test('picks the typical value for the frequency\'s own band', () {
        expect(ContourPower.basePowerDbm(NetworkType.LTE, 700.0, 0.0, 0.0, null, coefficients),
            coefficients.typicalPerReEirpDbm(NetworkType.LTE, 'LOW'));
        expect(ContourPower.basePowerDbm(NetworkType.LTE, 1865.0, 0.0, 0.0, null, coefficients),
            coefficients.typicalPerReEirpDbm(NetworkType.LTE, 'MID'));
        expect(ContourPower.basePowerDbm(NetworkType.LTE, 2650.0, 0.0, 0.0, null, coefficients),
            coefficients.typicalPerReEirpDbm(NetworkType.LTE, 'HIGH'));
      });

      test('picks the typical value for NR, not LTE, when the technology is NR', () {
        const ContourCoefficients distinctByTech = ContourCoefficients(
          classes: <String, ContourClassRow>{},
          pooled: <String, ContourClassRow>{'MID': ContourClassRow(0.82, -5.09)},
          nrTddOffsetByMnc: <String, double>{'default': 9.2},
          typicalPerReEirpDbmByTech: <String, Map<String, double>>{
            'LTE': <String, double>{'MID': 34.6},
            'NR': <String, double>{'MID': 20.0},
          },
          gatePassed: true,
        );
        final double actual =
            ContourPower.basePowerDbm(NetworkType.NR, 1865.0, 0.0, 0.0, null, distinctByTech);
        expect(actual, 20.0);
      });
    });

    group('maxPowerDbm', () {
      test('returns the maximum of a list of powers', () {
        expect(ContourPower.maxPowerDbm(const [-10.0, 5.0, -3.0, 5.0, -100.0]), 5.0);
      });

      test('a single-element iterable returns that element', () {
        expect(ContourPower.maxPowerDbm(const [-42.0]), -42.0);
      });

      test('throws on an empty iterable -- callers only call this with at least one row', () {
        expect(() => ContourPower.maxPowerDbm(const <double>[]), throwsStateError);
      });
    });

    group('relativePatternDb', () {
      test('is the plain difference when power is at or below the maximum', () {
        expect(ContourPower.relativePatternDb(-10.0, -5.0), closeTo(-5.0, 1e-9));
        expect(ContourPower.relativePatternDb(-5.0, -5.0), closeTo(0.0, 1e-9));
      });

      test('is never positive, even for a power passed in above the supplied maximum', () {
        expect(ContourPower.relativePatternDb(0.0, -5.0), 0.0);
      });
    });

    group('worked example regression pin (spec section 6)', () {
      test(
          'LTE, SUBURBAN, 1865 MHz, 20 MHz, 13,489.6 W, effective height 30 m, boresight: the '
          '-95 dBm distance matches the closed-form formula for the bundled SUBURBAN|MID row, '
          'and lies between 0.5 and 3 km', () {
        final String rawAssetText =
            File(ContourCoefficients.bundledAssetPath).readAsStringSync();
        final ContourCoefficients bundled = ContourCoefficients.parse(rawAssetText);

        const double freqMHz = 1865.0;
        const double bandwidthHz = 20000000;
        const double eirpW = 13489.6;
        const double effectiveHeightM = 30.0;
        const double rungDbm = -95.0;

        // Boresight: no pattern loss, and no HRP maximum is available or needed on this path.
        final double p = ContourPower.basePowerDbm(
            NetworkType.LTE, freqMHz, bandwidthHz, eirpW, null, bundled);

        final ContourClassRow row = bundled.forClass(CityDensity.SUBURBAN, 'MID');
        final double aUrban =
            AnalyticPathLossModel.hataInterceptDb(CityDensity.URBAN, freqMHz, effectiveHeightM);
        final double slope = AnalyticPathLossModel.hataSlopeDb(effectiveHeightM);
        final double expected = math
            .pow(10, (p - rungDbm - aUrban - row.offsetDb) / (row.k * slope))
            .toDouble();

        final double actual = ContourModel(bundled).distanceKm(
            NetworkType.LTE, 0, CityDensity.SUBURBAN, freqMHz, effectiveHeightM, p - rungDbm);

        expect(actual, closeTo(expected, 1e-6));
        expect(actual, inInclusiveRange(0.5, 3.0),
            reason: 'the Strong ring of a typical suburban LTE tower should now be several '
                'hundred metres to a few kilometres out, not the old few-hundred-metre radius');
      });
    });
  });
}
