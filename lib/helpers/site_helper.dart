import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../model/overlay.dart';
import '../model/site.dart';
import '../restful/get_licenceHRP.dart';
import '../ui/widgets/navigation_menu.dart';
import 'network_type_helper.dart';
import 'polygon_helper.dart';
import 'telco_helper.dart';

class SiteHelper with ChangeNotifier {
  static final SiteHelper _singleton = new SiteHelper._internal();

  factory SiteHelper() {
    return _singleton;
  }

  SiteHelper._internal();

  static Set<String> downloadedGeohashes = new Set<String>();
  static final int EXPANSION_LIMIT = 20;
  static final int RECURSION_LIMIT = 3;
  static List<MapOverlay> globalListMapOverlay = [];
  static Set<Telco> hideTelco = Set<Telco>();
  static Set<NetworkType> hideNetworkType = Set<NetworkType>();

  static int GEOHASH_LENGTH = 5;

  //static ConcurrentHashMap<Marker, Site> markersHashMap = new ConcurrentHashMap<>();
  /// Number of polygon-download chains currently in flight for each site, one per device
  /// whose GetLicenceHRP pagination chain has started (see [startSiteDownload]) but not yet
  /// terminated — successfully, with an error, or via cancellation (see [finishSiteDownload]).
  /// A site is considered "locked" (PolygonHelper.queryForSignalPolygon will refuse to start a
  /// new download for it) while it has an entry here; entries are removed entirely once their
  /// count reaches zero, so `containsKey` / `isEmpty` style checks reflect "nothing in flight".
  ///
  /// This used to be a plain `Set<Site>` (added on tap, removed on the first device's download
  /// to finish). That under-counted multi-device sites — the guard could reopen while sibling
  /// devices were still downloading — so it is now a per-site in-flight counter instead.
  static Map<Site, int> siteDownloadSinceLastClick = Map<Site, int>();

  /// True if [site] currently has at least one polygon-download chain in flight.
  static bool isSiteDownloadInFlight(Site site) =>
      (siteDownloadSinceLastClick[site] ?? 0) > 0;

  /// Record that another device's download chain has started for [site]. Call once per
  /// device, right before kicking off its (fire-and-forget) GetLicenceHRP chain.
  static void startSiteDownload(Site site) {
    siteDownloadSinceLastClick[site] = (siteDownloadSinceLastClick[site] ?? 0) + 1;
  }

  /// Record that one of [site]'s device download chains has terminated — successfully (last
  /// page processed), with an error, or via cancellation. Only clears the site-level guard once
  /// every chain started for this site has terminated (count reaches zero).
  static void finishSiteDownload(Site site) {
    final int remaining = (siteDownloadSinceLastClick[site] ?? 1) - 1;
    if (remaining <= 0) {
      siteDownloadSinceLastClick.remove(site);
    } else {
      siteDownloadSinceLastClick[site] = remaining;
    }
  }

  static Set<List<int>> hideFrequency = Set<List<int>>();
  static Set<CityDensity> hideDensity = Set<CityDensity>();

  static bool downloadedGeohashAlready(String geohash, Telco telco) {
    // Don't download the same area more than once for a given telco
    String geohashTelco = getGeohashTelco(geohash, telco);
    if (downloadedGeohashes.contains(geohashTelco)) {
      //logger.d("MapsActivity", "onMapScroll: downloadedGeohashAlready: geohashTelco=" + geohashTelco + ", return true");
      return true;
    } else {
      //logger.d("MapsActivity", "onMapScroll: downloadedGeohashAlready: geohashTelco=" + geohashTelco + ", return false");
      downloadedGeohashes.add(geohashTelco);

      return false;
    }
  }

  static String getGeohashTelco(String geohash, Telco telco) {
    return geohash + "_" + TelcoHelper.getName(telco);
  }

  void toggleTelcoMarkers(Telco telco, bool enable) {
    // Record that we have hidden this telco
    if (enable) {
      hideTelco.remove(telco);
    } else {
      hideTelco.add(telco);
    }

    // Add/Remove markers
    for (int i = 0; i < SiteHelper.globalListMapOverlay.length; i++) {
      if (SiteHelper.globalListMapOverlay[i].site != null) {
        if (SiteHelper.globalListMapOverlay[i].site!.getTelco() == telco) {
          final Marker? marker = SiteHelper.globalListMapOverlay[i].marker;
          // When enabling, re-evaluate shouldBeVisible() so network-type /
          // density / multiplex filters are applied — not every marker of this
          // telco should be shown (e.g. if 5G-only is selected).
          final bool visible = enable
              ? SiteHelper.globalListMapOverlay[i].site!.shouldBeVisible()
              : false;
          SiteHelper.globalListMapOverlay[i].marker = marker!.copyWith(
            visibleParam: visible,
          );
        }
      }
    }

    // Add/Remove polygons
    if (PolygonHelper.globalListPolygons.isNotEmpty) {
      PolygonHelper.globalListPolygons.removeWhere((mapOverlay) {
        return !mapOverlay.polygon!.polygonId.value.contains('developer') &&
            mapOverlay.site!.getTelco() == telco;
      });
    }
    // Remove the matching labels so they don't outlive their polygons.
    PolygonHelper.labelOverlays.removeWhere((mapOverlay) =>
        mapOverlay.site != null && mapOverlay.site!.getTelco() == telco);

    notifyListeners(); //Refresh main UI
  }

