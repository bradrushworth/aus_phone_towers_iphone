import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/pathloss/path_loss_model_provider.dart';
import 'package:phonetowers/restful/get_elevation.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/height_distance_pair.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/site_response.dart';

typedef void ShowSnackBar({
  required String message,
  Duration duration,
  bool isDismissible,
});

class GetLicenceHRP {
  static final double EARTH_MEAN_RADIUS_KILOMETERS = 6371.009;
  /// Metres added to the ground elevation to place the receiver for a terrain line-of-sight test.
  ///
  /// Renamed from HEIGHT_RECEIVER_FROM_GROUND 2026-08-26, matching the Android app. It shared that
  /// name and the value 1 with Okumura-Hata's mobile antenna reference height, an unrelated
  /// quantity that merely happens to be a similar size — this one is where a phone physically sits
  /// when asking whether a hill blocks the path.
  static final double RECEIVER_ELEVATION_OFFSET_M = 1;
  final ShowSnackBar? showSnackBar;
  // Default used only if a device has no associated site density (matches Android behaviour).
  static const CityDensity defaultRadiationModel = CityDensity.SUBURBAN;
  Logger logger = new Logger();
  Api api = Api.initialize();

  Site site;
  DeviceDetails device;
  List<List<LatLng>>? list;
  bool dataFound;
  String url;
  CancelToken? cancelToken;

  GetLicenceHRP(
      {required this.url,
      required this.site,
      required this.device,
      this.list,
      this.dataFound = false,
      this.showSnackBar,
      this.cancelToken});

