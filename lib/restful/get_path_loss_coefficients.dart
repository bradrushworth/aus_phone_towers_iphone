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

  /// Rows requested per RESTify page. Matches the server's own page-size ceiling, so a full
  /// page is the signal that more rows may follow (see [fetchFromServer]).
  static const int _pageSize = 100;
  static const String _path =
      '/towers/pathloss_coefficients/?_view=json&_expand=no&_count=$_pageSize';
  static const Duration _timeout = Duration(seconds: 5);

  /// Hard ceiling on pages followed in one fetch, guarding against a malformed or looping
  /// `nextPage` link turning a bad response into an infinite fetch. 50 pages is 5,000 rows at
  /// the current page size — far beyond any plausible stratum count.
  static const int _maxPages = 50;

  GetPathLossCoefficients._();

  /// Fetches coefficients from the server, following RESTify's `nextPage.href` link (the same
  /// pattern [GetLicenceHRP]/[GetDevices] use) until every page has been collected. Only 22
  /// coefficient groups existed when this endpoint was first written, so `_count=100` alone
  /// never truncated — but with no paging, any stratum published past row 100 would silently
  /// vanish and those sites would fall back to analytic Okumura-Hata with no error surfaced.
  /// Returns null if the fetch fails before any page succeeds (caller falls back to the
  /// analytic model). If a later page fails after at least one earlier page has already been
  /// collected, the rows gathered so far are kept and returned rather than discarded — the
  /// truncation is logged, but a mid-sequence hiccup no longer forces a full fallback.
  ///
  /// [api] is injectable for tests; production callers omit it and get a real [Api.initialize].
  static Future<PathLossCoefficients?> fetchFromServer({Api? api}) async {
    Api resolvedApi = api ?? Api.initialize();
    List<Map<String, dynamic>> allRows = [];
    try {
      String? nextPath = _path;
      int pageCount = 0;

      while (nextPath != null) {
        pageCount++;
        if (pageCount > _maxPages) {
          _logger.w(
              'pathloss_coefficients: stopped after $_maxPages pages (possible pagination loop); '
              'using the ${allRows.length} rows collected so far');
          break;
        }

        Response response = await resolvedApi.dio.get(
          nextPath,
          options: Options(
            sendTimeout: _timeout,
            receiveTimeout: _timeout,
          ),
        );

        if (response.statusCode == null ||
            response.statusCode! < 200 ||
            response.statusCode! >= 300) {
          if (allRows.isNotEmpty) {
            _logger.w('Server returned HTTP ${response.statusCode} on page $pageCount, '
                'keeping the ${allRows.length} rows already collected from earlier pages');
            return _rowsToCoefficients(allRows);
          }
          _logger.w('Server returned HTTP ${response.statusCode}, falling back');
          return null;
        }

        Map<String, dynamic> json = response.data is String
            ? jsonDecode(response.data)
            : response.data as Map<String, dynamic>;

        Map<String, dynamic> root = json;
        if (root.containsKey('restify')) {
          root = root['restify'] as Map<String, dynamic>;
        }
        List rows = (root['rows'] as List?) ?? const [];

        // A full page means there may be more rows waiting past this one — worth knowing about
        // even when nextPage is present, since it is the direct evidence that _count=100 would
        // have silently truncated here without paging.
        if (rows.length >= _pageSize) {
          _logger.i(
              'pathloss_coefficients: page $pageCount returned ${rows.length} rows (page full)');
        }

        allRows.addAll(rows.cast<Map<String, dynamic>>());

        Map<String, dynamic>? nextPage = root['nextPage'] as Map<String, dynamic>?;
        nextPath = nextPage != null ? nextPage['href'] as String? : null;
      }

      return _rowsToCoefficients(allRows);
    } catch (e) {
      if (allRows.isNotEmpty) {
        _logger.w('Could not fetch coefficients from server: $e; '
            'keeping the ${allRows.length} rows already collected from earlier pages');
        return _rowsToCoefficients(allRows);
      }
      _logger.w('Could not fetch coefficients from server: $e');
      return null;
    }
  }

  /// Converts the accumulated RESTify rows (across every page) into a [PathLossCoefficients]
  /// object.
  static PathLossCoefficients? _rowsToCoefficients(List<Map<String, dynamic>> rows) {
    try {
      if (rows.isEmpty) return null;

      // Use the first row's form/trained/referencePowerDbm as the global values
      Map<String, dynamic> firstRow =
          rows[0]['values'] as Map<String, dynamic>;
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
        Map<String, dynamic> values = row['values'] as Map<String, dynamic>;
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