  void refreshSites() {
    // Add/Remove markers
    for (int i = 0; i < SiteHelper.globalListMapOverlay.length; i++) {
      if (SiteHelper.globalListMapOverlay[i].site != null) {
        final Marker? marker = SiteHelper.globalListMapOverlay[i].marker;
        SiteHelper.globalListMapOverlay[i].marker = marker!.copyWith(
          visibleParam:
              SiteHelper.globalListMapOverlay[i].site!.shouldBeVisible(),
        );
      }
    }

    notifyListeners();
  }

  void toggleTelcoNetwork(NetworkType networkType, bool isShow) {
    if (isShow) {
      SiteHelper.hideNetworkType.remove(networkType);
    } else {
      SiteHelper.hideNetworkType.add(networkType);
    }

    refreshSites();
    PolygonHelper().refreshPolygons(!isShow);
  }

  void toggleFrequencyRange(bool isShow, List<int> range) {
    if (isShow) {
      SiteHelper.hideFrequency.removeWhere((rangeinside) {
        return range[0] == rangeinside[0];
      });
    } else {
      SiteHelper.hideFrequency.add(range);
    }

    refreshSites();
    PolygonHelper().refreshPolygons(!isShow);
  }

  //sets the radiation according to the map like: METRO,URBAN,SUBURBAN,OPEN
  void toggleCityDensity(bool isShow, CityDensity model) {
    if (isShow) {
      SiteHelper.hideDensity.removeWhere((modelinside) {
        return model == modelinside;
      });
    } else {
      SiteHelper.hideDensity.add(model);
    }

    refreshSites();
    PolygonHelper().refreshPolygons(!isShow);
  }

  void setSignalStrength(int position) {
    PolygonHelper.polygonSignalStrengthPos = position;
    notifyListeners();
    PolygonHelper().refreshPolygons(false);
  }

  void enableTelcoInUse(bool drawDefaultTelco) {
    if (drawDefaultTelco) {
      Telco? telcoInUse; // I want to show all of the telcos now
      if (telcoInUse == null || telcoInUse == Telco.Telstra)
        toggleTelcoMarkers(Telco.Telstra, NavigationMenu.isTelstraVisible);
      if (telcoInUse == null || telcoInUse == Telco.Optus)
        toggleTelcoMarkers(Telco.Optus, NavigationMenu.isOptusVisible);
      if (telcoInUse == null || telcoInUse == Telco.Vodafone)
        toggleTelcoMarkers(Telco.Vodafone, NavigationMenu.isVodafoneVisible);
      if (telcoInUse == null || telcoInUse == Telco.Dense_Air)
        toggleTelcoMarkers(Telco.Dense_Air, NavigationMenu.isDenseAirVisible);
      if (telcoInUse == null || telcoInUse == Telco.NBN)
        toggleTelcoMarkers(Telco.NBN, NavigationMenu.isNBNVisible);
      if (telcoInUse == null || telcoInUse == Telco.Other)
        toggleTelcoMarkers(Telco.Other, NavigationMenu.isOptusVisible);
    }

    //TODO code for currently connected tower
  }

  void disableTelcos() {
    if (!hideTelco.contains(Telco.Telstra)) {
      toggleTelcoMarkers(Telco.Telstra, false);
    }
    if (!hideTelco.contains(Telco.Optus)) {
      toggleTelcoMarkers(Telco.Optus, false);
    }
    if (!hideTelco.contains(Telco.Vodafone)) {
      toggleTelcoMarkers(Telco.Vodafone, false);
    }
    if (!hideTelco.contains(Telco.Dense_Air)) {
      toggleTelcoMarkers(Telco.Dense_Air, false);
    }
    if (!hideTelco.contains(Telco.NBN)) {
      toggleTelcoMarkers(Telco.NBN, false);
    }
    if (!hideTelco.contains(Telco.Other)) {
      toggleTelcoMarkers(Telco.Other, false);
    }

    //TODO code for currently connected tower
  }

  void clearMap({required void Function() onCameraMoveFromLastLocation}) {
    PolygonHelper().clearSitePatterns(true);
    //For markers
    downloadedGeohashes.clear();
    globalListMapOverlay.clear();
    //For polygons
    siteDownloadSinceLastClick.clear();
    PolygonHelper.globalListPolygons.removeWhere((mapOverlay) {
      return !mapOverlay.polygon!.polygonId.value.contains('developer');
    });
    PolygonHelper.sitesPolygons.clear();
    PolygonHelper.allPolygons.clear();
    PolygonHelper.labelOverlays.clear();
//    CurrentCellHelper.currentCellMarkers.clear();
//    CurrentCellHelper.currentCellCircles.clear();
//    CurrentCellHelper.currentCellLine = null;
//    CurrentCellHelper.currentCellOverlay = null;
//    CalculateConnectedTower.currentFollowGpsLine = null;
    notifyListeners();
    onCameraMoveFromLastLocation();
  }

  void clearPolygons() {
    //For polygons
    siteDownloadSinceLastClick.clear();
    PolygonHelper.globalListPolygons.removeWhere((mapOverlay) {
      return !mapOverlay.polygon!.polygonId.value.contains('developer');
    });
    PolygonHelper.labelOverlays.clear();
    PolygonHelper.sitesPolygons.clear();
    PolygonHelper.allPolygons.clear();
    notifyListeners();
  }
}
