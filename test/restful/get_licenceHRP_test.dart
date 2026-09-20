import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/pathloss/analytic_path_loss_model.dart';
import 'package:phonetowers/pathloss/contour_coefficients.dart';
import 'package:phonetowers/pathloss/contour_model.dart';
import 'package:phonetowers/pathloss/nr3gpp_path_loss_model.dart';
import 'package:phonetowers/pathloss/path_loss_coefficients.dart';
import 'package:phonetowers/pathloss/path_loss_model_provider.dart';
import 'package:phonetowers/pathloss/terrain_coverage.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

void main() {
  group('GetLicenceHRP.hrpDistanceKm', () {
    // Regression tests for the licence_hrp polygon loop drawing REAL coverage patterns
    // several times too large: it used the density-only calculateDistance overload, but
    // since the 2026-08-22 trainer re-baseline the server publishes ONLY composite
    // (density|mnc|networkType|band) coefficient groups. The density-only lookup found
    // nothing and silently fell back to raw analytic Okumura-Hata (3.8x too far for a
    // 778 MHz LTE cell, 12x+ for 3.5 GHz NR, measured against the trained calibration).
    // The loop must use the SAME composite lookup as PolygonHelper.createBasicPolygon
    // and the connected-tower mapping path.
    tearDown(() {
      // Restore the untrained default so other tests see the analytic fallback.
      PathLossModelProvider()
          .overrideCoefficientsForTesting(PathLossCoefficients.empty());
    });

    test('applies composite calibration when only composite groups exist (server shape)',
        () {
      const double b0 = -0.35828640617403174; // URBAN|1|LTE|LOW, live server 2026-08-23
      const double b1 = 0.824930925974219;
      final PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      coeffs.setComposite(1, NetworkType.LTE, 'LOW', CityDensity.URBAN,
          [b0, b1, 0.0, 0.0], 34579, 0.19);
      PathLossModelProvider().overrideCoefficientsForTesting(coeffs);

      const double level = 170.0, freq = 778.0, height = 30.0;
      final double logAnchor =
          (level - AnalyticPathLossModel.hataInterceptDb(CityDensity.URBAN, freq, height)) /
              AnalyticPathLossModel.hataSlopeDb(height);
      final double calibrated = math.pow(10.0, b0 + b1 * logAnchor).toDouble();

      final double actual = GetLicenceHRP.hrpDistanceKm(
          1, NetworkType.LTE, CityDensity.URBAN, level, freq, height);

      expect(actual, closeTo(calibrated, 1e-9),
          reason: 'HRP polygons must use the trained composite calibration');

      // And it must NOT be the raw analytic fallback (~3.8x larger here).
      final double analytic = AnalyticPathLossModel()
          .calculateDistance(CityDensity.URBAN, level, freq, height);
      expect(actual, lessThan(analytic / 3),
          reason: 'density-only lookup would silently fall back to analytic Hata');
    });

    test('routes NR to the 3GPP 38.901 anchor when no NR coefficients are trained', () {
      // Server-shaped coefficients: trained, but no NR groups at all.
      final PathLossCoefficients coeffs = PathLossCoefficients(
          true, 57.0, PathLossCoefficients.formHataCalibration);
      coeffs.setComposite(1, NetworkType.LTE, 'LOW', CityDensity.URBAN,
          [-0.36, 0.82, 0.0, 0.0], 1000, 0.19);
      PathLossModelProvider().overrideCoefficientsForTesting(coeffs);

      const double level = 165.0, freq = 3595.0, height = 30.0;
      final double expected = Nr3gppPathLossModel()
          .calculateDistance(CityDensity.URBAN, level, freq, height);
      final double actual = GetLicenceHRP.hrpDistanceKm(
          1, NetworkType.NR, CityDensity.URBAN, level, freq, height);
      expect(actual, closeTo(expected, 1e-9),
          reason: 'NR must anchor on 3GPP 38.901, not sub-3GHz Hata');
    });
  });

  group('GetLicenceHRP.rowStepForBearingIncrement', () {
    // Regression test: the Polygon Precision menu previously had no effect on real
    // (non-estimated) coverage, because the server-row sampling loop hardcoded a step
    // of 2 regardless of PolygonHelper.polygonBearingIncrement. This pins the mapping
    // from each precision preset to its resulting row step.
    test('medium (default) preset preserves the original hardcoded step of 2', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionMedium),
        2,
      );
    });

    test('low preset samples fewer rows (coarser, faster)', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionLow),
        4,
      );
    });

    test('high preset samples every row (finer, smoother)', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionHigh),
        1,
      );
    });

    test('never returns a step below 1, even for a very small increment', () {
      expect(GetLicenceHRP.rowStepForBearingIncrement(0.01), 1);
    });

    test('scales monotonically with the bearing increment', () {
      final int lowStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionLow);
      final int mediumStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionMedium);
      final int highStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionHigh);
      expect(highStep, lessThan(mediumStep));
      expect(mediumStep, lessThan(lowStep));
    });
  });

  group('GetLicenceHRP.shouldKeepWaitingForElevation', () {
    // Task F6: bounds the terrain-mode elevation wait to 30 seconds so a download that never
    // starts (or never finishes) cannot hang a device's polygon forever. Pure and static so the
    // deadline boundary is testable without a real 30-second wait.
    late Site site;

    setUp(() {
      site = Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN);
    });

    test('not finished and before the deadline -> keep waiting', () {
      final DateTime now = DateTime(2026, 1, 1, 12, 0, 0);
      final DateTime deadline = now.add(const Duration(seconds: 30));
      site.finishedDownloadingElevations = false;

      expect(GetLicenceHRP.shouldKeepWaitingForElevation(site, now, deadline), isTrue);
    });

    test('deadline has passed -> stop waiting even though still unfinished', () {
      final DateTime deadline = DateTime(2026, 1, 1, 12, 0, 0);
      final DateTime now = deadline.add(const Duration(milliseconds: 1));
      site.finishedDownloadingElevations = false;

      expect(GetLicenceHRP.shouldKeepWaitingForElevation(site, now, deadline), isFalse);
    });

    test('already finished before the deadline -> stop waiting', () {
      final DateTime now = DateTime(2026, 1, 1, 12, 0, 0);
      final DateTime deadline = now.add(const Duration(seconds: 30));
      site.finishedDownloadingElevations = true;

      expect(GetLicenceHRP.shouldKeepWaitingForElevation(site, now, deadline), isFalse);
    });

    test('exactly at the deadline -> stop waiting (isBefore is strict)', () {
      final DateTime deadline = DateTime(2026, 1, 1, 12, 0, 0);
      site.finishedDownloadingElevations = false;

      expect(GetLicenceHRP.shouldKeepWaitingForElevation(site, deadline, deadline), isFalse);
    });
  });

  group('GetLicenceHRP.isCancelledFor', () {
    // bead 8uq item 2: the terrain waits in getLicenceHRPData must honour BOTH the Dio
    // CancelToken and the stale-generation check (requestIsCurrent), not just the latter one
    // that already existed. Pure and static so the combination is unit-testable with fakes,
    // without a real CancelToken or async wait.

    test('neither signal fired -> not cancelled', () {
      expect(
        GetLicenceHRP.isCancelledFor(
            cancelTokenCancelled: false, requestIsCurrentResult: true),
        isFalse,
      );
    });

    test('the CancelToken alone fired -> cancelled', () {
      expect(
        GetLicenceHRP.isCancelledFor(
            cancelTokenCancelled: true, requestIsCurrentResult: true),
        isTrue,
      );
    });

    test('requestIsCurrent alone says false -> cancelled', () {
      expect(
        GetLicenceHRP.isCancelledFor(
            cancelTokenCancelled: false, requestIsCurrentResult: false),
        isTrue,
      );
    });

    test('no requestIsCurrent callback supplied (null) -> only the CancelToken matters', () {
      expect(
        GetLicenceHRP.isCancelledFor(cancelTokenCancelled: false, requestIsCurrentResult: null),
        isFalse,
      );
      expect(
        GetLicenceHRP.isCancelledFor(cancelTokenCancelled: true, requestIsCurrentResult: null),
        isTrue,
      );
    });

    test('both signals fired -> cancelled', () {
      expect(
        GetLicenceHRP.isCancelledFor(
            cancelTokenCancelled: true, requestIsCurrentResult: false),
        isTrue,
      );
    });
  });

  group('GetLicenceHRP.computeModelV2Vertices', () {
    // Path-loss model v2 (LTE/NR only). A small synthetic table, not the bundled one, so these
    // numbers don't move if the table is recalibrated -- see contour_power_test.dart for the
    // worked example pinned against the real bundled table.
    final ContourCoefficients coefficients = ContourCoefficients(
      classes: const <String, ContourClassRow>{
        'SUBURBAN|MID': ContourClassRow(0.85, -4.0),
      },
      pooled: const <String, ContourClassRow>{
        'MID': ContourClassRow(0.85, -4.0),
      },
      nrTddOffsetByMnc: const <String, double>{'default': 0.0},
      typicalPerReEirpDbmByTech: const <String, Map<String, double>>{},
      gatePassed: true,
    );
    const LatLng origin = LatLng(0, 0);
    LatLng travelTo(double bearing, double distanceKm) =>
        GetLicenceHRP.travel(origin, bearing, distanceKm);

    // Common fixture values shared by most cases below: usable LTE EIRP, MID band (not a TDD
    // band, so the carrier mnc is irrelevant to these), SUBURBAN.
    const NetworkType networkType = NetworkType.LTE;
    const int mnc = 0;
    const CityDensity density = CityDensity.SUBURBAN;
    const double freqInMHz = 1865.0;
    const double bandwidthHz = 20000000;
    const double eirpW = 1000.0;
    const double towerHeightM = 30.0;

    test('an empty row list returns null and adds nothing to any of the output collections',
        () {
      final List<List<LatLng>> list = [[]];
      final Map<double, double> bearingToPower = {};
      final List<double> bearingsUsed = [];
      final List<List<TerrainCoverageResult>> coverageByRung = [[]];

      final ModelV2DrawSummary? result = GetLicenceHRP.computeModelV2Vertices(
        rows: const [],
        rowStep: 1,
        networkType: networkType,
        mnc: mnc,
        density: density,
        freqInMHz: freqInMHz,
        bandwidthHz: bandwidthHz,
        eirpW: eirpW,
        towerHeightM: towerHeightM,
        coefficients: coefficients,
        rungs: const [-95],
        list: list,
        effectiveHeightForBearing: (_) => 30.0,
        terrainLossForBearing: (_) => null,
        travelTo: travelTo,
        bearingToPower: bearingToPower,
        bearingsUsed: bearingsUsed,
        coverageByRung: coverageByRung,
      );

      expect(result, isNull);
      expect(list[0], isEmpty);
      expect(bearingToPower, isEmpty);
      expect(bearingsUsed, isEmpty);
      expect(coverageByRung[0], isEmpty);
    });

    test('two pages whose strongest bearing is on the second page: the first page\'s vertex '
        'is computed against the OVERALL maximum, not its own page\'s maximum', () {
      // Row 0 stands in for a row from the first page; row 1 (stronger) for a row from the
      // second, accumulated into one list exactly as getLicenceHRPData now does before calling
      // this function.
      const HrpPowerRow firstPageRow = HrpPowerRow(0.0, 1.0, -70.0);
      const HrpPowerRow secondPageStrongestRow = HrpPowerRow(180.0, 181.0, -50.0);
      final List<List<LatLng>> list = [[]];

      final ModelV2DrawSummary? result = GetLicenceHRP.computeModelV2Vertices(
        rows: [firstPageRow, secondPageStrongestRow],
        rowStep: 1,
        networkType: networkType,
        mnc: mnc,
        density: density,
        freqInMHz: freqInMHz,
        bandwidthHz: bandwidthHz,
        eirpW: eirpW,
        towerHeightM: towerHeightM,
        coefficients: coefficients,
        rungs: const [-95],
        list: list,
        effectiveHeightForBearing: (_) => 30.0,
        terrainLossForBearing: (_) => null,
        travelTo: travelTo,
        bearingToPower: {},
        bearingsUsed: [],
        coverageByRung: [[]],
      );

      expect(result, isNotNull);
      expect(result!.maxHrpPowerDbm, -50.0, reason: 'the maximum must be the SECOND page\'s row');

      final ContourModel model = ContourModel(coefficients);
      const double firstPageBearing = 0.5; // 0.0 + sectorHalfWidth(0.0, 1.0)
      final double correctDistanceKm = model.distanceKm(networkType, mnc, density, freqInMHz,
          30.0, result.basePowerDbm + (-70.0 - -50.0) - (-95.0));
      // What the first row's distance would have been had its OWN power wrongly been treated
      // as this transmitter's maximum (relativePatternDb == 0) -- the bug this deferral fixes.
      final double wrongDistanceIfOwnPageWereMax = model.distanceKm(
          networkType, mnc, density, freqInMHz, 30.0, result.basePowerDbm - (-95.0));

      expect(correctDistanceKm, lessThan(wrongDistanceIfOwnPageWereMax));
      expect(
          list[0][0], _closeToLatLng(travelTo(firstPageBearing, correctDistanceKm)));
    });

    test('the row step samples the ACCUMULATED list (what were originally separate pages), '
        'not a per-page index', () {
      final List<HrpPowerRow> rows = [
        const HrpPowerRow(0.0, 1.0, -70.0),
        const HrpPowerRow(90.0, 91.0, -71.0),
        const HrpPowerRow(180.0, 181.0, -72.0),
        const HrpPowerRow(270.0, 271.0, -73.0),
      ];
      final List<double> bearingsUsed = [];

      GetLicenceHRP.computeModelV2Vertices(
        rows: rows,
        rowStep: 2,
        networkType: networkType,
        mnc: mnc,
        density: density,
        freqInMHz: freqInMHz,
        bandwidthHz: bandwidthHz,
        eirpW: eirpW,
        towerHeightM: towerHeightM,
        coefficients: coefficients,
        rungs: const [-95],
        list: [[]],
        effectiveHeightForBearing: (_) => 30.0,
        terrainLossForBearing: (_) => null,
        travelTo: travelTo,
        bearingToPower: {},
        bearingsUsed: bearingsUsed,
        coverageByRung: [[]],
      );

      // Only rows[0] and rows[2] are visited (step 2 over 4 accumulated rows) -- rows[1] and
      // rows[3], which would have been the second row of each original page, are skipped.
      expect(bearingsUsed, [closeTo(0.5, 1e-9), closeTo(180.5, 1e-9)]);
    });

    test('a directional site whose GSM/UMTS/other transmitter uses the untouched legacy loop: '
        'ContourModel.supports (the predicate getLicenceHRPData branches on) is false for '
        'every network type except LTE and NR, so those types never reach this function and '
        'keep exactly the legacy hrpDistanceKm arithmetic tested above', () {
      for (final NetworkType nt in <NetworkType>[
        NetworkType.GSM,
        NetworkType.UMTS,
        NetworkType.CDMA,
        NetworkType.NB_IOT,
        NetworkType.OTHER,
        NetworkType.UNKNOWN,
      ]) {
        expect(ContourModel.supports(nt), isFalse, reason: '$nt');
      }
    });

    test(
        'call-site level: an NR transmitter at 3510 MHz (a TDD band, n78) is drawn smaller for '
        'Telstra (mnc 1, +13.2 dB) than for Vodafone (mnc 3, +4.3 dB), while an LTE transmitter '
        'at the same frequency is identical for both -- the extra loss never applies to LTE',
        () {
      // The real carrier-specific TDD losses from the bundled table (spec section 7). A small
      // standalone table here, not the bundled one, so this pins the MECHANISM -- which carrier
      // gets more loss, and that LTE never sees it -- rather than the exact calibrated numbers,
      // which contour_power_test.dart's worked example already pins against the real table.
      final ContourCoefficients tddCoefficients = ContourCoefficients(
        classes: const <String, ContourClassRow>{'SUBURBAN|HIGH': ContourClassRow(0.82, -8.18)},
        pooled: const <String, ContourClassRow>{'HIGH': ContourClassRow(0.82, -8.18)},
        nrTddOffsetByMnc: const <String, double>{'default': 9.2, '1': 13.2, '3': 4.3},
        typicalPerReEirpDbmByTech: const <String, Map<String, double>>{},
        gatePassed: true,
      );
      const double freqInMHz3510 = 3510.0; // >= 3300 MHz: n78, a TDD band.
      const int telstraMnc = 1;
      const int vodafoneMnc = 3;

      double distanceFor(NetworkType nt, int forMnc) {
        final ModelV2DrawSummary summary = GetLicenceHRP.computeModelV2Vertices(
          rows: const [HrpPowerRow(0.0, 1.0, -70.0)],
          rowStep: 1,
          networkType: nt,
          mnc: forMnc,
          density: density,
          freqInMHz: freqInMHz3510,
          bandwidthHz: bandwidthHz,
          eirpW: eirpW,
          towerHeightM: towerHeightM,
          coefficients: tddCoefficients,
          rungs: const [-95],
          list: [[]],
          effectiveHeightForBearing: (_) => 30.0,
          terrainLossForBearing: (_) => null,
          travelTo: travelTo,
          bearingToPower: {},
          bearingsUsed: [],
          coverageByRung: [[]],
        )!;
        return summary.boresightDistanceKmByRung.single;
      }

      final double nrTelstraKm = distanceFor(NetworkType.NR, telstraMnc);
      final double nrVodafoneKm = distanceFor(NetworkType.NR, vodafoneMnc);
      expect(nrTelstraKm, lessThan(nrVodafoneKm),
          reason: 'Telstra\'s larger extra loss (+13.2 dB) must draw a smaller NR contour than '
              'Vodafone\'s (+4.3 dB)');

      final double lteTelstraKm = distanceFor(NetworkType.LTE, telstraMnc);
      final double lteVodafoneKm = distanceFor(NetworkType.LTE, vodafoneMnc);
      expect(lteTelstraKm, closeTo(lteVodafoneKm, 1e-9),
          reason: 'the extra loss never applies to LTE, regardless of carrier');
    });

    test('when terrainLossForBearing returns a loss, each rung is resolved through '
        'TerrainCoverage.evaluate and recorded in coverageByRung', () {
      final List<List<TerrainCoverageResult>> coverageByRung = [[]];

      final ModelV2DrawSummary? result = GetLicenceHRP.computeModelV2Vertices(
        rows: const [HrpPowerRow(0.0, 1.0, -70.0)],
        rowStep: 1,
        networkType: networkType,
        mnc: mnc,
        density: density,
        freqInMHz: freqInMHz,
        bandwidthHz: bandwidthHz,
        eirpW: eirpW,
        towerHeightM: towerHeightM,
        coefficients: coefficients,
        rungs: const [-95],
        list: [[]],
        effectiveHeightForBearing: (_) => 30.0,
        terrainLossForBearing: (_) => (double distanceKm) => 0.0, // clear path, zero loss
        travelTo: travelTo,
        bearingToPower: {},
        bearingsUsed: [],
        coverageByRung: coverageByRung,
      );

      expect(result, isNotNull);
      expect(coverageByRung[0], hasLength(1));
    });

    test('the summary reports base power, max HRP power, k, offset, class and one boresight '
        'distance per rung', () {
      final ModelV2DrawSummary result = GetLicenceHRP.computeModelV2Vertices(
        rows: const [HrpPowerRow(0.0, 1.0, -70.0), HrpPowerRow(180.0, 181.0, -50.0)],
        rowStep: 1,
        networkType: networkType,
        mnc: mnc,
        density: density,
        freqInMHz: freqInMHz,
        bandwidthHz: bandwidthHz,
        eirpW: eirpW,
        towerHeightM: towerHeightM,
        coefficients: coefficients,
        rungs: const [-95, -105],
        list: [[], []],
        effectiveHeightForBearing: (_) => 30.0,
        terrainLossForBearing: (_) => null,
        travelTo: travelTo,
        bearingToPower: {},
        bearingsUsed: [],
        coverageByRung: [[], []],
      )!;

      expect(result.densityBand, 'SUBURBAN|MID');
      expect(result.k, 0.85);
      expect(result.offsetDb, -4.0);
      expect(result.maxHrpPowerDbm, -50.0);
      expect(result.boresightDistanceKmByRung, hasLength(2));

      final ContourModel model = ContourModel(coefficients);
      expect(
        result.boresightDistanceKmByRung[0],
        closeTo(
            model.distanceKm(
                networkType, mnc, density, freqInMHz, towerHeightM, result.basePowerDbm - -95),
            1e-9),
      );
      expect(
        result.boresightDistanceKmByRung[1],
        closeTo(
            model.distanceKm(
                networkType, mnc, density, freqInMHz, towerHeightM, result.basePowerDbm - -105),
            1e-9),
      );
      expect(result.nrTddOffsetAppliedDb, 0.0, reason: 'LTE never carries the extra 5G loss');
    });
  });
}

/// Matches a [LatLng] whose latitude and longitude are both within a small tolerance of
/// [expected] -- floating-point equality on the two independently-derived doubles that make up
/// a lat/lng pair is too strict.
Matcher _closeToLatLng(LatLng expected, {double delta = 1e-9}) => predicate<LatLng>((actual) {
      return (actual.latitude - expected.latitude).abs() < delta &&
          (actual.longitude - expected.longitude).abs() < delta;
    }, 'is close to $expected');
