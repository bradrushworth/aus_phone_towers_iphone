import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:phonetowers/model/site.dart';

class MapOverlay {
  Marker? marker;
  Polyline? polyline;
  Polygon? polygon;
  Circle? circle;
  Site? site;

  MapOverlay(
      {this.marker,
      this.polyline,
      this.polygon,
      this.circle,
      this.site});
}
