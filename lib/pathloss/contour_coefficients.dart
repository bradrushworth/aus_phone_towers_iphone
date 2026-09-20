import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart' show rootBundle;
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// One class's slope scale and offset from the bundled table (`k`, `offset_db` -- section 4 of
/// the path-loss model v2 spec). Two sections of the table share this shape: the 15 density|band
/// classes and the 3 band-pooled rows a class falls back to.
class ContourClassRow {
  final double k;
  final double offsetDb;

  const ContourClassRow(this.k, this.offsetDb);

  @override
  bool operator ==(Object other) =>
      other is ContourClassRow && k == other.k && offsetDb == other.offsetDb;

  @override
  int get hashCode => Object.hash(k, offsetDb);

  @override
  String toString() => 'ContourClassRow(k: $k, offsetDb: $offsetDb)';
}

/// The bundled coefficient table for the path-loss model v2
/// (`assets/pathloss/pathloss_v2.json`), parsed once and immutable from then on.
///
/// Mirrors the Android app's `au.com.bitbot.phonetowers.pathloss.ContourCoefficients`: same
/// names, same table bytes (see [bundledTableSha256]). Spec:
/// docs/pathloss/2026-09-20-model-v2-spec.md, section 4, in bradrushworth/aus_phone_towers_java.
class ContourCoefficients {
  /// The only `format` value this parser accepts.
  static const String expectedFormat = 'pathloss-v2';

  /// Where the bundled table is declared in pubspec.yaml and read from via [rootBundle].
  static const String bundledAssetPath = 'assets/pathloss/pathloss_v2.json';

  /// SHA-256 of the bundled asset's text, with every carriage return removed (a Windows checkout
  /// may hold CRLF) -- the one place this value is written down; see the "bundled table hash"
  /// test. PROVISIONAL: the coordinator will replace both the asset and this constant once the
  /// table is recalibrated on real evidence, per the hand-off note in brief F1.
  static const String bundledTableSha256 =
      'b5b3272ac2f8b87bcba0754ca26788eca72df675e8af2907bc13a4fbc5fb3b84';

  /// Set by [loadBundled] (via [parseOrFallback]) when the bundled asset could not be read or
  /// parsed; `null` otherwise, including before the first load. This class has no Crashlytics
  /// dependency of its own -- the call-site wiring is responsible for reporting it.
  static Object? bundledLoadError;

  static ContourCoefficients? _loaded;
  static Future<ContourCoefficients>? _loading;

  /// `density|band` -> row, e.g. `SUBURBAN|MID` (15 entries: 5 densities x 3 bands. `METRO` and
  /// `MEDIUM` are present as copies of `URBAN` and `SUBURBAN` -- the density classifier does not
  /// emit them today).
  final Map<String, ContourClassRow> classes;

  /// `band` -> row (3 entries: LOW, MID, HIGH), used by [forClass] when [classes] has no entry.
  final Map<String, ContourClassRow> pooled;

  /// `band` -> extra loss for NR (section 3). Zero for LTE; that split is the caller's job (see
  /// [ContourModel]), not this table's.
  final Map<String, double> nrOffsetByBand;

  /// `technology` (`LTE`/`NR`) -> `band` -> typical per-RE EIRP, dBm. Used in place of
  /// `TransmitPower.perReEirpDbm` when the registered EIRP is not usable.
  final Map<String, Map<String, double>> typicalPerReEirpDbmByTech;

  /// Whether the calibration run that produced this table passed its held-out gate
  /// (`evidence.gate_passed`); see section 7 of the spec.
  final bool gatePassed;

  const ContourCoefficients({
    required this.classes,
    required this.pooled,
    required this.nrOffsetByBand,
    required this.typicalPerReEirpDbmByTech,
    required this.gatePassed,
  });

  /// The class row for `density|band`, else [band]'s pooled row.
  ContourClassRow forClass(CityDensity density, String band) {
    return classes['${density.name}|$band'] ?? pooled[band]!;
  }

  /// Extra loss for NR in [band] (zero if the table has no entry for it).
  double nrOffsetDb(String band) => nrOffsetByBand[band] ?? 0.0;

  /// Typical per-RE EIRP (dBm) for [networkType]/[band] (zero if the table has no entry for it).
  double typicalPerReEirpDbm(NetworkType networkType, String band) {
    return typicalPerReEirpDbmByTech[networkType.name]?[band] ?? 0.0;
  }

