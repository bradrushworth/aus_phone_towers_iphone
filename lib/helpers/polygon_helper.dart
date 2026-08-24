import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:logger/logger.dart';

import '../model/device_detail.dart';
import '../model/height_distance_pair.dart';
import '../model/overlay.dart';
import '../model/site.dart';
import '../restful/get_elevation.dart';
import '../restful/get_licenceHRP.dart';
import '../utils/app_constants.dart';
import '../utils/polygon_container.dart';
import 'let_type_helper.dart';
import 'map_helper.dart';
import 'network_type_helper.dart';
import 'site_helper.dart';
import '../ui/map_common.dart';
import 'telco_helper.dart';

typedef void ShowSnackBar({
  required String message,
  Duration duration,
  bool isDismissible,
});

/// Fallback for the [ShowSnackBar] callback that most internal callers never supply.
///
/// [PolygonHelper.queryForSignalPolygon] takes a *nullable* callback but used to force-unwrap it
/// (`showSnackBar!`) before handing it to GetLicenceHRP. Three internal callers — refreshPolygons,
/// switchTerrainAwareness and clearSitePatterns — pass nothing, so any signal-strength / filter /
/// terrain change threw "Null check operator used on a null value" as soon as a coverage polygon
/// was on the map. That aborted the redraw loop part-way through, which is why the remaining
/// coverage then looked wrong. Routing to the live map state keeps the user-facing messages
/// (HRP failures and the like) rather than swallowing them.
void defaultShowSnackBar({
  required String message,
  Duration duration = const Duration(seconds: 1),
  bool isDismissible = false,
}) {
  final MapBodyState? state = MapBodyState.currentInstance;
  if (state != null && state.mounted) {
    state.showSnackbar(message: message, duration: duration, isDismissible: isDismissible);
  }
}

class PolygonHelper with ChangeNotifier {
  static final PolygonHelper _singleton = new PolygonHelper._internal();

  factory PolygonHelper() {
    return _singleton;
  }

  PolygonHelper._internal();

  static final double BEARING_START = 1.25;
  static final double BEARING_INCREMENT = 2.50;

  /// Polygon rendering precision — the bearing step (in degrees) used when tracing each
  /// signal-strength band. A smaller step draws more points and a smoother, more accurate
  /// shape (at the cost of CPU/time); a larger step is faster but blockier. Mirrors the
  /// Android app's polygon-point-count control. Default 2.5° ≈ 144 points per ring.
  static double polygonBearingIncrement = BEARING_INCREMENT;

  /// Named precision presets for the Polygon Precision menu.
  static const double kPolygonPrecisionLow = 5.0; // ~72 points per ring
  static const double kPolygonPrecisionMedium = 2.5; // ~144 points per ring (default)
  static const double kPolygonPrecisionHigh = 1.0; // ~360 points per ring

  /// Default signal-strength ring drawn on first launch (or before any stored
  /// preference is applied). Indexes into NetworkTypeHelper.getNetworkBars():
  /// 0 = Maximum, 1 = Strong, 2 = Good, 3 = Weak. We default to Good.
  static int polygonSignalStrengthPos = kGoodSignalStrength;
  static bool showPolygonBorders = true;
  static bool preventPolygonRefresh = false;

  static bool displayNotLteMultiplex = true;
  static bool displayFdMultiplex = true;
  static bool displayTdMultiplex = true;

  static bool calculateTerrain = false;
  static bool switchingBetweenTerrainAwareness = false;

  static Set<PolygonContainer> allPolygons = new Set<PolygonContainer>();
  static Map<Site, Map<DeviceDetails, Set<PolygonContainer>>> sitesPolygons =
      new Map<Site, Map<DeviceDetails, Set<PolygonContainer>>>();
  static late Map<Site, Map<DeviceDetails, Set<PolygonContainer>>> sitesPolygonsOppositeTerrain;
  static bool drawPolygonsOnClick = true;
  // When true, tapping a tower does NOT clear existing polygons, so multiple
  // towers' coverage can be shown together. Requested in issue #27.
  static bool multiTowerCoverage = false;
  static Logger logger = Logger();

