import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../pathloss/terrain_coverage.dart';

/// Returns the point [distanceKm] out from the site along [bearingDegrees].
typedef PointAt = LatLng Function(double bearingDegrees, double distanceKm);

/// One licence_hrp page's contribution to the shared bearingsUsed / coverageByRung accumulators
/// [GetLicenceHRP.getLicenceHRPData] builds while walking a (possibly multi-page) response. See
/// [ShadowHoles.mergePages].
class ShadowHolesPage {
  final List<double> bearingsUsed;
  final List<List<TerrainCoverageResult>> coverageByRung;

  const ShadowHolesPage({required this.bearingsUsed, required this.coverageByRung});
}

/// Turns the shadow bands [TerrainCoverage] found on each bearing into rings that the map draws
/// as holes in the coverage polygon (PolygonOptions.addHole). Adjacent bearings whose shadows
/// overlap in range share one ring, so a valley behind a ridge is one hole rather than a comb of
/// slivers. Every ring is kept strictly inside the outer polygon: far edges are shrunk to 98% of
/// that bearing's outer radius and the angular caps are clamped to the interpolated edge toward
/// the neighbouring bearing.
///
/// Ported from the Java `au.com.bitbot.phonetowers.utilities.ShadowHoles`.
class ShadowHoles {
  ShadowHoles._();

  static const double shrink = 0.98;
  static const double capDegrees = 1.0;
  static const double minNearKm = 0.05;
  static const double _capFraction = 0.8;

  static List<List<LatLng>> build(
    LatLng site,
    List<double> bearings,
    List<TerrainCoverageResult?> results,
    PointAt pointAt,
  ) {
    final runs = <_Run>[];
    for (int i = 0; i < bearings.length; i++) {
      final r = results[i];
      if (r == null || !(r.outerKm > 0)) {
        continue;
      }
      for (final s in r.shadows) {
        final near = s.nearKm > minNearKm ? s.nearKm : minNearKm;
        final farLimit = shrink * r.outerKm;
        final far = s.farKm < farLimit ? s.farKm : farLimit;
        if (far <= near) {
          continue;
        }
        _Run? target;
        for (final run in runs) {
          if (!run.closed && run.last == i - 1) {
            final lastNear = run.near.last;
            final lastFar = run.far.last;
            if (near < lastFar && far > lastNear) {
              target = run;
              break;
            }
          }
        }
        if (target == null) {
          target = _Run();
          runs.add(target);
        }
        target.index.add(i);
        target.near.add(near);
        target.far.add(far);
      }
      for (final run in runs) {
        if (!run.closed && run.last < i) {
          run.closed = true;
        }
      }
    }

    return [for (final run in runs) _ring(bearings, results, run, pointAt)];
  }

  /// Concatenates every page's bearings and per-rung coverage results, in page order, into the
  /// single accumulator [buildAllRungs] expects.
  ///
  /// **Multi-page hole assembly (bead 8uq item 1).** A licence_hrp response for a site with more
  /// sectors than fit in one `_count=360` page arrives as several pages, each handled by its own
  /// chained [GetLicenceHRP.getLicenceHRPData] call. Before this method existed, each page built
  /// its own `bearingsUsed`/`coverageByRung` from scratch and called
  /// [PolygonHelper.applyTerrainHoles] directly, so only the LAST page's shadow holes survived —
  /// every earlier page's holes were silently overwritten (not merged) the moment the next
  /// page's response was processed. This is a pure function (no Dio/network types) precisely so
  /// the merge itself — order preserved, every page's rungs concatenated — is unit-testable
  /// without async plumbing: see `test/helpers/shadow_holes_test.dart`'s `mergePages` group for
  /// two-page vectors whose rungs must merge into one.
  ///
  /// A page whose rung count doesn't match the others is not specially handled here — every page
  /// is assumed built against the same device and therefore the same rung count, which
  /// [GetLicenceHRP.getLicenceHRPData] guarantees since the polygon-point list and rung count are
  /// fixed for the whole chained request. [buildAllRungs]'s own length guard still applies per
  /// rung once merged.
  static ShadowHolesPage mergePages(List<ShadowHolesPage> pages) {
    final List<double> bearings = [];
    int rungs = 0;
    for (final page in pages) {
      if (page.coverageByRung.length > rungs) rungs = page.coverageByRung.length;
    }
    final List<List<TerrainCoverageResult>> coverageByRung = [
      for (int r = 0; r < rungs; r++) <TerrainCoverageResult>[]
    ];
    for (final page in pages) {
      bearings.addAll(page.bearingsUsed);
      for (int r = 0; r < page.coverageByRung.length; r++) {
        coverageByRung[r].addAll(page.coverageByRung[r]);
      }
    }
    return ShadowHolesPage(bearingsUsed: bearings, coverageByRung: coverageByRung);
  }

