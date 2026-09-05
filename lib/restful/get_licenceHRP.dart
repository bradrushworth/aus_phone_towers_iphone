import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
import 'package:phonetowers/pathloss/terrain_coverage.dart';

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

      // The nightly site_terrain row (Task F6) feeds the effective antenna height in BOTH
      // modes, so give it a short bounded wait here regardless of calculateTerrain: most rows
      // answer well within this, and a genuinely absent/slow row must never stall a
      // non-terrain polygon draw. Bounded (not "wait until terrainLoaded") so a request that
      // never even starts (see PolygonHelper.needsGoogleElevation's comment) can't hang this
      // device's polygon forever.
      final DateTime terrainRowDeadline = DateTime.now().add(const Duration(seconds: 2));
      while (site.terrainRequested &&
          !site.terrainLoaded &&
          DateTime.now().isBefore(terrainRowDeadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (PolygonHelper.calculateTerrain) {
        // Wait for the site elevation data to be downloaded (via the served site_terrain
        // profile, or the Google Elevation fallback it starts when no profile arrives).
        // Bounded to 30 seconds so a stuck or never-started download cannot hang this
        // device's polygon forever.
        final DateTime elevationDeadline = DateTime.now().add(const Duration(seconds: 30));
        while (shouldKeepWaitingForElevation(site, DateTime.now(), elevationDeadline)) {
          await Future.delayed(Duration(milliseconds: 500));
        }
        if (!site.finishedDownloadingElevations) {
          logger.w(
              'PolygonHelper: GetLicenceHRP: timed out after 30s waiting for elevation data for site ${site.siteId}, device ${device.sddId} — proceeding without terrain');
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

      // Terrain-mode per-rung coverage results, aligned 1:1 with bearingsUsed below, so
      // ShadowHoles can rebuild the shadow rings once every bearing has been walked.
      final List<double> bearingsUsed = [];
      final List<List<TerrainCoverageResult>> coverageByRung = [
        for (int p = 0; p <= PolygonHelper.getPolygonSignalStrengthPosition(); p++)
          <TerrainCoverageResult>[]
      ];

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
        bearingsUsed.add(bearing);

        Set<HeightDistancePair> heights =
            PolygonHelper.calculateTerrain ? site.getHeightsAlongBearing(bearing) : {};

        // Antenna height above the average terrain toward this bearing (TerrainHeight) - the
        // same quantity the trainer fitted the coefficients against, used in BOTH modes. Terrain
        // mode used to add the site's height above the median profile here on top of coefficients
        // that already averaged hilltop sites into the stratum (counted twice).
        final double effectiveHeight = site.effectiveHeightM(towerHeight.toDouble(), bearing);

        // Calculate the distance the signal will travel. Use the composite
        // (mnc + networkType + density + band) lookup — see hrpDistanceKm.
        CityDensity model = device.getRadiationModel() ?? defaultRadiationModel;
        // The path-loss model with this transmitter's context bound, so calculateTerrainCoverage
        // can re-solve the distance after charging terrain to the link budget.
        double solver(double budgetDb) => hrpDistanceKm(
            TelcoHelper.getMnc(site.getTelco()),
            device.getNetworkType(),
            model,
            budgetDb,
            freqInMHz,
            effectiveHeight);

        // I2: one memoising terrain loss per bearing, shared by every rung below - see the
        // comment on terrainExcessLossForBearing.
        final ExcessLoss? terrainLoss = PolygonHelper.calculateTerrain
            ? terrainExcessLossForBearing(
                site, heights, bearing, freqInMHz.toDouble(), towerHeight)
            : null;

        int pos = 0;
        for (int p = 0;
            p <= PolygonHelper.getPolygonSignalStrengthPosition();
            p++) {
          int receiver_dBm = polygons[p];
          double freeSpaceLoss_dBi = power_dBm - receiver_dBm;

          double distanceKm;
          if (PolygonHelper.calculateTerrain) {
            final TerrainCoverageResult coverage = TerrainCoverage.evaluate(
                freeSpaceLoss_dBi, solver, terrainLoss!, GetElevation.SAMPLE_DISTANCES);
            distanceKm = coverage.outerKm;
            coverageByRung[p].add(coverage);
          } else {
            distanceKm = solver(freeSpaceLoss_dBi);
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

      // I3: only clear/rebuild shadow holes in terrain mode. Clearing them unconditionally, as
      // before, wiped out a previous terrain pass's holes the moment terrain mode was toggled
      // off. A terrain toggle itself never redraws from the polygon cache —
      // switchTerrainAwareness() always calls refreshPolygons(false) — but a later same-mode
      // refresh with cachingPolygons true (a signal-strength position or precision change from
      // the layers sheet / option menu) redraws this device's polygon from cache (the cache
      // path in PolygonHelper.queryForSignalPolygon) with no recomputation, so it would draw it
      // with no holes at all.
      if (PolygonHelper.calculateTerrain) {
        PolygonHelper.applyTerrainHoles(
          site.getLatLng(),
          device,
          bearingsUsed,
          coverageByRung,
          (b, km) => travel(site.getLatLng(), b, km),
        );
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

  /// Whether the terrain-mode elevation wait in [getLicenceHRPData] should keep looping: the
  /// download hasn't finished yet, and the bounded [deadline] hasn't passed. Extracted as a
  /// pure, static function (rather than inlining `DateTime.now()` into the while condition) so
  /// the 30-second timeout boundary is unit-testable without an actual 30-second wait.
  static bool shouldKeepWaitingForElevation(Site site, DateTime now, DateTime deadline) {
    return !site.finishedDownloadingElevations && now.isBefore(deadline);
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

  /// The Earth's effective refractive index used for the bulge term.
  static const double EARTH_REFRACTIVE_INDEX = 0.8;

  /// The coverage distance along [bearing] once terrain is taken into account: the outer radius
  /// of [calculateTerrainCoverage], discarding the shadow intervals.
  ///
  /// **Terrain is charged to the link budget as diffraction loss, not applied as a hard
  /// cut-off** (GitHub issue #56). Originally an obstructed bearing was walked down
  /// [GetElevation.SAMPLE_DISTANCES] until it reached a rung whose path was clear, and the answer
  /// was always one of those rungs. Because that ladder does not depend on the signal level being
  /// drawn, every contour of a site - MAX through WEAK - collapsed onto the SAME rung the moment
  /// anything blocked the path: in hilly country (the report came from Tasmania) all four
  /// coverage rings landed on top of each other, so the chosen signal strength made no visible
  /// difference. It also cut coverage dead at the first ridge, with no allowance for the
  /// diffraction that in reality carries a signal well past it, and it could only shrink the
  /// distance, so coverage that returned on a far slope past a shadowed valley could never be
  /// drawn. This has been replaced with [TerrainCoverage.evaluate], which charges every elevation
  /// sample independently and returns the full set of covered intervals.
  ///
  /// [linkBudgetDb] is the path loss this contour can afford, i.e. the transmitted power minus
  /// the receiver threshold, before terrain. [solver] resolves a link budget to a distance with
  /// no terrain applied.
  ///
  /// Minor 9: no production caller remains (superseded by [TerrainCoverage.evaluate] via
  /// [calculateTerrainCoverage]/[terrainExcessLossForBearing]); kept only for its existing unit
  /// tests, hence [visibleForTesting].
  @visibleForTesting
  static double calculateTerrainLosses(
      final Site site,
      final Set<HeightDistancePair> heightToDistance,
      final double linkBudgetDb,
      final DistanceSolver solver,
      final double bearing,
      final double freqInMHz,
      final int towerHeight) {
    return calculateTerrainCoverage(
            site, heightToDistance, linkBudgetDb, solver, bearing, freqInMHz, towerHeight)
        .outerKm;
  }

  /// Coverage along [bearing] with terrain charged per sample point ([TerrainCoverage]): the
  /// outer radius plus the shadow bands behind ridges, which [PolygonHelper] draws as holes.
  ///
  /// Kept for existing single-shot callers (e.g. the `calculateTerrainLosses` tests): builds its
  /// own [ExcessLoss] via [terrainExcessLossForBearing]. A caller evaluating several rungs along
  /// the SAME bearing should build one loss with that method and call [TerrainCoverage.evaluate]
  /// for each rung instead (I2), so the ~19-22 knife-edge questions per rung are asked once per
  /// bearing rather than once per rung.
  ///
  /// Minor 9: no production caller remains — [PolygonHelper] and [GetLicenceHRP] itself now go
  /// straight through [terrainExcessLossForBearing] + [TerrainCoverage.evaluate] per rung. Kept
  /// only for [calculateTerrainLosses] and its existing unit tests, hence [visibleForTesting].
  @visibleForTesting
  static TerrainCoverageResult calculateTerrainCoverage(
      final Site site,
      final Set<HeightDistancePair> heightToDistance,
      final double linkBudgetDb,
      final DistanceSolver solver,
      final double bearing,
      final double freqInMHz,
      final int towerHeight) {
    final ExcessLoss loss =
        terrainExcessLossForBearing(site, heightToDistance, bearing, freqInMHz, towerHeight);
    return TerrainCoverage.evaluate(linkBudgetDb, solver, loss, GetElevation.SAMPLE_DISTANCES);
  }

  /// A memoising [ExcessLoss] for one bearing (I2). The knife-edge loss at a distance does not
  /// depend on the rung's link budget - only on distance, bearing and the (fixed, per-bearing)
  /// terrain profile - so building this once here instead of once per rung avoids re-running
  /// [TerrainCoverage.evaluate]'s ~19-22 questions, and the [Site.getElevation] linear scan of the
  /// elevation map behind each one, once per rung for the same answers. Computed once here and
  /// shared by every rung's [TerrainCoverage.evaluate] call.
  static ExcessLoss terrainExcessLossForBearing(
      final Site site,
      final Set<HeightDistancePair> heightToDistance,
      final double bearing,
      final double freqInMHz,
      final int towerHeight) {
    final double transmitterGroundElevationM = site.getElevation(site.getLatLng());
    final Map<double, double> cache = {};
    return (double distanceKm) => cache.putIfAbsent(
        distanceKm,
        () => terrainExcessLossDb(site, heightToDistance, distanceKm, bearing, freqInMHz,
            towerHeight,
            transmitterGroundElevationM: transmitterGroundElevationM));
  }

  static bool _isUsableDistance(double distanceKm) {
    return distanceKm.isFinite && distanceKm > 0;
  }

  /// The worst knife-edge diffraction loss, in dB, imposed by the terrain between the site and a
  /// receiver [distanceKm] away along [bearing]. Zero when the path is clear.
  ///
  /// Every sample is examined because obstacles are not the highest samples on a rising profile;
  /// 19 per bearing is cheap.
  ///
  /// [transmitterGroundElevationM] is `site.getElevation(site.getLatLng())` - constant for the
  /// whole polygon. Pass it (see [terrainExcessLossForBearing]) when evaluating many distances
  /// along one bearing so the elevation map isn't rescanned for it every time; left null (the
  /// default) it is computed here, which keeps this signature usable directly by tests and other
  /// single-shot callers.
  static double terrainExcessLossDb(
      final Site site,
      final Set<HeightDistancePair> heightToDistance,
      final double distanceKm,
      final double bearing,
      final double freqInMHz,
      final int towerHeight,
      {final double? transmitterGroundElevationM}) {
    if (!_isUsableDistance(distanceKm) || heightToDistance.isEmpty) {
      return 0;
    }

    final LatLng siteLatLon = site.getLatLng();
    final double transmitterHeight =
        (transmitterGroundElevationM ?? site.getElevation(siteLatLon)) + towerHeight;

    final LatLng receiverLatLon = travel(siteLatLon, bearing, distanceKm);
    final double receiverHeight =
        site.getElevation(receiverLatLon) + RECEIVER_ELEVATION_OFFSET_M;

    // The tan gradient of the line of sight, transmitter down to receiver.
    final double gradient =
        (transmitterHeight - receiverHeight) / (distanceKm * 1000);

    double worstLossDb = 0;

    for (HeightDistancePair pair in heightToDistance) {
      // Height of sample above mean sea level
      final double sampleHeight = pair.height;
      // Distance before obstacle
      final double distanceBefore = pair.distance;
      // Distance after obstacle
      final double distanceAfter = distanceKm - distanceBefore;
      // Don't sample the site itself, or distances beyond the receiver
      if (distanceAfter <= 0 || distanceBefore <= 0) continue;

      // The Earth bulge in metres
      final double bulge =
          (distanceBefore * distanceAfter) / (12.75 * EARTH_REFRACTIVE_INDEX);
      // Height of the line of sight (ASL) above the obstacle
      final double lineOfSight =
          (gradient * (distanceAfter * 1000)) + receiverHeight;
      // First Fresnel zone radius at the obstacle, in metres
      final double fresnelRadius = 548 *
          math.sqrt(
              (distanceBefore * distanceAfter) / (distanceKm * freqInMHz));
      if (!(fresnelRadius > 0)) continue;

      // Positive when the line of sight passes above the obstacle.
      final double clearance = lineOfSight - bulge - sampleHeight;
      // Only obstacles that actually break the line of sight are charged for. An obstacle that
      // merely intrudes into the Fresnel zone without blocking it is left alone: the trained
      // path-loss coefficients were fitted against real observations over real ground, so that
      // loss is already in them and charging it again would double-count.
      if (clearance >= 0) continue;
      // ITU-R P.526 diffraction parameter: positive when the obstacle intrudes.
      final double v = -clearance * math.sqrt(2) / fresnelRadius;

      final double lossDb = knifeEdgeLossDb(v);
      if (lossDb > worstLossDb) worstLossDb = lossDb;
    }

    return worstLossDb;
  }

  /// Single knife-edge diffraction loss in dB for the ITU-R P.526 diffraction parameter [v].
  /// Zero below v = -0.78, where the obstacle is clear of the first Fresnel zone and costs
  /// nothing.
  static double knifeEdgeLossDb(double v) {
    if (v <= -0.78) {
      return 0;
    }
    return 6.9 +
        20 *
            (math.log(math.sqrt((v - 0.1) * (v - 0.1) + 1) + v - 0.1) /
                math.ln10);
  }
}

enum CityDensity { METRO, URBAN, MEDIUM, SUBURBAN, OPEN }