  //static Set<Polygon> globalPolygons = Set<Polygon>();
  static List<MapOverlay> globalListPolygons = [];
  static CancelToken? cancelFetchingPolygonRequestToken;
  static String terrainAwarenessKey = '';

  /// The iOS-restricted Maps key (Elevation API enabled, bundle au.com.bitbot.phonetowers).
  /// Empty when the secrets file predates it — iOS then falls back to the legacy key.
  static String terrainAwarenessKeyIos = '';

  /// The Android-restricted Maps key (Elevation API enabled, package
  /// au.com.bitbot.phonetowers.flutter). Empty until one is provisioned — Android then
  /// falls back to the legacy key + site-Referer arrangement.
  static String terrainAwarenessKeyAndroid = '';

  /// Cache of generated label icons keyed by "text|argb" so we don't re-render text every time.
  static final Map<String, BitmapDescriptor> _labelIconCache =
      <String, BitmapDescriptor>{};

  /// Frequency / technology labels drawn along the outer signal ring (replaces the Android
  /// GroundOverlay text, since google_maps_flutter's Polygon has no text support).
  static List<MapOverlay> labelOverlays = [];

  void queryForSignalPolygon(Site site, bool refreshingPolygons, bool cachingPolygons,
      {Set<DeviceDetails>? specificDevices, ShowSnackBar? showSnackBar}) {
    // If we have decided not to refresh (because we are loading a saved state for instance)
    logger.d('inside query for signal polygon');

    if (preventPolygonRefresh) {
      return;
    }

    // Bail out if a download is already in flight for this site. The guard is only set
    // below, once we actually start a device's download (see SiteHelper.startSiteDownload) —
    // NOT here — so a call that turns out to just unregister the site's existing polygons
    // (e.g. from clearSitePatterns with refreshingPolygons == false, below) never leaves a
    // stale entry behind for the very next "real" queryForSignalPolygon call to get stuck on.
    // Each in-flight device chain decrements this counter when it terminates — successfully,
    // with an error, or via cancellation (see GetLicenceHRP.getLicenceHRPData's finally block)
    // — so the site can only get properly "stuck" here if that finally block never runs.
    if (SiteHelper.isSiteDownloadInFlight(site)) {
      return;
    }

    // Save bandwidth by caching polygons when cachingPolygons==true
    Map<DeviceDetails, Set<PolygonContainer>> polygonCache =
        Map<DeviceDetails, Set<PolygonContainer>>();

    if (sitesPolygons.containsKey(site)) {
      //Remove any existing polygons first (unless multi-tower coverage is on, in which case
      //other previously-shown towers' polygons should be left alone - see #27)
      if (!multiTowerCoverage) {
        globalListPolygons.removeWhere((mapOverlay) {
          return !mapOverlay.polygon!.polygonId.value.contains('developer');
        });
      }
      // Remove this site's labels too, so they don't linger once the polygon is gone.
      labelOverlays.removeWhere((mapOverlay) => mapOverlay.site == site);

      for (DeviceDetails device in sitesPolygons[site]!.keys) {
        Set<PolygonContainer> polygons = sitesPolygons[site]![device]!;
        //TODO implement below for loop
//        for (PolygonContainer polygonContainer in polygons) {
//          // Remove from map display
//          //polygonContainer.getPolygon().remove();//TODO think about this
//          //TODO no support for ground overlay. UPDATE: There is now!
////     for (GroundOverlay overlay : polygonContainer.getOverlays()) {
////     overlay.remove();
////     }
//        }
        // Retain polygons in case they can be reused
        polygonCache[device] = polygons;
      }

      if (!switchingBetweenTerrainAwareness) {
        // Remove from hashmap
        sitesPolygons.remove(site);
      }

      // Exit unless we are refreshing the polygons. This call is only unregistering the
      // site's existing polygons (no download guard was taken above), so a subsequent
      // "real" queryForSignalPolygon call for this site — e.g. the one map_common.dart
      // fires right after clearSitePatterns() on every tap — will find the site no
      // longer in sitesPolygons and fall through to actually (re)download it below,
      // exactly like a first-time tap on a site that's never been shown before.
      if (!refreshingPolygons) {
        return;
      }
    }

    if (calculateTerrain) {
      // Get elevation data from Google
      try {
        if (!site.startedDownloadingElevations) {
          site.startedDownloadingElevations = true;
          String positionsString = GetElevation.getPositionsString(site.getLatLng());
          // Each platform uses the key whose restriction it can satisfy, and sends the
          // identity that restriction is checked against — see GetElevation.
          final bool isIOS = !kIsWeb && Platform.isIOS;
          final bool hasAndroidKey = !kIsWeb &&
              !isIOS &&
              Platform.isAndroid &&
              terrainAwarenessKeyAndroid.isNotEmpty;
          final String key = GetElevation.selectTerrainKey(
              isWeb: kIsWeb,
              isIOS: isIOS,
              defaultKey: terrainAwarenessKey,
              iosKey: terrainAwarenessKeyIos,
              androidKey: hasAndroidKey ? terrainAwarenessKeyAndroid : '');
          String url = (kIsWeb ? 'https://api.bitbot.com.au/cors/' : '') +
              'https://maps.googleapis.com/maps/api/elevation/json?locations=$positionsString&key=$key';
          GetElevation(
                  site: site,
                  url: url,
                  headers: GetElevation.elevationRequestHeaders(
                      isWeb: kIsWeb, isIOS: isIOS, hasAndroidKey: hasAndroidKey),
                  showSnackBar: showSnackBar)
              .getElevationData();
        }
      } catch (e, stack) {
        site.startedDownloadingElevations = false;
        print(stack);
        return;
      }
    }

    // Prepare for the download
    if (!sitesPolygons.containsKey(site)) {
      sitesPolygons[site] = Map<DeviceDetails, Set<PolygonContainer>>();
    }

    //This is helpful in cancelling all apis which refers to this token
    cancelFetchingPolygonRequestToken = CancelToken();

    // Download the polygon data
    deviceLoop:
    for (DeviceDetails d in site.getDeviceDetailsMobile()) {
      int frequency = d.frequency! / 1000 ~/ 1000;

      // Don't download devices we are not interested in
      //Log.d("PolygonHelper", "queryForSignalPolygon: specificDevices=" + specificDevices);
      if (specificDevices != null && specificDevices.isNotEmpty) {
        // If we know the specific devices we are looking for, ignore the user's configuration
        if (!specificDevices.contains(d)) {
          // This isn't the connected device
          logger.d("PolygonHelper: queryForSignalPolygon: !devices.contains($d)");
          continue deviceLoop;
        }
      } else {
        // If we don't know the specific devices, use the menu configuration

        // Don't download network types we are hiding
        if (SiteHelper.hideNetworkType.contains(d.getNetworkType())) {
          logger.d(
              "PolygonHelper: queryForSignalPolygon: SiteHelper.hideNetworkType.contains(${d.getNetworkType()})");
          continue deviceLoop;
        }

        // Don't download LTE types we are hiding
        LteType lteType = d.getLteType();
        if (lteType == LteType.NOT_LTE && !displayNotLteMultiplex) {
          logger.d("PolygonHelper: queryForSignalPolygon: !displayNotLteMultiplex");
          continue deviceLoop;
        }
        if (lteType == LteType.TD_LTE && !displayTdMultiplex) {
          logger.d("PolygonHelper: queryForSignalPolygon: !displayTdMultiplex");
          continue deviceLoop;
        }
        if (lteType == LteType.FD_LTE && !displayFdMultiplex) {
          logger.d("PolygonHelper: queryForSignalPolygon: !displayFdMultiplex");
          continue deviceLoop;
        }

        // Don't download frequencies we are hiding
        for (List<int> range in SiteHelper.hideFrequency) {
          if (frequency >= range[0] && frequency <= range[1]) {
            logger.d("PolygonHelper: queryForSignalPolygon: r.contains($frequency)");
            continue deviceLoop;
          }
        }
      }

      if (cachingPolygons && polygonCache.containsKey(d)) {
        // Choice of implementations
        //ConcurrentHashMap<Polygon, List<GroundOverlay>> oldPolygons = polygonCache.get(d);
        //ConcurrentHashMap<Polygon, List<GroundOverlay>> newPolygons = redrawPolygons(site, d, oldPolygons);
        //sitesPolygons.get(site).put(d, newPolygons);

        // Draw the polygon, no need to download it again. However we do have to calculate it
        // again because the input parameters may have changed (like user settings).
        List<List<LatLng>> data = [];
        for (PolygonContainer? polygonContainer in polygonCache[d]!) {
          data.add(polygonContainer!.getPolygon().points);
        }
        createPolygon(
          data,
          site,
          d,
        );
        logger.d("PolygonHelper: queryForSignalPolygon: polygonCache.containsKey($d)");
        continue deviceLoop;
      }

      // Signal that the polygons have changed
      switchingBetweenTerrainAwareness = false;

      List<List<LatLng>> results = [];
      for (int i = 0; i <= PolygonHelper.getPolygonSignalStrengthPosition(); i++) {
        results.insert(i, []);
      }

      String? dri = d.deviceRegistrationIdentifier;
      if (dri == null || dri.isEmpty || MapHelper().developerMode) {
        //if (!site.getTelco().isTelecommunications()) {
        // If we can't do any better, lets create a simple circular polygon
        createBasicPolygon(d, site, results);
        //}
        logger.d(
            "PolygonHelper: queryForSignalPolygon: device_registration_identifier == null for [${site.siteId} , ${d.getNetworkType()} ,  $frequency ]");
        continue deviceLoop;
      }

      String filter = "device_registration_identifier%3D%3D" + dri;
      // stop_angle is needed to place each vertex at the middle of the sector the row measures:
      // ACMA publishes a mix of sector widths, so it cannot be assumed (see sectorHalfWidth).
      // %2C is an encoded comma.
      String fields = "start_angle%2Cstop_angle%2Cpower";
      String url =
          '/towers/licence_hrp/?_view=json&_expand=no&_count=360&_filter=$filter&_fields=$fields&_sort=start_angle ASC';

      // Claim the guard for this device's chain before firing it off — GetLicenceHRP
      // releases its contribution (SiteHelper.finishSiteDownload) in a finally block
      // regardless of how the chain terminates, so this always balances out.
      SiteHelper.startSiteDownload(site);

      GetLicenceHRP(
              site: site,
              device: d,
              list: results,
              url: url,
              showSnackBar: showSnackBar ?? defaultShowSnackBar,
              cancelToken: cancelFetchingPolygonRequestToken)
          .getLicenceHRPData();
    }
  }

