import 'package:google_maps_flutter/google_maps_flutter.dart'
    if (dart.library.js) 'package:google_maps_flutter_web/google_maps_flutter_web.dart';
import 'package:phonetowers/model/site.dart';

class MapOverlay {
  Marker marker;
  Polyline polyline;
  Polygon polygon;
  Circle circle;
  Site site;

  MapOverlay(
      {this.marker, this.polyline, this.polygon, this.circle, this.site});
}
