import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppConstants {
  static bool isDebug = false;
  static final String AUTHORIZATION = "Authorization";
  static final String TOKEN = "Token";
  static final bool isMock = false;
}

const LatLng kLagLongBathurst = LatLng(-33.433, 149.565);
const double kDefaultZoom = 13.0;
const double kZoomTooFar = 11;

const int kMaximumSignalStrength = 0;
const int kStrongSignalStrength = 1;
const int kGoodSignalStrength = 2;
const int kWeakSignalStrength = 3;

const int kMetropolitanRadiationModel = 0;
const int kUrbanRadiationModel = 1;
const int kSuburbanRadiationModel = 2;
const int kOpenRadiationModel = 3;

const int kSearchStarted = 0;
const int kSearching = 1;
const int kSearchStopped = 2;

const int kMapModeTerrain = 1;

const int kClearMenu = 1;
const int kHidingMenu = 2;
const int kRemoveAds = 3;
const int kDonate = 4;

const String kAppleId = '1488594332';