  void createPolygon(List<List<LatLng>> data, Site site, DeviceDetails device) {
    Set<PolygonContainer> polygons = new Set<PolygonContainer>();

    for (int i = 0; i < data.length; i++) {
      if (data[i].length == 0) continue;

      int capacity = device.getAntennaCapacity();
      Telco telco = site.getTelco();
      int alpha = 50;
      if (TelcoHelper.isTelecommunications(telco)) {
        // Match the Java app exactly (PolygonHelper.createPolygon): base 10, not 20 — a
        // suburb stacks dozens of rings (per signal level × per antenna × per site), so a
        // doubled per-ring fill compounds into the near-opaque blue sheet reported on the
        // web build. The border alpha (30 + fill) lightens with it.
        alpha = 10;
        if (MapHelper.followGPS) {
          alpha += 20;
        }
        alpha += (math.log(1 + (capacity / (1000 * 1000))) * 2).toInt();
      }

      switch (MapHelper().mapMode) {
        case 2:
        case 3:
          {
            // Java adds 25 on satellite/hybrid, not 40.
            alpha += 25;
          }
          break;
      }

      int lineAlpha = 0;
      if (showPolygonBorders) lineAlpha = 30 + alpha;

      //Log.d("PolygonHelper", "i=" + i + " capacity=" + capacity + " alpha=" + alpha);
      Polygon po = Polygon(
        polygonId: PolygonId("polygon_${i}_${device.sddId}"),
        strokeColor:
            i != data.length - 1 ? Colors.transparent : TelcoHelper.getColor(telco, lineAlpha),
        strokeWidth: 6,
        fillColor: TelcoHelper.getColor(telco, alpha),
        points: data[i],
      );

      if (PolygonHelper.sitesPolygons.containsKey(site)) {
//        List<GroundOverlay> overlays = new ArrayList<>();
//
//                // Only draw frequency on the outer most polygon
//                if (i == data.size() - 1) {
//                    for (int j = (int) (Math.random() * 15); j < data.get(i).size() - 1; j = j + 15) {
//                        try {
//                            LatLng latLng = data.get(i).get(j);
//                            LatLng nextLatLng = data.get(i).get(j + 1);
//                            int towerDistance = (int) SphericalUtil.computeDistanceBetween(latLng, site.getLatLng());
//                            int towerBearing = (int) SphericalUtil.computeHeading(latLng, site.getLatLng());
//                            // Text of Frequency and Technology
//                            overlays.add(calculateTextOverlay(frequencyOverlay, towerBearing, towerDistance, latLng, nextLatLng, 17500, 5));
//                        } catch (IndexOutOfBoundsException e) {}
//                    }
//                }
//
//                if (CustomLocationListener.followGPS) {
//                    // Draw signal strength once on each polygon
//                    int azimuth = 0;
//                    try {
//                        azimuth = device.azimuth / 2; // Divide by 2 because we are downloading every second degree value?
//                    } catch (NullPointerException e) {}
//                    LatLng latLng, nextLatLng;
//                    try {
//                        latLng = data.get(i).get(azimuth + 1); // Straighten it up for some reason
//                        nextLatLng = data.get(i).get(azimuth + 3);
//                    } catch (IndexOutOfBoundsException e1) {
//                        latLng = data.get(i).get(0);
//                        try {
//                            nextLatLng = data.get(i).get(1);
//                        } catch (IndexOutOfBoundsException e2) {
//                            nextLatLng = data.get(i).get(0);
//                        }
//                    }
//                    int towerDistance = (int) SphericalUtil.computeDistanceBetween(latLng, site.getLatLng());
//                    int towerBearing = (int) SphericalUtil.computeHeading(latLng, site.getLatLng());
//                    // Signal strength on polygons
//                    overlays.add(calculateTextOverlay(signalStrengthOverlay, towerBearing, towerDistance, latLng, nextLatLng, 8500, 2));
//                }

        // Add the overlay to the polygon
        //globalPolygons.add(po);
        MapOverlay mapOverlay = MapOverlay(polygon: po, site: site);
        globalListPolygons.add(mapOverlay);
        notifyListeners();
        polygons.add(new PolygonContainer(order: i, polygon: po));

        // Draw frequency / technology labels along the outer-most ring (Android draws a
        // GroundOverlay of text here; google_maps_flutter has no Polygon text, so we use
        // Marker icons instead).
        if (i == data.length - 1) {
          addOuterRingLabels(site, device, data[i]);
        }
      } else {
        // Skip it, since it arrived too late
      }
    }

    // Be prepared for other threads removing the site
    if (sitesPolygons.containsKey(site)) {
      // Save the polygons
      allPolygons.addAll(polygons);
      sitesPolygons[site]![device] = polygons;
    } else {
      //PolygonHelper.globalPolygons.clear();
      // Clean up polygons that were received too late for the map
//    for (PolygonContainer polygonContainer in polygons) {
//    ///polygonContainer.getPolygon().remove();
////    for (GroundOverlay overlay : polygonContainer.getOverlays()) {
////    overlay.remove();
////    }
//    }
    }

    if (data.length > 0) {
      // This probably slows everything down
      // Map<String, Object> eventMap = Map<String, Object>();
      // eventMap['site_id'] = site.siteId!;
      // eventMap['site_telco'] = TelcoHelper.getName(site.getTelco());
      // eventMap['device_lteType'] = LteTypeHelper.getName(device.getLteType());
      // eventMap['device_networkType'] =
      //     NetworkTypeHelper.resolveNetworkToName(device.getNetworkType());
      // eventMap['device_antennaCapacity'] = device.getAntennaCapacity();
      // AnalyticsHelper()
      //     .sendCustomAnalyticsEvent(eventName: 'create_polygon', eventParameters: eventMap);
    }
  }

