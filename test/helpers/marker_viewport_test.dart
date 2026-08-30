import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phonetowers/helpers/marker_viewport.dart';

Marker _markerAt(String id, double lat, double lng, {bool visible = true}) {
  return Marker(
    markerId: MarkerId(id),
    position: LatLng(lat, lng),
    visible: visible,
  );
}

void main() {
  group('selectMarkersForViewport', () {
    test('drops null markers', () {
      final List<Marker?> input = <Marker?>[null, _markerAt('a', 0, 0), null];

      final Set<Marker> result = selectMarkersForViewport(
        input,
        center: null,
        zoom: 13.5,
      );

      expect(result.length, 1);
      expect(result.single.markerId, const MarkerId('a'));
    });

    test('drops invisible markers', () {
      final List<Marker?> input = <Marker?>[
        _markerAt('visible', 0, 0),
        _markerAt('hidden', 0, 0, visible: false),
      ];

      final Set<Marker> result = selectMarkersForViewport(
        input,
        center: null,
        zoom: 13.5,
      );

      expect(result.map((Marker m) => m.markerId.value), <String>['visible']);
    });

    test('null center keeps all visible markers up to cap', () {
      final List<Marker?> input = <Marker?>[
        _markerAt('a', -10, 10),
        _markerAt('b', 40, -70),
        _markerAt('c', 0, 0, visible: false),
      ];

      final Set<Marker> result = selectMarkersForViewport(
        input,
        center: null,
        zoom: 13.5,
      );

      expect(result.length, 2);
      expect(
        result.map((Marker m) => m.markerId.value).toSet(),
        <String>{'a', 'b'},
      );
    });

    test('markers outside the box are dropped, inside kept', () {
      // At zoom 13.5, halfSpan = 360 * 1.5 / 2^13.5, very small (~0.037 degrees).
      const double centerLat = -33.8688;
      const double centerLng = 151.2093;
      final LatLng center = const LatLng(centerLat, centerLng);

      final Marker near = _markerAt('near', centerLat + 0.001, centerLng + 0.001);
      final Marker far = _markerAt('far', centerLat + 10, centerLng + 10);

      final Set<Marker> result = selectMarkersForViewport(
        <Marker?>[near, far],
        center: center,
        zoom: 13.5,
      );

      expect(result.map((Marker m) => m.markerId.value).toSet(), <String>{'near'});
    });

    test('caps to the nearest markers to center when too many survive', () {
      const LatLng center = LatLng(0, 0);
      // All within the box at a very low (but clamped) zoom.
      final List<Marker?> input = <Marker?>[
        _markerAt('closest', 0.001, 0.001),
        _markerAt('middle', 0.01, 0.01),
        _markerAt('farthest', 0.05, 0.05),
      ];

      final Set<Marker> result = selectMarkersForViewport(
        input,
        center: center,
        zoom: 3,
        cap: 2,
      );

      expect(result.length, 2);
      expect(
        result.map((Marker m) => m.markerId.value).toSet(),
        <String>{'closest', 'middle'},
      );
    });

    test('label-style markers follow the same visibility/box rules', () {
      const LatLng center = LatLng(-33.8688, 151.2093);
      final Marker label = _markerAt('freq-label', -33.8688, 151.2093);
      final Marker hiddenLabel =
          _markerAt('hidden-label', -33.8688, 151.2093, visible: false);
      final Marker farLabel = _markerAt('far-label', 10, 10);

      final Set<Marker> result = selectMarkersForViewport(
        <Marker?>[label, hiddenLabel, farLabel],
        center: center,
        zoom: 13.5,
      );

      expect(result.map((Marker m) => m.markerId.value).toSet(), <String>{'freq-label'});
    });

    test('zoom is clamped to a minimum of 3 for very low zoom levels', () {
      const LatLng center = LatLng(0, 0);
      final Marker inRangeAtZoom3 = _markerAt('a', 30, 30);

      final Set<Marker> resultAtZoomZero = selectMarkersForViewport(
        <Marker?>[inRangeAtZoom3],
        center: center,
        zoom: 0,
      );
      final Set<Marker> resultAtZoomThree = selectMarkersForViewport(
        <Marker?>[inRangeAtZoom3],
        center: center,
        zoom: 3,
      );

      expect(resultAtZoomZero, resultAtZoomThree);
    });
  });
}
