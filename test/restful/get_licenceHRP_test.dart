import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/nr3gpp_path_loss_model.dart';
import 'package:phonetowers/pathloss/path_loss_coefficients.dart';
import 'package:phonetowers/pathloss/path_loss_model_provider.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

void main() {
  group('GetLicenceHRP.hrpDistanceKm', () {
    // Regression tests for the licence_hrp polygon loop drawing REAL coverage patterns
    // several times too large: it used the density-only calculateDistance overload, but
    // since the 2026-08-22 trainer re-baseline the server publishes ONLY composite
    // (density|mnc|networkType|band) coefficient groups. The density-only lookup found
    // nothing and silently fell back to raw analytic Okumura-Hata (3.8x too far for a
    // 778 MHz LTE cell, 12x+ for 3.5 GHz NR, measured against the trained calibration).
    // The loop must use the SAME composite lookup as PolygonHelper.createBasicPolygon
    // and the connected-tower mapping path.
    tearDown(() {
      // Restore the untrained default so other tests see the analytic fallback.
      PathLossModelProvider()
          .overrideCoefficientsForTesting(PathLossCoefficients.empty());
    });

    test('applies composite calibration when only composite groups exist (server shape)',
        () {
      const double b0 = -0.35828640617403174; // URBAN|1|LTE|LOW, live server 2026-08-23
      const double b1 = 0.824930925974219;
      final PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      coeffs.setComposite(1, NetworkType.LTE, 'LOW', CityDensity.URBAN,
          [b0, b1, 0.0, 0.0], 34579, 0.19);
      PathLossModelProvider().overrideCoefficientsForTesting(coeffs);

      const double level = 170.0, freq = 778.0, height = 30.0;
      final double logAnchor =
          (level - AnalyticPathLossModel.hataInterceptDb(CityDensity.URBAN, freq, height)) /
              AnalyticPathLossModel.hataSlopeDb(height);
      final double calibrated = math.pow(10.0, b0 + b1 * logAnchor).toDouble();

      final double actual = GetLicenceHRP.hrpDistanceKm(
          1, NetworkType.LTE, CityDensity.URBAN, level, freq, height);

      expect(actual, closeTo(calibrated, 1e-9),
          reason: 'HRP polygons must use the trained composite calibration');

      // And it must NOT be the raw analytic fallback (~3.8x larger here).
      final double analytic = AnalyticPathLossModel()
          .calculateDistance(CityDensity.URBAN, level, freq, height);
      expect(actual, lessThan(analytic / 3),
          reason: 'density-only lookup would silently fall back to analytic Hata');
    });

    test('routes NR to the 3GPP 38.901 anchor when no NR coefficients are trained', () {
      // Server-shaped coefficients: trained, but no NR groups at all.
      final PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      coeffs.setComposite(1, NetworkType.LTE, 'LOW', CityDensity.URBAN,
          [-0.36, 0.82, 0.0, 0.0], 1000, 0.19);
      PathLossModelProvider().overrideCoefficientsForTesting(coeffs);

      const double level = 165.0, freq = 3595.0, height = 30.0;
      final double expected = Nr3gppPathLossModel()
          .calculateDistance(CityDensity.URBAN, level, freq, height);
      final double actual = GetLicenceHRP.hrpDistanceKm(
          1, NetworkType.NR, CityDensity.URBAN, level, freq, height);
      expect(actual, closeTo(expected, 1e-9),
          reason: 'NR must anchor on 3GPP 38.901, not sub-3GHz Hata');
    });
  });

  group('GetLicenceHRP.rowStepForBearingIncrement', () {
    // Regression test: the Polygon Precision menu previously had no effect on real
    // (non-estimated) coverage, because the server-row sampling loop hardcoded a step
    // of 2 regardless of PolygonHelper.polygonBearingIncrement. This pins the mapping
    // from each precision preset to its resulting row step.
    test('medium (default) preset preserves the original hardcoded step of 2', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionMedium),
        2,
      );
    });

    test('low preset samples fewer rows (coarser, faster)', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionLow),
        4,
      );
    });

    test('high preset samples every row (finer, smoother)', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionHigh),
        1,
      );
    });

    test('never returns a step below 1, even for a very small increment', () {
      expect(GetLicenceHRP.rowStepForBearingIncrement(0.01), 1);
    });

    test('scales monotonically with the bearing increment', () {
      final int lowStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionLow);
      final int mediumStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionMedium);
      final int highStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionHigh);
      expect(highStep, lessThan(mediumStep));
      expect(mediumStep, lessThan(lowStep));
    });
  });
}
