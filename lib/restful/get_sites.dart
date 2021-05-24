//import 'package:google_maps_flutter/google_maps_flutter.dart';
//import 'package:logger/logger.dart';
//import 'package:phonetowers/helpers/site_helper.dart';
//import 'package:phonetowers/helpers/telco_helper.dart';
//import 'package:phonetowers/model/overlay.dart';
//import 'package:phonetowers/model/site.dart';
//import 'package:phonetowers/networking/api.dart';
//import 'package:phonetowers/networking/response/site_response.dart';
//import 'package:phonetowers/utils/geo_hash.dart';
//
//typedef void TowerAdded();
//typedef void ShowSnackBar({String message});
//
//class GetSites {
//  String url;
//  Telco telco;
//  String geoHash;
//  bool expandGeohash;
//  int expansionAmount;
//  int recursionDepth;
//  List<MapOverlay> listMapOverlay;
//  Logger logger = new Logger();
//  Api api = Api.initialize();
//  final TowerAdded onTowerAdded;
//  final ShowSnackBar showSnackBar;
//
//  GetSites(
//      {this.url,
//      this.telco,
//      this.geoHash,
//      this.expandGeohash,
//      this.expansionAmount = 0,
//      this.recursionDepth = 0,
//      this.listMapOverlay,
//      this.onTowerAdded,
//      this.showSnackBar});
//
//  Future downloadTowersForSingleTelco(
//      {String nextPageURL,
//      int expansionAmount = 0,
//      int recursionDepth = 0}) async {
//    this.url = nextPageURL;
//    this.expansionAmount = expansionAmount;
//    this.recursionDepth = recursionDepth;
//    this.listMapOverlay = new List<MapOverlay>();
//
//    logger.d(
//        'GetSites: ${url != null ? url : '/towers/${TelcoHelper.getNameLowerCase(telco)}/?_view=json&_expand=yes&_count=50&_filter=geohash%3D%3D$geoHash'}');
//
//    showSnackBar(
//        message: "Downloading ${TelcoHelper.getName(telco)} towers...");
//
//    SiteReponse rawReponse = await api.getMarkerData(nextPageURL != null
//        ? nextPageURL
//        : '/towers/${TelcoHelper.getNameLowerCase(telco)}/?_view=json&_expand=yes&_count=50&_filter=geohash%3D%3D$geoHash');
//
//    int totalLatLong = rawReponse.restify.rows.length;
//
//    //If no data found for this telco then don't do anything
//    if (totalLatLong == 0) {
//      return;
//    }
//
//    //1) Start displaying markers
//    for (int i = 0; i <= totalLatLong - 1; i++) {
//      //Get the row
//      Values values = rawReponse.restify.rows[i].values;
//
//      //Create site from row
//      Site site = Site(
//          telco: telco,
//          siteId: values.siteId.value,
//          name: values.name.value,
//          licensingAreaId: values.licensingAreaId != null
//              ? int.parse(values.licensingAreaId.value)
//              : 0,
//          latitude: double.parse(values.latitude.value),
//          longitude: double.parse(values.longitude.value),
//          state: values.state.value,
//          postcode: values.postcode.value,
//          elevation: values.elevation.value);
//
//      ///create marker
//      Marker marker = Marker(
//          markerId: MarkerId(
//              "marker_${TelcoHelper.getName(site.telco)}_${site.siteId}_${site.latitude}_${site.longitude}"),
//          position: LatLng(site.latitude, site.longitude),
//          icon: BitmapDescriptor.defaultMarkerWithHue(site.color),
//          rotation: site.rotation,
//          alpha: site.alpha);
//
//      //add to map overlay
//      MapOverlay mapOverlay = MapOverlay(marker: marker, site: site);
//
//      //add mapoverlay to list
//      listMapOverlay.add(mapOverlay);
//    }
//
//    //Display towers for each telco one by one
//    logger.d(
//        'Displaying $totalLatLong towers for  ${TelcoHelper.getName(telco)} and total towers are ${listMapOverlay.length}');
//    logger.d(
//        "Displaying markers to set ${listMapOverlay.map((data) => data.marker).toSet().length}");
//
//    //Add to global markers list
//    SiteHelper().globalListMapOverlay.addAll(listMapOverlay);
//    //Refresh main UI
//    onTowerAdded();
//
//    //Add expansion amount
//    this.expansionAmount = this.expansionAmount + totalLatLong;
//    logger.d("expansion amount is ${this.expansionAmount}");
//
//    //2) Download next page towers if exist
//    NextPage nextPage = rawReponse.restify.nextPage;
//    if (nextPage != null) {
//      logger.d("next page exist");
//      downloadTowersForSingleTelco(
//          nextPageURL: nextPage.href,
//          expansionAmount: this.expansionAmount,
//          recursionDepth: this.recursionDepth);
//    } else {
//      //TODO developer mode
//    }
//
//    //3) Prepare to query for the devices at the site
////    String site_ids = "";
////    listMapOverlay.forEach((MapOverlay mapOverlay) {
////      if (mapOverlay.site != null) {
////        site_ids = site_ids + 'site_id%3D%3D${mapOverlay.site.siteId}||';
////      }
////    });
////    if (site_ids.length > 2) {
////      // Trim the last two "||" characters
////      site_ids = site_ids.substring(0, site_ids.length - 2);
////
////      // Reduce bandwidth by only downloading required fields
////      String fields =
////          "sdd_id%2Cdevice_registration_identifier%2Csite_id%2Cfrequency%2Cemission%2Cbandwidth%2Cpolarisation%2Cheight%2Ceirp%2Ccall_sign%2Cazimuth";
////
////      String url='';
////
////      if (telco.isTelecom) {
////        fields += "%2Cactive";
////        url = '/towers/device_details_mobile_${telco.name.toLowerCase()}/?_view=json&_expand=yes&_count=150&_sort=site_id+asc&_fields=$fields&_filter=$site_ids';
////      } else {
////        url = '/towers/device_details_${telco.name.toLowerCase()}/?_view=json&_expand=yes&_count=150&_sort=site_id+asc&_fields=$fields&_filter=$site_ids';
////      }
////
////      logger.d('get device url is $url');
////      showSnackbar(message: "Downloading tower frequencies...");
////      GetDevices(url: url, telco: telco, listMapOverlay: listMapOverlay)
////          .getDevicesData();
////    }
//
//    //4) See if any neighbour sites need downloading and fetch them if required also
//    fetchNeighbourSites(
//        expansionAmount: this.expansionAmount,
//        recursionDepth: this.recursionDepth,
//        geoHash: geoHash,
//        telco: telco);
//  }
//
//  void fetchNeighbourSites(
//      {int expansionAmount = 0,
//      int recursionDepth = 0,
//      String geoHash,
//      Telco telco}) {
//    // See if any neighbour sites need downloading and fetch them if required also
//    if (expansionAmount < SiteHelper.EXPANSION_LIMIT &&
//        recursionDepth < SiteHelper.RECURSION_LIMIT) {
//      String filter =
//          getNeighbourRing(recursionDepth + 1, geoHash, telco).toString();
//      if (filter.length > 2) {
//        // Trim the last two "||" characters
//        filter = filter.substring(0, filter.length - 2);
//        logger.d(
//            'neighbour ring is $filter for telco ${TelcoHelper.getName(telco)}');
//        logger.i(
//            "fetchNeighbourSites: recursionDepth=$recursionDepth + telco= ${TelcoHelper.getName(telco)} +  filter= $filter");
//        String neightbourURL =
//            '/towers/${TelcoHelper.getNameLowerCase(telco)}/?_view=json&_expand=yes&_count=50&_filter=$filter';
//
//        downloadTowersForSingleTelco(
//          nextPageURL: neightbourURL,
//          expansionAmount: expansionAmount,
//          recursionDepth: recursionDepth + 1,
//        );
//      }
//    }
//  }
//
//  StringBuffer getNeighbourRing(int ringNumber, String geohash, Telco telco) {
//    StringBuffer filter = new StringBuffer();
//
//    // Move to the starting position
//    for (int i = 0; i < ringNumber; i++) {
//      geohash = GeoHashUtil().neighbor(geohash, [1, -1]);
//    }
//
//    //logger.d('final geo hash is $geohash for telco is ${telco.name}');
//
//    // Record all the neighbours in a ring shape around the starting geohash
//    final int moves = ringNumber * 2;
//    final List<List<int>> directions = [
//      [0, 1], //Right
//      [-1, 0], //Bottom
//      [0, -1], //Let
//      [1, 0] //Top
//    ];
//    directions.forEach((List<int> direction) {
//      for (int i = 0; i < moves; i++) {
//        if (!SiteHelper.downloadedGeohashAlready(geohash, telco)) {
//          //Log.d("GetSites", "getNeighbourRing: geohash="+geohash);
//          filter.write("geohash%3D%3D" + geohash + "||");
//        }
//        geohash = GeoHashUtil().neighbor(geohash, direction);
//      }
//    });
//
//    return filter;
//  }
//}
