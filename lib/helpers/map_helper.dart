import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geohash/geohash.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/model/overlay.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapHelper with ChangeNotifier {
  static final MapHelper _singleton = new MapHelper._internal();

  factory MapHelper() {
    return _singleton;
  }

  MapHelper._internal();

  int mapMode = kMapModeTerrain;
  bool developerMode = false;
  Logger logger = new Logger();

  void setMapMode(int mode, SharedPreferences prefs) {
    mapMode = mode;
    SharedPreferencesHelper.setInt(
        key: SharedPreferencesHelper.kMapMode, value: mapMode, prefs: prefs);
    notifyListeners();
  }

  MapType getMapType() {
    switch (mapMode) {
      case 1:
        return MapType.terrain;
      case 2:
        return MapType.hybrid;
      case 3:
        return MapType.satellite;
      case 4:
        return MapType.normal;
      default:
        return MapType.terrain;
    }
  }

  void toggleDeveloperMode() {
    if (developerMode) {
      drawDeveloperShapes();
    } else {
      removeDeveloperShapes();
    }
  }

  void drawDeveloperShapes() {
    Set<String> hashes = Set<String>();
    for (String hash in SiteHelper.downloadedGeohashes) {
      // Remove the "_Telstra" bit from the end
      hashes.add(hash.split("_")[0]);
    }

    for (String hash in hashes) {
      // Convert from David Morton's implementation to Silvio Heuberger's implementation
      //Point<double> centre = Geohash.decode(hash);
      final Rectangle<double> extents = Geohash.getExtents(hash);
      List<LatLng> polygonPoints = <LatLng>[];
      polygonPoints.add(LatLng(extents.left, extents.top));
      polygonPoints.add(LatLng(extents.right, extents.top));
      polygonPoints.add(LatLng(extents.right, extents.bottom));
      polygonPoints.add(LatLng(extents.left, extents.bottom));

      Polygon po = Polygon(
        polygonId: PolygonId("polygon_developer_$hash"),
        strokeColor: Colors.grey[500]!,
        fillColor: Colors.transparent,
        strokeWidth: 2,
        points: polygonPoints,
      );

      MapOverlay mapOverlay = MapOverlay(polygon: po);
      PolygonHelper.globalListPolygons.add(mapOverlay);

      //TODO ground overlay
    }

    notifyListeners();
  }

  void removeDeveloperShapes() {
    PolygonHelper.globalListPolygons.removeWhere((mapOverlay) {
      return mapOverlay.polygon!.polygonId.value.contains('developer');
    });
    notifyListeners();
  }
}
