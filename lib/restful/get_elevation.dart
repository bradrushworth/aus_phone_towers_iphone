import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/elevation_response.dart';

import 'get_licenceHRP.dart';

typedef void ShowSnackBar({
  required String message,
  Duration duration,
  bool isDismissible,
});

class GetElevation {
  /// The iOS app's bundle identifier, sent as X-Ios-Bundle-Identifier so the Elevation web
  /// service can verify the iOS-restricted key's identity (mirrors the Java app's
  /// GoogleApiIdentity for its Android-restricted key).
  static const String iosBundleId = 'au.com.bitbot.phonetowers';

  /// The website the legacy key is Websites-restricted to. Google accepts Elevation
  /// requests carrying a matching Referer (live-verified 2026-08-23), so the Android build
  /// sends it explicitly until au.com.bitbot.phonetowers.flutter gets its own
  /// Android-restricted key.
  static const String siteReferer = 'https://ausphonetowers.com.au/';

  /// The Android app's identity for its own Android-restricted key (used once
  /// terrainAwarenessKeyAndroid is configured). The Elevation web service checks these
  /// headers against the key's registered (package, SHA-1) rows — it cannot verify which
  /// certificate actually signed the APK, so any registered pair works; this fingerprint is
  /// the registered debug-keystore cert (54:EF:0F:58:...:D1:78) in the colon-free uppercase
  /// form the headers require.
  static const String androidPackage = 'au.com.bitbot.phonetowers.flutter';
  static const String androidCertSha1 = '54EF0F58CE4DE39A1C29538EE795E1DE92BFD178';

  static final List<double> SAMPLE_DISTANCES = [
    0.50,
    0.75,
    1,
    1.25,
    1.5,
    1.75,
    2,
    2.25,
    2.5,
    3,
    3.5,
    4,
    4.5,
    5.5,
    7,
    8.5,
    10,
    13,
    16
  ];
  Logger logger = Logger();
  Site site;
  Api api = Api.initialize();
  String url;
  Map<String, String> headers;
  ShowSnackBar? showSnackBar;

  GetElevation(
      {required this.url,
      required this.site,
      this.headers = const {},
      this.showSnackBar});

  /// Which Maps key the elevation request should use. iOS has its own iOS-restricted key
  /// (proved via [iosBundleId]); Android uses its own Android-restricted key once one is
  /// configured (proved via [androidPackage]/[androidCertSha1]); everything else keeps the
  /// legacy key. Pure and static so it is unit-testable.
  static String selectTerrainKey(
      {required bool isWeb,
      required bool isIOS,
      required String defaultKey,
      required String iosKey,
      String androidKey = ''}) {
    if (!isWeb && isIOS && iosKey.isNotEmpty) return iosKey;
    if (!isWeb && !isIOS && androidKey.isNotEmpty) return androidKey;
    return defaultKey;
  }

  /// The identity headers the elevation request must carry for its key's restriction:
  /// iOS proves its bundle id; Android proves its package + signing-cert SHA-1 once its own
  /// Android-restricted key is configured ([hasAndroidKey]), else it sends the site Referer
  /// the legacy key is restricted to; web sends nothing (XHR forbids overriding Referer —
  /// the browser sends the page origin, and the CORS proxy forwards it to Google). Pure and
  /// static.
  static Map<String, String> elevationRequestHeaders(
      {required bool isWeb, required bool isIOS, bool hasAndroidKey = false}) {
    if (isWeb) return const {};
    if (isIOS) return const {'X-Ios-Bundle-Identifier': iosBundleId};
    if (hasAndroidKey) {
      return const {
        'X-Android-Package': androidPackage,
        'X-Android-Cert': androidCertSha1,
      };
    }
    return const {'Referer': siteReferer};
  }

