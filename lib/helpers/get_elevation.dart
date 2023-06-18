import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/elevation_response.dart';

import 'get_licenceHRP.dart';

class GetElevation {
  static final List<double> SAMPLE_DISTANCES = [
    0.50,
    0.75,
    1,
    1.25,
    1.5,
    1.75,
    2,
    2.25,
    2.5,
    3,
    3.5,
    4,
    4.5,
    5.5,
    7,
    8.5,
    10,
    13,
    16
  ];
  Logger logger = Logger();
  Site site;
  Api api = Api.initialize();
  String url;

  GetElevation({required this.url, required this.site});

  static String getPositionsString(LatLng latLng) {
    StringBuffer sb = StringBuffer();
    sb.write(latLng.latitude.toStringAsFixed(3));
    sb.write(",");
    sb.write(latLng.longitude.toStringAsFixed(3));
    sb.write("|");

    int measurements = 1;
    num loops = 0;

    for (double dist in SAMPLE_DISTANCES) {
      // Randomise the layout a little bit
      loops += dist;
      // Don't query the elevation for every point when at a close radius
      int modulo =
          (3 + (SAMPLE_DISTANCES[SAMPLE_DISTANCES.length - 1]) / dist).toInt();
      // Limit the modulo for close accuracy. Using prime number for randomness
      if (modulo > 17) modulo = 17;
      for (double dir = 0; dir < 360; dir += 2.5) {
        loops++;
//                // Don't query the elevation for every point when at a close radius
        if (loops % modulo != 0) continue;

        LatLng point = GetLicenceHRP.travel(latLng, dir, dist);
        sb.write(point.latitude.toStringAsFixed(3));
        sb.write(",");
        sb.write(point.longitude.toStringAsFixed(3));
        sb.write("|");

        //mapsActivity.addMarkerToMap(new MarkerOptions().position(point).title("Elevation").alpha(0.2f), site);
        measurements++;
      }
    }

    String positionString = sb.toString().substring(0, sb.length - 1);
    //debugPrint('GetElevation", "getPositionsString: measurements=$measurements and positionString is $positionString');
    return positionString;
  }

  Future getElevationData() async {
    ElevationResponse? elevationResponse = await api.getElevationDataApi(url);
    List<Results>? rows = elevationResponse!.results;

    // looping through rows
    for (int i = 0; i < rows!.length; i++) {
      Results row = rows[i];
      double elevation = row.elevation.toDouble();
      double lat = row.location!.lat.toDouble();
      double lng = row.location!.lng.toDouble();
      site.addElevation(LatLng(lat, lng), elevation);
      if (i == rows.length - 1) {
        site.finishedDownloadingElevations = true;
      }
    }
  }
}
