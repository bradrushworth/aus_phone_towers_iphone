import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/restful/rest_filter.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/site_response.dart';
import 'package:phonetowers/ui/map_common.dart';
import 'package:phonetowers/ui/widgets/search_sheet.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef void ShowSnackBar({
  required String message,
  Duration duration,
  bool isDismissible,
});

/// One search result row, parsed from the site table.
class SearchResult {
  final String siteId;
  final String name;
  final String state;
  final String postcode;
  final String geohash;
  final double latitude;
  final double longitude;

  SearchResult(
      {required this.siteId,
      required this.name,
      required this.state,
      required this.postcode,
      required this.geohash,
      required this.latitude,
      required this.longitude});
}

/// F6 (UI overhaul port): a search fetches structured result rows for the [SearchSheet] —
/// ranked nearest-first, tapped into individually — instead of clearing the map, flying the
/// camera to all of Australia and bulk-downloading every matching tile. Recent searches
/// (last 10) persist here.
class SearchHelper with ChangeNotifier {
  static bool calculatingSearchResults = false;
  static int searchStatus = kSearchStopped;
  static final String DB_WILD_CARD = "%25";
  static const String _kRecentSearches = 'recentSearches';
  static const int _kMaxRecents = 10;
  Logger logger = new Logger();
  Api api = Api.initialize();
  final ShowSnackBar? showSnackBar;
  dynamic mapController; // Could be a platform or web Google map controller

  SearchHelper({this.showSnackBar, this.mapController});

  void setSearchStatus(bool status) {
    calculatingSearchResults = status;
    notifyListeners();
  }

  void executeSiteSearch(String query,
      void Function(String geoHash, bool expandGeohash) downloadTowers) {
    // A blank query would build a wildcard-only filter (and a blank postcode an
    // empty _filter value, which RESTify faults with HTTP 412 ERROR #120) —
    // there is nothing sensible to search for, so skip the request entirely.
    query = query.trim();
    if (!RestFilter.isUsableValue(query)) {
      showSnackBar!(
          message: 'Type a site name or postcode to search for',
          isDismissible: true);
      return;
    }
    PolygonHelper().clearSitePatterns(true);
    calculatingSearchResults = true;
    recordRecentSearch(query);
    String filter;
    if (RegExp(r'\d{4}').hasMatch(query)) {
      filter = 'postcode~~$query';
    } else {
      filter = 'name~~$DB_WILD_CARD${Uri.encodeFull(query)}$DB_WILD_CARD';
    }
    String fields = "site_id,name,state,postcode,latitude,longitude,geohash";
    String url =
        '/towers/site/?_view=json&_expand=no&_count=50&_filter=$filter&_fields=$fields';
    getSearch(url, query, downloadTowers);
  }

  /// Returns a Future (never `async void`): an `async void` body sends any failure straight to
  /// the zone as an unhandled error — the caller cannot catch it and the user just sees a dead
  /// search with an opaque console exception. Everything here is guarded so a network fault or a
  /// single malformed row reports itself instead of escaping.
  Future<void> getSearch(String url, String query,
      void Function(String geoHash, bool expandGeohash) downloadTowers) async {
    logger.d('get search url $url');
    final List<SearchResult> results = [];
    try {
      SiteResponse? rawResponse = await api.getSearchedData(url);

      int totalRows = rawResponse?.restify?.rows?.length ?? 0;
      for (int i = 0; i < totalRows; i++) {
        try {
          final values = rawResponse?.restify?.rows?[i].values;
          if (values == null) continue;
          results.add(SearchResult(
            siteId: _text(() => values.siteId?.value),
            // Some ACMA names arrive with HTML entities ("cnr MacArthur &amp; Northbourne").
            name: _unescape(_text(() => values.name?.value)),
            state: _text(() => values.state?.value),
            postcode: _text(() => values.postcode?.value),
            geohash: _text(() => values.geohash?.value),
            latitude: double.tryParse(_text(() => values.latitude?.value)) ?? 0,
            longitude: double.tryParse(_text(() => values.longitude?.value)) ?? 0,
          ));
        } catch (e, st) {
          // The generated response models declare `late String value`, so a null or absent
          // field throws while reading it. One bad row must not lose the whole result set.
          logger.w('Skipping malformed search row $i: $e', stackTrace: st);
        }
      }
    } catch (e, st) {
      logger.e('Search request failed', error: e, stackTrace: st);
      calculatingSearchResults = false;
      notifyListeners();
      showSnackBar?.call(
          message: 'Could not reach the tower database. Check your connection and try again.',
          isDismissible: true);
      return;
    }

    calculatingSearchResults = false;
    notifyListeners();

    final context = MapBodyState.currentInstance?.context;
    if (context != null && context.mounted) {
      await SearchSheet.show(context, query, results, downloadTowers, mapController);
    }
  }

  /// Reads a `late String value` field defensively — the generated models throw rather than
  /// return null when the server omits a column.
  static String _text(String? Function() read) {
    try {
      return read() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'");

  // ----- recent searches (last 10, newest first) -----

  static Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecentSearches) ?? '[]';
    try {
      return (jsonDecode(raw) as List).map((e) => '$e').toList();
    } catch (_) {
      return [];
    }
  }

  static void recordRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = await getRecentSearches();
    recents.remove(query);
    recents.insert(0, query);
    while (recents.length > _kMaxRecents) {
      recents.removeLast();
    }
    prefs.setString(_kRecentSearches, jsonEncode(recents));
  }
}
