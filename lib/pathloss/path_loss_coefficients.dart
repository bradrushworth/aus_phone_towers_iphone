import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/path_loss_key.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Per-environment learned coefficients for the log-distance path-loss model.
///
/// Coefficients are keyed either by [CityDensity] alone (the density-only fallback) or by a
/// composite key `density|mnc|networkType|band` (see [PathLossKey]) so each telco / tech /
/// band / density stratum gets its own b0..b3.
///
/// Three functional forms are supported, selected by [form]:
/// - [formLogDistance]: levelInDb = b0 + b1·log10(d) + b2·log10(f) + b3·log10(h)
/// - [formHataCorrection]: Hata-anchored inversion with learned offset (b0) and slope multiplier (b1)
/// - [formHataCalibration]: regress log-distance on the analytic model's own log-distance estimate
///
/// Ported from the Java `au.com.bitbot.phonetowers.pathloss.PathLossCoefficients`.
class PathLossCoefficients {
  static const int numParams = 4;
  static const int idxB0 = 0;
  static const int idxB1 = 1;
  static const int idxB2 = 2;
  static const int idxB3 = 3;

  static const String formLogDistance = 'log-distance';
  static const String formHataCorrection = 'hata-correction';
  static const String formHataCalibration = 'hata-calibration';

  static const double defaultReferencePowerDbm = 57.0;

  bool trained;
  final double referencePowerDbm;
  final String form;
  final Map<String, List<double>> _coefficients = {};

  PathLossCoefficients(this.trained, this.referencePowerDbm, [String? form])
      : form = (form == null || form.isEmpty) ? formLogDistance : form;

  bool get isHataCorrectionForm => form == formHataCorrection;
  bool get isHataCalibrationForm => form == formHataCalibration;

  void set(CityDensity density, List<double> beta, int sampleCount, double rSquared) {
    _coefficients[PathLossKey.densityKey(density)] =
        _pack(beta, sampleCount, rSquared);
  }

  void setComposite(int mnc, NetworkType networkType, String band,
      CityDensity density, List<double> beta, int sampleCount, double rSquared) {
    _coefficients[PathLossKey.compositeKey(mnc, networkType, band, density)] =
        _pack(beta, sampleCount, rSquared);
  }

  static List<double> _pack(List<double> beta, int sampleCount, double rSquared) {
    return [...beta, sampleCount.toDouble(), rSquared];
  }

  bool isTrainedFor(CityDensity density) =>
      _coefficients.containsKey(PathLossKey.densityKey(density));

  bool isTrainedComposite(int mnc, NetworkType networkType, String band,
          CityDensity density) =>
      _coefficients.containsKey(
          PathLossKey.compositeKey(mnc, networkType, band, density));

  bool get isAnyTrained => _coefficients.isNotEmpty;

  bool get isTrained => trained && _coefficients.isNotEmpty;

  List<double>? get(CityDensity density) =>
      _coefficients[PathLossKey.densityKey(density)];

  List<double>? getComposite(
          int mnc, NetworkType networkType, String band, CityDensity density) =>
      _coefficients[PathLossKey.compositeKey(mnc, networkType, band, density)];

  Map<String, List<double>> get allComposite => Map.unmodifiable(_coefficients);

  static PathLossCoefficients empty(
          [double referencePowerDbm = defaultReferencePowerDbm]) =>
      PathLossCoefficients(false, referencePowerDbm);

  /// Serialise to the JSON format used by the bundled asset and the REST endpoint.
  Map<String, dynamic> toJson() {
    Map<String, dynamic> coeffs = {};
    for (var entry in _coefficients.entries) {
      List<double> v = entry.value;
      coeffs[entry.key] = {
        'b0': v[idxB0],
        'b1': v[idxB1],
        'b2': v[idxB2],
        'b3': v[idxB3],
        'sampleCount': v[numParams].toInt(),
        'rSquared': v[numParams + 1],
      };
    }
    return {
      'trained': trained,
      'referencePowerDbm': referencePowerDbm,
      'form': form,
      'coefficients': coeffs,
    };
  }

  /// Parse from the JSON format used by the bundled asset and the REST endpoint's
  /// converted output: `{"trained":true,"form":"...","referencePowerDbm":57,"coefficients":{...}}`.
  static PathLossCoefficients fromJson(Map<String, dynamic> json) {
    bool trained = json['trained'] ?? false;
    double ref = _asDouble(json['referencePowerDbm'], defaultReferencePowerDbm);
    String form = json['form'] is String
        ? json['form'] as String
        : formLogDistance;
    PathLossCoefficients pc = PathLossCoefficients(trained, ref, form);

    var coeffsObj = json['coefficients'];
    if (coeffsObj is Map) {
      for (var entry in coeffsObj.entries) {
        String key = entry.key as String;
        Map<String, dynamic> o = entry.value as Map<String, dynamic>;
        List<double> beta = [
          _asDouble(o['b0'], 0),
          _asDouble(o['b1'], 0),
          _asDouble(o['b2'], 0),
          _asDouble(o['b3'], 0),
        ];
        int n = _asInt(o['sampleCount'], 0);
        double r2 = _asDouble(o['rSquared'], 0);

        if (key.contains('|')) {
          List<String> parts = key.split('|');
          if (parts.length == 4) {
            CityDensity? d = _parseDensity(parts[0]);
            if (d != null) {
              int mnc = int.tryParse(parts[1]) ?? 0;
              NetworkType nt = _parseNetworkType(parts[2]);
              pc.setComposite(mnc, nt, parts[3], d, beta, n, r2);
            }
          }
        } else {
          CityDensity? d = _parseDensity(key);
          if (d != null) {
            pc.set(d, beta, n, r2);
          }
        }
      }
    }
    return pc;
  }

  static double _asDouble(dynamic o, double def) {
    if (o is num) return o.toDouble();
    if (o is String) return double.tryParse(o) ?? def;
    return def;
  }

  static int _asInt(dynamic o, int def) {
    if (o is num) return o.toInt();
    if (o is String) return int.tryParse(o) ?? def;
    return def;
  }

  static NetworkType _parseNetworkType(String s) {
    if (s == '?' || s.isEmpty) return NetworkType.UNKNOWN;
    return NetworkType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => NetworkType.UNKNOWN,
    );
  }

  static CityDensity? _parseDensity(String key) {
    for (CityDensity d in CityDensity.values) {
      if (d.name.equalsIgnoreCase(key)) return d;
    }
    return null;
  }
}

extension on String {
  bool equalsIgnoreCase(String other) =>
      toLowerCase() == other.toLowerCase();
}
