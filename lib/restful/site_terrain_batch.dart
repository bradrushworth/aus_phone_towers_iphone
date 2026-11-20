import 'dart:async';

import 'package:logger/logger.dart';

import '../networking/api.dart';
import 'rest_filter.dart';

/// Bounded fetch of `site_terrain.ground_m` for many sites at once, for the tower export.
/// Mirrors the Android app's `SiteTerrainBatchFetcher`.
///
/// `GetSiteTerrain` (which feeds map drawing) is neither used nor changed: this reads only
/// `site_id` and `ground_m` (not the large profile), [batchSize] sites per request with an OR
/// filter. Requests run [poolSize] at a time and the whole call gives up after the deadline;
/// sites not answered simply have no terrain-model height. A failed or missing batch (a 404
/// included) only leaves its own sites unverified and never throws.
class SiteTerrainBatchFetcher {
  SiteTerrainBatchFetcher._();

  static const int batchSize = 50;
  static const int poolSize = 3;
  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration defaultDeadline = Duration(seconds: 20);

  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_\-]+$');

  /// Only plain ids go into a filter: an operator character in a value would give ERROR #121.
  static bool isUsableId(String? id) =>
      RestFilter.isUsableValue(id) && _safeId.hasMatch(id!.trim());

  /// Pure: the `_filter` clause (not URL encoded) for one batch, or null when no id is usable.
  /// A bare `0` is zero-padded by [RestFilter.zeroSafe].
  static String? buildFilter(Iterable<String?> siteIds) {
    final List<String> clauses = <String>[];
    for (final String? id in siteIds) {
      if (!isUsableId(id)) continue;
      final String trimmed = id!.trim();
      clauses.add('site_id==${trimmed == '0' ? RestFilter.zeroSafe(0) : trimmed}');
    }
    return clauses.isEmpty ? null : clauses.join('||');
  }

  /// Pure: splits the distinct usable ids into batches of at most [size].
  static List<List<String>> batches(Iterable<String?> siteIds, int size) {
    final Set<String> distinct = <String>{};
    for (final String? id in siteIds) {
      if (isUsableId(id)) distinct.add(id!.trim());
    }
    final List<List<String>> out = <List<String>>[];
    List<String> current = <String>[];
    for (final String id in distinct) {
      current.add(id);
      if (current.length == size) {
        out.add(current);
        current = <String>[];
      }
    }
    if (current.isNotEmpty) out.add(current);
    return out;
  }

  /// Pure: the request path for one batch, the filter encoded like `GetSiteTerrain.urlFor`.
  /// Null when no id in [batch] is usable.
  static String? urlFor(List<String> batch) {
    final String? filter = buildFilter(batch);
    if (filter == null) return null;
    return '/towers/site_terrain/?_view=json&_expand=no&_count=${batch.length}'
        '&_filter=${Uri.encodeComponent(filter)}&_fields=site_id%2Cground_m';
  }

  /// Pure: site_id to ground_m from a decoded RESTify response; rows without both are skipped.
  static Map<String, int> parseRows(Map<String, dynamic>? json) {
    final Map<String, int> out = <String, int>{};
    final dynamic restify = json?['restify'];
    final dynamic rows = restify is Map ? restify['rows'] : null;
    if (rows is! List) return out;
    for (final dynamic row in rows) {
      final dynamic values = row is Map ? row['values'] : null;
      if (values is! Map) continue;
      final String? id = _value(values, 'site_id');
      final String? ground = _value(values, 'ground_m');
      final int? metres =
          ground == null ? null : (int.tryParse(ground) ?? double.tryParse(ground)?.round());
      if (id != null && metres != null) out[id] = metres;
    }
    return out;
  }

  static String? _value(Map<dynamic, dynamic> values, String key) {
    final dynamic field = values[key];
    if (field is! Map) return null;
    final dynamic raw = field['value'];
    if (raw is String) return raw;
    if (raw is num) return '$raw';
    return null;
  }

  /// site_id to ground_m for every site answered before the deadline. Never throws.
  static Future<Map<String, int>> fetchGround(
    Iterable<String?> siteIds,
    Api api, {
    Duration deadline = defaultDeadline,
    Logger? logger,
  }) async {
    final Map<String, int> result = <String, int>{};
    final List<List<String>> queue = batches(siteIds, batchSize);
    if (queue.isEmpty) return result;
    final Logger log = logger ?? Logger();

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final List<String> batch = queue.removeAt(0);
        final String? url = urlFor(batch);
        if (url == null) continue;
        try {
          final Map<String, dynamic>? json =
              await api.getSiteTerrainData(url).timeout(requestTimeout);
          result.addAll(parseRows(json));
        } catch (e) {
          // Timeout or a bad response: this batch's sites export without a terrain-model height.
          log.w('SiteTerrainBatchFetcher: batch failed: $e');
        }
      }
    }

    final int workers = poolSize < queue.length ? poolSize : queue.length;
    try {
      await Future.wait(<Future<void>>[for (int i = 0; i < workers; i++) worker()])
          .timeout(deadline);
    } on TimeoutException {
      queue.clear();
      log.w('SiteTerrainBatchFetcher: deadline reached with ${result.length} answers');
    }
    return Map<String, int>.of(result);
  }
}
