import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/contour_coefficients.dart';
import 'package:phonetowers/pathloss/contour_model.dart';
import 'package:phonetowers/pathloss/transmit_power.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Path-loss model v2, shared cross-app test vectors (spec section 6): `test_vectors.json` was
/// produced by an independent Python port of the analytic model, using its own small fixed table
/// (not the bundled `pathloss_v2.json`), so these vectors do not move when the bundled table is
/// recalibrated. The same file is used verbatim by the Android twin of this task.
///
/// Reads with dart:io, not as a Flutter asset: plain `flutter test` has no asset bundle, and
/// paths are relative to the package root under `flutter test` (see
/// test/docs/user_guide_html_test.dart for the same pattern).
void main() {
  group('SharedVectorsTest', () {
    late Map<String, dynamic> data;
    late ContourCoefficients coefficients;

    setUpAll(() {
      final String text = File('test/pathloss/test_vectors.json').readAsStringSync();
      data = jsonDecode(text) as Map<String, dynamic>;

      final Map<String, dynamic> table = data['table'] as Map<String, dynamic>;
      final Map<String, ContourClassRow> classes = table.map((key, value) {
        final Map<String, dynamic> row = value as Map<String, dynamic>;
        return MapEntry(key, ContourClassRow(
            (row['k'] as num).toDouble(), (row['offset_db'] as num).toDouble()));
      });
      final Map<String, dynamic> nrOffsetJson = data['nr_offset_db'] as Map<String, dynamic>;
      final Map<String, double> nrOffsetByBand =
          nrOffsetJson.map((key, value) => MapEntry(key, (value as num).toDouble()));

      coefficients = ContourCoefficients(
        classes: classes,
        pooled: const <String, ContourClassRow>{},
        nrOffsetByBand: nrOffsetByBand,
        typicalPerReEirpDbmByTech: const <String, Map<String, double>>{},
        gatePassed: true,
      );
    });

    void expectRelativelyClose(double actual, double expected, String reason) {
      final double tolerance = expected.abs() * 1e-6;
      expect(actual, closeTo(expected, tolerance > 1e-9 ? tolerance : 1e-9), reason: reason);
    }

    test('every shared vector matches TransmitPower, AnalyticPathLossModel and ContourModel', () {
      final ContourModel model = ContourModel(coefficients);
      final List<dynamic> vectors = data['vectors'] as List<dynamic>;
      expect(vectors, isNotEmpty);

      for (final dynamic entry in vectors) {
        final Map<String, dynamic> v = entry as Map<String, dynamic>;
        final String reason = 'vector: $v';

        final NetworkType networkType =
            (v['technology'] as String) == 'NR' ? NetworkType.NR : NetworkType.LTE;
        final List<String> classParts = (v['class'] as String).split('|');
        final CityDensity density =
            CityDensity.values.firstWhere((d) => d.name == classParts[0]);
        final String band = classParts[1];

        final double frequencyMhz = (v['frequency_mhz'] as num).toDouble();
        final double bandwidthHz = (v['bandwidth_hz'] as num).toDouble();
        final double eirpW = (v['eirp_w'] as num).toDouble();
        final double patternDb = (v['pattern_db'] as num).toDouble();
        final double effectiveHeightM = (v['effective_height_m'] as num).toDouble();
        final double rungDbm = (v['rung_dbm'] as num).toDouble();

        // subcarriers: exact.
        final int subcarriers =
            TransmitPower.subcarriers(networkType, frequencyMhz, bandwidthHz);
        expect(subcarriers, (v['subcarriers'] as num).toInt(), reason: reason);

        // power_per_re_dbm: relative 1e-6. The vector's field is P itself (spec section 3:
        // `P = perReEirpDbm + relativePatternDb`), i.e. already pattern-adjusted -- confirmed by
        // the SUBURBAN|MID vectors, which share eirp/subcarriers but differ in pattern_db and in
        // this field by exactly that much.
        final double perReEirpDbmBase = TransmitPower.perReEirpDbm(eirpW, subcarriers);
        final double p = perReEirpDbmBase + patternDb;
        expectRelativelyClose(p, (v['power_per_re_dbm'] as num).toDouble(), reason);

        // hata_urban_intercept_db and hata_slope_db: relative 1e-6.
        final double aUrban =
            AnalyticPathLossModel.hataInterceptDb(CityDensity.URBAN, frequencyMhz, effectiveHeightM);
        expectRelativelyClose(
            aUrban, (v['hata_urban_intercept_db'] as num).toDouble(), reason);

        final double slope = AnalyticPathLossModel.hataSlopeDb(effectiveHeightM);
        expectRelativelyClose(slope, (v['hata_slope_db'] as num).toDouble(), reason);

        // distance_km: relative 1e-6. budgetDb = P - rung.
        final double budgetDb = p - rungDbm;
        final double distanceKm =
            model.distanceKm(networkType, density, frequencyMhz, effectiveHeightM, budgetDb);
        expectRelativelyClose(distanceKm, (v['distance_km'] as num).toDouble(), reason);

        // Sanity: the vector's own k/offset_db (informational, not re-verified above) are
        // exactly what the table this vector was built from carries for that class/band. The
        // vector's own "nr_offset_db" is the EFFECTIVE offset already gated by technology (zero
        // for every LTE vector, even when the table's band entry is non-zero), which is exactly
        // what the distance_km check above exercises via ContourModel -- not re-checked here
        // separately, since coefficients.nrOffsetDb(band) alone does not know the technology.
        expect(coefficients.forClass(density, band).k, (v['k'] as num).toDouble(), reason: reason);
        expect(coefficients.forClass(density, band).offsetDb, (v['offset_db'] as num).toDouble(),
            reason: reason);
      }
    });
  });
}
