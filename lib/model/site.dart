import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phonetowers/helpers/get_elevation.dart';
import 'package:phonetowers/helpers/get_licenceHRP.dart';
import 'package:phonetowers/helpers/let_type_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/model/device_detail.dart';

import 'height_distance_pair.dart';

class Site {
  String siteId, name;
  int licensingAreaId = 0;
  double latitude, longitude;
  String state, postcode, elevation;
  CityDensity cityDensity;

  bool startedDownloadingElevations = false;
  bool finishedDownloadingElevations = false;

  // We split sites per telco
  Telco telco;

  // This is all the mobile transmitters on the site per telco. We need it to support concurrency.
  //List<DeviceDetails> deviceDetailsMobile = new CopyOnWriteArrayList<>();
  // This is the elevations of various points
  Map<LatLng, double> elevations = Map<LatLng, double>();

  // Does this site have an active transmitter?
  bool active = false;

  //double colour;
  double rotation, alpha;
  List<DeviceDetails> deviceDetailsMobile;

  Site(
      {@required this.telco,
      @required this.cityDensity,
      this.siteId,
      this.name,
      this.licensingAreaId = 0,
      this.latitude,
      this.longitude,
      this.state,
      this.postcode,
      this.elevation,
      this.startedDownloadingElevations = false,
      this.finishedDownloadingElevations = false,
      this.active = false,
      //this.colour,
      this.rotation,
      this.alpha,
      this.deviceDetailsMobile}) {
    //this.colour = TelcoHelper.getColour(this.telco);
    this.rotation = TelcoHelper.getRotation(this.telco);
    this.alpha = TelcoHelper.getAlpha(this.telco);
    this.deviceDetailsMobile = [];
  }

  // double getColour() {
  //   return TelcoHelper.getColour(telco);
  // }

  double getRotation() {
    return TelcoHelper.getRotation(telco);
  }

  double getAlpha() {
    return TelcoHelper.getAlpha(telco);
  }

  String getIconName() {
    return TelcoHelper.getIconName(telco);
  }

  Future<Uint8List> getIcon(int width) {
    return TelcoHelper.getIcon(telco, width);
  }

  List<DeviceDetails> getDeviceDetailsMobile() {
    return deviceDetailsMobile;
  }

  void appendActive(bool active) {
    if (active) {
      this.active = true;
    }
  }

  // bool hasTechnology(int networkType) {
  //   NetworkType networkGen = CellIdentity.getNetworkGeneration(networkType);
  //   return hasTechnology(networkGen);
  // }

  bool shouldBeVisible() {
    // Keep hidden telcos hidden
    if (SiteHelper.hideTelco.contains(this.getTelco())) {
      return false;
    }

    // Return true for sites where we don't know about the devices
    if (getDeviceDetailsMobile().isEmpty) {
      return true;
    }

    deviceLoop:
    for (DeviceDetails d in getDeviceDetailsMobile()) {
      //Log.i("Site", "shouldBeVisible(): checking site=" + this + " d=" + d);

      // Check we want to see this network type (e.g. 2G, 3G)
      if (SiteHelper.hideNetworkType.contains(d.getNetworkType())) {
        continue deviceLoop;
      }

      // Check we want to see this multiplex type
      LteType lteType = d.getLteType();
      if (lteType == LteType.NOT_LTE && !PolygonHelper.displayNotLteMultiplex) {
        continue deviceLoop;
      }
      if (lteType == LteType.TD_LTE && !PolygonHelper.displayTdMultiplex) {
        continue deviceLoop;
      }
      if (lteType == LteType.FD_LTE && !PolygonHelper.displayFdMultiplex) {
        continue deviceLoop;
      }

      // Check we want to see this frequency band
      int frequency = d.frequency / 1000 ~/ 1000;
      for (List<int> range in SiteHelper.hideFrequency) {
        if (frequency >= range[0] && frequency <= range[1]) {
          continue deviceLoop;
        }
      }

      // This site has at least one transmitter we are interested in
      return true;
    }
    // This site has zero transmitters we are interested in
    //Log.i("Site", "shouldBeVisible(): false for site=" + this);
    return false;
  }

  Telco getTelco() {
    return telco;
  }

  String getNameFormatted() {
    String name = "";
    bool newLineNumber = false;
    int tokensSinceSplit = 0;
    List<String> tokens = HtmlEscape().convert(this.name).split(" ");
    for (int i = 0; i < tokens.length; i++) {
      final numbers = RegExp(r'^[0-9-]+$');
      if (i > 1 &&
              tokensSinceSplit > 1 &&
              !newLineNumber &&
              numbers.hasMatch(tokens[i]) ||
          tokens[i].toLowerCase() == "lot") {
        name += "\n";
        newLineNumber = true;
        tokensSinceSplit = 0;
      } else if (i > 1 &&
          tokensSinceSplit > 1 &&
          tokens[i].toUpperCase() == tokens[i]) {
        name += "\n";
        tokensSinceSplit = 0;
      } else if (i > 0 &&
          (tokens[i - 1].toLowerCase() == "site" ||
              tokens[i - 1].toLowerCase() == "exchange")) {
        name += "\n";
        tokensSinceSplit = 0;
      } else if (tokensSinceSplit >= 4) {
        name += "\n";
        tokensSinceSplit = 0;
      }
      name += tokens[i] + " ";
      tokensSinceSplit++;
    }
    return name.trim();
  }

