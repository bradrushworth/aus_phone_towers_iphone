import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Builds the grouping keys used by the learned path-loss model.
///
/// Ported from the Java `au.com.bitbot.phonetowers.pathloss.PathLossKey`.
class PathLossKey {
  PathLossKey._();

  static String densityKey(CityDensity density) => density.name;

  static String compositeKey(
      int mnc, NetworkType networkType, String band, CityDensity density) {
    return '${density.name}|$mnc|${networkType.name}|$band';
  }

  /// Bucket a carrier frequency (Hz) into LOW / MID / HIGH.
  /// LOW < 1 GHz, MID 1-2.5 GHz, HIGH >= 2.5 GHz.
  static String bandBucket(double freqHz) {
    double fMHz = freqHz / 1_000_000.0;
    if (fMHz < 1000.0) return 'LOW';
    if (fMHz < 2500.0) return 'MID';
    return 'HIGH';
  }
}
