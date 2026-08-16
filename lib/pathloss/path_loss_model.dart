import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Estimates the distance (km) at which a given signal path-loss is observed, for a carrier of a
/// given frequency and a base station of a given antenna height, in a given environment.
///
/// This is the seam that lets the app swap the legacy Okumura-Hata / COST-231-Hata analytic
/// formulas for a model whose constants are learned from real observations
/// (see [LearnedPathLossModel]).
///
/// Ported from the Java `au.com.bitbot.phonetowers.pathloss.PathLossModel` interface.
abstract class PathLossModel {
  /// [density] environment (METRO / URBAN / MEDIUM / SUBURBAN / OPEN)
  /// [levelInDb] path-loss magnitude in dB (power_dBm - receiver_dBm)
  /// [freqInMHz] carrier frequency in MHz
  /// [height] effective base-station antenna height in metres (tower height + hill height)
  /// Returns estimated distance in km.
  double calculateDistance(
      CityDensity density, double levelInDb, double freqInMHz, double height);

  /// Context-aware variant used at runtime. Selects the learned coefficients for the
  /// (mnc, networkType, band, density) stratum (band derived from [freqInMHz]), falling
  /// back to the density-only coefficients, then to the analytic model.
  double calculateDistanceWithContext(int mnc, NetworkType networkType,
      CityDensity density, double levelInDb, double freqInMHz, double height);
}
