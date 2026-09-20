import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/contour_coefficients.dart';
import 'package:phonetowers/pathloss/path_loss_key.dart';
import 'package:phonetowers/pathloss/transmit_power.dart';

/// Call-site glue for the path-loss model v2 drawing paths (spec section 3, F2 brief item 1):
/// combines [TransmitPower] and the bundled [ContourCoefficients] into the two small
/// calculations both v2 call sites need -- the base transmit power `P`, and how a row's power
/// folds into it relative to the transmitter's strongest bearing.
///
/// Not one of the three classes the spec mirrors byte-for-byte from the Android app
/// ([TransmitPower], [ContourCoefficients], [ContourModel]) -- this is Flutter call-site glue
/// only, so it carries no "same names in both apps" obligation.
class ContourPower {
  ContourPower._();

  /// Transmit power per resource element, dBm (`P`, spec section 3): [TransmitPower.perReEirpDbm]
  /// when [eirpW] is usable and, when [maxHrpPowerDbm] is supplied (the licence_hrp paths only --
  /// the estimated-pattern path has no HRP maximum and passes `null`), does not look like a
  /// dB-scale reading; otherwise the bundled table's typical per-RE EIRP for [networkType]'s band.
  static double basePowerDbm(NetworkType networkType, double freqMHz, double bandwidthHz,
      double eirpW, double? maxHrpPowerDbm, ContourCoefficients coefficients) {
    final bool usable = TransmitPower.isUsableEirp(eirpW, bandwidthHz) &&
        (maxHrpPowerDbm == null || !TransmitPower.looksLikeDbScale(eirpW, maxHrpPowerDbm));
    if (usable) {
      final int subcarriers = TransmitPower.subcarriers(networkType, freqMHz, bandwidthHz);
      return TransmitPower.perReEirpDbm(eirpW, subcarriers);
    }
    final String band = PathLossKey.bandBucket(freqMHz * 1e6);
    return coefficients.typicalPerReEirpDbm(networkType, band);
  }

  /// Maximum `power` over [powers] (licence_hrp's power density, one reading per bearing), taken
  /// over every row of every page BEFORE row-step sampling (spec section 3: "The maximum is over
  /// every page of the response, not the page in hand"). Callers only call this when [powers] is
  /// non-empty.
  static double maxPowerDbm(Iterable<double> powers) {
    final Iterator<double> it = powers.iterator;
    if (!it.moveNext()) {
      throw StateError('ContourPower.maxPowerDbm: powers must not be empty');
    }
    double max = it.current;
    while (it.moveNext()) {
      if (it.current > max) max = it.current;
    }
    return max;
  }

  /// `relativePatternDb = power - max` (spec section 3), clamped so it is never positive --
  /// [power] should always be `<= max` by construction (max is taken over a set that includes
  /// [power]), but this guards against floating-point slack or a caller passing a max that did
  /// not actually include this row.
  static double relativePatternDb(double power, double max) {
    final double relative = power - max;
    return relative > 0 ? 0.0 : relative;
  }
}
