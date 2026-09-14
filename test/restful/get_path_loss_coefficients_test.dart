import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/pathloss/path_loss_coefficients.dart';
import 'package:phonetowers/pathloss/path_loss_key.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart' show CityDensity;
import 'package:phonetowers/restful/get_path_loss_coefficients.dart';

/// A fake Dio [HttpClientAdapter] that hands back a canned JSON body per request path instead
/// of making a real network call, and records every path it was asked for so tests can assert
/// how many pages were actually fetched.
///
/// aptios-4uh: `get_path_loss_coefficients.dart` used to request `_count=100` with no paging,
/// so any stratum published past row 100 vanished silently and those sites fell back to
/// analytic Okumura-Hata with no error surfaced. These tests exercise the paging loop that
/// follows RESTify's `nextPage.href` link (the same pattern `GetLicenceHRP`/`GetDevices` use)
/// until every page has been collected.
class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._responsesByPath);

  final Map<String, Map<String, dynamic>> _responsesByPath;
  final List<String> requestedPaths = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requestedPaths.add(options.path);
    final Map<String, dynamic>? body = _responsesByPath[options.path];
    if (body == null) {
      throw StateError('Unexpected request to ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// A RESTify `pathloss_coefficients` row for composite coefficient group (mnc, density),
/// distinguished by [mnc] so many rows can coexist in one fetch. Uses the composite key format
/// (`density|mnc|networkType|band`) — the only form the server has published since the
/// 2026-08-22 trainer re-baseline.
Map<String, dynamic> _row(int mnc, CityDensity density, double b0) {
  final String key =
      PathLossKey.compositeKey(mnc, NetworkType.LTE, 'n78', density);
  return {
    'href': '/towers/pathloss_coefficients/$mnc',
    'values': {
      'coeff_key': {'value': key},
      'form': {'value': 'log-distance'},
      'trained': {'value': '1'},
      'reference_power_dbm': {'value': '57.0'},
      'b0': {'value': b0.toString()},
      'b1': {'value': '1.0'},
      'b2': {'value': '2.0'},
      'b3': {'value': '3.0'},
      'sample_count': {'value': '10'},
      'r_squared': {'value': '0.9'},
    },
  };
}

/// Builds a RESTify page body from [rows], linking to [nextHref] when there is another page.
Map<String, dynamic> _page(List<Map<String, dynamic>> rows, {String? nextHref}) {
  return {
    'restify': {
      'rowCount': rows.length,
      'rows': rows,
      if (nextHref != null) 'nextPage': {'href': nextHref},
    },
  };
}

/// [count] distinct rows (unique by mnc, so they all survive merging), spread across the given
/// [densities] cyclically.
List<Map<String, dynamic>> _rows(int count, {int startMnc = 0}) {
  return [
    for (int i = 0; i < count; i++)
      _row(startMnc + i, CityDensity.values[i % CityDensity.values.length], i.toDouble()),
  ];
}

void main() {
  const String firstPagePath =
      '/towers/pathloss_coefficients/?_view=json&_expand=no&_count=100';

  group('GetPathLossCoefficients.fetchFromServer paging', () {
    test('a single, non-full page is read with no follow-up request', () async {
      final List<Map<String, dynamic>> rows = _rows(2);
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter({
        firstPagePath: _page(rows),
      });
      final Api api = Api.initialize()..dio.httpClientAdapter = adapter;

      final PathLossCoefficients? coeffs = await GetPathLossCoefficients.fetchFromServer(api: api);

      expect(coeffs, isNotNull);
      expect(coeffs!.allComposite.length, 2);
      expect(adapter.requestedPaths, [firstPagePath]);
    });

    test('several full pages are all followed and merged (the aptios-4uh bug)', () async {
      // 250 rows across three pages of 100/100/50 — well past the old hard _count=100 cap, so
      // strata from page 2 and 3 would previously vanish silently.
      final List<Map<String, dynamic>> allRows = _rows(250);
      final List<Map<String, dynamic>> page1 = allRows.sublist(0, 100);
      final List<Map<String, dynamic>> page2 = allRows.sublist(100, 200);
      final List<Map<String, dynamic>> page3 = allRows.sublist(200, 250);

      const String page2Path = '/towers/pathloss_coefficients/page2';
      const String page3Path = '/towers/pathloss_coefficients/page3';

      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter({
        firstPagePath: _page(page1, nextHref: page2Path),
        page2Path: _page(page2, nextHref: page3Path),
        page3Path: _page(page3), // last page, no nextPage
      });
      final Api api = Api.initialize()..dio.httpClientAdapter = adapter;

      final PathLossCoefficients? coeffs = await GetPathLossCoefficients.fetchFromServer(api: api);

      expect(coeffs, isNotNull);
      // Every one of the 250 rows made it into the merged result, including the ones that
      // only existed on page 2 and page 3.
      expect(coeffs!.allComposite.length, 250);
      expect(adapter.requestedPaths, [firstPagePath, page2Path, page3Path]);
    });

    test('an exact multiple of the page size still terminates via an empty next page', () async {
      // Exactly 200 rows over two full 100-row pages, where the server's nextPage link points
      // at a genuinely empty page rather than omitting nextPage on the last full page. The
      // loop must stop there rather than looping forever or throwing.
      final List<Map<String, dynamic>> allRows = _rows(200);
      final List<Map<String, dynamic>> page1 = allRows.sublist(0, 100);
      final List<Map<String, dynamic>> page2 = allRows.sublist(100, 200);

      const String page2Path = '/towers/pathloss_coefficients/page2';
      const String page3Path = '/towers/pathloss_coefficients/page3-empty';

      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter({
        firstPagePath: _page(page1, nextHref: page2Path),
        page2Path: _page(page2, nextHref: page3Path),
        page3Path: _page(const []), // empty page, no nextPage: end of pagination
      });
      final Api api = Api.initialize()..dio.httpClientAdapter = adapter;

      final PathLossCoefficients? coeffs = await GetPathLossCoefficients.fetchFromServer(api: api);

      expect(coeffs, isNotNull);
      expect(coeffs!.allComposite.length, 200);
      expect(adapter.requestedPaths, [firstPagePath, page2Path, page3Path]);
    });

    test('a fetch failure on a later page falls back to null rather than a partial set',
        () async {
      final List<Map<String, dynamic>> page1 = _rows(1);
      const String page2Path = '/towers/pathloss_coefficients/page2';

      final Api api = Api.initialize()
        ..dio.httpClientAdapter = _FakeHttpClientAdapter({
          firstPagePath: _page(page1, nextHref: page2Path),
          // page2Path deliberately absent: the fake adapter throws, simulating a network
          // failure partway through pagination.
        });

      final PathLossCoefficients? coeffs = await GetPathLossCoefficients.fetchFromServer(api: api);

      expect(coeffs, isNull);
    });
  });
}