  /// A human-readable description of a failed elevation response, or null when it is OK.
  /// Google reports failures (REQUEST_DENIED, OVER_QUERY_LIMIT, ...) inside an HTTP 200,
  /// so the body's status field is the only failure signal. Pure and static.
  static String? describeElevationFailure(String? status, String? errorMessage) {
    if (status == null || status == 'OK') return null;
    if (errorMessage == null || errorMessage.isEmpty) return status;
    return '$status: $errorMessage';
  }

  static String getPositionsString(LatLng latLng) {
    StringBuffer sb = StringBuffer();
    sb.write(latLng.latitude.toStringAsFixed(3));
    sb.write(",");
    sb.write(latLng.longitude.toStringAsFixed(3));
    sb.write("|");

    int measurements = 1;
    num loops = 0;

    for (double dist in SAMPLE_DISTANCES) {
      // Randomise the layout a little bit
      loops += dist;
      // Don't query the elevation for every point when at a close radius
      int modulo =
          (3 + (SAMPLE_DISTANCES[SAMPLE_DISTANCES.length - 1]) / dist).toInt();
      // Limit the modulo for close accuracy. Using prime number for randomness
      if (modulo > 17) modulo = 17;
      for (double dir = 0; dir < 360; dir += 2.5) {
        loops++;
//                // Don't query the elevation for every point when at a close radius
        if (loops % modulo != 0) continue;

        LatLng point = GetLicenceHRP.travel(latLng, dir, dist);
        sb.write(point.latitude.toStringAsFixed(3));
        sb.write(",");
        sb.write(point.longitude.toStringAsFixed(3));
        sb.write("|");

        //mapsActivity.addMarkerToMap(new MarkerOptions().position(point).title("Elevation").alpha(0.2f), site);
        measurements++;
      }

    }

    String positionString = sb.toString().substring(0, sb.length - 1);
    //debugPrint('GetElevation", "getPositionsString: measurements=$measurements and positionString is $positionString');
    return positionString;
  }

  Future getElevationData() async {
    try {
      ElevationResponse? elevationResponse =
          await api.getElevationDataApi(url, headers: headers);

      // Google reports failures as HTTP 200 with a non-OK status and an empty results
      // array (e.g. REQUEST_DENIED for a restricted key with no identity). Looping over
      // the zero rows used to "succeed" silently — and, worse, the finished flag was only
      // set inside the loop, so an empty response left GetLicenceHRP's wait loop spinning
      // forever. Surface the failure instead; the finally below always releases the wait.
      String? failure = describeElevationFailure(
          elevationResponse?.status, elevationResponse?.errorMessage);
      if (elevationResponse == null || failure != null) {
        logger.e('Elevation request failed: ${failure ?? "no response"}');
        _warnTerrainUnavailableOnce(failure ?? 'no response');
        return;
      }

      List<Results> rows = elevationResponse.results ?? [];
      for (Results row in rows) {
        double elevation = row.elevation.toDouble();
        double lat = row.location!.lat.toDouble();
        double lng = row.location!.lng.toDouble();
        site.addElevation(LatLng(lat, lng), elevation);
      }
    } finally {
      // Always release GetLicenceHRP's wait loop — on failure the polygons simply draw
      // without terrain, and the user has been told why.
      site.finishedDownloadingElevations = true;
    }
  }

  /// Tell the user terrain data is unavailable — once per app session, not once per site.
  static bool _warnedTerrainUnavailable = false;

  void _warnTerrainUnavailableOnce(String failure) {
    if (_warnedTerrainUnavailable) return;
    // I1: only consume the once-per-session budget when a callback actually runs. This used
    // to set the flag unconditionally via `showSnackBar?.call(...)` — a silent caller (no
    // showSnackBar supplied) still burned the flag, so the one caller that could have shown
    // the warning next never got the chance.
    final ShowSnackBar? callback = showSnackBar;
    if (callback == null) return;
    _warnedTerrainUnavailable = true;
    callback(
      message: 'Terrain data is unavailable (${failure.split(':').first}) — '
          'drawing coverage without terrain.',
      duration: const Duration(seconds: 6),
      isDismissible: true,
    );
  }
}
