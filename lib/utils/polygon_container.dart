import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolygonContainer {
  int order;
  Polygon polygon;
  //List<GroundOverlay> overlays;

  PolygonContainer({this.order, this.polygon});

  int getOrder() {
    return order;
  }

  Polygon getPolygon() {
    return polygon;
  }
}
