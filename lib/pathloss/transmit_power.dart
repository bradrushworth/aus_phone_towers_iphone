import 'dart:math' as math;

import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';

/// Transmit power per resource element on a bearing -- the `P` term of the path-loss model v2
/// (`P = perReEirpDbm + relativePatternDb`; see the spec, section 3:
/// docs/pathloss/2026-09-20-model-v2-spec.md in bradrushworth/aus_phone_towers_java).
///
/// Static, pure functions only, no Flutter imports, so this can be exercised directly by plain
/// Dart tests. Mirrors the Android app's `au.com.bitbot.phonetowers.pathloss.TransmitPower`:
/// same names, same arithmetic.
class TransmitPower {
  TransmitPower._();

  /// Number of subcarriers sharing the transmitter's wideband EIRP -- the divisor in
  /// [perReEirpDbm]. [ContourModel.supports] restricts the whole v2 model to LTE and NR, so a
  /// [networkType] that is not NR always takes the LTE formula.
  ///
  /// LTE: `12 * N_RB`, with `N_RB` the standard resource-block count for an exact-width licence
  /// (1.4/3/5/10/15/20 MHz), else `max(1, floor(0.9 * bandwidthHz / 180000))` -- ACMA licences of
  /// 25-40+ MHz are several carriers folded into one record, not one of the standard widths.
  ///
  /// NR: `12 * max(1, floor(0.95 * bandwidthHz / (12 * scsHz)))`, with `scsHz` 30 kHz for the TDD
  /// bands n40 (2300-2400 MHz) and n78 (>= 3300 MHz), else 15 kHz.
  static int subcarriers(NetworkType networkType, double freqMHz, double bandwidthHz) {
    if (networkType == NetworkType.NR) {
      final bool tdd = (freqMHz >= 2300 && freqMHz < 2400) || freqMHz >= 3300;
      final double scsHz = tdd ? 30000 : 15000;
      final int resourceBlocks = math.max(1, (0.95 * bandwidthHz / (12 * scsHz)).floor());
      return 12 * resourceBlocks;
    }
    return 12 * _lteResourceBlocks(bandwidthHz);
  }

  /// LTE resource blocks for [bandwidthHz]: the standard table for an exact-width licence, else
  /// the formula for a wider ACMA record that packs several carriers into one licence row.
  static int _lteResourceBlocks(double bandwidthHz) {
    if (bandwidthHz == 1400000) return 6;
    if (bandwidthHz == 3000000) return 15;
    if (bandwidthHz == 5000000) return 25;
    if (bandwidthHz == 10000000) return 50;
    if (bandwidthHz == 15000000) return 75;
    if (bandwidthHz == 20000000) return 100;
    return math.max(1, (0.9 * bandwidthHz / 180000).floor());
  }

  /// True when [eirpW] and [bandwidthHz] are numerically usable for [perReEirpDbm]: finite and
  /// positive. This is the general check; it does not catch the dB-scale symptom a few narrow
  /// 2.1 GHz licences show, which needs the licence_hrp maximum power -- see [looksLikeDbScale].
  static bool isUsableEirp(double eirpW, double bandwidthHz) {
    return eirpW.isFinite && eirpW > 0 && bandwidthHz.isFinite && bandwidthHz > 0;
  }

  /// True when [eirpW], read directly as dBm (`10*log10(eirpW) + 30`), lands within 0.05 dB of
  /// [maxHrpPowerDbm] -- the maximum `licence_hrp.power` reading for the same transmitter. A
  /// handful of licences carry a dB-scale number in the `eirp` field rather than Watts; this is
  /// only checkable on the licence_hrp paths, where a maximum power is available.
  static bool looksLikeDbScale(double eirpW, double maxHrpPowerDbm) {
    if (!eirpW.isFinite || eirpW <= 0 || !maxHrpPowerDbm.isFinite) return false;
    final double eirpReadAsDbm = 10 * log10(eirpW) + 30;
    return (eirpReadAsDbm - maxHrpPowerDbm).abs() < 0.05;
  }

  /// Transmit power per resource element, dBm: the wideband EIRP divided among the [subcarriers]
  /// that share it. Callers who found [isUsableEirp] false (or [looksLikeDbScale] true) use
  /// `ContourCoefficients.typicalPerReEirpDbm` in place of this.
  static double perReEirpDbm(double eirpW, int subcarriers) {
    return 10 * log10(eirpW) + 30 - 10 * log10(subcarriers);
  }

  /// The estimated-pattern loss (dB, `>= 0`) for a directional antenna at [bearing] given the
  /// transmitter's [azimuth] and front-to-back ratio [frontToBackDb]; `0` for an omnidirectional
  /// antenna (`azimuth == null`).
  ///
  /// Extracted verbatim from `DeviceDetails.getPowerAtBearing` so that call site and this model's
  /// `P` term share one definition -- this function must keep reproducing exactly what that
  /// method already returned (pinned in test/model/device_detail_test.dart), never the other way
  /// round; `getPowerAtBearing` itself still feeds tower matching unchanged (spec section 1).
  static double estimatedPatternLossDb(double? azimuth, double bearing, double frontToBackDb) {
    if (azimuth == null) {
      return 0.0;
    }
    final double referenceAngle = (bearing - azimuth).abs();
    double loss =
        (math.pow(1 - math.cos(_toRadians(referenceAngle)), 1.15)).abs() * frontToBackDb;
    if (loss.isNaN) {
      // 1 - cos(x) can round to just under zero right at a multiple of 2*pi radians; pow() of a
      // negative base to a non-integer exponent is undefined (NaN), not a near-zero loss.
      loss = frontToBackDb;
    }
    return math.min(loss, frontToBackDb);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
