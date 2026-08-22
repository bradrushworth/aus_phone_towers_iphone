import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:after_layout/after_layout.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geohash/geohash.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:location/location.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as onlyPath;
import 'package:phonetowers/helpers/ads_helper.dart';
import 'package:phonetowers/helpers/analytics_helper.dart';
import 'package:phonetowers/helpers/camera_restore_helper.dart';
import 'package:phonetowers/helpers/frequency_range_helper.dart';
import 'package:phonetowers/restful/rest_filter.dart';
import 'package:phonetowers/restful/get_devices.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/helpers/let_type_helper.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/helpers/screenshot_controller.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/support_prompt_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/overlay.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/site_response.dart';
import 'package:phonetowers/ui/map_platform.dart'
    if (dart.library.js) 'package:phonetowers/ui/map_web.dart';
import 'package:phonetowers/ui/widgets/ad_banner_container.dart';
import 'package:phonetowers/ui/widgets/navigation_menu.dart';
import 'package:phonetowers/ui/widgets/option_menu.dart';
import 'package:phonetowers/ui/widgets/support_prompt_screen.dart';
import 'package:phonetowers/utils/geo_hash.dart';
import 'package:phonetowers/utils/hex_color.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_constants.dart';

/// The three Rotating Map modes, mirroring Android's mutually-exclusive `rotatingMapGroup`
/// radio group (res/menu/popup_menu.xml) and
/// `RotationVectorSensorEventListener.ROTATING_MAP_TYPE`. Requested in #28.
enum RotatingMapMode {
  /// Bearing = GPS course-over-ground (Android's "Travel Direction", the default-checked item).
  travelDirection,

  /// Bearing = device magnetometer/fused-orientation heading (Android's "Phone Orientation"),
  /// works while the phone is stationary.
  phoneOrientation,

