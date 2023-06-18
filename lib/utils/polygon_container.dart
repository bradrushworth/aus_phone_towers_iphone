import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

class PolygonContainer {
  int order;
  Polygon polygon;
  //List<GroundOverlay> overlays;

  PolygonContainer({required this.order, required this.polygon});

  int getOrder() {
    return order;
  }

  Polygon getPolygon() {
    return polygon;
  }
}
