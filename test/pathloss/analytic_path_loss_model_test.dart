import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Pins the exact numeric outputs of the legacy Okumura-Hata / COST-231-Hata formulas
/// (moved verbatim from GetLicenceHRP into AnalyticPathLossModel). These are the same
/// assertions previously held by GetLicenceHRPTest, kept here so the reference
/// implementation can never silently drift.
///
/// Ported from the Java `AnalyticPathLossModelTest`.
void main() {
  final model = AnalyticPathLossModel();

  group('AnalyticPathLossModelTest', () {
    test('metro', () {
      expect(model.calculateDistance(CityDensity.METRO, 127.0, 1865.0, 30.0),
          closeTo(0.39611, 1e-3));
      expect(model.calculateDistance(CityDensity.METRO, 137.0, 1865.0, 30.0),
          closeTo(0.76157, 1e-3));
      expect(model.calculateDistance(CityDensity.METRO, 147.0, 1865.0, 30.0),
          closeTo(1.46420, 1e-3));
      expect(model.calculateDistance(CityDensity.METRO, 127.0, 2680.0, 30.0),
          closeTo(0.27811, 1e-3));
      expect(model.calculateDistance(CityDensity.METRO, 127.0, 763.0, 30.0),
          closeTo(0.94720, 1e-3));
      expect(model.calculateDistance(CityDensity.METRO, 127.0, 1865.0, 3.0),
          closeTo(0.21382, 1e-3));
      expect(model.calculateDistance(CityDensity.METRO, 127.0, 1865.0, 60.0),
          closeTo(0.50012, 1e-3));
    });

    test('urban', () {
      expect(model.calculateDistance(CityDensity.URBAN, 127.0, 1865.0, 30.0),
          closeTo(0.55519, 1e-3));
      expect(model.calculateDistance(CityDensity.URBAN, 137.0, 1865.0, 30.0),
          closeTo(1.06742, 1e-3));
      expect(model.calculateDistance(CityDensity.URBAN, 147.0, 1865.0, 30.0),
          closeTo(2.05223, 1e-3));
      expect(model.calculateDistance(CityDensity.URBAN, 127.0, 2680.0, 30.0),
          closeTo(0.42414, 1e-3));
      expect(model.calculateDistance(CityDensity.URBAN, 127.0, 763.0, 30.0),
          closeTo(1.07823, 1e-3));
      expect(model.calculateDistance(CityDensity.URBAN, 127.0, 1865.0, 3.0),
          closeTo(0.28424, 1e-3));
      expect(model.calculateDistance(CityDensity.URBAN, 127.0, 1865.0, 60.0),
          closeTo(0.71515, 1e-3));
    });

    test('suburban', () {
      expect(model.calculateDistance(CityDensity.SUBURBAN, 127.0, 1865.0, 30.0),
          closeTo(0.99565, 1e-3));
      expect(model.calculateDistance(CityDensity.SUBURBAN, 137.0, 1865.0, 30.0),
          closeTo(1.91424, 1e-3));
      expect(model.calculateDistance(CityDensity.SUBURBAN, 147.0, 1865.0, 30.0),
          closeTo(3.68033, 1e-3));
      expect(model.calculateDistance(CityDensity.SUBURBAN, 127.0, 2680.0, 30.0),
          closeTo(0.82258, 1e-3));
      expect(model.calculateDistance(CityDensity.SUBURBAN, 127.0, 763.0, 30.0),
          closeTo(1.63880, 1e-3));
      expect(model.calculateDistance(CityDensity.SUBURBAN, 127.0, 1865.0, 3.0),
          closeTo(0.46513, 1e-3));
      expect(model.calculateDistance(CityDensity.SUBURBAN, 127.0, 1865.0, 60.0),
          closeTo(1.32770, 1e-3));
    });

    test('open', () {
      expect(model.calculateDistance(CityDensity.OPEN, 127.0, 1865.0, 30.0),
          closeTo(2.76969, 1e-3));
      expect(model.calculateDistance(CityDensity.OPEN, 137.0, 1865.0, 30.0),
          closeTo(5.32503, 1e-3));
      expect(model.calculateDistance(CityDensity.OPEN, 147.0, 1865.0, 30.0),
          closeTo(10.2379, 1e-3));
      expect(model.calculateDistance(CityDensity.OPEN, 127.0, 2680.0, 30.0),
          closeTo(2.43608, 1e-3));
      expect(model.calculateDistance(CityDensity.OPEN, 127.0, 763.0, 30.0),
          closeTo(4.06048, 1e-3));
      expect(model.calculateDistance(CityDensity.OPEN, 127.0, 1865.0, 3.0),
          closeTo(1.10215, 1e-3));
      expect(model.calculateDistance(CityDensity.OPEN, 127.0, 1865.0, 60.0),
          closeTo(3.92440, 1e-3));
    });

    /// The intercept/slope decomposition exposed for the Hata-anchored trained model must reproduce
    /// calculateDistance exactly for every density, frequency and height. If this drifts, a trained
    /// hata-correction asset would silently be anchored to a different model than the analytic
    /// fallback it is meant to generalise.
    test('interceptAndSlopeReproduceCalculateDistance', () {
      List<double> levels = [110.0, 127.0, 150.0];
      List<double> freqs = [200.0, 700.0, 1865.0, 2680.0, 3500.0];
      List<double> heights = [3.0, 15.0, 30.0, 60.0];
      for (CityDensity d in CityDensity.values) {
        for (double level in levels) {
          for (double f in freqs) {
            for (double h in heights) {
              double expected = model.calculateDistance(d, level, f, h);
              double intercept = AnalyticPathLossModel.hataInterceptDb(d, f, h);
              double slope = AnalyticPathLossModel.hataSlopeDb(h);
              double actual =
                  math.pow(10, (level - intercept) / slope).toDouble();
              expect(
                  actual,
                  closeTo(
                      expected, math.max(1e-9, expected.abs() * 1e-9)),
                  reason: '$d level=$level f=$f h=$h');
            }
          }
        }
      }
    });
  });
}