  static int getPolygonSignalStrengthPosition() {
    return polygonSignalStrengthPos;
  }

  /// Draw frequency + technology labels along the outer signal-strength ring, mirroring the
  /// Android app's GroundOverlay behaviour. google_maps_flutter's Polygon cannot render text, so
  /// we use lightweight Markers whose icons are bitmaps rendered from the label text.
  static Future<void> addOuterRingLabels(
      Site site, DeviceDetails device, List<LatLng> ring) async {
    if (ring.length < 3) return;
    // Remove any existing labels for this site so re-draws don't duplicate them.
    // Remove only this device's previous labels so re-draws don't duplicate them,
    // while other antennas on the same site keep their own labels.
    labelOverlays.removeWhere((MapOverlay overlay) =>
        overlay.site == site &&
        overlay.marker?.markerId.value.startsWith('label_${device.sddId}') == true);
    final Telco telco = site.getTelco();
    final int frequencyMhz = (device.frequency! / 1000 / 1000).toInt();
    final String tech = NetworkTypeHelper.resolveNetworkToName(device.getNetworkType());
    final String text = '$frequencyMhz MHz $tech';
    final Color color = TelcoHelper.getColor(telco, 255);
    await _buildLabels(site, device, ring, text, color);
  }

  static Future<void> _buildLabels(Site site, DeviceDetails device, List<LatLng> ring,
      String text, Color color) async {
    final BitmapDescriptor icon = await _createLabelIcon(text, color);
    if (!sitesPolygons.containsKey(site)) return;
    // Place the label right on the coverage polygon's outer line, rather than on top of the
    // shaded fill or the site marker. We anchor on the point of the outer ring furthest from
    // the tower, then nudge the marker a small margin further outward (away from the tower) so
    // it sits on the line itself instead of just inside the fill. HRP rings are irregular
    // (terrain, hills, sectors), so anchoring on the furthest point keeps labels clear of the
    // centre instead of piling up on the site.
    final LatLng sitePos = site.getLatLng();
    int bestIndex = 0;
    double maxDist = -1;
    for (int k = 0; k < ring.length; k++) {
      final double d = _distanceMetres(sitePos, ring[k]);
      if (d > maxDist) {
        maxDist = d;
        bestIndex = k;
      }
    }
    final LatLng furthest = ring[bestIndex];
    // Bearing from the tower out to the furthest ring point; nudge just past it so the label
    // sits right on the polygon's outer line rather than inside the shaded fill.
    final double bearing = _bearingDegrees(sitePos, furthest);
    final LatLng position =
        GetLicenceHRP.travel(furthest, bearing, kLabelOuterMarginKm);

    final Marker marker = Marker(
      markerId: MarkerId('label_${device.sddId}'),
      position: position,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      zIndex: 2,
      consumeTapEvents: false,
    );
    labelOverlays.add(MapOverlay(marker: marker, site: site));
    // PolygonHelper is a ChangeNotifier singleton; notify its listeners (the map) so the
    // newly added label markers are rendered. Called on the singleton instance because
    // this is a static method.
    PolygonHelper().notifyListeners();
  }

