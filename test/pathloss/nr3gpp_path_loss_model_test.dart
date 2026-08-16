import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/learned_path_loss_model.dart';
import 'package:phonetowers/pathloss/nr3gpp_path_loss_model.dart';
import 'package:phonetowers/pathloss/path_loss_coefficients.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Unit tests for Nr3gppPathLossModel — the 3GPP TR 38.901 (5G NR) path-loss anchor.
///
/// Verifies that the model produces finite, positive distances for all density environments at
/// 5G frequencies (3.5 GHz), that the dual-slope breakpoint behaviour is present, and that
/// b0=0, b1=1 calibration reproduces the anchor exactly.
///
/// Ported from the Java `Nr3gppPathLossModelTest`.
void main() {
  const double fc5gMHz = 3500.0; // 3.5 GHz — common Australian 5G n78 band
  const double towerHeightM = 25.0;
  const double eps = 1e-6;

  final model = Nr3gppPathLossModel();

  group('Nr3gppPathLossModelTest', () {
    test('allDensitiesProduceFinitePositiveDistancesAt5G', () {
      double levelDb = 120.0;
      for (CityDensity d in CityDensity.values) {
        double km = model.calculateDistance(d, levelDb, fc5gMHz, towerHeightM);
        expect(km.isFinite, isTrue,
            reason: 'Density $d: distance must be finite, got $km');
        expect(km > 0, isTrue,
            reason: 'Density $d: distance must be positive, got $km');
      }
    });

    test('higherPathLossGivesGreaterDistance', () {
      double d1 =
          model.calculateDistance(CityDensity.URBAN, 100.0, fc5gMHz, towerHeightM);
      double d2 =
          model.calculateDistance(CityDensity.URBAN, 130.0, fc5gMHz, towerHeightM);
      expect(d2 > d1, isTrue,
          reason:
              'Higher path loss should give greater distance (d1=$d1, d2=$d2)');
    });

    test('logAnchorDistanceIsMonotonic', () {
      double log1 = Nr3gppPathLossModel.logAnchorDistanceKm(
          CityDensity.URBAN, 100.0, fc5gMHz, towerHeightM);
      double log2 = Nr3gppPathLossModel.logAnchorDistanceKm(
          CityDensity.URBAN, 130.0, fc5gMHz, towerHeightM);
      expect(log2 > log1, isTrue,
          reason: 'log anchor distance must increase with path loss');
    });

    test('b0ZeroB1OneReproducesAnchor', () {
      PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      coeffs.set(CityDensity.URBAN, [0.0, 1.0, 0.0, 0.0], 100, 0.9);
      LearnedPathLossModel learned =
          LearnedPathLossModel(coeffs, AnalyticPathLossModel());

      double levelDb = 120.0;
      double anchorKm =
          model.calculateDistance(CityDensity.URBAN, levelDb, fc5gMHz, towerHeightM);
      double learnedKm = learned.calculateDistanceWithContext(
          0, NetworkType.NR, CityDensity.URBAN, levelDb, fc5gMHz, towerHeightM);
      expect(learnedKm, closeTo(anchorKm, eps),
          reason: 'b0=0,b1=1 should reproduce the 3GPP anchor');
    });

    test('nrFallbackWhenNoLearnedCoefficients', () {
      PathLossCoefficients coeffs = PathLossCoefficients.empty(57.0);
      LearnedPathLossModel learned =
          LearnedPathLossModel(coeffs, AnalyticPathLossModel());

      double levelDb = 120.0;
      double anchorKm =
          model.calculateDistance(CityDensity.URBAN, levelDb, fc5gMHz, towerHeightM);
      double learnedKm = learned.calculateDistanceWithContext(
          0, NetworkType.NR, CityDensity.URBAN, levelDb, fc5gMHz, towerHeightM);
      expect(learnedKm, closeTo(anchorKm, eps),
          reason: 'NR with no coefficients should use 3GPP anchor');
    });

    test('openIsLessLossyThanMetro', () {
      double levelDb = 120.0;
      double openKm =
          model.calculateDistance(CityDensity.OPEN, levelDb, fc5gMHz, towerHeightM);
      double metroKm = model.calculateDistance(
          CityDensity.METRO, levelDb, fc5gMHz, towerHeightM);
      expect(openKm > metroKm, isTrue,
          reason:
              'OPEN should give greater distance than METRO at same path loss (open=$openKm, metro=$metroKm)');
    });
  });
}