  /// Parses the bundled table's JSON text. Throws [FormatException] if `format` is not
  /// [expectedFormat], or a required section is missing or the wrong shape. Callers that want
  /// the "never throw, fall back instead" behaviour described in the spec should call
  /// [parseOrFallback] rather than this directly.
  factory ContourCoefficients.parse(String jsonText) {
    final dynamic root = jsonDecode(jsonText);
    if (root is! Map || root['format'] != expectedFormat) {
      final dynamic format = root is Map ? root['format'] : null;
      throw FormatException(
          'ContourCoefficients.parse: format is "$format", not "$expectedFormat"');
    }
    final Map<dynamic, dynamic>? evidence =
        root['evidence'] is Map ? root['evidence'] as Map : null;
    return ContourCoefficients(
      classes: _parseRowMap(root['classes'], 'classes'),
      pooled: _parseRowMap(root['pooled'], 'pooled'),
      nrOffsetByBand: _parseDoubleMap(root['nr_offset_db'], 'nr_offset_db'),
      typicalPerReEirpDbmByTech: _parseNestedDoubleMap(
          root['typical_per_re_eirp_dbm'], 'typical_per_re_eirp_dbm'),
      gatePassed: evidence?['gate_passed'] == true,
    );
  }

  /// [parse], but never throws: a read/parse failure is recorded in [bundledLoadError] and
  /// [fallback] is returned instead.
  static ContourCoefficients parseOrFallback(String jsonText) {
    try {
      final ContourCoefficients parsed = ContourCoefficients.parse(jsonText);
      bundledLoadError = null;
      return parsed;
    } catch (e) {
      bundledLoadError = e;
      return ContourCoefficients.fallback();
    }
  }

  /// Hard-coded copies of the bundled table's three pooled rows, NR offsets of zero and the
  /// typical per-RE EIRP powers -- used when the bundled asset cannot be read or parsed.
  /// [classes] is intentionally empty: every density falls back to [pooled] via [forClass].
  ///
  /// A unit test asserts these constants equal the bundled file's own `pooled` /
  /// `typical_per_re_eirp_dbm` values, so they cannot silently drift from it.
  factory ContourCoefficients.fallback() {
    return const ContourCoefficients(
      classes: <String, ContourClassRow>{},
      pooled: <String, ContourClassRow>{
        'LOW': ContourClassRow(0.78, 3.78),
        'MID': ContourClassRow(0.82, -5.09),
        'HIGH': ContourClassRow(0.82, -8.18),
      },
      nrOffsetByBand: <String, double>{'LOW': 0.0, 'MID': 0.0, 'HIGH': 0.0},
      typicalPerReEirpDbmByTech: <String, Map<String, double>>{
        'LTE': <String, double>{'LOW': 36.1, 'MID': 34.6, 'HIGH': 30.6},
        'NR': <String, double>{'LOW': 36.1, 'MID': 34.6, 'HIGH': 30.6},
      },
      gatePassed: false,
    );
  }

  /// Loads and parses the bundled asset once, caching the result. Concurrent callers before the
  /// first load finishes all await the same in-flight read rather than starting their own
  /// (single-isolate "thread safety" -- section 4 of the spec).
  static Future<ContourCoefficients> loadBundled() {
    final ContourCoefficients? loaded = _loaded;
    if (loaded != null) {
      return Future<ContourCoefficients>.value(loaded);
    }
    return _loading ??= _load();
  }

  static Future<ContourCoefficients> _load() async {
    ContourCoefficients result;
    try {
      final String text = await rootBundle.loadString(bundledAssetPath);
      result = parseOrFallback(text);
    } catch (e) {
      bundledLoadError = e;
      result = ContourCoefficients.fallback();
    }
    _loaded = result;
    return result;
  }

  /// The loaded table, synchronously: [fallback] until [loadBundled] has completed at least
  /// once, then whatever it resolved to.
  static ContourCoefficients get current => _loaded ?? ContourCoefficients.fallback();

  static Map<String, ContourClassRow> _parseRowMap(dynamic node, String field) {
    if (node is! Map) {
      throw FormatException('ContourCoefficients.parse: missing "$field"');
    }
    final Map<String, ContourClassRow> result = {};
    node.forEach((key, value) {
      final Map<dynamic, dynamic> row = value as Map;
      result[key as String] = ContourClassRow(
        (row['k'] as num).toDouble(),
        (row['offset_db'] as num).toDouble(),
      );
    });
    return result;
  }

  static Map<String, double> _parseDoubleMap(dynamic node, String field) {
    if (node is! Map) {
      throw FormatException('ContourCoefficients.parse: missing "$field"');
    }
    final Map<String, double> result = {};
    node.forEach((key, value) {
      result[key as String] = (value as num).toDouble();
    });
    return result;
  }

  static Map<String, Map<String, double>> _parseNestedDoubleMap(dynamic node, String field) {
    if (node is! Map) {
      throw FormatException('ContourCoefficients.parse: missing "$field"');
    }
    final Map<String, Map<String, double>> result = {};
    node.forEach((techKey, bandMap) {
      result[techKey as String] = _parseDoubleMap(bandMap, '$field.$techKey');
    });
    return result;
  }
}
