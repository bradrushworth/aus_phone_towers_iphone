import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/learned_path_loss_model.dart';
import 'package:phonetowers/pathloss/path_loss_coefficients.dart';
import 'package:phonetowers/pathloss/path_loss_model.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/restful/get_path_loss_coefficients.dart';

/// Supplies the active [PathLossModel]. Fetches coefficients from the REST endpoint
/// (MySQL `pathloss_coefficients` table) on startup; until that completes (or if it fails),
/// the learned model falls back to the analytic Okumura-Hata / COST-231-Hata formulas,
/// preserving today's behaviour.
///
/// Ported from the Java `au.com.bitbot.phonetowers.pathloss.PathLossModelProvider`.
class PathLossModelProvider {
  static final Logger _logger = Logger();

  static PathLossModelProvider? _instance;

  PathLossModelProvider._();

  factory PathLossModelProvider() {
    _instance ??= PathLossModelProvider._();
    return _instance!;
  }

  PathLossModel? _model;
  PathLossCoefficients? _coefficients;
  bool _fetching = false;

  PathLossModel get model {
    _model ??= _build();
    return _model!;
  }

  PathLossCoefficients? get coefficients {
    // Ensure model is built so coefficients are populated
    model;
    return _coefficients;
  }

  /// Kick off an asynchronous fetch of coefficients from the server. Fire-and-forget —
  /// the app continues with the analytic fallback until the fetch completes, at which
  /// point the learned model is swapped in. Safe to call multiple times.
  Future<void> init() async {
    if (_fetching) return;
    _fetching = true;
    try {
      PathLossCoefficients? serverCoeffs =
          await GetPathLossCoefficients.fetchFromServer();
      if (serverCoeffs != null && serverCoeffs.isAnyTrained) {
        _logger.i('Using server-fetched path-loss coefficients '
            '(form=${serverCoeffs.form}, groups=${serverCoeffs.allComposite.length})');
        _coefficients = serverCoeffs;
        _model = LearnedPathLossModel(serverCoeffs);
      }
    } catch (e) {
      _logger.w('Server coefficient fetch failed, using analytic fallback: $e');
    } finally {
      _fetching = false;
    }
  }

  PathLossModel _build() {
    PathLossCoefficients coeffs =
        _coefficients ?? PathLossCoefficients.empty();
    _coefficients = coeffs;
    return LearnedPathLossModel(coeffs);
  }

  /// Force a reload from the server (e.g. after coefficients are updated).
  Future<void> reset() async {
    _model = null;
    _coefficients = null;
    await init();
  }

  // Convenience static delegates mirroring the Java API.

  static double calculateDistance(
          CityDensity density, double levelInDb, double freqInMHz, double height) =>
      PathLossModelProvider().model.calculateDistance(density, levelInDb, freqInMHz, height);

  static double calculateDistanceWithContext(int mnc, NetworkType networkType,
          CityDensity density, double levelInDb, double freqInMHz, double height) =>
      PathLossModelProvider().model.calculateDistanceWithContext(
          mnc, networkType, density, levelInDb, freqInMHz, height);

  static Future<void> initProvider() => PathLossModelProvider().init();
}
