import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/learned_path_loss_model.dart';
import 'package:phonetowers/pathloss/path_loss_coefficients.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Checks the learned model: it must fall back to the analytic Hata/COST-231 formulas when a density
/// has no trained coefficients, and must exactly invert its own forward equation once trained.
///
/// Ported from the Java `LearnedPathLossModelTest`.
void main() {
  group('LearnedPathLossModelTest', () {
    test('fallsBackToAnalyticWhenUntrained', () {
      PathLossCoefficients empty = PathLossCoefficients.empty(57.0);
      LearnedPathLossModel learned = LearnedPathLossModel(empty);
      AnalyticPathLossModel analytic = AnalyticPathLossModel();
      for (CityDensity d in CityDensity.values) {
        double a = analytic.calculateDistance(d, 127.0, 1865.0, 30.0);
        double l = learned.calculateDistance(d, 127.0, 1865.0, 30.0);
        expect(l, closeTo(a, 1e-9), reason: 'density $d');
      }
    });

    test('invertsTrainedCoefficients', () {
      PathLossCoefficients coeffs = PathLossCoefficients.empty(57.0);
      coeffs.set(CityDensity.URBAN, [100.0, 40.0, 0.0, 0.0], 1000, 0.95);
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);

      double levelFor2km = 100 + 40 * log10(2.0);
      expect(learned.calculateDistance(CityDensity.URBAN, levelFor2km, 1865.0, 30.0),
          closeTo(2.0, 1e-6));

      double levelFor10km = 100 + 40 * log10(10.0);
      expect(learned.calculateDistance(CityDensity.URBAN, levelFor10km, 1865.0, 30.0),
          closeTo(10.0, 1e-6));
    });

    test('invertsTrainedCoefficientsWithFreqAndHeight', () {
      PathLossCoefficients coeffs = PathLossCoefficients.empty(57.0);
      coeffs.set(CityDensity.OPEN, [50.0, 35.0, 12.0, 8.0], 500, 0.9);
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);

      double f = 900.0, h = 45.0, d = 5.0;
      double level = 50 + 35 * log10(d) + 12 * log10(f) + 8 * log10(h);
      expect(learned.calculateDistance(CityDensity.OPEN, level, f, h),
          closeTo(d, 1e-6));
    });

    /// The Hata-anchored form must reduce EXACTLY to the analytic model at the identity correction
    /// (b0 = 0, b1 = 1). This is what makes the new formulation a strict generalisation of Hata rather
    /// than a gamble: the worst a trained correction can do is drift away from a model we already ship.
    test('hataCorrectionWithIdentityCoefficientsMatchesAnalytic', () {
      PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCorrection);
      AnalyticPathLossModel analytic = AnalyticPathLossModel();
      for (CityDensity d in CityDensity.values) {
        coeffs.set(d, [0.0, 1.0, 0.0, 0.0], 1000, 0.5);
      }
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);
      for (CityDensity d in CityDensity.values) {
        for (double f in [700.0, 1865.0, 3500.0]) {
          for (double h in [15.0, 30.0, 60.0]) {
            double a = analytic.calculateDistance(d, 127.0, f, h);
            double l = learned.calculateDistance(d, 127.0, f, h);
            expect(l, closeTo(a, 1e-9), reason: '$d f=$f h=$h');
          }
        }
      }
    });

    /// A learned correction must invert its own forward equation.
    test('hataCorrectionInvertsItsOwnForwardEquation', () {
      PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCorrection);
      double b0 = -6.5, b1 = 1.2;
      coeffs.set(CityDensity.SUBURBAN, [b0, b1, 0.0, 0.0], 5000, 0.2);
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);

      double f = 1865.0, h = 30.0, d = 7.5;
      double level = AnalyticPathLossModel.hataInterceptDb(CityDensity.SUBURBAN, f, h) +
          b0 +
          b1 * AnalyticPathLossModel.hataSlopeDb(h) * log10(d);
      expect(learned.calculateDistance(CityDensity.SUBURBAN, level, f, h),
          closeTo(d, 1e-6));
    });

    /// The calibration form must also reduce EXACTLY to the analytic model at b0=0, b1=1 — this is the
    /// property that makes the shipped hata-calibration asset a safe generalisation of Hata.
    test('hataCalibrationWithIdentityCoefficientsMatchesAnalytic', () {
      PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      AnalyticPathLossModel analytic = AnalyticPathLossModel();
      for (CityDensity d in CityDensity.values) {
        coeffs.set(d, [0.0, 1.0, 0.0, 0.0], 1000, 0.1);
      }
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);
      for (CityDensity d in CityDensity.values) {
        for (double f in [700.0, 1865.0, 3500.0]) {
          for (double h in [15.0, 30.0, 60.0]) {
            expect(
                learned.calculateDistance(d, 127.0, f, h),
                closeTo(analytic.calculateDistance(d, 127.0, f, h), 1e-9),
                reason: '$d f=$f h=$h');
          }
        }
      }
    });

    /// The calibration form must apply the learned rescaling in log-distance space, and — crucially —
    /// must stay bounded. The live-trained OPEN gain of 0.145 with the legacy inverted forward fit
    /// produced 1e16 km; here a very weak signal must still yield a sane, finite distance.
    test('hataCalibrationRescalesInLogSpaceAndStaysBounded', () {
      PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      double b0 = 0.825, b1 = 0.145; // live-trained OPEN coefficients
      coeffs.set(CityDensity.OPEN, [b0, b1, 0.0, 0.0], 153772, 0.014);
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);
      AnalyticPathLossModel analytic = AnalyticPathLossModel();

      double f = 1865.0, h = 30.0;
      for (double level in [100.0, 127.0, 160.0, 200.0]) {
        double expected = math.pow(
            10, b0 + b1 * log10(analytic.calculateDistance(CityDensity.OPEN, level, f, h))).toDouble();
        double actual = learned.calculateDistance(CityDensity.OPEN, level, f, h);
        expect(actual, closeTo(expected, 1e-6), reason: 'level=$level');
        expect(actual < 1000.0, isTrue,
            reason: 'level=$level must stay bounded, was $actual');
      }
    });

    /// A positive gain must keep the model monotonic: weaker signal ⇒ farther, which tower ranking relies on.
    test('hataCalibrationIsMonotonicInSignal', () {
      PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      coeffs.set(CityDensity.SUBURBAN, [-0.106, 0.382, 0.0, 0.0], 38693, 0.107);
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);
      double previous = 0;
      for (double level = 100.0; level <= 170.0; level += 5.0) {
        double d = learned.calculateDistance(CityDensity.SUBURBAN, level, 1865.0, 30.0);
        expect(d > previous, isTrue,
            reason: 'distance must increase with path loss at level=$level');
        previous = d;
      }
    });

    /// The form flag must survive a JSON round trip, or a trained asset would be inverted wrongly.
    test('formSurvivesJsonRoundTrip', () {
      PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCorrection);
      coeffs.set(CityDensity.OPEN, [-3.0, 1.1, 0.0, 0.0], 900, 0.15);
      String json = jsonEncode(coeffs.toJson());
      PathLossCoefficients parsed =
          PathLossCoefficients.fromJson(jsonDecode(json));
      expect(parsed.form, PathLossCoefficients.formHataCorrection);
      expect(parsed.isHataCorrectionForm, isTrue);
      expect(parsed.get(CityDensity.OPEN)![1], closeTo(1.1, 1e-9));
    });

    /// Assets written before the form field existed must keep the legacy log-distance behaviour.
    test('legacyAssetWithoutFormDefaultsToLogDistance', () {
      String json = '{"trained":true,"referencePowerDbm":57,"coefficients":'
          '{"URBAN":{"b0":100.0,"b1":40.0,"b2":0.0,"b3":0.0,"sampleCount":10,"rSquared":0.5}}}';
      PathLossCoefficients parsed =
          PathLossCoefficients.fromJson(jsonDecode(json));
      expect(parsed.form, PathLossCoefficients.formLogDistance);
      LearnedPathLossModel learned = LearnedPathLossModel(parsed);
      expect(
          learned.calculateDistance(
              CityDensity.URBAN, 100 + 40 * log10(2.0), 1865.0, 30.0),
          closeTo(2.0, 1e-6));
    });

    /// Pins the exact gap the coverage-polygon estimate fix closed. The on-device "estimated polygon"
    /// (PolygonHelper.createBasicPolygon) is drawn for transmitters that have no real antenna pattern.
    /// Before the fix it called the density-only calculateDistance overload, which for SUBURBAN/METRO
    /// (which have no trained density-only group) silently fell back to analytic Hata. The fix routes
    /// it through the composite calculateDistanceWithContext overload used by the tower-mapping path.
    test('compositeOverloadUsesTrainedSuburbanLteWhenDensityOnlyAbsent', () {
      PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      coeffs.setComposite(1, NetworkType.LTE, 'MID', CityDensity.SUBURBAN,
          [-0.3108574332021878, 0.38223136074523323, 0.0, 0.0], 13724, 0.1059);
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);
      AnalyticPathLossModel analytic = AnalyticPathLossModel();

      double f = 1800.0, h = 30.0, level = 127.0;
      double trained = learned.calculateDistanceWithContext(
          1, NetworkType.LTE, CityDensity.SUBURBAN, level, f, h);
      double analyticOnly = analytic.calculateDistance(CityDensity.SUBURBAN, level, f, h);

      expect(trained > 0 && trained.isFinite, isTrue,
          reason: 'trained distance must be finite and positive');
      expect((trained - analyticOnly).abs() > 1e-6, isTrue,
          reason:
              'composite overload must apply the trained group, not fall back to analytic Hata');

      double oldPath = learned.calculateDistance(CityDensity.SUBURBAN, level, f, h);
      expect(oldPath, closeTo(analyticOnly, 1e-9),
          reason:
              'density-only overload falls back to analytic when no density-only group exists');
    });

    test('roundTripsThroughJson', () {
      PathLossCoefficients coeffs = PathLossCoefficients.empty(57.0);
      coeffs.set(CityDensity.SUBURBAN, [80.0, 38.0, 10.0, 6.0], 250, 0.88);
      String json = jsonEncode(coeffs.toJson());
      PathLossCoefficients parsed =
          PathLossCoefficients.fromJson(jsonDecode(json));
      expect(parsed.isTrainedFor(CityDensity.SUBURBAN), isTrue);
      List<double> b = parsed.get(CityDensity.SUBURBAN)!;
      expect(b[0], closeTo(80.0, 1e-9));
      expect(b[1], closeTo(38.0, 1e-9));
      expect(b[2], closeTo(10.0, 1e-9));
      expect(b[3], closeTo(6.0, 1e-9));
    });

    // ---------------------------------------------------------------------------------
    // Nearest-density fallback.
    //
    // The published table is sparse and lopsided by MNC — at the time of writing the
    // density-only safety net has exactly one row (URBAN). A carrier whose density missed
    // dropped straight to raw analytic Okumura-Hata, which get_licenceHRP itself warns is
    // "several times too large". That is what made two co-located towers at site 50917
    // differ by ~6x in radius: Optus has 31 sites in the geohash so resolved to URBAN and
    // stayed calibrated, while Vodafone's 14 resolved to SUBURBAN and fell through.
    // ---------------------------------------------------------------------------------

    test('borrowsNearestCalibratedDensityInsteadOfDroppingToAnalytic', () {
      // Only URBAN is published, mirroring the real table's single density-only row.
      PathLossCoefficients coeffs = PathLossCoefficients.empty(57.0);
      coeffs.set(CityDensity.URBAN, [100.0, 40.0, 0.0, 0.0], 1000, 0.95);
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);
      AnalyticPathLossModel analytic = AnalyticPathLossModel();

      double level = 100 + 40 * log10(2.0);

      // The Vodafone case: SUBURBAN, MNC 3, no group of its own.
      double suburban = learned.calculateDistanceWithContext(
          3, NetworkType.LTE, CityDensity.SUBURBAN, level, 1865.0, 30.0);
      // The Optus case: URBAN, calibrated.
      double urban = learned.calculateDistanceWithContext(
          2, NetworkType.LTE, CityDensity.URBAN, level, 1865.0, 30.0);

      expect(suburban, closeTo(urban, 1e-9),
          reason: 'a missing density must borrow the nearest calibrated one');

      double raw =
          analytic.calculateDistance(CityDensity.SUBURBAN, level, 1865.0, 30.0);
      expect((suburban - raw).abs(), greaterThan(1e-6),
          reason: 'must no longer fall through to the uncalibrated analytic model');
    });

    test('prefersTheClosestDensityOnTheScale', () {
      // MEDIUM is one step from SUBURBAN, METRO is three. SUBURBAN must take MEDIUM.
      PathLossCoefficients coeffs = PathLossCoefficients.empty(57.0);
      coeffs.set(CityDensity.MEDIUM, [100.0, 40.0, 0.0, 0.0], 1000, 0.95);
      coeffs.set(CityDensity.METRO, [200.0, 80.0, 0.0, 0.0], 1000, 0.95);
      LearnedPathLossModel learned = LearnedPathLossModel(coeffs);

      double level = 100 + 40 * log10(3.0);
      double got = learned.calculateDistanceWithContext(
          3, NetworkType.LTE, CityDensity.SUBURBAN, level, 1865.0, 30.0);

      expect(got, closeTo(3.0, 1e-6),
          reason: 'should invert MEDIUM (nearest), not METRO');
    });

    test('stillFallsBackToAnalyticWhenNothingIsCalibrated', () {
      // With nothing published at all the previous behaviour must be unchanged.
      PathLossCoefficients empty = PathLossCoefficients.empty(57.0);
      LearnedPathLossModel learned = LearnedPathLossModel(empty);
      AnalyticPathLossModel analytic = AnalyticPathLossModel();

      double got = learned.calculateDistanceWithContext(
          3, NetworkType.LTE, CityDensity.SUBURBAN, 127.0, 1865.0, 30.0);
      expect(
          got,
          closeTo(
              analytic.calculateDistance(
                  CityDensity.SUBURBAN, 127.0, 1865.0, 30.0),
              1e-9));
    });
  });
}
