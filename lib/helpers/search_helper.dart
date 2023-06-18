import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/site_response.dart';
import 'package:phonetowers/utils/app_constants.dart';

typedef void ShowSnackBar({String message, bool isDismissible});

class SearchHelper with ChangeNotifier {
  static bool calculatingSearchResults = false;
  static int searchStatus = kSearchStopped;
  static final String DB_WILD_CARD = "%25";
  Logger logger = new Logger();
  Api api = Api.initialize();
  final ShowSnackBar? showSnackBar;
  dynamic mapController; // Could be a platform or web Google map controller
  List<LatLng> listLatLongBounds = [];

  SearchHelper({this.showSnackBar, this.mapController});

  void setSearchStatus(bool status) {
    calculatingSearchResults = status;
    notifyListeners();
  }

  void executeSiteSearch(String query,
      void Function(String geoHash, bool expandGeohash) downloadTowers) {
    //MapsActivity.instance().disableFollowGPS();//TODO
    PolygonHelper().clearSitePatterns(true);
    calculatingSearchResults = true;
    String filter;
    if (RegExp(r'\d{4}').hasMatch(query)) {
      filter = 'postcode~~$query';
      showSnackBar!(
          message: 'Searching for postcode: $query', isDismissible: true);
    } else {
      filter = 'name~~$DB_WILD_CARD${Uri.encodeFull(query)}$DB_WILD_CARD';
      showSnackBar!(message: 'Searching for sites: $query', isDismissible: true);
    }
    String fields = "geohash";
    String url =
        '/towers/site/?_view=json&_expand=no&_count=50&_filter=$filter&_fields=$fields';
    getSearch(url, downloadTowers);
  }

  void getSearch(String url,
      void Function(String geoHash, bool expandGeohash) downloadTowers) async {
    Set<String> geohashes = Set<String>();
    logger.d('get search url $url');
    SiteResponse? rawResponse = await api.getSearchedData(url);

    int totalRows = rawResponse?.restify?.rows?.length ?? 0;

    //If no data found for this telco then don't do anything
    if (totalRows == 0) {
      showSnackBar!(message: 'No search results found!', isDismissible: true);
      return;
    }

    for (int i = 0; i < totalRows; i++) {
      //Get the row
      String? geoHashFromAPI = rawResponse?.restify?.rows?[i].values?.geohash?.value;
      geohashes.add(geoHashFromAPI!);
    }

    for (String geohash in geohashes) {
      // Draw these geohashes to map
      downloadTowers(geohash, false);
    }

    zoomToCurrentSites();
  }

  void zoomToCurrentSites() {
    calculatingSearchResults = false;
    notifyListeners();

    listLatLongBounds.clear();

    Future.delayed(Duration(seconds: 6), () {
      for (int i = 0; i < SiteHelper.globalListMapOverlay.length; i++) {
        if (SiteHelper.globalListMapOverlay[i].site != null) {
          final Marker? marker = SiteHelper.globalListMapOverlay[i].marker;
          listLatLongBounds.add(marker!.position);
        }
      }

      LatLngBounds latLngBoundsBuilder =
          boundsFromLatLngList(listLatLongBounds);

      // Ensure that the box is reasonably big
      double minSizeKm = 2;
      listLatLongBounds.add(
          GetLicenceHRP.travel(latLngBoundsBuilder.northeast, 45, minSizeKm));
      listLatLongBounds.add(
          GetLicenceHRP.travel(latLngBoundsBuilder.southwest, 225, minSizeKm));
      latLngBoundsBuilder = boundsFromLatLngList(listLatLongBounds);

      mapController.moveCamera(
        CameraUpdate.newLatLngBounds(
          latLngBoundsBuilder,
          10.0,
        ),
      );

      showSnackBar!(message: 'Searching is finished!');
    });
  }

  LatLngBounds boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(southwest: LatLng(x0!, y0!), northeast: LatLng(x1!, y1!));
  }
}