  /// How far (km) outside the furthest ring point the coverage label is pushed -- just enough
  /// to sit on the polygon's outer line instead of on top of the shaded fill or the site marker.
  static const double kLabelOuterMarginKm = 0.03;

  /// Great-circle distance (metres) between two coordinates, via the haversine formula.
  /// Used to find the ring point furthest from the tower when placing text labels.
  static double _distanceMetres(LatLng a, LatLng b) {
    const double earthRadius = 6371000.0;
    final double lat1 = a.latitude * math.pi / 180;
    final double lat2 = b.latitude * math.pi / 180;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180;
    final double dLon = (b.longitude - a.longitude) * math.pi / 180;
    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Initial bearing (degrees, 0 = north, clockwise) from coordinate [a] to [b].
  static double _bearingDegrees(LatLng a, LatLng b) {
    final double lat1 = a.latitude * math.pi / 180;
    final double lat2 = b.latitude * math.pi / 180;
    final double dLon = (b.longitude - a.longitude) * math.pi / 180;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Render a small rounded label bitmap for use as a Marker icon.
  static Future<BitmapDescriptor> _createLabelIcon(String text, Color color) async {
    final String key = '$text|${color.value}';
    final BitmapDescriptor? cached = _labelIconCache[key];
    if (cached != null) return cached;

    final TextStyle textStyle = const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout();
    const double padding = 6;
    final double width = painter.width + padding * 2;
    final double height = painter.height + padding * 2;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint bg = ui.Paint()..color = ui.Color(color.value);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, width, height),
        const ui.Radius.circular(6),
      ),
      bg,
    );
    painter.paint(canvas, ui.Offset(padding, padding));
    final ui.Image image =
        await recorder.endRecording().toImage(width.ceil(), height.ceil());
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final BitmapDescriptor descriptor =
        BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    _labelIconCache[key] = descriptor;
    return descriptor;
  }

  void createBasicPolygon(DeviceDetails device, Site site, List<List<LatLng>> results) {
    // If we can't use the Licence HRP table, lets make a circle estimate
//    double eirp = d.eirp;
//    if (eirp == null) eirp = 0.0;
//    double power_dBm = 10 * log10(eirp) + 30; // Convert Watts to dBm
//    //power_dBm += 30; // Extra FM radio sensitivity (over mobiles)
//    power_dBm += 18; // FIXME Antenna gain
//    power_dBm -= 47; // FIXME Propagation loss
//
//    //Double power = d.power; // Watts

    int freqInMHz = device.frequency! / 1000 ~/ 1000;

    // Draw appropriate signal strength
    List<int> polygons = NetworkTypeHelper.getNetworkBars(device.getNetworkType());

    int towerHeight = 0;
    towerHeight = device.height!;
    if (towerHeight < 10) {
      // Sensible default value
      towerHeight = 10;
    }
    //Log.d("PolygonHelper", "power_dBm="+power_dBm+" freeSpaceLoss_dBi="+freeSpaceLoss_dBi+" towerHeight="+towerHeight);

    for (double bearing = BEARING_START; bearing < 360; bearing += polygonBearingIncrement) {
      //TODO calculare Terrain
      Set<HeightDistancePair> heightToDistance = {};
      int hillHeight = 0;
      if (PolygonHelper.calculateTerrain) {
        // Is the tower on top of a hill?
        heightToDistance = site.getHeightsAlongBearing(bearing);
        hillHeight = site.getSiteHillElevation(heightToDistance);
        if (hillHeight < 0) {
          hillHeight = 0;
        }
        //Log.d("PolygonHelper", "hillHeight="+hillHeight);
      }

      double power_dBm = device.getPowerAtBearing(bearing);

      int pos = 0;
      for (int p = 0; p <= PolygonHelper.getPolygonSignalStrengthPosition(); p++) {
        int receiver_dBm = polygons[p];
        double freeSpaceLoss_dBi = power_dBm - receiver_dBm;

        // Use the composite (mnc + networkType + density + frequency-band) overload so the
        // estimate is tuned to the SAME trained coefficients as the connected-tower path
        // (learned from observed signal strengths), instead of only the density-only
        // coefficients. The composite lookup degrades gracefully
        // (composite -> density-only -> analytic Hata), identical to the mapping path.
        CityDensity model = device.getRadiationModel() ??
            GetLicenceHRP.defaultRadiationModel;
        double distanceKm = GetLicenceHRP.calculateDistanceWithContext(
            TelcoHelper.getMnc(site.getTelco()),
            device.getNetworkType(),
            model,
            freeSpaceLoss_dBi,
            freqInMHz.toDouble(),
            (towerHeight + hillHeight).toDouble());
        //Log.d("PolygonHelper", "distanceKm="+distanceKm);

//    TreeSet<HeightDistancePair> heightToDistance = site.getHeightsAlongBearing(distanceKm, bearing);//TODO later on
//    distanceKm = GetLicenceHRP.calculateTerrainLosses(site, heightToDistance, distanceKm, bearing, freqInMHz, towerHeight);
        if (calculateTerrain) {
          distanceKm = GetLicenceHRP.calculateTerrainLosses(
              site, heightToDistance, distanceKm, bearing, freqInMHz.toDouble(), towerHeight);
        }

        if (distanceKm > 100) {
          distanceKm = 100;
        }

        LatLng latlng = GetLicenceHRP.travel(site.getLatLng(), bearing, distanceKm);
        results[pos].add(latlng);
        pos++;
      }
    }
    createPolygon(results, site, device);
  }

  void clearSitePatterns(bool cancelAllTaskTypes, {Site? skipSite, ShowSnackBar? showSnackBar}) {
    // Cancel pending REST requests for polygons
    if (cancelFetchingPolygonRequestToken != null) {
      if (!cancelFetchingPolygonRequestToken!.isCancelled) {
        cancelFetchingPolygonRequestToken!
            .cancel("future request for signal polygon have been cancelled");
      }
    }

    // Signal that the polygons have changed
    PolygonHelper.switchingBetweenTerrainAwareness = false;

    // Clear all polygons, except maybe skipSite.
    // Does not use iterator to avoid "Concurrent modification during iteration"
    for (int i = 0; i < PolygonHelper.sitesPolygons.keys.length; i++) {
      Site s = PolygonHelper.sitesPolygons.keys.elementAt(i);
      if (s != skipSite) {
        queryForSignalPolygon(
          s,
          false,
          false,
          showSnackBar: showSnackBar,
        );
      }
    }
  }

  void refreshPolygons(bool cachingPolygons) {
    // Reset the fail-safe preventing race conditions going crazy
    SiteHelper.siteDownloadSinceLastClick.clear();

    // Cancel pending REST requests for polygons
    if (cancelFetchingPolygonRequestToken != null) {
      if (!cancelFetchingPolygonRequestToken!.isCancelled) {
        cancelFetchingPolygonRequestToken!
            .cancel("future reuqest for signal polygon have been cancelled");
      }
    }

    // Refresh polygons to show/hide depending on settings
    for (int i = 0; i < PolygonHelper.sitesPolygons.keys.length; i++) {
      Site site = PolygonHelper.sitesPolygons.keys.elementAt(i);
      // Recalculate all the polygons
      queryForSignalPolygon(site, true, cachingPolygons);
    }
  }

  void switchTerrainAwareness() {
    // For really fast switching, cache the terrain and non-terrain polygons
    if (PolygonHelper.switchingBetweenTerrainAwareness) {
      // Remove the older polygons
      for (Site site in sitesPolygons.keys) {
        // Remove the polygon
        queryForSignalPolygon(site, false, false);
        clearSitePatterns(false);
      }

      Map<Site, Map<DeviceDetails, Set<PolygonContainer>>>? switcher =
          PolygonHelper.sitesPolygonsOppositeTerrain;
      PolygonHelper.sitesPolygonsOppositeTerrain = PolygonHelper.sitesPolygons;
      PolygonHelper.sitesPolygons = switcher;

      SiteHelper.siteDownloadSinceLastClick.clear();

      // Now that we have switched polygons over to the opposite terrain, we need to draw the correct polygons
      //restoreTelcoPolygons();//TODO revert this
      refreshPolygons(false);
    } else {
      // Back up the opposite terrain in case the user selects back to it
      PolygonHelper.sitesPolygonsOppositeTerrain = PolygonHelper.sitesPolygons;

      // Redraw the polygons by recalculating them with the new terrain setting
      refreshPolygons(false);
    }

    PolygonHelper.switchingBetweenTerrainAwareness = true;
  }

  void restoreTelcoPolygons() {
    Map<Site, Map<DeviceDetails, Set<PolygonContainer>>> oldSitesPolygons =
        PolygonHelper.sitesPolygons;

    for (Site site in oldSitesPolygons.keys) {
      for (DeviceDetails deviceDetails in oldSitesPolygons[site]!.keys) {
        Set<PolygonContainer> oldPolygons = oldSitesPolygons[site]![deviceDetails]!;
        redrawPolygons(site, deviceDetails, oldPolygons);
      }
    }
  }

  void redrawPolygons(Site site, DeviceDetails deviceDetails, Set<PolygonContainer> oldPolygons) {
    List<List<LatLng>> data = [];
    for (PolygonContainer oldContainer in oldPolygons) {
      logger.d('PolygonHelper: redrawPolygons: oldContainer= $oldContainer');
      data.add(oldContainer.polygon.points);
    }
    createPolygon(data, site, deviceDetails);
  }
}
