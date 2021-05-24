//import 'package:phonetowers/model/device_detail.dart';
//import 'package:phonetowers/model/site.dart';
//
//class CustomInfoWindow {
//  static String getSnippet(Site site) {
//    String snippet = '';
//
//    // Get site details
//    String name = site.getNameFormatted();
//
//    // Clear existing polygons on clicking the next one
//    //PolygonHelper.clearSitePatterns(false);
//
//    snippet += Site.centerEachLine(
//        name + " " + site.state + " " + site.postcode + "\n");
//    snippet += "\n";
//
//    snippet += "Site ID: ${site.siteId}";
//    snippet += "Latitude: ${site.latitude}";
//    snippet += "Longitude: ${site.longitude}";
//
//    if (site.elevation.length > 0) {
//      snippet += "Elevation: ${site.elevation}";
//    }
//    if (site.getDeviceDetailsMobile().length > 0) {
//      int height = 0;
//      for (DeviceDetails d in site.getDeviceDetailsMobile()) {
//        height += d.getTowerHeight();
//      }
//      height = (height / site.getDeviceDetailsMobile().length) as int;
//      snippet += "Tower Height: $height metres\n";
//    }
//
//    return snippet;
//  }
//
////  // Create a popup info window
////  Site site = SiteHelper.markersHashMap.get(marker);
////  if (site == null) {
////  if (CurrentCellHelper.measurementDevices.containsKey(marker)) {
////  tvDesc.setText(marker.getTitle());
////  // Draw the polygon that was measured
////  Site connectedSite = CurrentCellHelper.measurementSite.get(marker);
////  Set<DeviceDetails> connectedDevices = CurrentCellHelper.measurementDevices.get(marker);
////  CalculateConnectedTower.drawCurrentConnectedTower(marker, connectedSite, connectedDevices, true);
////  } else if (marker.equals(CustomLongClickListener.longClickLocationMarker)) {
////  tvDesc.setText(marker.getTitle());
////  CustomLongClickListener.instance().onMapLongClick(marker.getPosition());
////  } else if (CurrentCellHelper.currentCellMarkers.containsValue(marker)) {
////  tvDesc.setText(marker.getTitle());
////  // Toggle the visibility of the yellow circle
////  for (String key : CurrentCellHelper.currentCellMarkers.keySet()) {
////  if (CurrentCellHelper.currentCellMarkers.get(key).equals(marker)) {
////  CurrentCellHelper.currentCellCircles.get(key).setVisible(!CurrentCellHelper.currentCellCircles.get(key).isVisible());
////  }
////  }
////  } else {
////  tvDesc.setText(marker.getTitle());
////  }
////  return infoView;
////  }
////
////  // Reset the downloads since last click
////  SiteHelper.siteDownloadSinceLastClick.clear();
////
////  // Not switching betten terrain awareness and back
////  PolygonHelper.switchingBetweenTerrainAwareness = false;
//}
