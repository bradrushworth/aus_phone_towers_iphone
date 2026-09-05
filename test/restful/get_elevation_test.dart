import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/elevation_response.dart';
import 'package:phonetowers/restful/get_elevation.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart' show CityDensity;

/// A fake [Api] that hands back a canned [ElevationResponse] (or null, mimicking a Dio error)
/// instead of making a network call. [Api.getSiteTerrainData] and friends are plain instance
/// methods with no interface, so overriding one on a subclass is the direct way to stub it;
/// `super.initialize()` runs the real constructor, which only builds an unused Dio client
/// (gated on AppConstants.isDebug, false by default) and is otherwise side-effect-free.
class _FakeApi extends Api {
  _FakeApi(this._response) : super.initialize();

  final ElevationResponse? _response;

  @override
  Future<ElevationResponse?> getElevationDataApi(String path,
          {Map<String, String> headers = const {}}) async =>
      _response;
}

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

    test('Android build uses the legacy key when no Android key is configured', () {
      expect(
        GetElevation.selectTerrainKey(
            isWeb: false, isIOS: false, defaultKey: legacy, iosKey: ios),
        legacy,
      );
    });

    test('Android build uses the Android-restricted key once configured', () {
      expect(
        GetElevation.selectTerrainKey(
            isWeb: false,
            isIOS: false,
            defaultKey: legacy,
            iosKey: ios,
            androidKey: 'android-key'),
        'android-key',
      );
    });

    test('the Android key never leaks onto web or iOS', () {
      expect(
        GetElevation.selectTerrainKey(
            isWeb: true,
            isIOS: false,
            defaultKey: legacy,
            iosKey: ios,
            androidKey: 'android-key'),
        legacy,
      );
      expect(
        GetElevation.selectTerrainKey(
            isWeb: false,
            isIOS: true,
            defaultKey: legacy,
            iosKey: ios,
            androidKey: 'android-key'),
        ios,
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

    test('Android proves app identity once its own restricted key is configured', () {
      // The web service checks these headers against the key's registered
      // (package, SHA-1) rows; the fingerprint constant matches the registered
      // debug-keystore cert (54:EF:0F:58:...:D1:78, colon-free uppercase).
      expect(
        GetElevation.elevationRequestHeaders(
            isWeb: false, isIOS: false, hasAndroidKey: true),
        {
          'X-Android-Package': 'au.com.bitbot.phonetowers.flutter',
          'X-Android-Cert': '54EF0F58CE4DE39A1C29538EE795E1DE92BFD178',
        },
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

  group('GetElevation._warnTerrainUnavailableOnce (I1)', () {
    // _warnedTerrainUnavailable is a static, once-per-session flag, so this whole scenario runs
    // as ONE sequential test rather than several independent ones — that pins the order the
    // three calls below must happen in, regardless of how the test runner schedules tests
    // within a file. (Different test *files* each get their own isolate, so this does not leak
    // into other test files.)
    test(
        'a callback-less call does not consume the budget; a real callback then fires once, '
        'and only once, for the rest of the session', () async {
      final Site site = Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN);
      final ElevationResponse failing = ElevationResponse(
          results: [], status: 'REQUEST_DENIED', errorMessage: 'not authorized');

      // Before I1: startGoogleElevation always called this with no showSnackBar, which used to
      // set _warnedTerrainUnavailable = true via `showSnackBar?.call(...)` even though nothing
      // was ever shown — burning the one warning the user could have seen for the rest of the
      // session. Must not crash, and must still release the caller's wait via the finally block.
      final GetElevation silent =
          GetElevation(site: site, url: 'https://example.invalid', showSnackBar: null)
            ..api = _FakeApi(failing);
      await silent.getElevationData();
      expect(site.finishedDownloadingElevations, isTrue);

      // A real callback, still within the same session: if the silent call above had wrongly
      // consumed the budget, this would never fire.
      int calls = 0;
      final GetElevation loud = GetElevation(
          site: site,
          url: 'https://example.invalid',
          showSnackBar: ({
            required String message,
            Duration duration = const Duration(seconds: 1),
            bool isDismissible = false,
          }) {
            calls++;
          })
        ..api = _FakeApi(failing);
      await loud.getElevationData();
      expect(calls, 1,
          reason: 'the earlier callback-less call must not have burned the once-per-session '
              'budget');

      // A second real callback: now that one callback has genuinely run, the once-per-session
      // guard must suppress any further warning for the rest of the session.
      int callsAgain = 0;
      final GetElevation loudAgain = GetElevation(
          site: site,
          url: 'https://example.invalid',
          showSnackBar: ({
            required String message,
            Duration duration = const Duration(seconds: 1),
            bool isDismissible = false,
          }) {
            callsAgain++;
          })
        ..api = _FakeApi(failing);
      await loudAgain.getElevationData();
      expect(callsAgain, 0,
          reason: 'still once per session now that a callback has actually run');
    });
  });
}