  /// One entry per rung; a rung whose result list length differs from bearings gets an empty list.
  static List<List<List<LatLng>>> buildAllRungs(
    LatLng site,
    List<double> bearings,
    List<List<TerrainCoverageResult>> coverageByRung,
    PointAt pointAt,
  ) {
    final holesByRung = <List<List<LatLng>>>[];
    for (final perBearing in coverageByRung) {
      if (perBearing.length != bearings.length) {
        // A cancelled or partial pass; no holes rather than misaligned ones.
        holesByRung.add(<List<LatLng>>[]);
        continue;
      }
      holesByRung.add(build(site, bearings, perBearing, pointAt));
    }
    return holesByRung;
  }

  static List<LatLng> _ring(
    List<double> bearings,
    List<TerrainCoverageResult?> results,
    _Run run,
    PointAt pointAt,
  ) {
    final k = run.index.length;
    final first = run.index.first;
    final last = run.index.last;
    final b1 = bearings[first];
    final bk = bearings[last];
    final nearFirst = run.near.first;
    final nearLast = run.near.last;

    // farFirstCap/farLastCap used to be clamped only by _capLimit, never re-checked against the
    // shadow's own near radius on that side: with a much shorter neighbour, _capLimit can shrink
    // the cap below "near", sending the cap-side edge back inward and self-crossing the ring (a
    // bow-tie). Clamp each cap far to at least its own near radius and, when that leaves the two
    // equal (a zero-width cap), omit both cap vertices on that side instead of drawing a
    // degenerate inward-then-outward edge.
    final firstCapLimit = _capLimit(results, first, first - 1);
    final farFirstRaw = run.far.first < firstCapLimit ? run.far.first : firstCapLimit;
    final farFirstCap = farFirstRaw > nearFirst ? farFirstRaw : nearFirst;

    final lastCapLimit = _capLimit(results, last, last + 1);
    final farLastRaw = run.far.last < lastCapLimit ? run.far.last : lastCapLimit;
    final farLastCap = farLastRaw > nearLast ? farLastRaw : nearLast;

    final firstCap = farFirstCap > nearFirst;
    final lastCap = farLastCap > nearLast;

    final ring = <LatLng>[];
    if (firstCap) {
      ring.add(pointAt(b1 - capDegrees, nearFirst));
    }
    for (int i = 0; i < k; i++) {
      ring.add(pointAt(bearings[run.index[i]], run.near[i]));
    }
    if (lastCap) {
      ring.add(pointAt(bk + capDegrees, nearLast));
      ring.add(pointAt(bk + capDegrees, farLastCap));
    }
    for (int i = k - 1; i >= 0; i--) {
      ring.add(pointAt(bearings[run.index[i]], run.far[i]));
    }
    if (firstCap) {
      ring.add(pointAt(b1 - capDegrees, farFirstCap));
    }
    return ring;
  }

  /// The outer edge [_capFraction] of the way toward the neighbouring bearing, shrunk.
  static double _capLimit(List<TerrainCoverageResult?> results, int index, int neighbour) {
    final own = results[index]!.outerKm;
    if (neighbour < 0 ||
        neighbour >= results.length ||
        results[neighbour] == null ||
        !(results[neighbour]!.outerKm > 0)) {
      return shrink * own;
    }
    final edge = own + (results[neighbour]!.outerKm - own) * _capFraction;
    return shrink * edge;
  }
}

class _Run {
  final List<int> index = [];
  final List<double> near = [];
  final List<double> far = [];
  bool closed = false;

  int get last => index.last;
}
