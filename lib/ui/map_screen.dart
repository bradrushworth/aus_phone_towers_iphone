import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geohash/geohash.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:location/location.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as onlyPath;
import 'package:phonetowers/helpers/ads_helper.dart';
import 'package:phonetowers/helpers/analytics_helper.dart';
import 'package:phonetowers/helpers/frequency_range_helper.dart';
import 'package:phonetowers/helpers/get_devices.dart';
import 'package:phonetowers/helpers/get_licenceHRP.dart';
import 'package:phonetowers/helpers/let_type_helper.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/helpers/screenshot_controller.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/site_response.dart';
import 'package:phonetowers/ui/widgets/navigation_menu.dart';
import 'package:phonetowers/ui/widgets/option_menu.dart';
import 'package:phonetowers/utils/geo_hash.dart';
import 'package:phonetowers/utils/hex_color.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/ads_helper.dart';
import '../model/overlay.dart';
import '../utils/app_constants.dart';

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> with AfterLayoutMixin<MapScreen> {
  double screenWidth = 0.0;
  double screenHeight = 0.0;
  Logger logger;

  //Create an instance of ScreenshotController
  ScreenshotController screenshotController = ScreenshotController();

  //media_query class : enum orientation { portrait,landscape}
  Orientation screenOrientation = Orientation.portrait;

  SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    logger = Logger();
  }

  /*
  * It uses after_layout(https://pub.dev/packages/after_layout) dependency
  *
  * */
  @override
  void afterFirstLayout(BuildContext context) async {
    //Show beta launch popup if not displayed.
    prefs = await SharedPreferences.getInstance();
    if (!SharedPreferencesHelper.getBoolean(
        SharedPreferencesHelper.betaLaunchPopup, prefs)) {
      _showAlertDialog();
    }
  }

  Future<void> _showAlertDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(Strings.betaLaunchPopupTitle),
          content: Text(Strings.betaLaunchPopupDesc),
          actions: <Widget>[
            FlatButton(
              child: Text(Strings.betaLaunchPopupAction),
              onPressed: () {
                Navigator.of(context).pop();
                SharedPreferencesHelper.saveBoolean(
                    key: SharedPreferencesHelper.betaLaunchPopup,
                    value: true,
                    prefs: prefs);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Consumer<SiteHelper>(
                builder: (context, siteHelper, child) => Expanded(
                      child: Screenshot(
                        controller: screenshotController,
                        child: Scaffold(
                          drawer: NavigationMenu(),
                          body: MapBody(screenshotController),
                        ),
                      ),
                    )),
            Consumer<PurchaseHelper>(
              builder: (context, purchaseHelper, child) => Visibility(
                visible: !purchaseHelper.isShowSubscribePreviousMenuItem,
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 0,
                      color: Colors.grey[300],
                    ),
                    Container(
                      height: 50,
                    ),
                    OrientationBuilder(
                      builder: (context, orientation) {
                        screenOrientation = MediaQuery.of(context).orientation;
                        configureAds();
                        return Container();
                      },
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  //Ad Integration in the widget
  void configureAds() {
    if (!kIsWeb && Platform.isAndroid) {
      //TODO remove this condition when IAP is implemented for iOS
      if (!PurchaseHelper().isHasPurchasedProcessed) {
        return;
      }
    }

    if (!kIsWeb) {
      if (!PurchaseHelper().isShowSubscribePreviousMenuItem) {
        //Show ads only if user has not subscribed to any of remove ads menu item
        AdSize bannerAdSize;
        String adUnitId = '';
        if (screenOrientation == Orientation.portrait) {
          logger.d('load ad in portrait mode');
          bannerAdSize = AdSize.banner;
          adUnitId = Platform.isAndroid
              ? AdsHelper.androidPortraitAdUnitId
              : AdsHelper.iOSPortraitAdUnitId;
        } else {
          logger.d('load ad in landscape mode');
          bannerAdSize = AdSize.smartBanner;
          adUnitId = Platform.isAndroid
              ? AdsHelper.androidLandscapeAdUnitId
              : AdsHelper.iOSLandscapeAdUnitId;
        }

        AdsHelper()
          ..hideBannerAd()
          ..showBannerAd(bannerAdSize, adUnitId);
      } else {
        AdsHelper().hideBannerAd();
      }
    }
  }
}

class MapBody extends StatefulWidget {
  ScreenshotController screenshotController;

  MapBody(this.screenshotController);

  @override
  _MapBodyState createState() => _MapBodyState();
}

class _MapBodyState extends State<MapBody> {
  /// ******************** State variables ************************************
  GoogleMapController mapController;
  Logger logger;
  Api api;
  Location _locationService = new Location();
  SharedPreferences prefs;
  CameraPosition lastCameraPosition;
  final TextEditingController _searchTextFilter = new TextEditingController();
  bool isShowCancelSearch = false;

  /*
  * Method channel for taking screenshots
  * */
  static const androidMethodChannel = const MethodChannel(
      'au.com.bitbot.phonetowers.flutter.provider/screenshot');

  // static const MobileAdTargetingInfo targetingInfo = MobileAdTargetingInfo(
  //   testDevices: <String>[
  //     'B5BD02099B12769D58DBD05B64D1DFAF',
  //     'FD6126EE250BB0AA9187FFE30B3C9EE1',
  //     'Simulator'
  //   ],
  // );

  /// ******************** Overrided methods **********************************
  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      PurchaseHelper().initStoreInfo(
        showSnackBar: showSnackbar,
      );
    }

    _loadNavigationSavedState();
    logger = Logger();
    api = Api.initialize();

    //Search text controller listener
    _searchTextFilter.addListener(() {
      setState(() {
        isShowCancelSearch = _searchTextFilter.text.isNotEmpty;
      });
    });

    if (!kIsWeb) AdsHelper().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: <Widget>[
            Consumer3<PolygonHelper, SiteHelper, MapHelper>(
              builder: (context, polygonHelper, siteHelper, mapHelper, child) =>
                  GoogleMap(
                padding: EdgeInsets.only(bottom: 100, top: 100),
                myLocationEnabled: true,
                mapType: mapHelper.getMapType(),
                initialCameraPosition: CameraPosition(
                  target: kLagLongBathurst,
                  zoom: kDefaultZoom,
                ),
                markers: SiteHelper.globalListMapOverlay.isNotEmpty
                    ? SiteHelper.globalListMapOverlay
                        .map((data) => data.marker)
                        .toSet()
                    : Set(),
                polygons: PolygonHelper.globalListPolygons.isNotEmpty
                    ? PolygonHelper.globalListPolygons
                        .map((data) => data.polygon)
                        .toSet()
                    : Set(),
                onMapCreated: _onMapCreated,
                onCameraMove: _onCameraMove,
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
//                  Container(
//                    height: 60,
//                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                    child: Center(
//                      child: Text(
//                        'Current Tower: 505-02-52200-123456789-1231 \n LTE band 28 | 763 MHz | -99 dBm | 41 ASU',
//                        style: TextStyle(color: Colors.grey, fontSize: 15),
//                      ),
//                    ),
//                  ),
                ],
              ),
            )
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Consumer<SearchHelper>(
            builder: (context, searchHelper, child) => AppBar(
              leading: SearchHelper.calculatingSearchResults
                  ? IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () {
                        Provider.of<SearchHelper>(context, listen: false)
                            .setSearchStatus(false);
                      })
                  : null,
              title: !SearchHelper.calculatingSearchResults
                  ? Text(
                      Strings.app_title,
                      style: TextStyle(color: Colors.grey),
                    )
                  : TextField(
                      cursorColor: Colors.grey[600],
                      controller: _searchTextFilter,
                      decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[600],
                          ),
                          suffixIcon: isShowCancelSearch
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchTextFilter.text = '';
                                    });
                                  })
                              : null),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (query) {
                        logger.d('search query is $query');
                        _handleSearchQuery(query);
                      },
                    ),
              actions: <Widget>[
//                Padding(
//                  padding: const EdgeInsets.symmetric(horizontal: 8),
//                  child: IconButton(
//                    icon: Icon(Icons.gps_fixed),
//                    onPressed: () {},
//                  ),
//                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: IconButton(
                    icon: Image.asset(PolygonHelper.calculateTerrain
                        ? 'assets/images/ic_terrain_selected.png'
                        : 'assets/images/ic_terrain_unselected.png'),
                    tooltip: Strings.calculate_terrain,
                    onPressed: () {
                      PolygonHelper.calculateTerrain =
                          !PolygonHelper.calculateTerrain;
                      SharedPreferencesHelper.saveBoolean(
                          key: SharedPreferencesHelper.kcalculateTerrain,
                          value: PolygonHelper.calculateTerrain,
                          prefs: prefs);
                      setState(() {});
                      showSnackbar(
                          message: PolygonHelper.calculateTerrain
                              ? 'Using terrain data when calculating propagation models! This is more accurate but slower.'
                              : 'Ignoring terrain when calculating propagation models.');
                      PolygonHelper().switchTerrainAwareness();
                    },
                  ),
                ),
                OptionsMenu(
                    showSnackBar: showSnackbar,
                    onCameraMoveFromLastLocation: onCameraMoveFromLastLocation,
                    takeScreenshot: takeScreenshot),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    //Free some memory
    //PurchaseHelper().subscription.cancel();
    if (!kIsWeb) AdsHelper().hideBannerAd();
    super.dispose();
  }

  ///********************** Helper methods *************************************

  void _loadNavigationSavedState() async {
    prefs = await SharedPreferences.getInstance();

    //Licences
    NavigationMenu.isTelstraVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisTelstraVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.Telstra, NavigationMenu.isTelstraVisible);
    NavigationMenu.isOptusVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisOptusVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.Optus, NavigationMenu.isOptusVisible);
    NavigationMenu.isVodafoneVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisVodafoneVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.Vodafone, NavigationMenu.isVodafoneVisible);
    NavigationMenu.isNBNVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisNBNVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.NBN, NavigationMenu.isNBNVisible);
    NavigationMenu.isOtherVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisOtherVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.Other, NavigationMenu.isOtherVisible);

    //2G/3G4G/5G
    NavigationMenu.is2GVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kis2GVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoNetwork(NetworkType.GSM, NavigationMenu.is2GVisible);
    NavigationMenu.is3GVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kis3GVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoNetwork(NetworkType.UMTS, NavigationMenu.is3GVisible);
    NavigationMenu.is4GVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kis4GVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoNetwork(NetworkType.LTE, NavigationMenu.is4GVisible);
    NavigationMenu.is5GVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kis5GVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoNetwork(NetworkType.NR, NavigationMenu.is5GVisible);

    //Multiplex type
    NavigationMenu.isNOTLTEVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisNOTLTEVisible, prefs: prefs);
    PolygonHelper.displayNotLteMultiplex = NavigationMenu.isNOTLTEVisible;
    NavigationMenu.isFDLTEVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisFDLTEVisible, prefs: prefs);
    PolygonHelper.displayFdMultiplex = NavigationMenu.isFDLTEVisible;
    NavigationMenu.isTDLTEVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisTDLTEVisible, prefs: prefs);
    PolygonHelper.displayTdMultiplex = NavigationMenu.isTDLTEVisible;
    SiteHelper().refreshSites();

    //Frequencies
    NavigationMenu.isLess700Visible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisLess700Visible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
        NavigationMenu.isLess700Visible,
        FrequencyRangesHelper.getValue(FrequencyRanges.VERY_LOW));
    NavigationMenu.isBet700_100Visible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisBet700_100Visible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
        NavigationMenu.isBet700_100Visible,
        FrequencyRangesHelper.getValue(FrequencyRanges.LOW));
    NavigationMenu.isBet1_2Visible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisBet1_2Visible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
        NavigationMenu.isBet1_2Visible,
        FrequencyRangesHelper.getValue(FrequencyRanges.MEDIUM));
    NavigationMenu.isBet2_3Visible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisBet2_3Visible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
        NavigationMenu.isBet2_3Visible,
        FrequencyRangesHelper.getValue(FrequencyRanges.HIGH));
    NavigationMenu.isGreater3Visible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisGreater3Visible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
        NavigationMenu.isGreater3Visible,
        FrequencyRangesHelper.getValue(FrequencyRanges.VERY_HIGH));

    NavigationMenu.radiationModelselection =
        SharedPreferencesHelper.getRadiationModel(
            key: SharedPreferencesHelper.kradiationModelselection,
            prefs: prefs);
    switch (NavigationMenu.radiationModelselection) {
      case 0:
        {
          GetLicenceHRP.radiationModel = CityDensity.METRO;
          break;
        }
      case 1:
        {
          GetLicenceHRP.radiationModel = CityDensity.URBAN;
          break;
        }
      case 2:
        {
          GetLicenceHRP.radiationModel = CityDensity.SUBURBAN;
          break;
        }
      case 3:
        {
          GetLicenceHRP.radiationModel = CityDensity.OPEN;
          break;
        }
    }

    NavigationMenu.signalStrenghtSelection =
        SharedPreferencesHelper.getSignalStrength(
            key: SharedPreferencesHelper.ksignalStrenghtSelection,
            prefs: prefs);
    switch (NavigationMenu.signalStrenghtSelection) {
      case 0:
        {
          PolygonHelper.polygonSignalStrengthPos = kMaximumSignalStrength;
          break;
        }
      case 1:
        {
          PolygonHelper.polygonSignalStrengthPos = kStrongSignalStrength;
          break;
        }
      case 2:
        {
          PolygonHelper.polygonSignalStrengthPos = kGoodSignalStrength;
          break;
        }
      case 3:
        {
          PolygonHelper.polygonSignalStrengthPos = kWeakSignalStrength;
          break;
        }
    }

    NavigationMenu.isTelcoVisible = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kisTelcoVisible, prefs: prefs);
    if (NavigationMenu.isTelcoVisible) {
      NavigationMenu.isTelstraVisible = NavigationMenu.isTelstraVisible;
      NavigationMenu.isOptusVisible = NavigationMenu.isOptusVisible;
      NavigationMenu.isVodafoneVisible = NavigationMenu.isVodafoneVisible;
      NavigationMenu.isNBNVisible = NavigationMenu.isNBNVisible;
      NavigationMenu.isOtherVisible = NavigationMenu.isOtherVisible;
      SiteHelper().enableTelcoInUse(true);
    } else {
      NavigationMenu.isTelstraVisible = false;
      NavigationMenu.isOptusVisible = false;
      NavigationMenu.isVodafoneVisible = false;
      NavigationMenu.isNBNVisible = false;
      NavigationMenu.isOtherVisible = false;
      SiteHelper().disableTelcos();
    }

    NavigationMenu.isRadioVisible =
        SharedPreferencesHelper.getMenuStatusOtherThanTelco(
            key: SharedPreferencesHelper.kisRadioVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.Radio, NavigationMenu.isRadioVisible);

    NavigationMenu.isTVVisible =
        SharedPreferencesHelper.getMenuStatusOtherThanTelco(
            key: SharedPreferencesHelper.kisTVVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.TV, NavigationMenu.isTVVisible);

    NavigationMenu.isCivilVisible =
        SharedPreferencesHelper.getMenuStatusOtherThanTelco(
            key: SharedPreferencesHelper.kisCivilVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.Civil, NavigationMenu.isCivilVisible);

    NavigationMenu.isPagerVisible =
        SharedPreferencesHelper.getMenuStatusOtherThanTelco(
            key: SharedPreferencesHelper.kisPagerVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.Pager, NavigationMenu.isPagerVisible);

    NavigationMenu.isCBRSVisible =
        SharedPreferencesHelper.getMenuStatusOtherThanTelco(
            key: SharedPreferencesHelper.kisCBRSVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.CBRS, NavigationMenu.isCBRSVisible);

    NavigationMenu.isAviationVisible =
        SharedPreferencesHelper.getMenuStatusOtherThanTelco(
            key: SharedPreferencesHelper.kisAviationVisible, prefs: prefs);
    Provider.of<SiteHelper>(context, listen: false)
        .toggleTelcoMarkers(Telco.Aviation, NavigationMenu.isAviationVisible);

    //Options menu
    PolygonHelper.showPolygonBorders = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kshowPolygonBorders, prefs: prefs);

    MapHelper().mapMode = SharedPreferencesHelper.getMapMode(
        key: SharedPreferencesHelper.kMapMode, prefs: prefs);

    PolygonHelper.drawPolygonsOnClick = SharedPreferencesHelper.getMenuStatus(
        key: SharedPreferencesHelper.kdrawPolygonsOnClick, prefs: prefs);

    PolygonHelper.calculateTerrain =
        SharedPreferencesHelper.getMenuStatusOtherThanTelco(
            key: SharedPreferencesHelper.kcalculateTerrain, prefs: prefs);

    setState(() {});
  }

  void _onMapCreated(GoogleMapController controllerParam) {
    setState(() {
      mapController = controllerParam;
    });

    askForLocationPermission();
//    Future.delayed(Duration(seconds: 2),(){
//      logger.d('after 2 second delay');
//      askForLocationPermission();
//    });
  }

  Future askForLocationPermission() async {
    //create default Geohash for bathurst
    double lat = kLagLongBathurst.latitude;
    double long = kLagLongBathurst.longitude;
    String geoHash = Geohash.encode(lat, long, codeLength: 5);

    try {
      bool _permission = await _locationService.requestPermission() ==
          PermissionStatus.granted;
      //print("Permission: $_permission");
      if (_permission) {
        bool serviceStatus = await _locationService.serviceEnabled();
        //print("Service status: $serviceStatus");
        if (serviceStatus) {
          //Permission given
          //get actual lat long from actual user's location and download towers for the area
          LocationData location = await _locationService.getLocation();
          //create GeoHash for Actual location
          lat = location.latitude;
          long = location.longitude;
          logger.d("lat $lat and long is $long");
          geoHash = Geohash.encode(lat, long, codeLength: 5);
        } else {
          bool serviceStatusResult = await _locationService.requestService();
          //print("Service status activated after request: $serviceStatusResult");
          if (serviceStatusResult) {
            askForLocationPermission();
          }
        }
      } else {
        logger.w('Location permissions were denied by the user!');
        showSnackbar(
            message: 'Location permissions were denied by the user!',
            isDismissible: true);
        AnalyticsHelper().log('Location permissions were denied by the user!');
      }
    } on PlatformException catch (e) {
      print(e);
      if (e.code == 'PERMISSION_DENIED') {
        logger.d(e.message);
      } else if (e.code == 'SERVICE_STATUS_ERROR') {
        logger.d(e.message);
      }
    }

    if (mounted) {
      setState(() {
        // create marker for location
        Marker marker = Marker(
            markerId: MarkerId("My Location"),
            position: LatLng(lat, long),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            rotation: 0,
            alpha: 0.50,
            visible: false);

        //add to map overlay
        MapOverlay mapOverlay = MapOverlay(marker: marker);

        //add mapoverlay to list
        SiteHelper.globalListMapOverlay.add(mapOverlay);

        //move camera to location
        mapController.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(lat, long),
              zoom: kDefaultZoom,
            ),
          ),
        );
      });
    }

    downloadTowers(geoHash, true);

    //Saving first camera position as last so that reload everything option menu works.
    lastCameraPosition = CameraPosition(
      target: LatLng(lat, long),
      zoom: kDefaultZoom,
    );

    // Start loading the first markers
    _onCameraMove(lastCameraPosition);
  }

  ///Download towers information for either bathurst or user's location
  void downloadTowers(String geoHash, bool expandGeohash) {
    //parse json and get all sites
    Telco.values.forEach((telco) {
//      if (telco != Telco.Telstra) {
//        return; //TODO remove this code
//      }

      int expansionAmount = 0;
      int recursionDepth = 0;

      // Don't download the same area more than once for a given telco
      if (SiteHelper.downloadedGeohashAlready(geoHash, telco)) {
        // See if any neighbour sites need downloading and fetch them if required also
        fetchNeighbourSites(
            geoHash: geoHash, telco: telco, expandGeohash: expandGeohash);
      } else {
        //logger.d('mygeoHash doest not exist');
        _downloadTowersForSingleTelco(telco, geoHash,
            expansionAmount: expansionAmount,
            recursionDepth: recursionDepth,
            expandGeohash: expandGeohash);
      }
    });
  }

  Future _downloadTowersForSingleTelco(Telco telco, String geoHash,
      {String nextPageURL,
      int expansionAmount,
      int recursionDepth,
      bool expandGeohash}) async {
    List<MapOverlay> listOfTowersForSingleTeclo = new List<MapOverlay>();

    logger.d(
        'GetSites: ${nextPageURL != null ? nextPageURL : '/towers/${TelcoHelper.getNameLowerCase(telco)}/?_view=json&_expand=yes&_count=50&_filter=geohash%3D%3D$geoHash'}');

    showSnackbar(
        message: "Downloading ${TelcoHelper.getName(telco)} towers...");

    SiteReponse rawReponse = await api.getMarkerData(nextPageURL != null
        ? nextPageURL
        : '/towers/${TelcoHelper.getNameLowerCase(telco)}/?_view=json&_expand=yes&_count=50&_filter=geohash%3D%3D$geoHash');

    int totalLatLong = rawReponse?.restify?.rows?.length ?? 0;

    //If no data found for this telco then don't do anything
    if (totalLatLong == 0) {
      return;
    }

    //1) Start displaying markers
    for (int i = 0; i <= totalLatLong - 1; i++) {
      //Get the row
      Values values = rawReponse.restify.rows[i].values;

      //Create site from row
      Site site = Site(
          telco: telco,
          siteId: values.siteId.value,
          name: values.name.value,
          licensingAreaId: values.licensingAreaId != null
              ? int.parse(values.licensingAreaId.value)
              : 0,
          latitude: double.parse(values.latitude.value),
          longitude: double.parse(values.longitude.value),
          state: values.state.value,
          postcode: values.postcode.value,
          elevation: values.elevation.value);

      ///create marker
      Marker marker = Marker(
          markerId: MarkerId(
              "marker_${TelcoHelper.getName(site.telco)}_${site.siteId}_${site.latitude}_${site.longitude}"),
          // title: site.name,
          position: LatLng(site.latitude, site.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(site.color),
          rotation: site.rotation,
          alpha: site.alpha,
          visible: site.shouldBeVisible(),
          //infoWindow: InfoWindow(title: ' ', snippet: 'Site Data \n dsfdf'),
          onTap: () {
            _showCustomInfoWindowAsBottomSheet(context, site);
          });

      //add to map overlay
      MapOverlay mapOverlay = MapOverlay(marker: marker, site: site);

      //add mapoverlay to list
      listOfTowersForSingleTeclo.add(mapOverlay);
    }

    setState(() {
      SiteHelper.globalListMapOverlay.addAll(listOfTowersForSingleTeclo);
    });

//    Future.delayed(Duration(seconds: 3), () {
//      logger.d(
//          "total towers downloaded are ${SiteHelper.globalListMapOverlay.length} and displaying on map are ${SiteHelper.globalListMapOverlay.map((data) => data.marker).toSet().length}");
//    });

    //Add expansion amount
    expansionAmount = expansionAmount + totalLatLong;

    //2) Download next page towers if exist
    NextPage nextPage = rawReponse.restify.nextPage;
    if (nextPage != null) {
      logger.d("next page exist");
      _downloadTowersForSingleTelco(telco, geoHash,
          nextPageURL: nextPage.href,
          expansionAmount: expansionAmount,
          recursionDepth: recursionDepth,
          expandGeohash: expandGeohash);
    } else {
      // Draw the developer mode squares, as required
      if (MapHelper().developerMode) {
        MapHelper().removeDeveloperShapes();
        MapHelper().drawDeveloperShapes();
      }
    }

    //3) Prepare to query for the devices at the site
    String site_ids = "";
    //int siteCounter = 0;
    listOfTowersForSingleTeclo.forEach((MapOverlay mapOverlay) {
      if (mapOverlay.site != null) {
        site_ids = site_ids + 'site_id%3D%3D${mapOverlay.site.siteId}||';
        //siteCounter++;
      }
    });
    if (site_ids.length > 2) {
      // Trim the last two "||" characters
      site_ids = site_ids.substring(0, site_ids.length - 2);

      // Reduce bandwidth by only downloading required fields
      String fields =
          "sdd_id%2Cdevice_registration_identifier%2Csite_id%2Cfrequency%2Cemission%2Cbandwidth%2Cpolarisation%2Cheight%2Ceirp%2Cantenna_id%2Ccall_sign%2Cazimuth";

      String url = '';

      if (TelcoHelper.isTelecommunications(telco)) {
        fields += "%2Cactive";
        url =
            '/towers/device_details_mobile_${TelcoHelper.getNameLowerCase(telco)}/?_view=json&_expand=yes&_count=150&_sort=site_id+asc&_fields=$fields&_filter=$site_ids';
      } else {
        url =
            '/towers/device_details_${TelcoHelper.getNameLowerCase(telco)}/?_view=json&_expand=yes&_count=150&_sort=site_id+asc&_fields=$fields&_filter=$site_ids';
      }

      //logger.d('get device url for site count $siteCounter');
      GetDevices(
              url: url,
              telco: telco,
              listOfTowersForSingleTeclo: listOfTowersForSingleTeclo,
              showSnackBar: showSnackbar,
              onTowerInfoChanged: refreshUI)
          .getDevicesData();
    }

    //4) See if any neighbour sites need downloading and fetch them if required also
    fetchNeighbourSites(
        expansionAmount: expansionAmount,
        recursionDepth: recursionDepth,
        geoHash: geoHash,
        telco: telco,
        expandGeohash: expandGeohash);
  }

  void fetchNeighbourSites(
      {int expansionAmount = 0,
      int recursionDepth = 0,
      String geoHash,
      Telco telco,
      bool expandGeohash}) {
    // See if any neighbour sites need downloading and fetch them if required also
    if (expandGeohash &&
        expansionAmount < SiteHelper.EXPANSION_LIMIT &&
        recursionDepth < SiteHelper.RECURSION_LIMIT) {
      String filter =
          getNeighbourRing(recursionDepth + 1, geoHash, telco).toString();
      if (filter.length > 2) {
        // Trim the last two "||" characters
        filter = filter.substring(0, filter.length - 2);
        logger.d(
            'neighbour ring is $filter for telco ${TelcoHelper.getName(telco)}');
        logger.i(
            "fetchNeighbourSites: recursionDepth=$recursionDepth + telco= ${TelcoHelper.getName(telco)} +  filter= $filter");
        String neightbourURL =
            '/towers/${TelcoHelper.getNameLowerCase(telco)}/?_view=json&_expand=yes&_count=50&_filter=$filter';

        _downloadTowersForSingleTelco(telco, geoHash,
            nextPageURL: neightbourURL,
            expansionAmount: expansionAmount,
            recursionDepth: recursionDepth + 1,
            expandGeohash: expandGeohash);
      }
    }
  }

  StringBuffer getNeighbourRing(int ringNumber, String geohash, Telco telco) {
    StringBuffer filter = new StringBuffer();

    // Move to the starting position
    for (int i = 0; i < ringNumber; i++) {
      geohash = GeoHashUtil().neighbor(geohash, [1, -1]);
    }

    //logger.d('final geo hash is $geohash for telco is ${telco.name}');

    // Record all the neighbours in a ring shape around the starting geohash
    final int moves = ringNumber * 2;
    final List<List<int>> directions = [
      [0, 1], //Right
      [-1, 0], //Bottom
      [0, -1], //Let
      [1, 0] //Top
    ];
    directions.forEach((List<int> direction) {
      for (int i = 0; i < moves; i++) {
        if (!SiteHelper.downloadedGeohashAlready(geohash, telco)) {
          //Log.d("GetSites", "getNeighbourRing: geohash="+geohash);
          filter.write("geohash%3D%3D" + geohash + "||");
        }
        geohash = GeoHashUtil().neighbor(geohash, direction);
      }
    });

    return filter;
  }

  void _onCameraMove(CameraPosition position) {
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

  void showSnackbar(
      {@required String message,
      Duration duration = const Duration(seconds: 1),
      bool isDismissible = false}) {
    final SnackBar snackBar = SnackBar(
      content: Text(message),
      duration: duration,
      backgroundColor: HexColor('3F51B5').withOpacity(0.8),
      action: isDismissible
          ? SnackBarAction(
              label: Strings.dismiss,
              textColor: Colors.white,
              onPressed: () {
                Scaffold.of(context)
                    .hideCurrentSnackBar(reason: SnackBarClosedReason.hide);
              })
          : null,
    );
    Scaffold.of(context).removeCurrentSnackBar();
    Scaffold.of(context).showSnackBar(snackBar);
  }

  void refreshUI({String message = 'Global refresh'}) {
    //logger.d('$message');
    if (mounted) {
      // TODO: This probably wasn't right!
      //setState(() {});
    }
  }

  void _showCustomInfoWindowAsBottomSheet(BuildContext context, Site site) {
    setState(() {
      //Remove any existing polygons first
      //PolygonHelper().globalListPolygons.clear();
      PolygonHelper.globalListPolygons.removeWhere((mapOverlay) {
        return !mapOverlay.polygon.polygonId.value.contains('developer');
      });
    });

    //disableFollowGPS(); //TODO

    // Reset the downloads since last click
    SiteHelper.siteDownloadSinceLastClick.clear();

    // Not switching betten terrain awareness and back
    PolygonHelper.switchingBetweenTerrainAwareness = false;

    // Get site details
    //String name = site.getNameFormatted();

    // Clear existing polygons on clicking the next one
    PolygonHelper().clearSitePatterns(false);

    _settingModalBottomSheet(context, site);

    if (PolygonHelper.drawPolygonsOnClick) {
      // Draw the signal polygon for this site
      Provider.of<PolygonHelper>(context, listen: false).queryForSignalPolygon(
        site,
        false,
        false,
        showSnackBar: showSnackbar,
      );
    }
  }

  void _settingModalBottomSheet(BuildContext context, Site site) {
    showDialog(
      context: context,
      builder: (BuildContext bc) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(site.getIconName(), width: 25),
                    SizedBox(height: 8.0),
                    ...prepareSiteTitleForInforWindow(
                        '${site.getNameFormatted()} ${site.state} ${site.postcode}'),
                    SizedBox(height: 8.0),
                    SitePropertiesTableWidget(
                      data: {
                        'Site ID:': '${site.siteId}',
                        'Latitude:': '${site.latitude}',
                        'Longitude:': '${site.longitude}',
                        if (site.elevation.isNotEmpty)
                          'Elevation:': '${site.elevation} metres',
                        if (getTowerHeightFromDeviceDetails(
                                site.getDeviceDetailsMobile()) >
                            0)
                          'Tower Height:':
                              '${getTowerHeightFromDeviceDetails(site.getDeviceDetailsMobile())} metres',
                      },
                    ),
                    // Text(
                    //   'Site ID: ${site.siteId}',
                    //   style: Theme.of(context).textTheme.bodyText1,
                    // ),
                    // Text(
                    //   'Latitude: ${site.latitude}',
                    //   style: Theme.of(context).textTheme.bodyText1,
                    // ),
                    // Text(
                    //   'Longitude: ${site.longitude}',
                    //   style: Theme.of(context).textTheme.bodyText1,
                    // ),
                    // if (site.elevation.length > 0) ...[
                    //   Text(
                    //     'Elevation: ${site.elevation}  metres',
                    //     style: Theme.of(context).textTheme.bodyText1,
                    //   ),
                    // ],
                    // if (site.getDeviceDetailsMobile().length > 0) ...[
                    //   Text(
                    //     'Tower Height:  ${getTowerHeightFromDeviceDetails(site.getDeviceDetailsMobile())}  metres',
                    //     style: Theme.of(context).textTheme.bodyText1,
                    //   ),
                    // ],
                    SizedBox(
                      height: 8.0,
                    ),
                    if (site.getDeviceDetailsMobile().length == 0) ...[
                      Text(
                        ' Device data still downloading...',
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                    ] else if (!TelcoHelper.isTelecommunications(
                        site.getTelco())) ...[
                      Text(
                        '${TelcoHelper.getName(site.getTelco())} Services',
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      Table(
                        border: TableBorder(),
                        children: [
                          TableRow(
                            children: [
                              Align(
                                alignment: AlignmentDirectional.topCenter,
                                child: Text(
                                  'Frequency',
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.topCenter,
                                child: Text(
                                  'Emission',
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.topCenter,
                                child: Text(
                                  'CallSign',
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.topCenter,
                                child: Text(
                                  'Capacity',
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ),
                            ],
                          ),
                          ...getMoreTableRowsForNonTelco(site),
                        ],
                      ),
                    ] else ...[
                      Text(
                        '${TelcoHelper.getName(site.getTelco())} Services',
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      SizedBox(height: 8),
                      Table(
                        columnWidths: {
                          0: IntrinsicColumnWidth(),
                          1: IntrinsicColumnWidth(),
                          2: IntrinsicColumnWidth(),
                          3: IntrinsicColumnWidth(),
                          4: IntrinsicColumnWidth(),
                          5: IntrinsicColumnWidth(),
                        },
                        children: [
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topCenter,
                                  child: Text(
                                    'Gen',
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topCenter,
                                  child: Text(
                                    'Freqncy',
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topCenter,
                                  child: Text(
                                    'Bandwth',
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topCenter,
                                  child: Text(
                                    'MIMO',
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topCenter,
                                  child: Text(
                                    'LTE',
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.topCenter,
                                child: Text(
                                  'Capacity',
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              )
                            ],
                          ),
                          ...getMoreTableRows(site),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                style: Theme.of(context).elevatedButtonTheme.style,
                onPressed: () {
                  launchURL(site.siteId);
                },
                child: Text('ACMA Website'),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  int getTowerHeightFromDeviceDetails(List<DeviceDetails> deviceDetailsMobile) {
    int height = 0;
    if (deviceDetailsMobile.length == 0) return height;
    for (DeviceDetails d in deviceDetailsMobile) {
      height += d.getTowerHeight();
    }
    return height = height ~/ deviceDetailsMobile.length;
  }

  List<TableRow> getMoreTableRows(Site site) {
    Map<String, MapEntry<DeviceDetails, bool>> freqToDeviceMapping =
        site.getDeviceDetailsMobileBands();

    List<TableRow> listOfTableRows = List<TableRow>();

    for (String bandEmission in freqToDeviceMapping.keys) {
      DeviceDetails d = freqToDeviceMapping[bandEmission].key;
      //Boolean active = freqToDeviceMapping.get(bandEmission).second;
      NetworkType networkType = d.getNetworkType();
      int mimoCount = site.countNumberAntennaPaths(d);

      TableRow singleTableRow = TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${NetworkTypeHelper.resolveNetworkToName(networkType)}',
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                '${TranslateFrequencies.formatFrequency(d.frequency, false)}',
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                '${TranslateFrequencies.formatBandwidth(d.bandwidth, false)}',
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                '${mimoCount}x',
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                '${LteTypeHelper.getFirstTwoChars(d.getLteType())}',
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              '${DeviceDetails.formatNetworkSpeed(site.getNetworkCapacity(d))}',
              style: Theme.of(context).textTheme.bodyText1,
            ),
          ),
        ],
      );
      listOfTableRows.add(singleTableRow);
    }

    return listOfTableRows;
  }

  List<TableRow> getMoreTableRowsForNonTelco(Site site) {
    Map<String, MapEntry<DeviceDetails, bool>> freqToDeviceMapping =
        site.getDeviceDetailsMobileBands();

    List<TableRow> listOfTableRows = List<TableRow>();

    for (String bandEmission in freqToDeviceMapping.keys) {
      DeviceDetails d = freqToDeviceMapping[bandEmission].key;
      //Boolean active = freqToDeviceMapping.get(bandEmission).second;
      TableRow singleTableRow = TableRow(children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            '${TranslateFrequencies.formatFrequency(d.frequency, true)}',
            style: Theme.of(context).textTheme.bodyText1,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            '${d.emission}',
            style: Theme.of(context).textTheme.bodyText1,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            '${d.callSign}',
            style: Theme.of(context).textTheme.bodyText1,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            '${DeviceDetails.formatNetworkSpeed(site.getNetworkCapacity(d))}',
            style: Theme.of(context).textTheme.bodyText1,
          ),
        ),
      ]);
      listOfTableRows.add(singleTableRow);
    }

    return listOfTableRows;
  }

  launchURL(String siteId) async {
    String url =
        'http://web.acma.gov.au/pls/radcom/site_search.site_lookup?pSITE_ID=$siteId&pSORT_BY=frequency';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      //throw 'Could not launch $url';
      logger.w('Could not luanch url');
    }
  }

  List<Text> prepareSiteTitleForInforWindow(String text) {
    List<Text> siteTitleDetails = List<Text>();
    for (String line in text.split(RegExp("\n"))) {
      siteTitleDetails.add(Text(
        '$line',
        style: Theme.of(context).textTheme.bodyText1,
      ));
    }
    return siteTitleDetails;
  }

  void _handleSearchQuery(String query) {
    // Centre the map on Australia
    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: const LatLng(-44, 113),
          northeast: const LatLng(-10, 154),
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

  void takeScreenshot() {
    widget.screenshotController.capture(pixelRatio: 1).then((File image) {
      logger.d("File Saved to Gallery ${image.path}");
      androidMethodChannel.invokeMethod(
          'takeScreenshot', onlyPath.basename(image.path));
    }).catchError((onError) {
      print(onError);
    });
  }
}

class SitePropertiesTableWidget extends StatelessWidget {
  final Map<String, String> data;

  const SitePropertiesTableWidget({
    Key key,
    @required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultColumnWidth: FixedColumnWidth(150.0),
      children: data.entries.map(
        (item) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    '${item.key}',
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${item.value}',
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
              ),
            ],
          );
        },
      ).toList(),
    );
  }
}
