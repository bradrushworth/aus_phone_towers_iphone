import 'dart:math' as math;

import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/nr3gpp_path_loss_model.dart';
import 'package:phonetowers/pathloss/path_loss_coefficients.dart';
import 'package:phonetowers/pathloss/path_loss_key.dart';
import 'package:phonetowers/pathloss/path_loss_model.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Path-loss model whose constants are learned from real observations.
///
/// Two functional forms are supported, selected by [PathLossCoefficients.form]:
/// - log-distance (legacy): levelInDb = b0 + b1·log10(d) + b2·log10(f) + b3·log10(h)
/// - hata-correction: levelInDb = hataIntercept + b0 + b1·hataSlope·log10(d)
/// - hata-calibration (current): log10(d) = b0 + b1·log10(hataDistance)
///
/// When the richer (mnc, networkType, density) context is supplied, it first looks up the
/// composite group `density|mnc|networkType|band`; if that has no learned coefficients it falls
/// back to the density-only group, and if neither exists it delegates to the analytic Hata/COST-231
/// model (or the 3GPP 38.901 anchor for NR) so the app behaves exactly as before until training
/// data is available. Any numerical failure also falls back.
///
/// Ported from the Java `au.com.bitbot.phonetowers.pathloss.LearnedPathLossModel`.
class LearnedPathLossModel implements PathLossModel {
  final PathLossCoefficients coefficients;
  final PathLossModel fallback;
  final Nr3gppPathLossModel _nrAnchor;

  LearnedPathLossModel(this.coefficients, [PathLossModel? fallback])
      : fallback = fallback ?? AnalyticPathLossModel(),
        _nrAnchor = Nr3gppPathLossModel();

  @override
  double calculateDistance(
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    List<double>? beta = coefficients.get(density);
    if (beta == null) {
      return fallback.calculateDistance(density, levelInDb, freqInMHz, height);
    }
    double distanceKm = _invert(beta, null, density, levelInDb, freqInMHz, height);
    return _isUsable(distanceKm)
        ? distanceKm
        : fallback.calculateDistance(density, levelInDb, freqInMHz, height);
  }

  /// Each density's coefficients are regressed independently from that density's own samples,
  /// with nothing tying one density's offset to a neighbour's — including a borrowed one, since
  /// the borrow above picks whichever nearby group has data at all, not the most generous one.
  /// That let a SUBURBAN site predict a SHORTER range than a nearby URBAN one for the same
  /// signal, inverting the OPEN > SUBURBAN > URBAN > METRO ordering Hata's own physics already
  /// guarantees. Recursing toward the next denser neighbour and taking the max restores that
  /// ordering regardless of which fallback tier either density landed in.
  ///
  /// Scoped to non-NR network types only: the guarantee this leans on is Hata's, and the 3GPP
  /// 38.901 anchor NR falls back to is not built the same way — its per-density values are not
  /// guaranteed monotonic (measured: at 3595 MHz/165 dB the METRO anchor is FARTHER than the
  /// URBAN one, the wrong way round), so borrowing a "denser" NR neighbour here could inject a
  /// worse number instead of a better one.
  ///
  /// Bounded depth: [CityDensity] has 5 values and this only ever steps toward index 0 (METRO),
  /// which is the base case and returns unclamped.
  ///
  /// Mirrors the equivalent clamp in the Java
  /// `au.com.bitbot.phonetowers.pathloss.LearnedPathLossModel.calculateDistance`.
  @override
  double calculateDistanceWithContext(int mnc, NetworkType networkType,
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    double distanceKm = _calculateDistanceWithContextRaw(
        mnc, networkType, density, levelInDb, freqInMHz, height);
    int index = density.index;
    if (index > 0 && networkType != NetworkType.NR) {
      CityDensity denser = CityDensity.values[index - 1];
      double denserKm = calculateDistanceWithContext(
          mnc, networkType, denser, levelInDb, freqInMHz, height);
      if (_isUsable(denserKm) && (!_isUsable(distanceKm) || denserKm > distanceKm)) {
        distanceKm = denserKm;
      }
    }
    return distanceKm;
  }

