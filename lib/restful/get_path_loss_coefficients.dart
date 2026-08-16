import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/pathloss/path_loss_coefficients.dart';

/// Fetches path-loss coefficients from the MySQL `pathloss_coefficients` table via the RESTify
/// endpoint. Called asynchronously by [PathLossModelProvider.init] at startup. Falls back to
/// the analytic Hata/COST-231 model if the fetch fails.
///
/// Ported from the Java `au.com.bitbot.phonetowers.restful.GetPathLossCoefficients`.
class GetPathLossCoefficients {
  static final Logger _logger = Logger();

  static const String _path =
      '/towers/pathloss_coefficients/?_view=json&_expand=no&_count=100';
  static const Duration _timeout = Duration(seconds: 5);

  GetPathLossCoefficients._();

  /// Fetches coefficients from the server. Returns null if the fetch fails (caller falls
  /// back to the analytic model).
  static Future<PathLossCoefficients?> fetchFromServer() async {
    try {
      Api api = Api.initialize();
      Response response = await api.dio.get(
        _path,
        options: Options(
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        _logger.w('Server returned HTTP ${response.statusCode}, falling back');
        return null;
      }

      Map<String, dynamic> json = response.data is String
          ? jsonDecode(response.data)
          : response.data as Map<String, dynamic>;

      return _restifyRowsToCoefficients(json);
    } catch (e) {
      _logger.w('Could not fetch coefficients from server: $e');
      return null;
    }
  }

  /// Converts a RESTify JSON response ({"restify":{"rows":[...]}}) into a
  /// [PathLossCoefficients] object.
  static PathLossCoefficients? _restifyRowsToCoefficients(
      Map<String, dynamic> restifyJson) {
    try {
      Map<String, dynamic> root = restifyJson;
      if (root.containsKey('restify')) {
        root = root['restify'] as Map<String, dynamic>;
      }
      List rows = root['rows'] as List;
      if (rows.isEmpty) return null;

      // Use the first row's form/trained/referencePowerDbm as the global values
      Map<String, dynamic> firstRow =
          (rows[0] as Map<String, dynamic>)['values'] as Map<String, dynamic>;
      String form = _fieldValue(firstRow['form'], 'hata-calibration');
      bool trained = _fieldInt(firstRow['trained'], 0) == 1;
      double refPower = _fieldDouble(firstRow['reference_power_dbm'], 57.0);

      Map<String, dynamic> result = {
        'trained': trained,
        'form': form,
        'referencePowerDbm': refPower,
        'coefficients': <String, dynamic>{},
      };
      Map<String, dynamic> coefficients = result['coefficients'];

      for (var row in rows) {
        Map<String, dynamic> values =
            (row as Map<String, dynamic>)['values'] as Map<String, dynamic>;
        String key = _fieldValue(values['coeff_key'], '');
        if (key.isEmpty) continue;
        coefficients[key] = {
          'b0': _fieldDouble(values['b0'], 0),
          'b1': _fieldDouble(values['b1'], 0),
          'b2': _fieldDouble(values['b2'], 0),
          'b3': _fieldDouble(values['b3'], 0),
          'sampleCount': _fieldInt(values['sample_count'], 0),
          'rSquared': _fieldDouble(values['r_squared'], 0),
        };
      }

      PathLossCoefficients coeffs =
          PathLossCoefficients.fromJson(result);
      _logger.i('Loaded ${coeffs.isAnyTrained ? "trained" : "untrained"} '
          'coefficients from server (form=${coeffs.form})');
      return coeffs;
    } catch (e) {
      _logger.w('Could not parse RESTify response: $e');
      return null;
    }
  }

  /// Extract the "value" field from a RESTify column object as a String.
  static String _fieldValue(dynamic col, String def) {
    if (col is Map<String, dynamic>) {
      var v = col['value'];
      return v?.toString() ?? def;
    }
    return def;
  }

  /// Extract the "value" field from a RESTify column object as a double.
  static double _fieldDouble(dynamic col, double def) {
    if (col is Map<String, dynamic>) {
      var v = col['value'];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? def;
    }
    return def;
  }

  /// Extract the "value" field from a RESTify column object as an int.
  static int _fieldInt(dynamic col, int def) {
    if (col is Map<String, dynamic>) {
      var v = col['value'];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? def;
    }
    return def;
  }
}
