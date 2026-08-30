import 'dart:async';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:geohash/geohash.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
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
  CameraPosition? lastCameraPosition;
  late Logger logger;
  late Api api;

  // Rebuild the marker set a short while after the camera stops moving, so the
  // viewport-bounded marker filter (issue #58 — capping markers to work around iOS
  // texture-atlas exhaustion) keeps following the camera even when panning doesn't
  // trigger a new tower download. Throttled rather than run on every frame since
  // onCameraMove fires continuously during a drag.
  Timer? _markerViewportRebuild;

  void onMapCreated(dynamic controllerParam);

  void onCameraMove(CameraPosition position) {
    //Store last camera position when map scrolled in order to make clear map option menu work.
    lastCameraPosition = position;
    _markerViewportRebuild ??= Timer(const Duration(milliseconds: 400), () {
      _markerViewportRebuild = null;
      if (mounted) setState(() {});
    });
    if (!SearchHelper.calculatingSearchResults) {
      onMapScroll(position);
    }
  }

  //Set camera to last location and perform further operations.
  void onCameraMoveFromLastLocation() {
    if (lastCameraPosition != null) {
      if (!SearchHelper.calculatingSearchResults) {
        onMapScroll(lastCameraPosition!);
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
    // F6 (UI overhaul port): no more flying the camera to all of Australia or clearing the
    // map — results appear in the SearchSheet ranked by distance, and the user chooses.
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
      {required String message,
      Duration duration = const Duration(seconds: 1),
      bool isDismissible = false});

  void downloadTowers(String geoHash, bool expandGeohash);

  void showCustomInfoWindowAsBottomSheet(BuildContext context, Site site);
}
