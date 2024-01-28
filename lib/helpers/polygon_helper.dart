import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:logger/logger.dart';

import '../model/device_detail.dart';
import '../model/height_distance_pair.dart';
import '../model/overlay.dart';
import '../model/site.dart';
import '../restful/get_elevation.dart';
import '../restful/get_licenceHRP.dart';
import '../utils/polygon_container.dart';
import 'analytics_helper.dart';
import 'let_type_helper.dart';
import 'map_helper.dart';
import 'network_type_helper.dart';
import 'site_helper.dart';
import 'telco_helper.dart';

typedef void ShowSnackBar({String message});

class PolygonHelper with ChangeNotifier {
  static final PolygonHelper _singleton = new PolygonHelper._internal();

  factory PolygonHelper() {
    return _singleton;
  }

  PolygonHelper._internal();

  static final double BEARING_START = 1.25;
  static final double BEARING_INCREMENT = 2.50;

  static int polygonSignalStrengthPos =
      NetworkTypeHelper.getNetworkBars(NetworkType.LTE).length - 1;
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
  static Logger logger = Logger();

  //static Set<Polygon> globalPolygons = Set<Polygon>();
  static List<MapOverlay> globalListPolygons = [];
  static CancelToken? cancelFetchingPolygonRequestToken;
  static String terrainAwarenessKey = '';

  void queryForSignalPolygon(Site site, bool refreshingPolygons, bool cachingPolygons,
      {Set<DeviceDetails>? specificDevices, ShowSnackBar? showSnackBar}) {
    // If we have decided not to refresh (because we are loading a saved state for instance)
    logger.d('inside query for signal polygon');

    if (preventPolygonRefresh) {
      return;
    }

    // Check if this site is stuck in a race condition?
    if (SiteHelper.siteDownloadSinceLastClick.contains(site)) {
      return;
    }

    SiteHelper.siteDownloadSinceLastClick.add(site);

    // Save bandwidth by caching polygons when cachingPolygons==true
    Map<DeviceDetails, Set<PolygonContainer>> polygonCache =
        Map<DeviceDetails, Set<PolygonContainer>>();

    if (sitesPolygons.containsKey(site)) {
      //Remove any existing polygons first
      globalListPolygons.removeWhere((mapOverlay) {
        return !mapOverlay.polygon!.polygonId.value.contains('developer');
      });

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

      // Exit unless we are refreshing the polygons
      if (!refreshingPolygons) {
        //Commenting this to fix clicking on same tower won't download.
        return;
      }
    }

    if (calculateTerrain) {
      // Get elevation data from Google
      try {
        if (!site.startedDownloadingElevations) {
          site.startedDownloadingElevations = true;
          String positionsString = GetElevation.getPositionsString(site.getLatLng());
          String url = (kIsWeb ? 'https://api.bitbot.com.au/cors/' : '') +
              'https://maps.googleapis.com/maps/api/elevation/json?locations=$positionsString&key=$terrainAwarenessKey';
          GetElevation(site: site, url: url).getElevationData();
        }
      } catch (e, stack) {
        site.startedDownloadingElevations = false;
        print(stack);
        return;
      }
    }

    // Prepare for the download
    if (!sitesPolygons!.containsKey(site)) {
      sitesPolygons![site] = Map<DeviceDetails, Set<PolygonContainer>>();
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
      String fields = "start_angle%2Cpower";
      String url =
          '/towers/licence_hrp/?_view=json&_expand=no&_count=360&_filter=$filter&_fields=$fields&_sort=start_angle ASC';

      GetLicenceHRP(
              site: site,
              device: d,
              list: results,
              url: url,
              showSnackBar: showSnackBar!,
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
        alpha = 10;
//                if (CustomLocationListener.followGPS) {
//                  alpha += 10;//TODO custom location listener
//                }
        alpha += (math.log(1 + (capacity / (1000 * 1000))) * 2).toInt();
      }

      switch (MapHelper().mapMode) {
        case 2:
        case 3:
          {
            alpha += 25;
          }
          break;
      }

      int lineAlpha = 0;
      if (showPolygonBorders) lineAlpha = 25 + alpha;

      //Log.d("PolygonHelper", "i=" + i + " capacity=" + capacity + " alpha=" + alpha);
      Polygon po = Polygon(
        polygonId: PolygonId("polygon_${i}_${device.sddId}"),
        strokeColor:
            i != data.length - 1 ? Colors.transparent : TelcoHelper.getColor(telco, lineAlpha),
        strokeWidth: 4,
        fillColor: TelcoHelper.getColor(telco, alpha),
        points: data[i],
      );

      if (PolygonHelper.sitesPolygons!.containsKey(site)) {
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
      } else {
        // Skip it, since it arrived too late
      }
    }

    // Be prepared for other threads removing the site
    if (sitesPolygons!.containsKey(site)) {
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
      Map<String, Object> eventMap = Map<String, Object>();
      eventMap['site_id'] = site.siteId!;
      eventMap['site_telco'] = TelcoHelper.getName(site.getTelco());
      eventMap['device_lteType'] = LteTypeHelper.getName(device.getLteType());
      eventMap['device_networkType'] =
          NetworkTypeHelper.resolveNetworkToName(device.getNetworkType());
      eventMap['device_antennaCapacity'] = device.getAntennaCapacity();
      AnalyticsHelper()
          .sendCustomAnalyticsEvent(eventName: 'create_polygon', eventParameters: eventMap);
    }
  }

  static int getPolygonSignalStrengthPosition() {
    return polygonSignalStrengthPos;
  }

  void createBasicPolygon(DeviceDetails device, Site site, List<List<LatLng>> results) {
    if (site == null || device == null) return;
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

    for (double bearing = BEARING_START; bearing < 360; bearing += BEARING_INCREMENT) {
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

        double distanceKm = GetLicenceHRP.calculateDistance(GetLicenceHRP.radiationModel,
            freeSpaceLoss_dBi, freqInMHz.toDouble(), towerHeight + hillHeight.toDouble());
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
