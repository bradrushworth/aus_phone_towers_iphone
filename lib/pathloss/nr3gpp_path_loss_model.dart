import 'dart:math' as math;

import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/pathloss/path_loss_model.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// 3GPP TR 38.901 (5G NR) path-loss anchor — the NR equivalent of
/// [AnalyticPathLossModel]'s Hata decomposition. Used as the calibration anchor for 5G NR
/// observations and as the runtime model when no learned NR coefficients exist.
///
/// 3GPP TR 38.901 defines three outdoor scenarios that map to the app's [CityDensity] enum:
///   RMa  (Rural Macro)        -> OPEN / SUBURBAN
///   UMa  (Urban Macro)        -> URBAN / METRO
///   UMi-StreetCanyon          -> METRO
///
/// The key structural difference from Hata is the dual-slope (breakpoint) model: real
/// propagation has a breakpoint distance d_BP = 4 * h'_BS * h'_UT * fc / c where the slope
/// changes from ~20 dB/decade to ~40 dB/decade. Hata is single-slope and cannot represent
/// this kink — which is why fitting Hata on 5G data produces NaN.
///
/// Ported from the Java `au.com.bitbot.phonetowers.pathloss.Nr3gppPathLossModel`.
class Nr3gppPathLossModel implements PathLossModel {
  static const double _c = 2.99792458e8; // speed of light (m/s)
  static const double _hUt = 1.5; // default UE antenna height above ground [m]
  static const double _hEff = 1.0; // effective antenna height correction constant
  static const double _maxDistanceKm = 5.0; // model validity limit

  @override
  double calculateDistance(
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    double hBs = math.max(height, 10.0);
    double fcGHz = freqInMHz / 1000.0;
    if (fcGHz < 0.5 || fcGHz > 100.0) {
      fcGHz = _clamp(freqInMHz / 1000.0, 0.5, 100.0);
    }
    return _solveDistance(density, levelInDb, fcGHz, hBs);
  }

  @override
  double calculateDistanceWithContext(int mnc, NetworkType networkType,
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    return calculateDistance(density, levelInDb, freqInMHz, height);
  }

  /// The model's own log10(distanceKm) estimate for one observation — the anchor for calibration.
  static double logAnchorDistanceKm(
      CityDensity density, double levelInDb, double freqMHz, double height) {
    double hBs = math.max(height, 10.0);
    double fcGHz = _clamp(freqMHz / 1000.0, 0.5, 100.0);
    double dKm = _solveDistance(density, levelInDb, fcGHz, hBs);
    return (dKm.isFinite && dKm > 0) ? log10(dKm) : double.nan;
  }

  /// Solves the (piecewise) 3GPP path-loss formula for distance given a measured path loss in dB.
  /// Uses bisection on the monotonic PL(d) function.
  static double _solveDistance(
      CityDensity density, double levelInDb, double fcGHz, double hBs) {
    if (!levelInDb.isFinite || levelInDb <= 0) return double.nan;

    double lo = 0.01; // 10 m
    double hi = _maxDistanceKm; // 5 km
    double plLo = _pathLossDb(density, lo, fcGHz, hBs);
    double plHi = _pathLossDb(density, hi, fcGHz, hBs);
    if (levelInDb <= plLo) return lo;
    if (levelInDb >= plHi) return hi;

    for (int i = 0; i < 60; i++) {
      double mid = (lo + hi) / 2.0;
      double plMid = _pathLossDb(density, mid, fcGHz, hBs);
      if (plMid < levelInDb) {
        lo = mid;
      } else {
        hi = mid;
      }
      if (hi - lo < 1e-6) break;
    }
    return (lo + hi) / 2.0;
  }

