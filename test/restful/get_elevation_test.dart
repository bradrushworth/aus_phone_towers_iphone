import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/restful/get_elevation.dart';

/// Regression tests for the elevation key selection and response status check.
///
/// Background (sister change to the Java app's fix, problem report 2026-08-23, Tasmania):
/// Google returns Elevation web-service failures as an HTTP 200 whose body carries a non-OK
/// `status` and an empty `results` array (e.g. REQUEST_DENIED for a restricted key queried
/// without app-identity headers). The old code looped over the zero rows without error AND —
/// worse than Java — only set `site.finishedDownloadingElevations` inside that loop, so an
/// empty response left the licence-HRP wait loop spinning forever. The status must be checked
/// and surfaced, and the finished flag must be set on every outcome.
///
/// The iOS build uses its own iOS-restricted key (proved to the web service via the
/// X-Ios-Bundle-Identifier header); other platforms keep the legacy key until they get their
/// own restricted arrangement.
void main() {
  group('GetElevation.describeElevationFailure', () {
    test('OK status is not a failure', () {
      expect(GetElevation.describeElevationFailure('OK', null), isNull);
    });

    test('missing status is treated as OK', () {
      expect(GetElevation.describeElevationFailure(null, null), isNull);
    });

    test('REQUEST_DENIED is reported with the Google error message', () {
      // The exact shape Google returns for a restricted key queried without identity
      // headers (live-captured 2026-08-23).
      expect(
        GetElevation.describeElevationFailure('REQUEST_DENIED',
            'This IP, site or mobile application is not authorized to use this API key.'),
        'REQUEST_DENIED: This IP, site or mobile application is not authorized to use this API key.',
      );
    });

    test('non-OK status without a message still reports the status', () {
      expect(GetElevation.describeElevationFailure('OVER_QUERY_LIMIT', null),
          'OVER_QUERY_LIMIT');
      expect(GetElevation.describeElevationFailure('OVER_QUERY_LIMIT', ''),
          'OVER_QUERY_LIMIT');
    });
  });

  group('GetElevation.selectTerrainKey', () {
    const String legacy = 'legacy-key';
    const String ios = 'ios-key';

    test('iOS build uses the iOS-restricted key', () {
      expect(
        GetElevation.selectTerrainKey(
            isWeb: false, isIOS: true, defaultKey: legacy, iosKey: ios),
        ios,
      );
    });

    test('iOS build falls back to the legacy key when no iOS key is configured', () {
      expect(
        GetElevation.selectTerrainKey(
            isWeb: false, isIOS: true, defaultKey: legacy, iosKey: ''),
        legacy,
      );
    });

    test('web build uses the legacy key (an iOS-restricted key would be denied)', () {
      expect(
        GetElevation.selectTerrainKey(
            isWeb: true, isIOS: false, defaultKey: legacy, iosKey: ios),
        legacy,
      );
    });

    test('Android build uses the legacy key', () {
      expect(
        GetElevation.selectTerrainKey(
            isWeb: false, isIOS: false, defaultKey: legacy, iosKey: ios),
        legacy,
      );
    });
  });

  group('GetElevation.elevationRequestHeaders', () {
    test('iOS proves its identity with the bundle-identifier header', () {
      expect(
        GetElevation.elevationRequestHeaders(isWeb: false, isIOS: true),
        {'X-Ios-Bundle-Identifier': 'au.com.bitbot.phonetowers'},
      );
    });

    test('Android sends the site referer the legacy key is restricted to', () {
      // Interim arrangement: the legacy key is Websites-restricted to
      // ausphonetowers.com.au, and Google accepts Elevation requests that carry a
      // matching Referer (live-verified 2026-08-23). Replaced by a proper
      // Android-restricted key once au.com.bitbot.phonetowers.flutter is registered.
      expect(
        GetElevation.elevationRequestHeaders(isWeb: false, isIOS: false),
        {'Referer': 'https://ausphonetowers.com.au/'},
      );
    });

    test('web sends nothing extra — the browser sets the Referer itself', () {
      // XHR forbids scripts overriding Referer; the browser sends the page origin,
      // and the CORS proxy must forward it to Google.
      expect(
        GetElevation.elevationRequestHeaders(isWeb: true, isIOS: false),
        isEmpty,
      );
    });
  });
}
