import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phonetowers/helpers/camera_restore_helper.dart';
import 'package:phonetowers/utils/app_constants.dart';

void main() {
  group('encodeCameraPosition / resolveRestoredCameraPosition (issue #26)', () {
    test('round-trips a normal camera position', () {
      final CameraPosition original = CameraPosition(
        target: LatLng(-33.865143, 151.209900),
        zoom: 15.5,
      );

      final String json = encodeCameraPosition(original);
      final CameraPosition? restored = resolveRestoredCameraPosition(
        storedJson: json,
        followGPSActive: false,
      );

      expect(restored, isNotNull);
      expect(restored!.target.latitude, original.target.latitude);
      expect(restored.target.longitude, original.target.longitude);
      expect(restored.zoom, original.zoom);
    });

    test('Follow GPS active -> never restores, even with valid saved data', () {
      final String json = encodeCameraPosition(
        CameraPosition(target: LatLng(-33.8, 151.2), zoom: 12),
      );

      final CameraPosition? restored = resolveRestoredCameraPosition(
        storedJson: json,
        followGPSActive: true,
      );

      expect(restored, isNull);
    });

    test('nothing saved yet (null) -> null', () {
      expect(
        resolveRestoredCameraPosition(storedJson: null, followGPSActive: false),
        isNull,
      );
    });

    test('nothing saved yet (empty string) -> null', () {
      expect(
        resolveRestoredCameraPosition(storedJson: '', followGPSActive: false),
        isNull,
      );
    });

    test('malformed / truncated JSON (mid-write kill) -> null, does not throw', () {
      expect(
        () => resolveRestoredCameraPosition(
          storedJson: '{"lat": -33.8, "lng": 151',
          followGPSActive: false,
        ),
        returnsNormally,
      );
      expect(
        resolveRestoredCameraPosition(
          storedJson: '{"lat": -33.8, "lng": 151',
          followGPSActive: false,
        ),
        isNull,
      );
    });

    test('missing required fields -> null', () {
      expect(
        resolveRestoredCameraPosition(
          storedJson: '{"lat": -33.8}',
          followGPSActive: false,
        ),
        isNull,
      );
    });

    test('all-zero placeholder position -> null (not meaningfully useful)', () {
      final String json = encodeCameraPosition(
        CameraPosition(target: LatLng(0, 0), zoom: kDefaultZoom),
      );

      expect(
        resolveRestoredCameraPosition(storedJson: json, followGPSActive: false),
        isNull,
      );
    });

    test('missing zoom falls back to kDefaultZoom', () {
      final CameraPosition? restored = resolveRestoredCameraPosition(
        storedJson: '{"lat": -33.8, "lng": 151.2}',
        followGPSActive: false,
      );

      expect(restored, isNotNull);
      expect(restored!.zoom, kDefaultZoom);
    });
  });
}