  static double _pathLossDb(
      CityDensity density, double distanceKm, double fcGHz, double hBs) {
    double d3d = distanceKm * 1000.0; // m
    double fcHz = fcGHz * 1e9;
    double hEffBs = math.max(hBs - _hEff, 1.0);
    double hEffUt = math.max(_hUt - _hEff, 1.0);
    double dBp = 4.0 * hEffBs * hEffUt * fcHz / _c;

    switch (density) {
      case CityDensity.OPEN:
        return _rmaLosPathLoss(d3d, fcGHz, hBs, dBp);
      case CityDensity.SUBURBAN:
        return _rmaPathLoss(d3d, fcGHz, hBs, dBp);
      case CityDensity.URBAN:
        return _umaPathLoss(d3d, fcGHz, hBs, dBp);
      case CityDensity.METRO:
        return _umiPathLoss(d3d, fcGHz, hBs, dBp);
      case CityDensity.MEDIUM:
        return _umaPathLoss(d3d, fcGHz, hBs, dBp);
    }
  }

  /// RMa (Rural Macro) — TR 38.901 §7.4.1. Default street width W=20m, avg building height h=5m.
  static double _rmaPathLoss(double d3dM, double fcGHz, double hBs, double dBp) {
    const double w = 20.0;
    const double h = 5.0;
    double plLos;
    if (d3dM <= dBp) {
      plLos = 20 * _log10(d3dM) + 20 * _log10(fcGHz) + 32.4;
    } else {
      plLos = 40 * _log10(d3dM) +
          20 * _log10(fcGHz) -
          9.5 * _log10(math.pow(dBp, 2) + math.pow(hBs - _hUt, 2));
    }
    double plNlos = 161.04 -
        7.1 * _log10(w) +
        7.5 * _log10(h) -
        24.37 -
        3.2 * math.pow(_log10(h), 2).toDouble() +
        44.9 * _log10(d3dM) -
        (1.5 * h - 0.8) * _log10(h) * _log10(d3dM) -
        3.0 +
        20 * _log10(fcGHz);
    return math.max(plLos, plNlos);
  }

  /// RMa LOS-only path loss — for truly open areas (no buildings to create NLOS).
  static double _rmaLosPathLoss(double d3dM, double fcGHz, double hBs, double dBp) {
    if (d3dM <= dBp) {
      return 20 * _log10(d3dM) + 20 * _log10(fcGHz) + 32.4;
    }
    return 40 * _log10(d3dM) +
        20 * _log10(fcGHz) -
        9.5 * _log10(math.pow(dBp, 2) + math.pow(hBs - _hUt, 2));
  }

  /// UMa (Urban Macro) — TR 38.901 §7.4.1.
  static double _umaPathLoss(double d3dM, double fcGHz, double hBs, double dBp) {
    double plLos;
    if (d3dM <= dBp) {
      plLos = 28.0 + 22.0 * _log10(d3dM) + 20.0 * _log10(fcGHz);
    } else {
      plLos = 28.0 +
          40.0 * _log10(d3dM) +
          20.0 * _log10(fcGHz) -
          9.0 * _log10(math.pow(dBp, 2) + math.pow(hBs - _hUt, 2));
    }
    double plNlos =
        13.54 + 39.08 * _log10(d3dM) + 20.0 * _log10(fcGHz) - 0.6 * (_hUt - 1.5);
    return math.max(plLos, plNlos);
  }

  /// UMi-StreetCanyon — TR 38.901 §7.4.1.
  static double _umiPathLoss(double d3dM, double fcGHz, double hBs, double dBp) {
    double plLos;
    if (d3dM <= dBp) {
      plLos = 32.4 + 21.0 * _log10(d3dM) + 20.0 * _log10(fcGHz);
    } else {
      plLos = 32.4 +
          40.0 * _log10(d3dM) +
          20.0 * _log10(fcGHz) -
          9.5 * _log10(math.pow(dBp, 2) + math.pow(hBs - _hUt, 2));
    }
    double plNlos = 32.4 +
        35.8 * _log10(d3dM) +
        20.0 * _log10(fcGHz) +
        0.7 * (_hUt - 1.5) -
        5.5 * _log10(math.max(hBs, 10.0));
    return math.max(plLos, plNlos);
  }

  static double _log10(num x) => log10(math.max(x, 1e-10));

  static double _clamp(double v, double lo, double hi) =>
      math.max(lo, math.min(hi, v));
}
