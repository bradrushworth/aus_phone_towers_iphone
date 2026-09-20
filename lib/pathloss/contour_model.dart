import 'dart:math' as math;

import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/contour_coefficients.dart';
import 'package:phonetowers/pathloss/path_loss_key.dart';
import 'package:phonetowers/pathloss/transmit_power.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// The path-loss model v2 solver (section 2 of the spec):
///
/// ```
/// predicted RSRP(d) = P - [ A_urban(f, h) + k*s(h)*log10(d_km) + offset + nrTddOffset ]
/// distance_km = 10 ^ ( (budgetDb - A_urban(f, h) - offset - nrTddOffset) / (k*s(h)) )
/// ```
///
/// for LTE and NR only (section 1: "does not change in this release ... every transmitter that
/// is not LTE or NR"; see [supports]). `A_urban` and `s` are the existing Okumura-Hata URBAN
/// intercept and slope ([AnalyticPathLossModel]) -- this class does not re-derive them, only
/// combines them with the bundled [ContourCoefficients]. `nrTddOffset` is non-zero only for NR on
/// a TDD band ([TransmitPower.isTddBand]), looked up by the carrier's `mnc`.
///
/// Mirrors the Android app's `au.com.bitbot.phonetowers.pathloss.ContourModel`: same names, same
/// arithmetic.
class ContourModel {
  final ContourCoefficients coefficients;

  const ContourModel(this.coefficients);

  /// This model only covers LTE and NR.
  static bool supports(NetworkType networkType) =>
      networkType == NetworkType.LTE || networkType == NetworkType.NR;

  /// Distance (km) at which link budget [budgetDb] (`P - rung`, less any diffraction loss) is
  /// exhausted, clamped to `[0.01, 100]` km. `null` [density] is treated as SUBURBAN. [mnc] is
  /// the carrier's mobile network code (an unknown carrier is passed as `0`, which gets the
  /// table's `default` TDD loss whenever it applies -- see [ContourCoefficients.nrTddOffsetDb]).
  ///
  /// A non-finite [budgetDb] or [effectiveHeightM] (division by a zero slope is not possible --
  /// [AnalyticPathLossModel.hataSlopeDb] cannot return zero -- but a NaN input propagates through
  /// the exponent) floors to `0.01` km rather than reaching the ordinary clamp below: `num.clamp`
  /// does not rescue NaN the way it rescues an out-of-range finite value, and Dart's `clamp` on
  /// this SDK resolves a NaN receiver to its UPPER bound (100 km) -- silently drawing the
  /// largest possible circle for a garbage input, worse than either leaving it NaN or flooring
  /// it. Matches the Android app (commit 74feac86 on pathloss-v2/a3-switch).
  double distanceKm(NetworkType networkType, int mnc, CityDensity? density, double freqMHz,
      double effectiveHeightM, double budgetDb) {
    final _ClassLookup c = _classify(networkType, mnc, density, freqMHz, effectiveHeightM);
    final double exponent =
        (budgetDb - c.aUrbanDb - c.row.offsetDb - c.nrTddOffsetDb) / (c.row.k * c.slopeDb);
    final double raw = math.pow(10, exponent).toDouble();
    if (raw.isNaN) {
      return 0.01;
    }
    return raw.clamp(0.01, 100.0).toDouble();
  }

  /// The forward model: predicted path loss (dB) at [distanceKm] for this class -- the inverse
  /// of [distanceKm] (`distanceKm(..., lossDb(..., d)) == d` for any in-range `d`), used by
  /// tests.
  double lossDb(NetworkType networkType, int mnc, CityDensity? density, double freqMHz,
      double effectiveHeightM, double distanceKm) {
    final _ClassLookup c = _classify(networkType, mnc, density, freqMHz, effectiveHeightM);
    return c.aUrbanDb +
        c.row.k * c.slopeDb * log10(distanceKm) +
        c.row.offsetDb +
        c.nrTddOffsetDb;
  }

  _ClassLookup _classify(NetworkType networkType, int mnc, CityDensity? density, double freqMHz,
      double effectiveHeightM) {
    final CityDensity d = density ?? CityDensity.SUBURBAN;
    final double h = math.max(effectiveHeightM, 1.0);
    final String band = PathLossKey.bandBucket(freqMHz * 1e6);
    final ContourClassRow row = coefficients.forClass(d, band);
    final double aUrban = AnalyticPathLossModel.hataInterceptDb(CityDensity.URBAN, freqMHz, h);
    final double slope = AnalyticPathLossModel.hataSlopeDb(h);
    final double nrTddOffset =
        (networkType == NetworkType.NR && TransmitPower.isTddBand(freqMHz))
            ? coefficients.nrTddOffsetDb(mnc)
            : 0.0;
    return _ClassLookup(row: row, aUrbanDb: aUrban, slopeDb: slope, nrTddOffsetDb: nrTddOffset);
  }
}

/// The per-call intermediate values [ContourModel.distanceKm] and [ContourModel.lossDb] share.
class _ClassLookup {
  final ContourClassRow row;
  final double aUrbanDb;
  final double slopeDb;
  final double nrTddOffsetDb;

  const _ClassLookup({
    required this.row,
    required this.aUrbanDb,
    required this.slopeDb,
    required this.nrTddOffsetDb,
  });
}
