import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/get_elevation.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/height_distance_pair.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/site_response.dart';

import 'translate_frequencies.dart';

typedef void ShowSnackBar({String message});

class GetLicenceHRP {
  static final double EARTH_MEAN_RADIUS_KILOMETERS = 6371.009;
  static final double HEIGHT_RECEIVER_FROM_GROUND = 1;
  final ShowSnackBar showSnackBar;
  static CityDensity radiationModel = CityDensity.SUBURBAN;
  Logger logger = new Logger();
  Api api = Api.initialize();

  Site site;
  DeviceDetails device;
  List<List<LatLng>> list;
  bool dataFound = false;
  String url;
  CancelToken cancelToken;

  GetLicenceHRP(
      {@required this.url,
      @required this.site,
      @required this.device,
      this.list,
      this.dataFound,
      this.showSnackBar,
      this.cancelToken})
      : assert(url != null, "Url should not be empty"),
        assert(site != null, "site should not be empty"),
        assert(device != null, "device should not be empty");

  Future getLicenceHRPData() async {
    //logger.d('get licence HRP url $url');

    if (PolygonHelper.calculateTerrain) {
      //showSnackBar(message: "Downloading tower AND terrain data...");
    } else {
      //showSnackBar(message: "Downloading tower radiation patterns...");
    }

    SiteReponse rawReponse =
        await api.getLicenceHRPData(url, cancelToken: cancelToken);

    int totalRows = rawReponse?.restify?.rows?.length ?? 0;

    //If no data found for this telco then don't do anything
    if (totalRows == 0) {
      return;
    }

    dataFound = true;

    double freqInMHz = 1.0 * device.frequency / 1000 / 1000;

    int towerHeight = device.getTowerHeight();

    if (PolygonHelper.calculateTerrain) {
      // Wait for the site elevation data to be downloaded
      while (!site.finishedDownloadingElevations) {
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    // Draw appropriate signal strength
    List<int> polygons =
        NetworkTypeHelper.getNetworkBars(device.getNetworkType());

    // Record the power output in each direction
    Map<double, double> bearingToPower = Map<double, double>();

    for (int i = 0; i < totalRows; i += 2) {
      //Get the row
      Values values = rawReponse.restify.rows[i].values;
      double start_angle = double.tryParse(values.startAngle.value) ?? 0;
      //double stop_angle = row.getJSONObject("stop_angle").getDouble("value");
      double power_dBm = double.tryParse(values.power.value) ?? 0;

      // Convert RSRP to RSSI to get more accurate results
      if (device.getNetworkType() == NetworkType.LTE) {
        power_dBm +=
            TranslateFrequencies.convertLteRsrpToRssi(device.bandwidth);
      }

      // 1.25 is half of 2.5, which is the measurement resolution with ACMA
      double bearing = start_angle + 1.25;
      bearingToPower[bearing] = power_dBm;

      Set<HeightDistancePair> heightToDistance = {};
      int hillHeight = 0;
      if (PolygonHelper.calculateTerrain) {
        // Is the tower on top of a hill?
        heightToDistance = site.getHeightsAlongBearing(bearing);
        hillHeight = site.getSiteHillElevation(heightToDistance);
        if (hillHeight < 0) {
          hillHeight = 0;
        }
      }

      int pos = 0;
      for (int p = 0;
          p <= PolygonHelper.getPolygonSignalStrengthPosition();
          p++) {
        int receiver_dBm = polygons[p];
        double freeSpaceLoss_dBi = power_dBm - receiver_dBm;

        // Calculate the distance the signal will travel
        double distanceKm = calculateDistance(radiationModel, freeSpaceLoss_dBi,
            freqInMHz, towerHeight.toDouble());
        if (PolygonHelper.calculateTerrain) {
          distanceKm = calculateTerrainLosses(site, heightToDistance,
              distanceKm, bearing, freqInMHz.toDouble(), towerHeight);
        }

        if (distanceKm > 100) {
          distanceKm = 100;
        }

        LatLng latlng = travel(site.getLatLng(), bearing, distanceKm);
        //Log.i("GetLicenceHRP", "2: algorithm=" + radiationModel + " power_dBm="+ power_dBm + " freeSpaceLoss_dBi+dBReduction=" + (freeSpaceLoss_dBi + dBReduction) + " distanceKm=" + distanceKm);

        list[pos].add(latlng);
        pos++;
      }
    }

    device.setBearingToPowerMap(bearingToPower);

    //onPostexecute
    NextPage nextPage = rawReponse.restify.nextPage;
    if (nextPage != null) {
      // Calling new async task to get json for next page
      GetLicenceHRP(
              site: site,
              device: device,
              list: list,
              url: nextPage.href,
              showSnackBar: showSnackBar,
              cancelToken: cancelToken)
          .getLicenceHRPData();
    } else {
      if (dataFound) {
        // Draw the polygon once the whole shape is downloaded
        PolygonHelper().createPolygon(list, site, device);
      } else {
        // If we can't do any better, lets create a simple circular polygon
        PolygonHelper().createBasicPolygon(device, site, list);
      }
    }
  }

  // Distance in km
  static double calculateDistance(
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    double hb =
        height; // base station antenna height above local terrain height [m]
    double hm =
        HEIGHT_RECEIVER_FROM_GROUND; // mobile station antenna height above local terrain height [m]
    double fc = freqInMHz;

    // http://www.comlab.hut.fi/opetus/333/2004_2005_slides/Path_loss_models
    double A = 69.55 + 26.16 * log10(fc) - 13.82 * log10(hb);
    double B = 44.9 - 6.55 * log10(hb);

    if (density == CityDensity.METRO) {
      // COST 231-Hata model
      // For medium to small cities
      double E = (1.1 * log10(fc) - 0.7) * hm - (1.56 * log10(fc) - 0.8);
      double F = 46.3 + 33.9 * log10(fc) - 13.82 * log10(hb);
      // 0 dB medium sized cities and suburban areas
      // 3 dB metropolitan areas
      double G = 3;
      // LdB = F + B * log10(R) – E + G
      double R = math.pow(10, (levelInDb + E - F - G) / B);
      return R;
    } else if (density == CityDensity.URBAN && freqInMHz >= 300) {
      // Okumura-Hata model
      // For large cities, fc >= 300MHz
      double E = 3.2 * math.pow(log10(11.7554 * hm), 2) - 4.97;
      // LdB = F + B * log10(R) – E + G
      double R = math.pow(10, (levelInDb + E - A) / B);
      return R;
    } else if (density == CityDensity.URBAN) {
      // Okumura-Hata model
      // For large cities, fc < 300MHz
      double E = 8.29 * math.pow(log10(1.54 * hm), 2) - 1.1;
      // LdB = F + B * log10(R) – E + G
      double R = math.pow(10, (levelInDb + E - A) / B);
      return R;
    } else if (density == CityDensity.MEDIUM) {
      // Okumura-Hata model
      // For medium to small cities
      double E = (1.1 * log10(fc) - 0.7) * hm - (1.56 * log10(fc) - 0.8);
      // LdB = A + B * log10(R) - E;
      double R = math.pow(10, (levelInDb + E - A) / B);
      return R;
    } else if (density == CityDensity.SUBURBAN) {
      // Okumura-Hata model
      // Suburban areas
      double C = 2 * math.pow(log10(fc / 28), 2) + 5.4;
      // Reach seems slightly too far, decrease by 4.42 dB since
      // mean absolute error = 4.42 dB in urban environment
      C -= 4.42;
      // LdB = A + B * log10(R) - C;
      double R = math.pow(10, (levelInDb + C - A) / B);
      return R;
    } else if (density == CityDensity.OPEN) {
      // Okumura-Hata model
      // Open areas
      double D = 4.78 * math.pow(log10(fc), 2) - 18.33 * log10(fc) + 40.94;
      // Reach seems slightly too far, decrease by 4.42 dB since
      // mean absolute error = 4.42 dB in urban environment
      D -= 4.42 * 2;
      // LdB = A + B * log10(R) - D;
      double R = math.pow(10, (levelInDb + D - A) / B);
      return R;
    } else {
      return 0;
    }
  }

  // Distance in km
  static LatLng travel(LatLng start, double initialBearing, double distance) {
    double bR = toRadians(initialBearing);
    double lat1R = toRadians(start.latitude);
    double lon1R = toRadians(start.longitude);
    double dR = distance / EARTH_MEAN_RADIUS_KILOMETERS;

    double a = math.sin(dR) * math.cos(lat1R);
    double lat2 = math.asin(math.sin(lat1R) * math.cos(dR) + a * math.cos(bR));
    double lon2 = lon1R +
        math.atan2(
            math.sin(bR) * a, math.cos(dR) - math.sin(lat1R) * math.sin(lat2));
    return LatLng(toDegrees(lat2), toDegrees(lon2));
  }

  static double toRadians(x) {
    return x * (math.pi) / 180;
  }

  static double toDegrees(double angrad) {
    return angrad * 180.0 / (math.pi);
  }

  static double calculateTerrainLosses(
      final Site site,
      final Set<HeightDistancePair> heightToDistance,
      final double transmissionDistance,
      final double bearing,
      final double freqInMHz,
      final int towerHeight) {
    //Log.d("GetLicenceHRP", "\n\n");
    //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: transmissionDistance="+transmissionDistance);
    final polygonHelper = PolygonHelper();
    // The Earth's Refractive Index
    final double K = 0.8; //1.33;

    final LatLng siteLatLon = site.getLatLng();
    double transmitterHeight = site.getElevation(siteLatLon) + towerHeight;

    final LatLng receiverLatLon =
        travel(siteLatLon, bearing, transmissionDistance);
    double receiverHeight =
        site.getElevation(receiverLatLon) + HEIGHT_RECEIVER_FROM_GROUND;
    // Don't calculate the angle looking down because the radiation is projected over objects
    //if (receiverHeight < transmitterHeight) {
    //receiverHeight = transmitterHeight;
    //}

    // The tan gradient of LOS
    final double MM =
        (transmitterHeight - receiverHeight) / (transmissionDistance * 1000);

    // Only calculate the highest obstacles to save CPU cycles
    final int limitSamples = (heightToDistance.length / 4).round() + 1;
    int samples = 0;
    var sortedHeightToDistance = heightToDistance.toList();
    sortedHeightToDistance.sort();
    sortedHeightToDistance = sortedHeightToDistance.reversed.toList();
    for (HeightDistancePair pair in sortedHeightToDistance) {
      samples++;
      if (samples > limitSamples) break;

      // Height of sample above mean sea level
      double sampleHeight = pair.height;
      // Distance before obstacle
      double distanceBefore = pair.distance;
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: sampleHeight="+sampleHeight+", distanceBefore="+distanceBefore);
      // Distance after obstacle
      double distanceAfter = transmissionDistance - distanceBefore;
      // Don't sample distances beyond the receiver
      if (distanceAfter < 0) continue;
      // The Earth bulge in metres
      double h = (distanceBefore * distanceAfter) / (12.75 * K);
      // Height of the LOS (ASL) at distanceAfter
      double LL = (MM * (distanceAfter * 1000)) + receiverHeight;
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: distanceAfter=" + distanceAfter + " h=" + h + " LL=" + LL);
      // Fresnel Radius at LL
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: F1...=" + (distanceBefore * distanceAfter));
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: F1...=" + (transmissionDistance * freqInMHz));
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: F1...=" + ((distanceBefore * distanceAfter) / (transmissionDistance * freqInMHz)));
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: F1...=" + Math.sqrt((distanceBefore * distanceAfter) / (transmissionDistance * freqInMHz)));
      double F1 = 548 *
          math.sqrt((distanceBefore * distanceAfter) /
              (transmissionDistance * freqInMHz));

      // Clearance between F1 and Mean Sea Level
      double C1 = LL - h - F1;

      // If the signal is not blocked at all, move to the next point
      if (LL - h >= sampleHeight) {
        //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: decision: Clear: sampleHeight="+sampleHeight+" < C1="+C1);
        continue;
      }

      // If the signal is blocked completely, return the distance to this point
      if (C1 < sampleHeight) {
        //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: Blocked completely: LL="+LL+" - h="+h+" <= sampleHeight="+sampleHeight);
        //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: Blocked completely: C1="+C1+" <= sampleHeight="+sampleHeight);
        //return distanceBefore;
        int i = getClosestSampleDistanceIndex(transmissionDistance);
        //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: decision: Blocked completely: i="+i+" GetElevation.SAMPLE_DISTANCES[i]="+GetElevation.SAMPLE_DISTANCES[i]);
        return calculateTerrainLosses(site, heightToDistance,
            GetElevation.SAMPLE_DISTANCES[i], bearing, freqInMHz, towerHeight);
      }

      // If the signal is partially blocked...

      // Obstacle intrusion into F1
      double H = MM * (distanceAfter * 1000) + (receiverHeight - sampleHeight);
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: H=" + H);
      // Ratio of signal loss
      double n = (H / F1);
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: n=" + n);

      double v = n * math.sqrt(2) * -1;
      // dB measurement of signal loss
      double Jv = 0;
      if (n > 0.6) {
        //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: n is greater than 0.6 !!!");
        int i = getClosestSampleDistanceIndex(transmissionDistance);
        //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: decision: n > 0.6: i="+i+" GetElevation.SAMPLE_DISTANCES[i]="+GetElevation.SAMPLE_DISTANCES[i]);
        return calculateTerrainLosses(site, heightToDistance,
            GetElevation.SAMPLE_DISTANCES[i], bearing, freqInMHz, towerHeight);
      } else if (n > -1.4) {
        Jv = 6.4 + 20 * (math.log(math.sqrt(v * v + 1 + v) / math.log(10)));
      } else {
        Jv = 13 + 20 * (math.log(v) / math.log(10));
      }
      //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: Jv=" + Jv);

      // If a significant loss was incurred on the transmission
      if (Jv > 6) {
        // Recalculate the distance factoring in the terrain
        //double tempDistance = transmissionDistance - calculateFreeSpaceDistance(Jv, freqInMHz);
        ////Log.d("GetLicenceHRP",  "elevation: calculateTerrainLosses: Jv="+Jv+", transmissionDistance="+transmissionDistance);
        //if (tempDistance < newDistance) {
        //    newDistance = tempDistance;
        //}
        ////Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: Jv="+Jv+", distanceBefore="+distanceBefore+", transmissionDistance="+transmissionDistance);
        //newDistance = distanceBefore;
        //continue;
        int i = getClosestSampleDistanceIndex(transmissionDistance);
        //Log.d("GetLicenceHRP", "elevation: calculateTerrainLosses: decision: Jv: i="+i+" GetElevation.SAMPLE_DISTANCES[i]="+GetElevation.SAMPLE_DISTANCES[i]);
        return calculateTerrainLosses(site, heightToDistance,
            GetElevation.SAMPLE_DISTANCES[i], bearing, freqInMHz, towerHeight);
      }
    }
    return transmissionDistance;
  }

  static int getClosestSampleDistanceIndex(double transmissionDistance) {
    var polygonHelper = PolygonHelper();
    //Arrays.binarySearch(GetElevation.SAMPLE_DISTANCES, 0, GetElevation.SAMPLE_DISTANCES.length, transmissionDistance) - 1
    for (int i = 0; i < GetElevation.SAMPLE_DISTANCES.length; i++) {
      if (GetElevation.SAMPLE_DISTANCES[i] < transmissionDistance) {
        if (i + 1 == GetElevation.SAMPLE_DISTANCES.length ||
            GetElevation.SAMPLE_DISTANCES[i + 1] >= transmissionDistance) {
          return i;
        }
      }
    }
    return 0;
  }
}

enum CityDensity { METRO, URBAN, MEDIUM, SUBURBAN, OPEN }
