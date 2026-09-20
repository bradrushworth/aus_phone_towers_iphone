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
  /// test. This is the FINAL, gated table (2026-09-20 5G calibration).
  static const String bundledTableSha256 =
      '35828a63dc20bb76756e8f501ab12a564461673bc8d9980a9cfb4d83e73bb366';

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

  /// Carrier `mnc` (as a string, e.g. `"1"`) or `"default"` -> extra loss for NR on a TDD band
  /// (section 2-3). Zero for LTE, and for NR on an FDD band; that gating is the caller's job (see
  /// [ContourModel]), not this table's. A valid table always has `"default"`.
  final Map<String, double> nrTddOffsetByMnc;

  /// `technology` (`LTE`/`NR`) -> `band` -> typical per-RE EIRP, dBm. Used in place of
  /// `TransmitPower.perReEirpDbm` when the registered EIRP is not usable. A valid table always
  /// has both technologies, each with all three bands (see [typicalPerReEirpDbm]).
  final Map<String, Map<String, double>> typicalPerReEirpDbmByTech;

  /// Whether the calibration run that produced this table passed its held-out gate
  /// (`evidence.gate_passed`); see section 7 of the spec.
  final bool gatePassed;

  const ContourCoefficients({
    required this.classes,
    required this.pooled,
    required this.nrTddOffsetByMnc,
    required this.typicalPerReEirpDbmByTech,
    required this.gatePassed,
  });

  /// The class row for `density|band`, else [band]'s pooled row.
  ContourClassRow forClass(CityDensity density, String band) {
    return classes['${density.name}|$band'] ?? pooled[band]!;
  }

  /// Extra loss for NR on a TDD band, for carrier [mnc]: that carrier's own value, else the
  /// table's `default` (also what an unknown carrier -- conventionally passed as mnc `0` -- gets).
  /// Zero if the table has neither (a hand-built table in a test, say; [parse] never produces
  /// one without `default`).
  double nrTddOffsetDb(int mnc) =>
      nrTddOffsetByMnc[mnc.toString()] ?? nrTddOffsetByMnc['default'] ?? 0.0;

  /// Typical per-RE EIRP (dBm) for [networkType]/[band]. Throws [StateError] if the table has no
  /// entry for it: [parse] rejects a table missing one, so reaching this means a coefficients
  /// table was built directly (e.g. in a test) without that validation -- silently returning 0
  /// dBm here would draw a tiny, bogus contour instead of surfacing the bug.
  double typicalPerReEirpDbm(NetworkType networkType, String band) {
    final double? value = typicalPerReEirpDbmByTech[networkType.name]?[band];
    if (value == null) {
      throw StateError('ContourCoefficients.typicalPerReEirpDbm: no entry for '
          '${networkType.name}/$band');
    }
    return value;
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
      nrTddOffsetByMnc: _parseNrTddOffsetMap(root['nr_tdd_offset_db']),
      typicalPerReEirpDbmByTech: _parseTypicalPowerMap(
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

  /// Hard-coded copies of the bundled table's three pooled rows, its `default` TDD loss and the
  /// typical per-RE EIRP powers -- used when the bundled asset cannot be read or parsed.
  /// [classes] is intentionally empty (every density falls back to [pooled] via [forClass]), and
  /// [nrTddOffsetByMnc] intentionally carries only `default` (an unknown carrier gets that
  /// anyway; there is no fallback-safe way to guess a specific carrier's own value).
  ///
  /// A unit test asserts the pooled rows, the `default` TDD loss AND the typical per-RE powers
  /// all equal the bundled file's own values, so none of them can silently drift from it.
  factory ContourCoefficients.fallback() {
    return const ContourCoefficients(
      classes: <String, ContourClassRow>{},
      pooled: <String, ContourClassRow>{
        'LOW': ContourClassRow(0.74, 3.68),
        'MID': ContourClassRow(0.81, -4.34),
        'HIGH': ContourClassRow(0.85, -8.49),
      },
      nrTddOffsetByMnc: <String, double>{'default': 9.9},
      typicalPerReEirpDbmByTech: <String, Map<String, double>>{
        'LTE': <String, double>{'LOW': 36.1, 'MID': 34.6, 'HIGH': 30.6},
        'NR': <String, double>{'LOW': 36.5, 'MID': 30.5, 'HIGH': 46.2},
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

  /// Parses `nr_tdd_offset_db` (carrier mnc, or `"default"`, -> extra loss). A table without the
  /// key, or without a `"default"` entry inside it, is malformed (section 4 of the spec).
  static Map<String, double> _parseNrTddOffsetMap(dynamic node) {
    final Map<String, double> result = _parseDoubleMap(node, 'nr_tdd_offset_db');
    if (!result.containsKey('default')) {
      throw FormatException('ContourCoefficients.parse: "nr_tdd_offset_db" has no "default"');
    }
    return result;
  }

  /// Parses `typical_per_re_eirp_dbm`, requiring both `LTE` and `NR`, each with `LOW`/`MID`/
  /// `HIGH` -- a table missing any of the six is malformed, since [typicalPerReEirpDbm] throws
  /// rather than silently drawing a bogus contour from a missing entry.
  static Map<String, Map<String, double>> _parseTypicalPowerMap(dynamic node, String field) {
    final Map<String, Map<String, double>> result = _parseNestedDoubleMap(node, field);
    for (final String tech in const <String>['LTE', 'NR']) {
      final Map<String, double>? bandMap = result[tech];
      if (bandMap == null) {
        throw FormatException('ContourCoefficients.parse: "$field" has no "$tech"');
      }
      for (final String band in const <String>['LOW', 'MID', 'HIGH']) {
        if (!bandMap.containsKey(band)) {
          throw FormatException('ContourCoefficients.parse: "$field.$tech" has no "$band"');
        }
      }
    }
    return result;
  }
}
