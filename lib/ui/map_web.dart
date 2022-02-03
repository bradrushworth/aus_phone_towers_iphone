import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geohash/geohash.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:google_maps_flutter_web/google_maps_flutter_web.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/ui/map_common.dart';
import 'package:phonetowers/utils/strings.dart';

import '../../utils/app_constants.dart';

//import 'package:phonetowers/helpers/map_platform.dart'
//if (dart.library.js) 'package:phonetowers/helpers/map_web.dart';

abstract class AbstractMapBodyState extends State<MapBody> {
  CameraPosition lastCameraPosition;
  Logger logger;
  Api api;

  void onMapCreated(dynamic controllerParam);

  void onCameraMove(CameraPosition position) {
    //Store last camera position when map scrolled in order to make clear map option menu work.
    lastCameraPosition = position;
    if (!SearchHelper.calculatingSearchResults) {
      onMapScroll(position);
    }
  }

  //Set camera to last location and perform further operations.
  void onCameraMoveFromLastLocation() {
    if (lastCameraPosition != null) {
      if (!SearchHelper.calculatingSearchResults) {
        onMapScroll(lastCameraPosition);
      }
    }
  }

  void onMapScroll(CameraPosition position) {
    if (position.zoom < kZoomTooFar) {
      showSnackbar(message: Strings.zoominFurther, isDismissible: true);
      return;
    }

    double lat = position.target.latitude;
    double long = position.target.longitude;
    String geoHash = Geohash.encode(lat, long, codeLength: 5);
    downloadTowers(geoHash, true);
  }

  void handleSearchQuery(dynamic mapController, String query) {
    // Centre the map on Australia
    mapController.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(-44, 113),
          northeast: LatLng(-10, 154),
        ),
        10.0,
      ),
    );

    //Clear the map
    SiteHelper()
        .clearMap(onCameraMoveFromLastLocation: onCameraMoveFromLastLocation);

    SearchHelper(showSnackBar: showSnackbar, mapController: mapController)
        .executeSiteSearch(query, downloadTowers);
  }

  void refreshUI({String message = 'Global refresh'}) {
    //logger.d('$message');
    if (mounted) {
      // TODO: This probably wasn't right!
      //setState(() {});
    }
  }

  void showSnackbar(
      {@required String message,
      Duration duration = const Duration(seconds: 1),
      bool isDismissible = false});

  void downloadTowers(String geoHash, bool expandGeohash);

  void showCustomInfoWindowAsBottomSheet(BuildContext context, Site site);
}