  Future getLicenceHRPData() async {
    //logger.d('get licence HRP url $url');

    if (PolygonHelper.calculateTerrain) {
      //showSnackBar(message: "Downloading tower AND terrain data...");
    } else {
      //showSnackBar(message: "Downloading tower radiation patterns...");
    }

    SiteResponse? rawResponse;
    // Set right before (and only immediately before) this page hands off to a
    // continuation for the next page. If that never happens — because this was the last
    // page, or because something threw before we got there (network failure, a
    // cancelled request, or one of the force-unwraps below choking on an unexpected
    // row) — this device's chain has genuinely ended here, and the finally block below
    // must release its contribution to the per-site in-flight guard so the site can
    // never get stuck the way it could before this fix.
    bool spawnedNextPageChain = false;

    try {
      rawResponse =
          await api.getLicenceHRPData(url, cancelToken: cancelToken);

      // Api.getLicenceHRPData swallows every DioException (network failure, timeout, 5xx,
      // a genuinely cancelled request) and returns null rather than throwing. A null
      // response here must NOT be treated the same as a genuine "zero rows" answer: a
      // successful zero-row response legitimately falls back to the circular estimate
      // below, but a failed fetch must not, or a transient network hiccup on a real
      // directional site paints a misleading omnidirectional disc instead of just
      // skipping that device this time. See createBasicPolygon dispatch note below.
      final bool fetchFailed = rawResponse == null;
      if (fetchFailed) {
        logger.e(
            'PolygonHelper: GetLicenceHRP: fetch failed (no response) for site ${site.siteId}, device ${device.sddId}, url=$url');
      }

      int totalRows = rawResponse?.restify?.rows?.length ?? 0;

      // A licence can legitimately have ZERO licence_hrp rows (e.g. device 12876553,
      // surfaced when the 2026-08-22 cell_mapping re-baseline started selecting it). This
      // used to early-return here, skipping the createBasicPolygon fallback below entirely —
      // the tower was silently drawn with no coverage polygon at all. Flow through instead:
      // with no rows, dataFound stays false and the fallback draws the estimated pattern,
      // exactly like a missing registration identifier does. Mirrors the Java app.
      if (totalRows > 0) {
        dataFound = true;
      }

      double freqInMHz = 1.0 * device.frequency! / 1000 / 1000;

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

      // Server rows arrive at a fixed base resolution (2 rows sampled per point at the
      // default/medium polygon precision). Scale the row-sampling step from the user's
      // Polygon Precision setting relative to that default, so Low/High actually change
      // the point density of real (non-estimated) coverage — not just the circular
      // fallback estimate in PolygonHelper.createBasicPolygon.
      final int rowStep = rowStepForBearingIncrement(PolygonHelper.polygonBearingIncrement);

      for (int i = 0; i < totalRows; i += rowStep) {
        //Get the row
        Values? values = rawResponse!.restify!.rows![i].values;
        double start_angle = double.tryParse(values!.startAngle!.value) ?? 0;
        double? stop_angle = values.stopAngle == null
            ? null
            : double.tryParse(values.stopAngle!.value);
        double power_dBm = double.tryParse(values.power!.value) ?? 0;

        // Convert RSRP to RSSI to get more accurate results
        if (NetworkTypeHelper.isRsrp(device.getNetworkType())) {
          //power_dBm += TranslateFrequencies.convertLteRsrpToRssi(device.bandwidth);
        }

        // Place the vertex at the middle of the sector this row measures, using the sector's
        // own width rather than a constant. This used to add a fixed 1.25 degrees ("half of 2.5,
        // the measurement resolution with ACMA"), but ACMA does not publish at a single
        // resolution: of ~175M licence_hrp rows, 96.2% are 1 degree sectors and only 2.1% are
        // actually 2.5 degrees (the rest run 0.5-6). So the constant was right for ~2% of rows
        // and rotated the other 96% by 0.75 degrees. Mirrors the Java app's
        // GetLicenceHRP.sectorHalfWidth. Measured against the live database 2026-08-24.
        double bearing = start_angle + sectorHalfWidth(start_angle, stop_angle);
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

          // Calculate the distance the signal will travel. Use the composite
          // (mnc + networkType + density + band) lookup — see hrpDistanceKm.
          CityDensity model =
              device.getRadiationModel() ?? defaultRadiationModel;
          double distanceKm = hrpDistanceKm(
              TelcoHelper.getMnc(site.getTelco()),
              device.getNetworkType(),
              model,
              freeSpaceLoss_dBi,
              freqInMHz,
              towerHeight.toDouble());
          if (PolygonHelper.calculateTerrain) {
            distanceKm = calculateTerrainLosses(site, heightToDistance,
                distanceKm, bearing, freqInMHz.toDouble(), towerHeight);
          }

          if (distanceKm > 100) {
            distanceKm = 100;
          }

          LatLng latlng = travel(site.getLatLng(), bearing, distanceKm);
          //Log.i("GetLicenceHRP", "2: algorithm=" + radiationModel + " power_dBm="+ power_dBm + " freeSpaceLoss_dBi+dBReduction=" + (freeSpaceLoss_dBi + dBReduction) + " distanceKm=" + distanceKm);

          list![pos].add(latlng);
          pos++;
        }
      }

      device.setBearingToPowerMap(bearingToPower);

      //onPostexecute
      NextPage? nextPage = fetchFailed ? null : rawResponse!.restify!.nextPage;
      if (nextPage != null) {
        // Calling new async task to get json for next page. This continuation carries
        // forward this device's contribution to the in-flight guard, so mark that we
        // handed off before firing it — see the finally block below.
        spawnedNextPageChain = true;
        GetLicenceHRP(
                site: site,
                device: device,
                list: list,
                url: nextPage.href,
                // Carry "did any page so far have real rows" forward across pagination.
                // dataFound defaults to false on a fresh instance, and this class only ever
                // sets it true (never resets it), so without threading it through here, a
                // directional site whose LAST page happens to return zero rows would lose
                // every earlier page's real angle data and fall back to
                // createBasicPolygon's full circle below — even though `list` already holds
                // genuine HRP-derived points. This was the actual cause of a real Telstra
                // site (St George QLD, issue #55) drawing an omnidirectional disc instead of
                // its directional lobes.
                dataFound: dataFound,
                showSnackBar: showSnackBar,
                cancelToken: cancelToken)
            .getLicenceHRPData();
      } else {
        if (dataFound) {
          // Draw the polygon once the whole shape is downloaded
          PolygonHelper().createPolygon(list!, site, device);
        } else if (!fetchFailed) {
          // Genuinely zero rows (or no registration identifier, handled earlier in
          // PolygonHelper.queryForSignalPolygon) — draw the estimated circular pattern.
          PolygonHelper().createBasicPolygon(device, site, list!);
        } else {
          // The fetch failed and no earlier page (if any) found real data either. Draw
          // nothing rather than a circular estimate that would misrepresent a directional
          // site's real coverage as omnidirectional.
          logger.e(
              'PolygonHelper: GetLicenceHRP: skipping polygon for site ${site.siteId}, device ${device.sddId} - fetch failed, no fallback drawn');
        }
      }
    } finally {
      // Release this device's contribution to the per-site in-flight guard on ANY
      // termination of this page's processing — success (no more pages) or a thrown
      // exception (network failure, cancellation, bad row data) — as long as we didn't
      // just hand off to a next-page continuation, which carries the contribution
      // forward instead. SiteHelper.finishSiteDownload only actually clears the
      // site-level guard once every device chain started for this site has terminated.
      if (!spawnedNextPageChain) {
        SiteHelper.finishSiteDownload(site);
      }
    }
  }

  /// Converts the Polygon Precision setting (a bearing step in degrees, see
  /// [PolygonHelper.polygonBearingIncrement]) into a row-sampling step for the server's
  /// licence HRP rows, which arrive at a fixed base resolution — 2 rows sampled per point
  /// at the default/medium precision ([PolygonHelper.BEARING_INCREMENT]). Pure and static
  /// so it's unit-testable without a server response.
  static int rowStepForBearingIncrement(double bearingIncrement) {
    final int step =
        (2 * bearingIncrement / PolygonHelper.BEARING_INCREMENT).round();
    return step < 1 ? 1 : step;
  }

  /// Width assumed for a licence_hrp sector when the row carries no usable stop_angle.
  /// 1 degree is what 96.2% of published rows use.
  static const double kDefaultSectorWidthDegrees = 1.0;

  /// Half the angular width of the sector a licence_hrp row measures, i.e. how far past
  /// [startAngle] that row's vertex belongs.
  ///
  /// Derived from the row's own stop_angle because ACMA publishes a mix of resolutions
  /// (1, 2, 2.5, 3, 0.5 and 4-6 degrees all occur). Falls back to
  /// [kDefaultSectorWidthDegrees] when stop_angle is absent or unusable, so a partial response
  /// degrades to the dominant case. Mirrors the Java app's GetLicenceHRP.sectorHalfWidth.
  static double sectorHalfWidth(double startAngle, double? stopAngle) {
    double width = kDefaultSectorWidthDegrees;
    if (stopAngle != null && !stopAngle.isNaN) {
      double measured = stopAngle - startAngle;
      // The last sector of a pattern wraps through north (e.g. 359 -> 0).
      if (measured < 0) {
        measured += 360;
      }
      // Ignore nonsense (zero-width rows, or a whole-circle span from a malformed row);
      // a sector wider than a semicircle is not a radiation pattern sample.
      if (measured > 0 && measured <= 180) {
        width = measured;
      }
    }
    return width / 2;
  }

  // Distance in km.
  // The Okumura-Hata / COST-231-Hata analytic formulas are now delegated to the pluggable
  // PathLossModel (see package:phonetowers/pathloss/). The active model is learned from real
  // observations fetched from the server; until that completes (or if it fails), the learned
  // model falls back to the analytic Hata/COST-231 formulas, preserving the original behaviour.
  static double calculateDistance(
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    return PathLossModelProvider.calculateDistance(
        density, levelInDb, freqInMHz, height);
  }

  /// Context-aware overload (see PathLossModel.calculateDistanceWithContext). Selects the
  /// learned coefficients for the (mnc, networkType, band, density) stratum, falling back to
  /// density-only / analytic inside the model when no composite coefficients exist yet.
  static double calculateDistanceWithContext(int mnc, NetworkType networkType,
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    return PathLossModelProvider.calculateDistanceWithContext(
        mnc, networkType, density, levelInDb, freqInMHz, height);
  }

  /// Distance (km) for one licence_hrp sample, as drawn by the real-pattern polygon loop.
  ///
  /// MUST use the composite (mnc + networkType + density + frequency-band) overload: since
  /// the 2026-08-22 trainer re-baseline the server publishes ONLY composite coefficient
  /// groups, so a density-only lookup finds nothing and silently falls back to raw analytic
  /// Okumura-Hata — drawing real coverage polygons several times too large (3.8x for a
  /// 778 MHz LTE cell, 12x+ for 3.5 GHz NR, which additionally missed the 3GPP 38.901
  /// anchor that only the composite path applies). Static and pure so it is unit-testable;
  /// mirrors PolygonHelper.createBasicPolygon and the connected-tower mapping path.
  static double hrpDistanceKm(int mnc, NetworkType networkType,
      CityDensity density, double levelInDb, double freqInMHz, double height) {
    return calculateDistanceWithContext(
        mnc, networkType, density, levelInDb, freqInMHz, height);
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
    // The Earth's Refractive Index
    final double K = 0.8; //1.33;

    final LatLng siteLatLon = site.getLatLng();
    double transmitterHeight = site.getElevation(siteLatLon) + towerHeight;

    final LatLng receiverLatLon =
        travel(siteLatLon, bearing, transmissionDistance);
    double receiverHeight =
        site.getElevation(receiverLatLon) + RECEIVER_ELEVATION_OFFSET_M;
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
