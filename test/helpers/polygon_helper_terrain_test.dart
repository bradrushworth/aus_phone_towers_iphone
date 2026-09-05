import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/pathloss/terrain_coverage.dart';

/// Tests for [PolygonHelper.applyTerrainHoles], the pure per-rung shadow-hole assembly extracted
/// out of the duplicated terrain wiring in `createBasicPolygon` and
/// `GetLicenceHRP.getLicenceHRPData` (Task F5). Deliberately free of Flutter widgets: it exercises
/// only [DeviceDetails]'s terrain-hole store and [ShadowHoles] geometry, both plain Dart, so no
/// TestWidgetsFlutterBinding is needed.
const LatLng _site = LatLng(-35.28, 149.13);

/// Flat-earth stand-in for GetLicenceHRP.travel: 1 km = 0.009 degrees.
LatLng _flat(double bearing, double km) => LatLng(
      _site.latitude + km * 0.009 * math.cos(bearing * math.pi / 180),
      _site.longitude + km * 0.009 * math.sin(bearing * math.pi / 180),
    );

TerrainCoverageResult _shadowed(double outer, double near, double far) =>
    TerrainCoverageResult(outer, [Shadow(near, far)]);

TerrainCoverageResult _clear(double outer) => TerrainCoverageResult(outer, const []);

DeviceDetails _device() => DeviceDetails(networkType: NetworkType.LTE);

void main() {
  group('PolygonHelper.applyTerrainHoles', () {
    const List<double> bearings = [10.0, 12.5, 15.0];

    test('builds a hole ring for a rung shadowed on every bearing, none for a clear rung', () {
      final device = _device();
      final coverageByRung = <List<TerrainCoverageResult>>[
        [_shadowed(10, 4, 8), _shadowed(10, 4, 8), _shadowed(10, 4, 8)], // rung 0: shadowed
        [_clear(10), _clear(10), _clear(10)], // rung 1: clear
      ];

      PolygonHelper.applyTerrainHoles(_site, device, bearings, coverageByRung, _flat);

      final holes0 = device.terrainHoles(0);
      expect(holes0, isNotEmpty,
          reason: 'rung 0 has a shadow on every bearing, so it should get a hole ring');
      for (final ring in holes0) {
        expect(ring.length, greaterThanOrEqualTo(3),
            reason: 'google_maps_flutter drops holes with fewer than 3 points anyway');
      }
      expect(device.terrainHoles(1), isEmpty, reason: 'rung 1 has no shadows, so no holes');
    });

    test('a fresh sweep replaces stale holes rather than merging with the previous one', () {
      final device = _device();

      PolygonHelper.applyTerrainHoles(
        _site,
        device,
        bearings,
        [
          [_shadowed(10, 4, 8), _shadowed(10, 4, 8), _shadowed(10, 4, 8)],
        ],
        _flat,
      );
      expect(device.terrainHoles(0), isNotEmpty);

      // A later sweep along the same bearings finds the path clear now (e.g. the terrain data
      // changed). The stale rung-0 ring must be gone, not merged with the new (empty) answer.
      PolygonHelper.applyTerrainHoles(
        _site,
        device,
        bearings,
        [
          [_clear(10), _clear(10), _clear(10)],
        ],
        _flat,
      );
      expect(device.terrainHoles(0), isEmpty,
          reason: 'a fresh sweep must replace the previous holes, not merge with them');
    });

    test('a rung whose coverage list is misaligned with bearings draws no holes', () {
      final device = _device();

      PolygonHelper.applyTerrainHoles(
        _site,
        device,
        bearings,
        [
          [_shadowed(10, 4, 8)], // length 1, mismatched with 3 bearings: a cancelled/partial pass
        ],
        _flat,
      );

      expect(device.terrainHoles(0), isEmpty,
          reason: 'a cancelled or partial pass must draw no holes rather than misaligned ones');
    });

    test('clears every previously-set rung, even one absent from the new sweep', () {
      final device = _device();
      // Simulate a stale rung 3 left over from a wider signal-strength selection.
      device.setTerrainHoles(3, [
        [_flat(0, 1), _flat(90, 1), _flat(180, 1)],
      ]);
      expect(device.terrainHoles(3), isNotEmpty);

      // The new sweep only covers rungs 0-1 (a narrower signal-strength selection).
      PolygonHelper.applyTerrainHoles(
        _site,
        device,
        bearings,
        [
          [_clear(10), _clear(10), _clear(10)],
        ],
        _flat,
      );

      expect(device.terrainHoles(3), isEmpty,
          reason: 'applyTerrainHoles must clear the whole device, not just the rungs it rebuilds');
    });
  });

  group('PolygonHelper.needsGoogleElevation', () {
    // Task F6: the site_terrain request now fires in both modes, so a row can finish loading
    // while terrain mode is off (the default at every app start). If the user then turns terrain
    // mode on, site.terrainRequested is already true and the request-guard in
    // queryForSignalPolygon never re-fires — this pure truth table is what notices that case and
    // starts the Google Elevation fallback instead of leaving GetLicenceHRP's wait spinning.
    test('terrain mode off -> never needed, regardless of load state', () {
      expect(PolygonHelper.needsGoogleElevation(false, false, false), isFalse);
      expect(PolygonHelper.needsGoogleElevation(false, true, false), isFalse);
    });

    test('terrain mode on but the row has not finished loading -> not yet', () {
      expect(PolygonHelper.needsGoogleElevation(true, false, false), isFalse);
    });

    test('terrain mode on, row loaded, elevations already finished -> not needed', () {
      expect(PolygonHelper.needsGoogleElevation(true, true, true), isFalse);
    });

    test('terrain mode on, row loaded, elevations not finished -> needed', () {
      expect(PolygonHelper.needsGoogleElevation(true, true, false), isTrue);
    });
  });
}