  static String centerEachLine(String text) {
    final int INFO_WINDOW_TEXT_WIDTH = 38;
    StringBuffer buffer = new StringBuffer();
    List<String> lines = new LineSplitter().convert(text);
    for (String line in lines) {
      String buffedLine = '$line';
      while (buffedLine.length < INFO_WINDOW_TEXT_WIDTH) {
        buffedLine = ' $buffedLine ';
      }
      if (buffedLine.length > INFO_WINDOW_TEXT_WIDTH &&
          buffedLine.startsWith(' ')) {
        buffedLine = buffedLine.substring(1);
      }
      buffer.write(buffedLine);
      buffer.write('\n');
    }
    return buffer.toString();
  }

  LatLng getLatLng() {
    return LatLng(latitude, longitude);
  }

  Map<String, MapEntry<DeviceDetails, bool>> getDeviceDetailsMobileBands() {
    Map<String, MapEntry<DeviceDetails, bool>> bands =
    Map<String, MapEntry<DeviceDetails, bool>>();
    for (DeviceDetails d in deviceDetailsMobile) {
      int frequency = d.frequency;
      //if (rounded) frequency = TranslateFrequencies.roundMobileFrequency(frequency);
      String emission = d.emission;
      // Ensure the key is padded to enable sorting to work correctly
      String key = '$frequency'.padLeft(12, '0') + '_' + emission;

      // Roll-up multiple transmitters so that if any are active, the frequency is active
      bool active = false;
      if (bands.containsKey(key)) {
        active = bands[key].value;
      }
      if (d.isActive()) {
        active = true;
      }

      bands[key] = MapEntry(d, active);
    }
    return bands;
  }

  int countNumberAntennaPaths(DeviceDetails d) {
    int count = countNumberAntennas(d);

    // In the absence of lookup tables on antenna specs, slant transmission indicates
    // two input ports. Important because it indicates twice the bandwidth per antenna
    // (45 deg and -45 deg orientation).
    if (d.isMIMO()) count *= 2;

    // We only care about powers of 2
    count = log2(count).toInt();
    count = math.pow(2, count).toInt();

    return count;
  }

  int countNumberAntennas(DeviceDetails referenceDevice) {
    int targetFreq = referenceDevice.frequency;
    String targetEmission = referenceDevice.emission;
    int count = 0;
    for (DeviceDetails d in deviceDetailsMobile) {
      if (d.frequency == targetFreq && d.emission == targetEmission) {
        count++;
      }
    }
    return count;
  }

  int getNetworkCapacity(DeviceDetails d) {
    int count = 1;

    if (d.getNetworkType() != NetworkType.GSM) {
      // Count the number of antennas operating on this frequency at this site
      count = countNumberAntennaPaths(d);
    }
    //Log.d("site", "getNetworkCapacity: count=" + count);

    // MIMO doubles the bandwidth every time you double the antennas
    return d.getAntennaCapacity() * count;
  }

  void addElevation(LatLng latLng, double elevation) {
    elevations.putIfAbsent(latLng, () => elevation);
  }

  Set<HeightDistancePair> getHeightsAlongBearing(double bearing) {
    return getHeightsAlongBearingWithDistanceAndBearing(
      GetElevation.SAMPLE_DISTANCES[GetElevation.SAMPLE_DISTANCES.length - 1],
      bearing,
    );
  }

  Set<HeightDistancePair> getHeightsAlongBearingWithDistanceAndBearing(double distanceKm, final double bearing) {
    final Set<HeightDistancePair> heightToDistance = {};
    for (int i = 0;
    i < GetElevation.SAMPLE_DISTANCES.length &&
        GetElevation.SAMPLE_DISTANCES[i] <= distanceKm;
    i++) {
      double distance = GetElevation.SAMPLE_DISTANCES[i];

      final LatLng sampleLatLon =
      GetLicenceHRP.travel(getLatLng(), bearing, distance);
      final double sampleHeight = getElevation(sampleLatLon);

      heightToDistance.add(
          new HeightDistancePair(height: sampleHeight, distance: distance));
      //Log.d("Site", "getHeightsAlongBearing(): sampleHeight="+sampleHeight+" distance="+distance);
    }
    return heightToDistance;
  }

  double getElevation(LatLng latLng) {
    double shortestDistance = double.maxFinite;
    double elevation = 0;
    for (LatLng haystack in elevations.keys) {
      // Lightweight distance calculation
      double dx = latLng.latitude - haystack.latitude;
      double dy = latLng.longitude - haystack.longitude;
      double distance = math.sqrt(dx * dx + dy * dy);
      // Return the closest height point
      if (distance < shortestDistance) {
        shortestDistance = distance;
        elevation = elevations[haystack];
      }
    }
    return elevation;
  }

  int getSiteHillElevation(Set<HeightDistancePair> heightToDistance) {
    int i = 0;
    for (HeightDistancePair pair in heightToDistance) {
      if (i == heightToDistance.length / 2) {
        // Return the difference in height between tower and median heights
        return (getElevation(getLatLng()) - pair.height).round();
      }
      i++;
    }
    return 0;
  }

  @override
  // Define that two persons are equal if their SSNs are equal
  bool operator ==(site) {
    return (site.siteId == siteId && site.getTelco() == getTelco());
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    return '$siteId($telco)';
  }
}
