import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phonetowers/helpers/shadow_holes.dart';
import 'package:phonetowers/pathloss/terrain_coverage.dart';

const LatLng _site = LatLng(-35.28, 149.13);

/// Flat-earth stand-in for GetLicenceHRP.travel: 1 km = 0.009 degrees.
LatLng _flat(double bearing, double km) => LatLng(
      _site.latitude + km * 0.009 * math.cos(bearing * math.pi / 180),
      _site.longitude + km * 0.009 * math.sin(bearing * math.pi / 180),
    );

TerrainCoverageResult _result(double outer, [List<double> nearFar = const []]) {
  final shadows = <Shadow>[];
  for (int i = 0; i < nearFar.length; i += 2) {
    shadows.add(Shadow(nearFar[i], nearFar[i + 1]));
  }
  return TerrainCoverageResult(outer, shadows);
}

double _kmFromSite(LatLng p) {
  final dy = (p.latitude - _site.latitude) / 0.009;
  final dx = (p.longitude - _site.longitude) / 0.009;
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  test('adjacent overlapping shadows become one ring', () {
    final bearings = [10.0, 12.5, 15.0];
    final r = <TerrainCoverageResult?>[
      _result(10, [4, 8]),
      _result(10, [4.5, 8.5]),
      _result(10, [4, 7]),
    ];
    final holes = ShadowHoles.build(_site, bearings, r, _flat);
    expect(holes.length, 1);
    expect(holes[0].length, 2 + 3 + 3 + 2);
    for (final p in holes[0]) {
      final km = _kmFromSite(p);
      expect(km, greaterThanOrEqualTo(4 - 1e-6));
      expect(km, lessThanOrEqualTo(8.5 + 1e-6));
    }
  });

  test('a clear bearing splits runs', () {
    final bearings = [10.0, 12.5, 15.0];
    final r = <TerrainCoverageResult?>[
      _result(10, [4, 8]),
      _result(10),
      _result(10, [4, 8]),
    ];
    expect(ShadowHoles.build(_site, bearings, r, _flat).length, 2);
  });

  test('non-overlapping ranges on adjacent bearings are separate rings', () {
    final bearings = [10.0, 12.5];
    final r = <TerrainCoverageResult?>[
      _result(10, [1, 2]),
      _result(10, [6, 8]),
    ];
    expect(ShadowHoles.build(_site, bearings, r, _flat).length, 2);
  });

  test('shadow is clamped inside the outer radius', () {
    final bearings = [10.0];
    final r = <TerrainCoverageResult?>[_result(5, [3, 9])];
    final holes = ShadowHoles.build(_site, bearings, r, _flat);
    expect(holes.length, 1);
    for (final p in holes[0]) {
      expect(_kmFromSite(p), lessThanOrEqualTo(5 * ShadowHoles.shrink + 1e-6));
    }
  });

  test('cap is clamped to the neighbour edge', () {
    // Bearing 10 has a deep shadow; bearing 12.5 (no shadow) only reaches 3 km, so the cap
    // toward it must stay under the interpolated outer edge.
    final bearings = [10.0, 12.5];
    final r = <TerrainCoverageResult?>[
      _result(10, [4, 8]),
      _result(3),
    ];
    final hole = ShadowHoles.build(_site, bearings, r, _flat)[0];
    final capLimit = ShadowHoles.shrink * (10 + (3 - 10) * 0.8);
    // The two cap-side points at bearing 11 are the 4th and 5th vertices of a single-bearing ring.
    expect(_kmFromSite(hole[3]), lessThanOrEqualTo(capLimit + 1e-6));
  });

  test('degenerate shadows are dropped', () {
    final bearings = [10.0];
    final r = <TerrainCoverageResult?>[
      _result(1, [0.98, 2]),
    ];
    expect(ShadowHoles.build(_site, bearings, r, _flat), isEmpty);
    expect(ShadowHoles.build(_site, bearings, <TerrainCoverageResult?>[null], _flat), isEmpty);
    expect(ShadowHoles.build(_site, const [], const [], _flat), isEmpty);
  });

  test('degenerate cap is omitted instead of bow-tied', () {
    // Bearing 15's outer radius is tiny, so the far-side cap toward it (computed from bearing
    // 12.5, the run's last bearing) collapses below the shadow's own near radius (6). Before the
    // fix that produced a self-crossing ring (bow-tie): a cap vertex landed INSIDE the near
    // boundary on the same angular spoke. The fix omits both cap vertices on that side instead of
    // drawing the inward dip.
    final bearings = [10.0, 12.5, 15.0];
    final r = <TerrainCoverageResult?>[
      _result(10, [6, 8]),
      _result(10, [6, 8]),
      _result(0.1), // no shadow of its own; only used as the tiny neighbour outer radius
    ];
    final hole = ShadowHoles.build(_site, bearings, r, _flat)[0];

    // Both caps present would be 1 (first-near) + 2 (near fwd) + 2 (last-near, last-far) +
    // 2 (far back) + 1 (first-far) = 8 vertices; the degenerate last-side cap drops the middle
    // two, leaving 6.
    expect(hole.length, 6);

    double minKm = double.maxFinite;
    for (final p in hole) {
      minKm = math.min(minKm, _kmFromSite(p));
    }
    // No vertex may sit closer to the site than the shadow's own near radius - that inward dip
    // is exactly the bow-tie this guards against.
    expect(minKm, greaterThanOrEqualTo(6 - 1e-6), reason: 'a ring vertex fell inside the shadow\'s near radius: minKm=$minKm');
  });

  test('buildAllRungs gives an empty list for a rung whose results are misaligned', () {
    final bearings = [10.0, 12.5];
    final aligned = <TerrainCoverageResult>[
      _result(10, [4, 8]),
      _result(10, [4.5, 8.5]),
    ];
    final misaligned = <TerrainCoverageResult>[
      _result(10, [4, 8]),
    ];
    final holesByRung = ShadowHoles.buildAllRungs(_site, bearings, [aligned, misaligned], _flat);
    expect(holesByRung.length, 2);
    expect(holesByRung[0].length, 1);
    expect(holesByRung[1], isEmpty);
  });
}