  double _calculateDistanceWithContextRaw(int mnc, NetworkType networkType,
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    String band = PathLossKey.bandBucket(freqInMHz * 1_000_000.0);
    List<double>? beta =
        coefficients.getComposite(mnc, networkType, band, density);
    beta ??= coefficients.get(density);

    // The density the chosen coefficients were fitted against. When a neighbouring density's
    // group is borrowed below, the analytic Hata distance that the calibration form inverts must
    // be recomputed for THAT density too — otherwise borrowed b0/b1 are applied to an input they
    // were never regressed against.
    CityDensity fitted = density;

    if (beta == null) {
      // Nearest-density fallback, before abandoning calibration altogether.
      //
      // The published table is sparse and lopsided by MNC: at the time of writing it holds 22
      // groups, of which MNC 3 has two, and the density-only safety net has exactly one row
      // (URBAN). A carrier whose density happens to miss therefore dropped straight through to
      // raw analytic Okumura-Hata — "several times too large", as get_licenceHRP already warns.
      //
      // That is what made two co-located towers at site 50917 differ by ~6x in radius: Optus has
      // 31 sites in the geohash so resolved to URBAN and stayed calibrated, while Vodafone's 14
      // resolved to SUBURBAN and fell through. Borrowing the nearest calibrated density moves
      // Vodafone from 2.07 km to about 0.20 km, alongside Optus's 0.33 km.
      for (final CityDensity near in _densitiesNearestFirst(density).skip(1)) {
        final List<double>? borrowed =
            coefficients.getComposite(mnc, networkType, band, near) ??
                coefficients.get(near);
        if (borrowed != null) {
          beta = borrowed;
          fitted = near;
          break;
        }
      }
    }

    if (beta == null) {
      if (networkType == NetworkType.NR) {
        double nr =
            _nrAnchor.calculateDistance(density, levelInDb, freqInMHz, height);
        return _isUsable(nr)
            ? nr
            : fallback.calculateDistance(density, levelInDb, freqInMHz, height);
      }
      return fallback.calculateDistance(density, levelInDb, freqInMHz, height);
    }
    double distanceKm =
        _invert(beta, networkType, fitted, levelInDb, freqInMHz, height);
    return _isUsable(distanceKm)
        ? distanceKm
        : fallback.calculateDistance(density, levelInDb, freqInMHz, height);
  }

  /// [density] first, then the rest of the METRO..OPEN scale ordered by increasing distance from
  /// it, preferring the denser side when two are equally close.
  ///
  /// e.g. SUBURBAN yields SUBURBAN, MEDIUM, OPEN, URBAN, METRO.
  static List<CityDensity> _densitiesNearestFirst(CityDensity density) {
    const List<CityDensity> all = CityDensity.values;
    final int i = density.index;
    final List<CityDensity> order = <CityDensity>[density];
    for (int step = 1; step < all.length; step++) {
      if (i - step >= 0) order.add(all[i - step]);
      if (i + step < all.length) order.add(all[i + step]);
    }
    return order;
  }

  double _invert(List<double> beta, NetworkType? networkType, CityDensity density,
      double levelInDb, double freqInMHz, double height) {
    if (coefficients.isHataCalibrationForm) {
      return _applyHataCalibration(
          beta, networkType, density, levelInDb, freqInMHz, height);
    }
    if (coefficients.isHataCorrectionForm) {
      return _invertHataCorrection(beta, density, levelInDb, freqInMHz, height);
    }
    return _invertLogDistance(beta, levelInDb, freqInMHz, height);
  }

  /// Hata calibration — the analytic model's own log-distance estimate is rescaled by
  /// coefficients fit in the log-distance direction, so the result can never blow up.
  /// For NR cells, the 3GPP TR 38.901 model is used as the anchor instead of Hata.
  static double _applyHataCalibration(
      List<double> beta,
      NetworkType? networkType,
      CityDensity density,
      double levelInDb,
      double freqInMHz,
      double height) {
    double h = math.max(height, 1.0);
    double logAnchorDistance;
    if (networkType == NetworkType.NR) {
      logAnchorDistance =
          Nr3gppPathLossModel.logAnchorDistanceKm(density, levelInDb, freqInMHz, h);
    } else {
      double intercept = AnalyticPathLossModel.hataInterceptDb(density, freqInMHz, h);
      double slope = AnalyticPathLossModel.hataSlopeDb(h);
      if (!intercept.isFinite || slope.abs() < 1e-9) return double.nan;
      logAnchorDistance = (levelInDb - intercept) / slope;
    }
    if (!logAnchorDistance.isFinite) return double.nan;
    return math.pow(10.0,
            beta[PathLossCoefficients.idxB0] +
                beta[PathLossCoefficients.idxB1] * logAnchorDistance)
        .toDouble();
  }

  /// Hata-anchored inversion — frequency/height physics from the analytic model; only offset
  /// (b0) and slope multiplier (b1) are learned.
  static double _invertHataCorrection(List<double> beta, CityDensity density,
      double levelInDb, double freqInMHz, double height) {
    double h = math.max(height, 1.0);
    double intercept = AnalyticPathLossModel.hataInterceptDb(density, freqInMHz, h);
    double slope = beta[PathLossCoefficients.idxB1] * AnalyticPathLossModel.hataSlopeDb(h);
    if (!intercept.isFinite || slope.abs() < 1e-9) return double.nan;
    double numerator = levelInDb - intercept - beta[PathLossCoefficients.idxB0];
    return math.pow(10.0, numerator / slope).toDouble();
  }

  static double _invertLogDistance(
      List<double> beta, double levelInDb, double freqInMHz, double height) {
    double logFreq = log10(freqInMHz);
    double logHeight = log10(math.max(height, 1.0));
    double numerator = levelInDb -
        beta[PathLossCoefficients.idxB0] -
        beta[PathLossCoefficients.idxB2] * logFreq -
        beta[PathLossCoefficients.idxB3] * logHeight;
    double exponent = numerator / beta[PathLossCoefficients.idxB1];
    return math.pow(10.0, exponent).toDouble();
  }

  static bool _isUsable(double distanceKm) =>
      distanceKm.isFinite && distanceKm > 0;
}