  /// No forced bearing changes; the camera keeps whatever bearing it currently has
  /// (Android's "Disable Rotation").
  disableRotation,
}

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> with AfterLayoutMixin<MapScreen> {
  double screenWidth = 0.0;
  double screenHeight = 0.0;
  late Logger logger;

  //Create an instance of ScreenshotController
  ScreenshotController screenshotController = ScreenshotController();

  //media_query class : enum orientation { portrait,landscape}
  Orientation screenOrientation = Orientation.portrait;

  late SharedPreferences prefs;

  late TrackingStatus _iOSTrackingStatus;

  // Guards configureAds() so we only request an ad once (and not on every rebuild).
  bool _adsConfigured = false;

  @override
  void initState() {
    super.initState();
    logger = Logger();
    WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_) => initAppTracingTransparency());
  }

  Future<void> initAppTracingTransparency() async {
    if (!kIsWeb && Platform.isIOS) {
      // Show tracking authorization dialog and ask for permission
      final TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;
      setState(() => _iOSTrackingStatus = status);

      // If the system can show an authorization request dialog
      if (status == TrackingStatus.notDetermined) {
        // Wait for dialog popping animation
        await Future.delayed(const Duration(milliseconds: 1000));
        // Request system's tracking authorization dialog
        final newStatus = await AppTrackingTransparency.requestTrackingAuthorization();
        setState(() => _iOSTrackingStatus = newStatus);

        // Check every 1s if the user has made a decision - previous await returns notDetermined instantly for some reason?
        if (newStatus == TrackingStatus.notDetermined) {
          Timer.periodic(const Duration(seconds: 1), (timer) async {
            final newStatus = await AppTrackingTransparency.trackingAuthorizationStatus;
            if (newStatus != _iOSTrackingStatus) {
              setState(() => _iOSTrackingStatus = newStatus);
              timer.cancel();
            }
          });
        }
      }
    }
  }

  /*
  * It uses after_layout(https://pub.dev/packages/after_layout) dependency
  *
  * */
  @override
  void afterFirstLayout(BuildContext context) async {
    //Show beta launch popup if not displayed.
    prefs = await SharedPreferences.getInstance();
    if (kIsWeb &&
        !SharedPreferencesHelper.getBoolean(SharedPreferencesHelper.betaLaunchPopup, prefs)) {
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
            TextButton(
              child: Text(Strings.betaLaunchPopupAction),
              onPressed: () {
                Navigator.of(context).pop();
                SharedPreferencesHelper.saveBoolean(
                  key: SharedPreferencesHelper.betaLaunchPopup,
                  value: true,
                  prefs: prefs,
                );
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
                  key: Key('screenshotKey'),
                  controller: screenshotController,
                  child: Scaffold(drawer: NavigationMenu(), body: MapBody(screenshotController)),
                ),
              ),
            ),
            Consumer<PurchaseHelper>(
              builder: (context, purchaseHelper, child) {
                // React to subscription changes: configure once when not
                // subscribed, and tear the ad down when the user is ad free.
                if (purchaseHelper.isSubscribed) {
                  _adsConfigured = false;
                  AdsHelper().hideBannerAd();
                } else {
                  _configureAdsOnce();
                }
                return Visibility(
                  visible: !purchaseHelper.isSubscribed,
                  child: Column(
                    children: <Widget>[
                      OrientationBuilder(
                        builder: (context, orientation) {
                          screenOrientation = MediaQuery.of(context).orientation;
                          return Container();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  //Ad Integration in the widget
  void _configureAdsOnce() {
    if (_adsConfigured) return;
    _adsConfigured = true;
    configureAds();
  }

  Future<void> configureAds() async {
    if (!kIsWeb) {
      if (!PurchaseHelper().isSubscribed) {
        // Show ads only if user has not subscribed to any of remove ads menu item
        // Get an AnchoredAdaptiveBannerAdSize before loading the ad.
        final AdSize bannerAdSize = AdSize.getInlineAdaptiveBannerAdSize(
          MediaQuery.sizeOf(context).width.truncate(),
          100,
        );

        String adUnitId = '';
        if (kDebugMode) {
          adUnitId = Platform.isAndroid
              ? "ca-app-pub-3940256099942544/9214589741"
              : "ca-app-pub-3940256099942544/2435281174";
          // adUnitId = Platform.isAndroid
          //     ? AdsHelper.androidPortraitAdUnitId
          //     : AdsHelper.iOSPortraitAdUnitId;
        } else {
          adUnitId = Platform.isAndroid
              ? AdsHelper.androidPortraitAdUnitId
              : AdsHelper.iOSPortraitAdUnitId;
        }

        //AdsHelper().hideBannerAd();
        AdsHelper().showBannerAd(bannerAdSize, adUnitId,
            onAdLoaded: () => setState(() {}));
      } else {
        AdsHelper().hideBannerAd();
      }
    }
  }
}

class MapBody extends StatefulWidget {
  final ScreenshotController screenshotController;

  MapBody(this.screenshotController);

  @override
  MapBodyState createState() => MapBodyState();
}

class MapBodyState extends AbstractMapBodyState with WidgetsBindingObserver {
  /// ******************** State variables ************************************
  late GoogleMapController mapController;
  Location _locationService = new Location();

  // Follow GPS (drive mode): keeps the map centred on the device's location. Mirrors the
  // Android app's "Follow GPS" toolbar action. The bool itself lives on MapHelper (see #23).
  // Lock Map: freezes pan/zoom/rotate/tilt/my-location/search camera moves so the map can be
  // screenshotted. Requested in #27.
  static bool lockMap = false;
  static StreamSubscription<LocationData>? _followGpsSubscription;

  // Rotating Map: 3-way mutually-exclusive mode selection matching Android's "Rotating Map"
  // submenu. Default is Travel Direction, matching Android's default-checked "Travel Direction"
  // item (RotationVectorSensorEventListener.rotatingMapType = ROTATING_MAP_TYPE.TRAVEL).
  // Requested in #28.
  static RotatingMapMode rotatingMapMode = RotatingMapMode.travelDirection;

  // Cached bearing sources. Like Android's CameraHelper.animateFollowGpsCamera(), which is only
  // ever invoked from CustomLocationListener on a Follow-GPS location update, the camera's
  // bearing here is only ever applied on a Follow-GPS location tick (see toggleFollowGPS below) -
  // these fields just cache the latest reading so it's ready at the next tick.

  // Travel Direction: GPS course-over-ground, gated on speed like Android's
  // CustomLocationListener (only updates the "direction of travel" while actually moving, so the
  // bearing doesn't jitter to 0/garbage while stationary or from GPS noise).
  static double? _lastTravelBearing;

  // Phone Orientation: latest device heading from the magnetometer/fused-orientation sensor,
  // kept continuously updated by _compassSubscription (mirrors Android's
  // RotationVectorSensorEventListener, which updates a field on every sensor event that's only
  // read back at the next location tick - i.e. it does NOT rotate a stationary phone outside of
  // a Follow-GPS tick).
  static double? _lastCompassHeading;
  static StreamSubscription<CompassEvent>? _compassSubscription;
  static Timer? _compassAvailabilityTimer;

  static MapBodyState? currentInstance;
  late SharedPreferences prefs;
  final TextEditingController _searchTextFilter = new TextEditingController();
  bool isShowCancelSearch = false;

  /*
  * Method channel for taking screenshots
  * */
  static const androidMethodChannel = const MethodChannel(
    'au.com.bitbot.phonetowers.flutter.provider/screenshot',
  );

  /// ******************** Overrided methods **********************************
  @override
  void initState() {
    super.initState();
    currentInstance = this;
    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb) {
      PurchaseHelper().initStoreInfo(showSnackBar: showSnackbar);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSupportPrompt());
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
              builder: (context, polygonHelper, siteHelper, mapHelper, child) => GoogleMap(
                padding: EdgeInsets.only(bottom: AdsHelper().bannerAd == null ? 80 : 120, top: 80),
                myLocationEnabled: true,
                mapType: mapHelper.getMapType(),
                buildingsEnabled: false,
                compassEnabled: !kIsWeb,
                myLocationButtonEnabled: !MapBodyState.lockMap,
                scrollGesturesEnabled: !MapBodyState.lockMap,
                trafficEnabled: false,
                rotateGesturesEnabled: !MapBodyState.lockMap,
                tiltGesturesEnabled: !MapBodyState.lockMap,
                indoorViewEnabled: false,
                mapToolbarEnabled: true,
                zoomControlsEnabled: true,
                zoomGesturesEnabled: !MapBodyState.lockMap,
                initialCameraPosition: CameraPosition(target: kLagLongBathurst, zoom: kDefaultZoom),
                markers: _buildMarkerSet(),
                polygons: PolygonHelper.globalListPolygons.isNotEmpty
                    ? PolygonHelper.globalListPolygons.map((data) => data.polygon!).toSet()
                    : Set(),
                onMapCreated: onMapCreated,
                onCameraMove: onCameraMove,
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5)),
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
            ),
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
                        Provider.of<SearchHelper>(context, listen: false).setSearchStatus(false);
                      },
                    )
                  : null,
              title: !SearchHelper.calculatingSearchResults
                  ? AutoSizeText(Strings.app_title, style: TextStyle(color: Colors.grey))
                  : TextField(
                      cursorColor: Colors.grey[600],
                      controller: _searchTextFilter,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        suffixIcon: isShowCancelSearch
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey[600]),
                                onPressed: () {
                                  setState(() {
                                    _searchTextFilter.text = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (query) {
                        logger.d('search query is $query');
                        handleSearchQuery(mapController, query);
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
                    icon: Image.asset(
                      PolygonHelper.calculateTerrain
                          ? 'assets/images/ic_terrain_selected.png'
                          : 'assets/images/ic_terrain_unselected.png',
                    ),
                    tooltip: Strings.calculate_terrain,
                    onPressed: () {
                      PolygonHelper.calculateTerrain = !PolygonHelper.calculateTerrain;
                      SharedPreferencesHelper.saveBoolean(
                        key: SharedPreferencesHelper.kcalculateTerrain,
                        value: PolygonHelper.calculateTerrain,
                        prefs: prefs,
                      );
                      setState(() {});
                      showSnackbar(
                        message: PolygonHelper.calculateTerrain
                            ? 'Using terrain data when calculating propagation models! This is more accurate but slower.'
                            : 'Ignoring terrain when calculating propagation models.',
                      );
                      PolygonHelper().switchTerrainAwareness();
                    },
                  ),
                ),
                OptionsMenu(
                  showSnackBar: showSnackbar,
                  onCameraMoveFromLastLocation: onCameraMoveFromLastLocation,
                  takeScreenshot: takeScreenshot,
                ),
              ],
            ),
          ),
        ),
        Visibility(
          visible: !PurchaseHelper().isSubscribed,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: AdBannerContainer(
                adSize: AdsHelper().loadedAdSize == null
                    ? null
                    : Size(
                        AdsHelper().loadedAdSize!.width.toDouble(),
                        AdsHelper().loadedAdSize!.height.toDouble(),
                      ),
                adChild: AdsHelper().bannerAd == null
                    ? null
                    : AdWidget(ad: AdsHelper().bannerAd!),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    //Free some memory
    //PurchaseHelper().subscription.cancel();
    // Phone Orientation's heading subscription is only cancelled when the user switches to a
    // different Rotating Map mode; if the widget is torn down while it's still active, cancel it
    // here too so it doesn't leak.
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _compassAvailabilityTimer?.cancel();
    _compassAvailabilityTimer = null;
    if (!kIsWeb) AdsHelper().hideBannerAd();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Persist camera position as a single JSON blob (one atomic write) so we
      // can restore it if the OS reclaims memory and cold-restarts the app
      // while backgrounded.
      if (lastCameraPosition != null) {
        SharedPreferencesHelper.setString(
          SharedPreferencesHelper.kCameraPosition,
          encodeCameraPosition(lastCameraPosition!),
          prefs,
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      // AppLifecycleState.resumed fires on every return to the foreground,
      // warm or cold restart alike -- it is not restricted to cold restarts.
      // Restoring here is safe to call unconditionally because
      // _restoreCameraIfAvailable() is a no-op unless there's a saved
      // position and Follow GPS isn't active.
      _restoreCameraIfAvailable();
    }
  }

  /// Restores the last-saved camera position (persisted above when the app is
  /// paused), used both for a cold OS restart (via [onMapCreated]) and for a
  /// plain foreground resume. Skips restoring when Follow GPS is active, since
  /// live GPS tracking should win over a stale pre-background position.
  ///
  /// Returns the restored position (or null if nothing was restored) so
  /// callers -- notably [askForLocationPermission] -- can tell whether they
  /// need to avoid clobbering it with their own GPS-centering camera move.
  CameraPosition? _restoreCameraIfAvailable() {
    final String storedJson = SharedPreferencesHelper.getString(
        SharedPreferencesHelper.kCameraPosition, prefs);
    final CameraPosition? restored = resolveRestoredCameraPosition(
      storedJson: storedJson.isEmpty ? null : storedJson,
      followGPSActive: MapHelper.followGPS,
    );
    if (restored == null) return null;

    lastCameraPosition = restored;
    mapController.animateCamera(
        CameraUpdate.newLatLngZoom(restored.target, restored.zoom));
    return restored;
  }

  ///********************** Helper methods *************************************

  // Weekly "Support the App" prompt, ported from the Java app's
  // MapsActivity.maybeShowSupportPrompt(). Decision logic lives in SupportPromptHelper
  // (pure, unit-tested); this just wires it to SharedPreferences + navigation.
  Future<void> _maybeShowSupportPrompt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? lastShown = prefs.containsKey(SharedPreferencesHelper.kSupportPromptLastShown)
        ? SharedPreferencesHelper.getInt(
            key: SharedPreferencesHelper.kSupportPromptLastShown, prefs: prefs)
        : null;
    final SupportPromptDecision decision = SupportPromptHelper.decide(
      lastShownMillis: lastShown,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    if (decision.newLastShownMillis != null) {
      await SharedPreferencesHelper.setInt(
        key: SharedPreferencesHelper.kSupportPromptLastShown,
        value: decision.newLastShownMillis!,
        prefs: prefs,
      );
    }
    if (decision.shouldShow && mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SupportPromptScreen()));
    }
  }

  void _loadNavigationSavedState() async {
    prefs = await SharedPreferences.getInstance();

    //Licences
    NavigationMenu.isTelstraVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisTelstraVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Telstra, NavigationMenu.isTelstraVisible);
    NavigationMenu.isOptusVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisOptusVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Optus, NavigationMenu.isOptusVisible);
    NavigationMenu.isVodafoneVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisVodafoneVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Vodafone, NavigationMenu.isVodafoneVisible);
    NavigationMenu.isDenseAirVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisDenseAirVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Dense_Air, NavigationMenu.isDenseAirVisible);
    NavigationMenu.isNBNVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisNBNVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.NBN, NavigationMenu.isNBNVisible);
    NavigationMenu.isOtherVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisOtherVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Other, NavigationMenu.isOtherVisible);

    //2G/3G4G/5G
    NavigationMenu.is2GVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kis2GVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoNetwork(NetworkType.GSM, NavigationMenu.is2GVisible);
    NavigationMenu.is3GVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kis3GVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoNetwork(NetworkType.UMTS, NavigationMenu.is3GVisible);
    NavigationMenu.is4GVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kis4GVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoNetwork(NetworkType.LTE, NavigationMenu.is4GVisible);
    NavigationMenu.is5GVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kis5GVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoNetwork(NetworkType.NR, NavigationMenu.is5GVisible);

    //Multiplex type
    NavigationMenu.isNOTLTEVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisNOTLTEVisible,
      prefs: prefs,
    );
    PolygonHelper.displayNotLteMultiplex = NavigationMenu.isNOTLTEVisible;
    NavigationMenu.isFDLTEVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisFDLTEVisible,
      prefs: prefs,
    );
    PolygonHelper.displayFdMultiplex = NavigationMenu.isFDLTEVisible;
    NavigationMenu.isTDLTEVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisTDLTEVisible,
      prefs: prefs,
    );
    PolygonHelper.displayTdMultiplex = NavigationMenu.isTDLTEVisible;
    SiteHelper().refreshSites();

    //Frequencies
    NavigationMenu.isLess700Visible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisLess700Visible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
      NavigationMenu.isLess700Visible,
      FrequencyRangesHelper.getValue(FrequencyRanges.VERY_LOW),
    );
    NavigationMenu.isBet700_100Visible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisBet700_100Visible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
      NavigationMenu.isBet700_100Visible,
      FrequencyRangesHelper.getValue(FrequencyRanges.LOW),
    );
    NavigationMenu.isBet1_2Visible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisBet1_2Visible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
      NavigationMenu.isBet1_2Visible,
      FrequencyRangesHelper.getValue(FrequencyRanges.MEDIUM),
    );
    NavigationMenu.isBet2_3Visible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisBet2_3Visible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
      NavigationMenu.isBet2_3Visible,
      FrequencyRangesHelper.getValue(FrequencyRanges.HIGH),
    );
    NavigationMenu.isGreater3Visible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisGreater3Visible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
      NavigationMenu.isGreater3Visible,
      FrequencyRangesHelper.getValue(FrequencyRanges.VERY_HIGH),
    );

    //CityDensities
    NavigationMenu.isMetroVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisMetroVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleCityDensity(NavigationMenu.isMetroVisible, CityDensity.METRO);
    NavigationMenu.isUrbanVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisUrbanVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleCityDensity(NavigationMenu.isUrbanVisible, CityDensity.URBAN);
    NavigationMenu.isSuburbanVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisSuburbanVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleCityDensity(NavigationMenu.isSuburbanVisible, CityDensity.SUBURBAN);
    NavigationMenu.isOpenVisible = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kisOpenVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleCityDensity(NavigationMenu.isOpenVisible, CityDensity.OPEN);

    NavigationMenu.signalStrengthSelection = SharedPreferencesHelper.getSignalStrength(
      key: SharedPreferencesHelper.ksignalStrengthSelection,
      prefs: prefs,
    );
    switch (NavigationMenu.signalStrengthSelection) {
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
      key: SharedPreferencesHelper.kisTelcoVisible,
      prefs: prefs,
    );
    if (NavigationMenu.isTelcoVisible) {
      NavigationMenu.isTelstraVisible = NavigationMenu.isTelstraVisible;
      NavigationMenu.isOptusVisible = NavigationMenu.isOptusVisible;
      NavigationMenu.isVodafoneVisible = NavigationMenu.isVodafoneVisible;
      NavigationMenu.isDenseAirVisible = NavigationMenu.isDenseAirVisible;
      NavigationMenu.isNBNVisible = NavigationMenu.isNBNVisible;
      NavigationMenu.isOtherVisible = NavigationMenu.isOtherVisible;
      SiteHelper().enableTelcoInUse(true);
    } else {
      NavigationMenu.isTelstraVisible = false;
      NavigationMenu.isOptusVisible = false;
      NavigationMenu.isVodafoneVisible = false;
      NavigationMenu.isDenseAirVisible = false;
      NavigationMenu.isNBNVisible = false;
      NavigationMenu.isOtherVisible = false;
      SiteHelper().disableTelcos();
    }

    NavigationMenu.isRadioVisible = SharedPreferencesHelper.getMenuStatusOtherThanTelco(
      key: SharedPreferencesHelper.kisRadioVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Radio, NavigationMenu.isRadioVisible);

    NavigationMenu.isTVVisible = SharedPreferencesHelper.getMenuStatusOtherThanTelco(
      key: SharedPreferencesHelper.kisTVVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.TV, NavigationMenu.isTVVisible);

    NavigationMenu.isCivilVisible = SharedPreferencesHelper.getMenuStatusOtherThanTelco(
      key: SharedPreferencesHelper.kisCivilVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Civil, NavigationMenu.isCivilVisible);

    NavigationMenu.isPagerVisible = SharedPreferencesHelper.getMenuStatusOtherThanTelco(
      key: SharedPreferencesHelper.kisPagerVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Pager, NavigationMenu.isPagerVisible);

    NavigationMenu.isCBRSVisible = SharedPreferencesHelper.getMenuStatusOtherThanTelco(
      key: SharedPreferencesHelper.kisCBRSVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.CBRS, NavigationMenu.isCBRSVisible);

    NavigationMenu.isAviationVisible = SharedPreferencesHelper.getMenuStatusOtherThanTelco(
      key: SharedPreferencesHelper.kisAviationVisible,
      prefs: prefs,
    );
    Provider.of<SiteHelper>(
      context,
      listen: false,
    ).toggleTelcoMarkers(Telco.Aviation, NavigationMenu.isAviationVisible);

    //Options menu
    PolygonHelper.showPolygonBorders = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kshowPolygonBorders,
      prefs: prefs,
    );

    MapHelper().mapMode = SharedPreferencesHelper.getMapMode(
      key: SharedPreferencesHelper.kMapMode,
      prefs: prefs,
    );

    PolygonHelper.drawPolygonsOnClick = SharedPreferencesHelper.getMenuStatus(
      key: SharedPreferencesHelper.kdrawPolygonsOnClick,
      prefs: prefs,
    );

    PolygonHelper.calculateTerrain = SharedPreferencesHelper.getMenuStatusOtherThanTelco(
      key: SharedPreferencesHelper.kcalculateTerrain,
      prefs: prefs,
    );

    setState(() {});
  }

  void onMapCreated(dynamic controllerParam) {
    setState(() {
      mapController = controllerParam;
    });

    // If the app was cold-restarted by the OS while backgrounded, restore the
    // last saved camera position once the map is ready -- BEFORE requesting
    // location permission, so askForLocationPermission() (below) knows to
    // skip its own GPS-centering camera move rather than silently clobbering
    // the just-restored position once its async permission/location lookup
    // resolves.
    final CameraPosition? restored = _restoreCameraIfAvailable();

    askForLocationPermission(skipCameraRecenter: restored != null);
    //    Future.delayed(Duration(seconds: 2),(){
    //      logger.d('after 2 second delay');
    //      askForLocationPermission();
    //    });
  }

  /// Toggle Follow GPS (drive mode). When enabled, the camera is recentred on the device's
  /// location as it moves. Mirrors the Android app's "Follow GPS" toolbar action.
  ///
  /// Each location tick also supplies the map's bearing, folded into the same camera-position
  /// update (target + zoom + bearing together, one call) - this exactly mirrors Android's
  /// CameraHelper.animateFollowGpsCamera(), which is only ever invoked from
  /// CustomLocationListener on a Follow-GPS location update. This means Rotating Map only
  /// actually moves the camera on a Follow-GPS tick; it never rotates the map on its own while
  /// Follow GPS is off.
  static Future<void> toggleFollowGPS() async {
    final MapBodyState? state = currentInstance;
    if (state == null) return;
    MapHelper.followGPS = !MapHelper.followGPS;
    if (MapHelper.followGPS) {
      PermissionStatus permission = await state._locationService.requestPermission();
      if (permission != PermissionStatus.granted) {
        MapHelper.followGPS = false;
        state.showSnackbar(
            message: 'Cannot activate Follow GPS because location permission was not granted!',
            isDismissible: true);
        return;
      }
      if (!await state._locationService.serviceEnabled()) {
        await state._locationService.requestService();
      }
      _followGpsSubscription = state._locationService.onLocationChanged.listen((LocationData location) {
        if (!MapHelper.followGPS) return;
        if (lockMap) return;

        // Cache the GPS course-over-ground for Travel Direction mode. Mirrors Android's
        // CustomLocationListener, which only updates the "direction of travel" bearing while the
        // device is actually moving (speed >= 2 m/s), so it doesn't jitter to 0/garbage while
        // stationary or from GPS noise; otherwise the previous cached bearing is kept.
        if (location.heading != null && (location.speed ?? 0) >= 2) {
          _lastTravelBearing = location.heading;
        }

        final CameraPosition? last = state.lastCameraPosition;
        state.mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(location.latitude!, location.longitude!),
              zoom: last?.zoom ?? kDefaultZoom,
              tilt: last?.tilt ?? 0,
              bearing: _rotatingMapBearing(fallback: last?.bearing ?? 0),
            ),
          ),
        );
      });
      state.showSnackbar(
          message:
              'GPS is now ON. This mode uses battery faster and keeps the screen centred on your location while you move!');
    } else {
      await _followGpsSubscription?.cancel();
      _followGpsSubscription = null;
      state.showSnackbar(
          message:
              'GPS is now OFF. This will save battery and stop the screen from recentring on your location!');
    }
    state.setState(() {});
  }

  /// The bearing to apply on the next Follow-GPS camera update, chosen per the current Rotating
  /// Map mode. Mirrors Android's RotationVectorSensorEventListener.getRotation():
  /// Travel Direction -> cached GPS course, Phone Orientation -> cached compass heading,
  /// Disable Rotation -> [fallback] (i.e. leave the bearing as it currently is).
  static double _rotatingMapBearing({required double fallback}) {
    switch (rotatingMapMode) {
      case RotatingMapMode.travelDirection:
        return _lastTravelBearing ?? fallback;
      case RotatingMapMode.phoneOrientation:
        return _lastCompassHeading ?? fallback;
      case RotatingMapMode.disableRotation:
        return fallback;
    }
  }

  /// Select a Rotating Map mode (Travel Direction / Phone Orientation / Disable Rotation).
  /// Mirrors Android's mutually-exclusive "Rotating Map" submenu
  /// (MapsActivity#onOptionsItemSelected, R.id.travelRotatingMapMenu /
  /// orientationRotatingMapMenu / disableRotatingMapMenu). Requested in #28.
  ///
  /// Selecting a mode does not by itself move the camera - the new bearing is only applied at the
  /// next Follow-GPS location tick (see toggleFollowGPS above), exactly like Android.
  static Future<void> setRotatingMapMode(RotatingMapMode mode) async {
    final MapBodyState? state = currentInstance;
    if (state == null) return;

    // Leaving Phone Orientation: stop listening to the compass, nothing left to cache.
    if (rotatingMapMode == RotatingMapMode.phoneOrientation &&
        mode != RotatingMapMode.phoneOrientation) {
      await _compassSubscription?.cancel();
      _compassSubscription = null;
      _compassAvailabilityTimer?.cancel();
      _compassAvailabilityTimer = null;
      _lastCompassHeading = null;
    }

    rotatingMapMode = mode;

    switch (mode) {
      case RotatingMapMode.travelDirection:
        state.showSnackbar(
            message:
                'Rotating Map: Travel Direction. While Follow GPS is on, the map will face the '
                'direction you are travelling.');
        break;
      case RotatingMapMode.disableRotation:
        state.showSnackbar(
            message: 'Rotating Map: Disabled. The map bearing will no longer be changed '
                'automatically.');
        break;
      case RotatingMapMode.phoneOrientation:
        // flutter_compass relies on CoreLocation on iOS (for true-heading/declination
        // correction), so it still needs location permission even though it isn't reading GPS
        // fixes for the heading itself.
        PermissionStatus permission = await state._locationService.requestPermission();
        if (permission != PermissionStatus.granted) {
          rotatingMapMode = RotatingMapMode.travelDirection;
          state.showSnackbar(
              message:
                  'Cannot use Phone Orientation because location permission was not granted!',
              isDismissible: true);
          state.setState(() {});
          return;
        }
        if (!await state._locationService.serviceEnabled()) {
          await state._locationService.requestService();
        }

        final Stream<CompassEvent>? events = FlutterCompass.events;
        if (events == null) {
          // Mirrors Android's RotationVectorSensorEventListener check for
          // Sensor.TYPE_ROTATION_VECTOR / "Unfortunately, your device has no compass!".
          state.showSnackbar(
              message: 'Unfortunately, your device has no compass!', isDismissible: true);
        } else {
          _lastCompassHeading = null;
          _compassSubscription = events.listen((CompassEvent event) {
            if (rotatingMapMode != RotatingMapMode.phoneOrientation) return;
            if (event.heading != null) _lastCompassHeading = event.heading;
          });
          // flutter_compass has no synchronous "has compass" check (unlike Android's
          // SensorManager.getDefaultSensor() == null), so detect it the way Android's message is
          // surfaced to the user: if no heading has arrived shortly after subscribing, assume
          // there's no usable compass sensor on this device.
          _compassAvailabilityTimer = Timer(const Duration(seconds: 3), () {
            if (rotatingMapMode == RotatingMapMode.phoneOrientation && _lastCompassHeading == null) {
              state.showSnackbar(
                  message: 'Unfortunately, your device has no compass!', isDismissible: true);
            }
          });
          state.showSnackbar(
              message: 'Rotating Map: Phone Orientation. While Follow GPS is on, the map will '
                  'face where you point the phone.');
        }
        break;
    }
    state.setState(() {});
  }

  /// [skipCameraRecenter] is set when a saved camera position was just
  /// restored from SharedPreferences (see [_restoreCameraIfAvailable]) --
  /// in that case we must NOT move the camera to the device's live GPS
  /// location (or the hardcoded default) here, or we'd silently overwrite
  /// the just-restored position.
  Future askForLocationPermission({bool skipCameraRecenter = false}) async {
    //create default Geohash for bathurst
    double lat = kLagLongBathurst.latitude;
    double long = kLagLongBathurst.longitude;
    String geoHash = Geohash.encode(lat, long, codeLength: 5);

    try {
      bool _permission = await _locationService.requestPermission() == PermissionStatus.granted;
      //print("Permission: $_permission");
      if (_permission) {
        bool serviceStatus = await _locationService.serviceEnabled();
        //print("Service status: $serviceStatus");
        if (serviceStatus) {
          //Permission given
          //get actual lat long from actual user's location and download towers for the area
          LocationData location = await _locationService.getLocation();
          //create GeoHash for Actual location
          lat = location.latitude!;
          long = location.longitude!;
          logger.d("lat $lat and long is $long");
          geoHash = Geohash.encode(lat, long, codeLength: 5);
        } else {
          bool serviceStatusResult = await _locationService.requestService();
          //print("Service status activated after request: $serviceStatusResult");
          if (serviceStatusResult) {
            askForLocationPermission(skipCameraRecenter: skipCameraRecenter);
          }
        }
      } else {
        logger.w('Location permissions were denied by the user!');
        showSnackbar(message: 'Location permissions were denied by the user!', isDismissible: true);
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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          rotation: 0,
          alpha: 0.50,
          visible: false,
        );

        // add to map overlay
        MapOverlay mapOverlay = MapOverlay(marker: marker);

        // add map overlay to list
        SiteHelper.globalListMapOverlay.add(mapOverlay);

        if (!skipCameraRecenter) {
          // move camera to location
          logger.i('moveCamera: $lat, $long');
          mapController.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(lat, long), zoom: kDefaultZoom),
            ),
          );
        }
      });
    }

    downloadTowers(geoHash, true);

    if (!skipCameraRecenter) {
      // Saving first camera position as last so that reload everything option menu works.
      lastCameraPosition = CameraPosition(target: LatLng(lat, long), zoom: kDefaultZoom);

      // Start loading the first markers
      onCameraMove(lastCameraPosition!);
    }
    // When skipCameraRecenter is true, _restoreCameraIfAvailable() already set
    // lastCameraPosition and kicked off marker loading for the restored
    // position via mapController.animateCamera()'s onCameraMove callback, so
    // there's nothing further to do here.
  }

  ///Download towers information for either bathurst or user's location
  void downloadTowers(String geoHash, bool expandGeohash) {
    //parse json and get all sites
    Telco.values.forEach((telco) {
      // Only get the currently selected ones!
      // TODO Remove Dense Air once ready to go
      if (!SiteHelper.hideTelco.contains(telco) && telco != Telco.Dense_Air) {
        int expansionAmount = 0;
        int recursionDepth = 0;

        // Don't download the same area more than once for a given telco
        if (SiteHelper.downloadedGeohashAlready(geoHash, telco)) {
          // See if any neighbour sites need downloading and fetch them if required also
          fetchNeighbourSites(geoHash: geoHash, telco: telco, expandGeohash: expandGeohash);
        } else {
          //logger.d('mygeoHash doest not exist');
          downloadTowersForSingleTelco(
            telco,
            geoHash,
            expansionAmount: expansionAmount,
            recursionDepth: recursionDepth,
            expandGeohash: expandGeohash,
          );
        }
      }
    });
  }

  Future downloadTowersForSingleTelco(
    Telco telco,
    String geoHash, {
    String? nextPageURL,
    required int expansionAmount,
    required int recursionDepth,
    required bool expandGeohash,
  }) async {
    List<MapOverlay> listOfTowersForSingleTeclo = [];

    // RESTify faults an empty _filter VALUE (geohash==) with HTTP 412 ERROR #120,
    // so a blank geohash must skip the request rather than send it.
    if (nextPageURL == null && !RestFilter.isUsableValue(geoHash)) {
      logger.w('downloadTowersForSingleTelco: skipping request — blank geohash for $telco');
      return;
    }

    // logger.d(
    //   'GetSites: ${nextPageURL != null ? nextPageURL : '/towers/${TelcoHelper.getNameForApi(telco)}/?_view=json&_expand=yes&_count=50&_filter=geohash%3D%3D$geoHash'}',
    // );

    //showSnackbar(message: "Downloading ${TelcoHelper.getName(telco)} towers...");

    SiteResponse? rawResponse = await api.getMarkerData(
      nextPageURL != null
          ? nextPageURL
          : '/towers/${TelcoHelper.getNameForApi(telco)}/?_view=json&_expand=yes&_count=50&_filter=geohash%3D%3D$geoHash',
    );

    int totalLatLong = rawResponse!.restify?.rows?.length ?? 0;

    //If no data found for this telco then don't do anything
    if (totalLatLong == 0) {
      return;
    }

    // What is the correct CityDensity for this Telco/GeoHash?
    CityDensity cityDensity = Site.getCityDensityStatic(totalLatLong);

    //1) Start displaying markers
    for (int i = 0; i <= totalLatLong - 1; i++) {
      //Get the row
      Values? values = rawResponse.restify?.rows?[i].values;

      //Create site from row
      Site site = Site(
        telco: telco,
        cityDensity: cityDensity,
        siteId: values!.siteId!.value,
        name: values.name!.value,
        licensingAreaId: values.licensingAreaId != null
            ? int.parse(values.licensingAreaId!.value)
            : 0,
        latitude: double.parse(values.latitude!.value),
        longitude: double.parse(values.longitude!.value),
        state: values.state!.value,
        postcode: values.postcode!.value,
        elevation: values.elevation!.value,
      );

      Marker marker = Marker(
        markerId: MarkerId(
          "marker_${TelcoHelper.getName(site.telco)}_${site.siteId}_${site.latitude}_${site.longitude}",
        ),
        // title: site.name,
        position: LatLng(site.latitude!, site.longitude!),
        icon: BitmapDescriptor.bytes(await site.getIcon(), width: 20),
        rotation: site.rotation,
        alpha: site.alpha,
        visible: site.shouldBeVisible(),
        //infoWindow: InfoWindow(title: ' ', snippet: 'Site Data \n dsfdf'),
        onTap: () {
          showCustomInfoWindowAsBottomSheet(context, site);
        },
      );

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
    NextPage? nextPage = rawResponse.restify!.nextPage;
    if (nextPage != null) {
      //logger.d("next page exist");
      downloadTowersForSingleTelco(
        telco,
        geoHash,
        nextPageURL: nextPage.href,
        expansionAmount: expansionAmount,
        recursionDepth: recursionDepth,
        expandGeohash: expandGeohash,
      );
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
        site_ids = site_ids + 'site_id%3D%3D${mapOverlay.site!.siteId}||';
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
            '/towers/device_details_mobile_${TelcoHelper.getNameForApi(telco)}/?_view=json&_expand=yes&_count=150&_sort=site_id+asc&_fields=$fields&_filter=$site_ids';
      } else {
        url =
            '/towers/device_details_${TelcoHelper.getNameForApi(telco)}/?_view=json&_expand=yes&_count=150&_sort=site_id+asc&_fields=$fields&_filter=$site_ids';
      }

      //logger.d('get device url for site count $siteCounter');
      GetDevices(
        url: url,
        telco: telco,
        listOfTowersForSingleTelco: listOfTowersForSingleTeclo,
        showSnackBar: showSnackbar,
        onTowerInfoChanged: refreshUI,
      ).getDevicesData();
    }

    //4) See if any neighbour sites need downloading and fetch them if required also
    fetchNeighbourSites(
      expansionAmount: expansionAmount,
      recursionDepth: recursionDepth,
      geoHash: geoHash,
      telco: telco,
      expandGeohash: expandGeohash,
    );
  }

  void fetchNeighbourSites({
    int expansionAmount = 0,
    int recursionDepth = 0,
    required String geoHash,
    required Telco telco,
    required bool expandGeohash,
  }) {
    // See if any neighbour sites need downloading and fetch them if required also
    if (expandGeohash &&
        expansionAmount < SiteHelper.EXPANSION_LIMIT &&
        recursionDepth < SiteHelper.RECURSION_LIMIT) {
      String filter = getNeighbourRing(recursionDepth + 1, geoHash, telco).toString();
      if (filter.length > 2) {
        // Trim the last two "||" characters
        filter = filter.substring(0, filter.length - 2);
        // logger.d('neighbour ring is $filter for telco ${TelcoHelper.getName(telco)}');
        // logger.d(
        //   "fetchNeighbourSites: recursionDepth=$recursionDepth + telco= ${TelcoHelper.getName(telco)} +  filter= $filter",
        // );
        String neightbourURL =
            '/towers/${TelcoHelper.getNameForApi(telco)}/?_view=json&_expand=yes&_count=50&_filter=$filter';

        downloadTowersForSingleTelco(
          telco,
          geoHash,
          nextPageURL: neightbourURL,
          expansionAmount: expansionAmount,
          recursionDepth: recursionDepth + 1,
          expandGeohash: expandGeohash,
        );
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
      [1, 0], //Top
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

  void showSnackbar({
    required String message,
    Duration duration = const Duration(seconds: 1),
    bool isDismissible = false,
  }) {
    final SnackBar snackBar = SnackBar(
      content: Text(message),
      duration: duration,
      backgroundColor: HexColor('3F51B5').withValues(alpha: 0.8),
      action: isDismissible
          ? SnackBarAction(
              label: Strings.dismiss,
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).hideCurrentSnackBar(reason: SnackBarClosedReason.hide);
              },
            )
          : null,
    );
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void showCustomInfoWindowAsBottomSheet(BuildContext context, Site site) {
    setState(() {
      //Remove any existing polygons first (unless multi-tower coverage is on, in which
      //case previously-shown polygons should remain rendered alongside the new one)
      //PolygonHelper().globalListPolygons.clear();
      if (!PolygonHelper.multiTowerCoverage) {
        PolygonHelper.globalListPolygons.removeWhere((mapOverlay) {
          return !mapOverlay.polygon!.polygonId.value.contains('developer');
        });
      }
      // Drop this site's labels as well so they don't remain after the polygons are cleared.
      PolygonHelper.labelOverlays.removeWhere((mapOverlay) => mapOverlay.site == site);
    });

    //disableFollowGPS(); //TODO

    // Reset the downloads since last click
    SiteHelper.siteDownloadSinceLastClick.clear();

    // Not switching betten terrain awareness and back
    PolygonHelper.switchingBetweenTerrainAwareness = false;

    // Get site details
    //String name = site.getNameFormatted();

    // Clear existing polygons on clicking the next one (unless multi-tower coverage is on)
    if (!PolygonHelper.multiTowerCoverage) {
      PolygonHelper().clearSitePatterns(false);
    }

    _settingModalBottomSheet(context, site);

    if (PolygonHelper.drawPolygonsOnClick) {
      // Draw the signal polygon for this site
      Provider.of<PolygonHelper>(
        context,
        listen: false,
      ).queryForSignalPolygon(site, false, false, showSnackBar: showSnackbar);
    }
  }

  void _settingModalBottomSheet(BuildContext context, Site site) {
    AutoSizeGroup sizeGroup = AutoSizeGroup();
    showDialog(
      context: context,
      builder: (BuildContext bc) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
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
                    Image.asset(site.getIconFullName(), width: 20),
                    SizedBox(height: 8.0),
                    ...prepareSiteTitleForInfoWindow(
                      '${site.getNameFormatted()} ${site.state} ${site.postcode}',
                    ),
                    SizedBox(height: 8.0),
                    SitePropertiesTableWidget(
                      data: {
                        'Site ID:': '${site.siteId}',
                        'Latitude:': '${site.latitude}',
                        'Longitude:': '${site.longitude}',
                        if (site.elevation!.isNotEmpty) 'Elevation:': '${site.elevation} metres',
                        if (getTowerHeightFromDeviceDetails(site.getDeviceDetailsMobile()) > 0)
                          'Tower Height:':
                              '${getTowerHeightFromDeviceDetails(site.getDeviceDetailsMobile())} metres',
                        if (getTowerHeightFromDeviceDetails(site.getDeviceDetailsMobile()) > 0)
                          'City Density:': '${Site.getCityDensityName(site.getCityDensity())}',
                      },
                    ),
                    // Text(
                    //   'Site ID: ${site.siteId}',
                    //   style: Theme.of(context).textTheme.bodySmall,
                    // ),
                    // Text(
                    //   'Latitude: ${site.latitude}',
                    //   style: Theme.of(context).textTheme.bodySmall,
                    // ),
                    // Text(
                    //   'Longitude: ${site.longitude}',
                    //   style: Theme.of(context).textTheme.bodySmall,
                    // ),
                    // if (site.elevation.length > 0) ...[
                    //   Text(
                    //     'Elevation: ${site.elevation}  metres',
                    //     style: Theme.of(context).textTheme.bodySmall,
                    //   ),
                    // ],
                    // if (site.getDeviceDetailsMobile().length > 0) ...[
                    //   Text(
                    //     'Tower Height:  ${getTowerHeightFromDeviceDetails(site.getDeviceDetailsMobile())}  metres',
                    //     style: Theme.of(context).textTheme.bodySmall,
                    //   ),
                    // ],
                    SizedBox(height: 8.0),
                    if (site.getDeviceDetailsMobile().length == 0) ...[
                      AutoSizeText(
                        ' Device data still downloading...',
                        group: sizeGroup,
                        minFontSize: 8,
                        maxFontSize: 16,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ] else if (!TelcoHelper.isTelecommunications(site.getTelco())) ...[
                      AutoSizeText(
                        '${TelcoHelper.getName(site.getTelco())} Services',
                        group: sizeGroup,
                        minFontSize: 8,
                        maxFontSize: 16,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Table(
                        columnWidths: {
                          0: const FixedColumnWidth(80),
                          1: const FixedColumnWidth(80),
                          2: const FixedColumnWidth(70),
                          3: const FixedColumnWidth(70),
                        },
                        children: [
                          TableRow(
                            children: [
                              Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: AutoSizeText(
                                  'Frequency',
                                  group: sizeGroup,
                                  minFontSize: 8,
                                  maxFontSize: 16,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: AutoSizeText(
                                  'Emission',
                                  group: sizeGroup,
                                  minFontSize: 8,
                                  maxFontSize: 16,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: AutoSizeText(
                                  'CallSign',
                                  group: sizeGroup,
                                  minFontSize: 8,
                                  maxFontSize: 16,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: AutoSizeText(
                                  'Capacity',
                                  group: sizeGroup,
                                  minFontSize: 8,
                                  maxFontSize: 16,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          ...getMoreTableRowsForNonTelco(site),
                        ],
                      ),
                    ] else ...[
                      AutoSizeText(
                        '${TelcoHelper.getName(site.getTelco())} Services',
                        group: sizeGroup,
                        minFontSize: 8,
                        maxFontSize: 16,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      SizedBox(height: 8),
                      Table(
                        //border: TableBorder.all(),
                        columnWidths: {
                          0: const FixedColumnWidth(30),
                          1: const FixedColumnWidth(60),
                          2: const FixedColumnWidth(60),
                          3: const FixedColumnWidth(35),
                          4: const FixedColumnWidth(30),
                          5: const FixedColumnWidth(60),
                        },
                        children: [
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topStart,
                                  child: AutoSizeText(
                                    'Gen',
                                    group: sizeGroup,
                                    minFontSize: 8,
                                    maxFontSize: 16,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topEnd,
                                  child: AutoSizeText(
                                    'Freqncy',
                                    group: sizeGroup,
                                    minFontSize: 8,
                                    maxFontSize: 16,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topEnd,
                                  child: AutoSizeText(
                                    'Bandwth',
                                    group: sizeGroup,
                                    minFontSize: 8,
                                    maxFontSize: 16,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topEnd,
                                  child: AutoSizeText(
                                    'MIMO',
                                    group: sizeGroup,
                                    minFontSize: 8,
                                    maxFontSize: 16,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Align(
                                  alignment: AlignmentDirectional.topEnd,
                                  child: AutoSizeText(
                                    'LTE',
                                    group: sizeGroup,
                                    minFontSize: 8,
                                    maxFontSize: 16,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: AutoSizeText(
                                  'Capacity',
                                  group: sizeGroup,
                                  minFontSize: 8,
                                  maxFontSize: 16,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
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
                  launchURL(site.siteId!);
                },
                child: AutoSizeText('ACMA Website'),
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
    Map<String, MapEntry<DeviceDetails, bool>> freqToDeviceMapping = site
        .getDeviceDetailsMobileBands();

    AutoSizeGroup sizeGroup = AutoSizeGroup();
    List<TableRow> listOfTableRows = <TableRow>[];

    for (String bandEmission in freqToDeviceMapping.keys) {
      DeviceDetails d = freqToDeviceMapping[bandEmission]!.key;
      //Boolean active = freqToDeviceMapping.get(bandEmission).second;
      NetworkType networkType = d.getNetworkType();
      int mimoCount = site.countNumberAntennaPaths(d);

      TableRow singleTableRow = TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AutoSizeText(
                '${NetworkTypeHelper.resolveNetworkToName(networkType)}',
                group: sizeGroup,
                minFontSize: 8,
                maxFontSize: 16,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AutoSizeText(
                '${TranslateFrequencies.formatFrequency(d.frequency!, false)}',
                group: sizeGroup,
                minFontSize: 8,
                maxFontSize: 16,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AutoSizeText(
                '${TranslateFrequencies.formatBandwidth(d.bandwidth!, false)}',
                group: sizeGroup,
                minFontSize: 8,
                maxFontSize: 16,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AutoSizeText(
                '${mimoCount}x',
                group: sizeGroup,
                minFontSize: 8,
                maxFontSize: 16,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AutoSizeText(
                '${LteTypeHelper.getFirstTwoChars(d.getLteType())}',
                group: sizeGroup,
                minFontSize: 8,
                maxFontSize: 16,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AutoSizeText(
              '${DeviceDetails.formatNetworkSpeed(site.getNetworkCapacity(d))}',
              group: sizeGroup,
              minFontSize: 8,
              maxFontSize: 16,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
      listOfTableRows.add(singleTableRow);
    }

    return listOfTableRows;
  }

  List<TableRow> getMoreTableRowsForNonTelco(Site site) {
    Map<String, MapEntry<DeviceDetails, bool>> freqToDeviceMapping = site
        .getDeviceDetailsMobileBands();

    AutoSizeGroup sizeGroup = AutoSizeGroup();
    List<TableRow> listOfTableRows = <TableRow>[];

    for (String bandEmission in freqToDeviceMapping.keys) {
      DeviceDetails d = freqToDeviceMapping[bandEmission]!.key;
      //Boolean active = freqToDeviceMapping.get(bandEmission).second;
      TableRow singleTableRow = TableRow(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AutoSizeText(
              '${TranslateFrequencies.formatFrequency(d.frequency!, true)}',
              group: sizeGroup,
              minFontSize: 8,
              maxFontSize: 16,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AutoSizeText(
              '${d.emission}',
              group: sizeGroup,
              minFontSize: 8,
              maxFontSize: 16,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AutoSizeText(
              '${d.callSign}',
              group: sizeGroup,
              minFontSize: 8,
              maxFontSize: 16,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AutoSizeText(
              '${DeviceDetails.formatNetworkSpeed(site.getNetworkCapacity(d))}',
              group: sizeGroup,
              minFontSize: 8,
              maxFontSize: 16,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
      listOfTableRows.add(singleTableRow);
    }

    return listOfTableRows;
  }

  launchURL(String siteId) async {
    final uri = Uri.parse(
        'https://www.acma.gov.au/register-radiocommunication-licences-rrl#/sites/$siteId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      //throw 'Could not launch $url';
      logger.w('Could not launch url');
    }
  }

  List<Widget> prepareSiteTitleForInfoWindow(String text) {
    AutoSizeGroup sizeGroup = AutoSizeGroup();
    List<Widget> siteTitleDetails = <Widget>[];
    for (String line in text.split(RegExp("\n"))) {
      siteTitleDetails.add(
        AutoSizeText(
          '$line',
          group: sizeGroup,
          minFontSize: 8,
          maxFontSize: 16,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return siteTitleDetails;
  }

  /// Combine the tower markers with the frequency / technology labels drawn along the outer
  /// signal rings (PolygonHelper.labelOverlays).
  Set<Marker> _buildMarkerSet() {
    final Set<Marker> markers = <Marker>{};
    for (final MapOverlay overlay in SiteHelper.globalListMapOverlay) {
      if (overlay.marker != null) markers.add(overlay.marker!);
    }
    for (final MapOverlay overlay in PolygonHelper.labelOverlays) {
      if (overlay.marker != null) markers.add(overlay.marker!);
    }
    return markers;
  }

  void takeScreenshot() {
    widget.screenshotController
        .capture(pixelRatio: 1)
        .then((File image) {
          logger.d("File Saved to Gallery ${image.path}");
          androidMethodChannel.invokeMethod('takeScreenshot', onlyPath.basename(image.path));
        })
        .catchError((onError) {
          print(onError);
        });
  }
}

class SitePropertiesTableWidget extends StatelessWidget {
  final Map<String, String> data;

  const SitePropertiesTableWidget({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AutoSizeGroup sizeGroup = AutoSizeGroup();
    return Table(
      defaultColumnWidth: FixedColumnWidth(90.0),
      children: data.entries.map((item) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AutoSizeText(
                  '${item.key}',
                  group: sizeGroup,
                  minFontSize: 8,
                  maxFontSize: 16,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AutoSizeText(
                  '${item.value}',
                  group: sizeGroup,
                  minFontSize: 8,
                  maxFontSize: 16,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
