import 'dart:math' as math;

import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/pathloss/path_loss_model.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// The legacy Okumura-Hata / COST-231-Hata analytic path-loss model, extracted verbatim from
/// the original inline [GetLicenceHRP.calculateDistance] so it can be kept as a reference
/// implementation and as the per-density fallback used by [LearnedPathLossModel] until real-world
/// coefficients are trained.
///
/// Ported from the Java `au.com.bitbot.phonetowers.pathloss.AnalyticPathLossModel`.
class AnalyticPathLossModel implements PathLossModel {
  /// Mobile station antenna height above local terrain [m] — matches the original constant.
  static const double heightReceiverFromGround = 1;

  @override
  double calculateDistance(
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    double hb = height;
    double hm = heightReceiverFromGround;
    double fc = freqInMHz;

    double a = 69.55 + 26.16 * log10(fc) - 13.82 * log10(hb);
    double b = 44.9 - 6.55 * log10(hb);

    if (density == CityDensity.METRO) {
      double e = (1.1 * log10(fc) - 0.7) * hm - (1.56 * log10(fc) - 0.8);
      double f = 46.3 + 33.9 * log10(fc) - 13.82 * log10(hb);
      double g = 3;
      return math.pow(10, (levelInDb + e - f - g) / b).toDouble();
    } else if (density == CityDensity.URBAN && freqInMHz >= 300) {
      double e = 3.2 * math.pow(log10(11.7554 * hm), 2) - 4.97;
      return math.pow(10, (levelInDb + e - a) / b).toDouble();
    } else if (density == CityDensity.URBAN) {
      double e = 8.29 * math.pow(log10(1.54 * hm), 2) - 1.1;
      return math.pow(10, (levelInDb + e - a) / b).toDouble();
    } else if (density == CityDensity.MEDIUM) {
      double e = (1.1 * log10(fc) - 0.7) * hm - (1.56 * log10(fc) - 0.8);
      return math.pow(10, (levelInDb + e - a) / b).toDouble();
    } else if (density == CityDensity.SUBURBAN) {
      double c = 2 * math.pow(log10(fc / 28), 2) + 5.4;
      c -= 4.42;
      return math.pow(10, (levelInDb + c - a) / b).toDouble();
    } else if (density == CityDensity.OPEN) {
      double d = 4.78 * math.pow(log10(fc), 2) - 18.33 * log10(fc) + 40.94;
      d -= 4.42 * 2;
      return math.pow(10, (levelInDb + d - a) / b).toDouble();
    } else {
      return 0;
    }
  }

  /// The Hata/COST-231 path-loss intercept for this environment, i.e. the modelled path loss
  /// (dB) at distance = 1 km. Exposing the anchor lets a trained model learn a small correction
  /// to Hata instead of re-learning the whole frequency/height dependence from noisy data.
  static double hataInterceptDb(
      CityDensity density, double freqInMHz, double height) {
    double hb = height;
    double hm = heightReceiverFromGround;
    double fc = freqInMHz;

    double a = 69.55 + 26.16 * log10(fc) - 13.82 * log10(hb);

    if (density == CityDensity.METRO) {
      double e = (1.1 * log10(fc) - 0.7) * hm - (1.56 * log10(fc) - 0.8);
      double f = 46.3 + 33.9 * log10(fc) - 13.82 * log10(hb);
      double g = 3;
      return f + g - e;
    } else if (density == CityDensity.URBAN && freqInMHz >= 300) {
      double e = 3.2 * math.pow(log10(11.7554 * hm), 2) - 4.97;
      return a - e;
    } else if (density == CityDensity.URBAN) {
      double e = 8.29 * math.pow(log10(1.54 * hm), 2) - 1.1;
      return a - e;
    } else if (density == CityDensity.MEDIUM) {
      double e = (1.1 * log10(fc) - 0.7) * hm - (1.56 * log10(fc) - 0.8);
      return a - e;
    } else if (density == CityDensity.SUBURBAN) {
      double c = 2 * math.pow(log10(fc / 28), 2) + 5.4;
      c -= 4.42;
      return a - c;
    } else if (density == CityDensity.OPEN) {
      double d = 4.78 * math.pow(log10(fc), 2) - 18.33 * log10(fc) + 40.94;
      d -= 4.42 * 2;
      return a - d;
    }
    return double.nan;
  }

  /// The Hata distance slope B = 44.9 - 6.55·log10(height) (dB per decade of km).
  static double hataSlopeDb(double height) {
    return 44.9 - 6.55 * log10(height);
  }

  @override
  double calculateDistanceWithContext(int mnc, NetworkType networkType,
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    return calculateDistance(density, levelInDb, freqInMHz, height);
  }
}
